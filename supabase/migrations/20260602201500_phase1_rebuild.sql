-- =====================================================================
-- Phase 1 REBUILD — clean concept-vocabulary schema + data migration
-- Design doc: docs/phase1-rebuild.md  (signed off 2026-06-02)
-- Concept:    docs/phase1-concept.md
--
-- Strategy (per the signed design):
--   * Create the genuinely-NEW concept tables: badge, forge_request,
--     project_slot, work_commitment.
--   * Resource is REBUILT ADDITIVELY (add monthly_quota + forge_request_id)
--     rather than dropped — it carries live FKs and RPCs; an in-place
--     column add preserves them and the running app.
--   * The STR ledger/account/settlement tables are KEPT under their
--     stater_* names (the live wallet reads them) and re-exposed under the
--     concept names via VIEWS (str_account, str_ledger, str_policy,
--     settlement, settlement_item) so new code can speak the concept.
--   * Old tables are NOT dropped — they are COMMENT-marked deprecated to
--     leave a rollback window. Retire happens in a later migration once the
--     new RPC layer + frontend are cut over and validated.
--
-- Idempotent: safe to re-run (create if not exists, insert ... where not
-- exists). A validation DO-block at the end RAISE NOTICEs source vs target
-- row counts. APPLY LOCALLY AND VALIDATE before any live push.
-- =====================================================================

begin;

-- =====================================================================
-- E. forge_request — unified create/update review queue
--    (created first; badge/project_slot/resource reference it)
-- =====================================================================
create table if not exists forge_request (
  id            uuid primary key default gen_random_uuid(),
  target_type   text not null check (target_type in
                  ('member_card','badge','resource','need','claim','project_done')),
  action        text not null default 'create' check (action in ('create','update')),
  target_id     uuid,                       -- update: object changed; create: backfilled on approve
  payload       jsonb not null default '{}',-- forged/updated fields
  batch_id      uuid,                       -- one forge of many badges = one batch
  fee           integer not null default 0,
  submitted_by  uuid references member (id) on delete set null,
  submitted_as  uuid references member (id) on delete set null,  -- act-as card
  status        text not null default 'submitted'
                  check (status in ('submitted','approved','rejected','cancelled')),
  reviewed_by   uuid references member (id) on delete set null,
  review_note   text,
  created_at    timestamptz not null default now(),
  settled_at    timestamptz
);
create index if not exists forge_request_status_idx on forge_request (status) where status = 'submitted';
create index if not exists forge_request_type_idx   on forge_request (target_type);
create index if not exists forge_request_batch_idx  on forge_request (batch_id) where batch_id is not null;

alter table forge_request enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='forge_request' and policyname='read_forge_request') then
    create policy read_forge_request on forge_request for select to authenticated using (true);
  end if;
end $$;
grant select on forge_request to authenticated;

-- =====================================================================
-- A. badge — Credential card (rebuilt from member_skill.certified_level)
-- =====================================================================
create table if not exists badge (
  id               uuid primary key default gen_random_uuid(),
  member_id        uuid not null references member (id) on delete cascade,
  skill_id         uuid not null references skill (id)  on delete cascade,
  level            guild_level not null,
  forged_at        timestamptz not null default now(),
  forge_request_id uuid references forge_request (id) on delete set null,
  unique (member_id, skill_id)
);
create index if not exists badge_member_idx on badge (member_id);
create index if not exists badge_skill_idx  on badge (skill_id);

alter table badge enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='badge' and policyname='read_badge') then
    create policy read_badge on badge for select to authenticated using (true);
  end if;
end $$;
grant select on badge to authenticated;

-- =====================================================================
-- D. resource — REBUILD additively (keep table, add authoritative columns)
-- =====================================================================
alter table resource add column if not exists monthly_quota numeric;
alter table resource add column if not exists forge_request_id uuid references forge_request (id) on delete set null;
-- backfill the authoritative numeric quota from the free-text capacity
update resource set monthly_quota = _capacity_num(capacity)
 where monthly_quota is null and _capacity_num(capacity) is not null;

-- =====================================================================
-- C. project_slot — unified intrinsic role slots + need slots
-- =====================================================================
create table if not exists project_slot (
  id               uuid primary key default gen_random_uuid(),
  project_id       uuid not null references project (id) on delete cascade,
  slot_kind        text not null check (slot_kind in ('leader','work_labor','work_resource')),
  req_access       guild_level,                                  -- badge threshold to enter
  skill_id         uuid references skill (id)         on delete set null, -- work_labor
  resource_type_id uuid references resource_type (id) on delete set null, -- work_resource
  quota            numeric,                                      -- monthly need amount
  headcount        integer not null default 1,
  authorship       text check (authorship in ('first','co','last_candidate')),
  status           text not null default 'open' check (status in ('open','filled','closed')),
  created_via      uuid references forge_request (id) on delete set null,
  created_at       timestamptz not null default now()
);
create index if not exists project_slot_project_idx on project_slot (project_id);
create index if not exists project_slot_status_idx  on project_slot (status);

alter table project_slot enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='project_slot' and policyname='read_project_slot') then
    create policy read_project_slot on project_slot for select to authenticated using (true);
  end if;
end $$;
grant select on project_slot to authenticated;

-- =====================================================================
-- F. work_commitment — REBUILD (merges stater_project_stake_commitment +
--    stater_commitment_period: one row per slot+member+month)
--    slot_id is nullable for migration safety (legacy commitments without a
--    clean slot match still migrate); new RPCs always set it.
-- =====================================================================
create table if not exists work_commitment (
  id             uuid primary key default gen_random_uuid(),
  slot_id        uuid references project_slot (id) on delete cascade,
  project_id     uuid references project (id) on delete cascade,   -- denormalised for migration/query
  member_id      uuid not null references member (id) on delete cascade,
  resource_id    uuid references resource (id) on delete set null, -- which resource (incl. time) is committed
  year_month     text not null,                                    -- 'YYYY-MM'
  monthly_amount numeric not null default 0,                       -- hours / units committed this month
  nominal_str    integer not null default 0,                       -- nominal STR minted this month (locked)
  approval       text not null default 'ok'
                  check (approval in ('ok','needs_review','approved','rejected')),
  created_at     timestamptz not null default now(),
  unique (slot_id, member_id, year_month)
);
create index if not exists work_commitment_member_idx  on work_commitment (member_id);
create index if not exists work_commitment_project_idx on work_commitment (project_id);
create index if not exists work_commitment_ym_idx      on work_commitment (year_month);

alter table work_commitment enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='work_commitment' and policyname='read_work_commitment') then
    create policy read_work_commitment on work_commitment for select to authenticated using (true);
  end if;
end $$;
grant select on work_commitment to authenticated;

-- =====================================================================
-- G. STR — concept-named VIEWS over the kept stater_* tables
--    (no rename: the live wallet reads stater_*; views add concept naming)
-- =====================================================================
create or replace view str_account   as select * from stater_account;
create or replace view str_ledger     as select * from stater_ledger;
create or replace view str_policy      as select * from stater_policy;
create or replace view settlement      as select * from stater_settlement;
create or replace view settlement_item as select * from stater_settlement_item;
grant select on str_account, str_ledger, str_policy, settlement, settlement_item to anon, authenticated;

-- =====================================================================
-- DATA MIGRATION (idempotent: insert ... where not exists)
-- =====================================================================

-- ---- E1. skillcard_request -> forge_request (target_type='badge') ----
insert into forge_request
  (id, target_type, action, target_id, payload, batch_id, fee,
   submitted_by, status, reviewed_by, review_note, created_at, settled_at)
select
  sr.id, 'badge',
  case when sr.kind = 'update' then 'update' else 'create' end,
  sr.member_id,
  jsonb_build_object('member_id', sr.member_id, 'skill_id', sr.skill_id,
                     'target_level', sr.target_level, 'legacy_kind', sr.kind),
  sr.batch_id, coalesce(sr.fee, 0),
  sr.submitted_by, sr.status, sr.reviewed_by, sr.review_note,
  sr.created_at, sr.settled_at
from skillcard_request sr
where not exists (select 1 from forge_request fr where fr.id = sr.id);

-- ---- E2. resource approval state -> forge_request (target_type='resource') ----
-- one forge row per resource recording its approval provenance
insert into forge_request
  (target_type, action, target_id, payload, status, created_at)
select
  'resource', 'create', r.id,
  jsonb_build_object('name', r.name, 'scope', r.scope, 'holder_member_id', r.holder_member_id),
  case r.approval_status when 'approved' then 'approved'
                         when 'rejected' then 'rejected'
                         else 'submitted' end,
  r.created_at
from resource r
where not exists (
  select 1 from forge_request fr where fr.target_type = 'resource' and fr.target_id = r.id
);
-- link resources back to their forge row
update resource r
   set forge_request_id = fr.id
  from forge_request fr
 where fr.target_type = 'resource' and fr.target_id = r.id
   and r.forge_request_id is null;

-- ---- A1. member_skill.certified_level -> badge ----
insert into badge (member_id, skill_id, level, forged_at, forge_request_id)
select ms.member_id, ms.skill_id, ms.certified_level, coalesce(ms.certified_at, now()),
       (select fr.id from forge_request fr
         where fr.target_type = 'badge'
           and (fr.payload->>'member_id')::uuid = ms.member_id
           and (fr.payload->>'skill_id')::uuid  = ms.skill_id
           and fr.status = 'approved'
         order by fr.settled_at desc nulls last limit 1)
from member_skill ms
where ms.certified_level is not null
  and not exists (select 1 from badge b where b.member_id = ms.member_id and b.skill_id = ms.skill_id);

-- ---- C1. intrinsic Leader slot per project (one, authorship 'first') ----
insert into project_slot (project_id, slot_kind, authorship, status, headcount)
select p.id, 'leader', 'first',
       case when exists (
         select 1 from project_member pm
         join project_role pr on pr.id = pm.project_role_id
         where pm.project_id = p.id and pr.can_manage
       ) then 'filled' else 'open' end,
       1
from project p
where not exists (
  select 1 from project_slot s where s.project_id = p.id and s.slot_kind = 'leader'
);

-- ---- C2. open_need -> project_slot (work_labor / work_resource) ----
-- seat/labor -> work_labor (co-author); resource -> work_resource (last-author candidate)
insert into project_slot
  (id, project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, authorship, status, created_at)
select
  n.id, n.project_id,
  case when n.contribution_kind = 'resource' then 'work_resource' else 'work_labor' end,
  n.min_guild_level,
  case when n.contribution_kind = 'resource' then null else n.skill_id end,
  null,                                  -- resource_type not modelled on legacy open_need
  n.hours_per_month,
  coalesce(n.headcount, 1),
  case when n.contribution_kind = 'resource' then 'last_candidate' else 'co' end,
  case n.status when 'filled' then 'filled' when 'closed' then 'closed' else 'open' end,
  n.created_at
from open_need n
where not exists (select 1 from project_slot s where s.id = n.id);

-- ---- F1. stater_project_stake_commitment + period -> work_commitment ----
-- Best-effort slot match within the same project:
--   labor -> a work_labor slot (prefer same skill); resource -> a work_resource
--   slot; leader_initiation -> the leader slot. Unmatched -> slot_id NULL.
-- One work_commitment per (commitment, period month).
insert into work_commitment
  (slot_id, project_id, member_id, resource_id, year_month, monthly_amount, nominal_str, approval)
select
  ( select s.id from project_slot s
     where s.project_id = c.project_id
       and s.slot_kind = case
             when c.commitment_type = 'leader_initiation' then 'leader'
             when c.commitment_type = 'resource'          then 'work_resource'
             else 'work_labor' end
       and (c.skill_id is null or s.skill_id is null or s.skill_id = c.skill_id)
     order by case when s.skill_id = c.skill_id then 0 else 1 end
     limit 1 ),
  c.project_id, c.member_id, c.resource_id,
  cp.year_month, coalesce(cp.committed_amount, 0), coalesce(cp.token_equivalent, 0),
  coalesce(cp.approval, 'ok')
from stater_commitment_period cp
join stater_project_stake_commitment c on c.id = cp.commitment_id
where not exists (
  select 1 from work_commitment w
   where w.member_id = c.member_id and w.year_month = cp.year_month
     and w.project_id = c.project_id
     and coalesce(w.resource_id::text,'') = coalesce(c.resource_id::text,'')
);

-- =====================================================================
-- Mark superseded tables deprecated (NOT dropped — rollback window).
-- =====================================================================
comment on table member_skill                    is 'DEPRECATED (phase1-rebuild): migrated to badge. Do not write.';
comment on table skillcard_request               is 'DEPRECATED (phase1-rebuild): migrated to forge_request. Do not write.';
comment on table open_need                        is 'DEPRECATED (phase1-rebuild): migrated to project_slot. Do not write.';
comment on table need_application                 is 'DEPRECATED (phase1-rebuild): superseded by project_slot/work_commitment.';
comment on table stater_project_stake_commitment  is 'DEPRECATED (phase1-rebuild): migrated to work_commitment. Do not write.';
comment on table stater_commitment_period         is 'DEPRECATED (phase1-rebuild): migrated to work_commitment. Do not write.';
comment on column resource.capacity               is 'DEPRECATED (phase1-rebuild): use monthly_quota (numeric). Kept for unit/display only.';

-- =====================================================================
-- VALIDATION — RAISE NOTICE source vs target counts (no failure on mismatch;
-- review the notices after a local apply before any live push).
-- =====================================================================
do $$
declare
  src_badge   int; tgt_badge   int;
  src_forge_b int; tgt_forge_b int;
  src_res     int; tgt_forge_r int;
  src_need    int; tgt_slot_n  int;
  tgt_slot_l  int; src_proj    int;
  src_period  int; tgt_work    int; unmatched int;
begin
  select count(*) into src_badge from member_skill where certified_level is not null;
  select count(*) into tgt_badge from badge;
  select count(*) into src_forge_b from skillcard_request;
  select count(*) into tgt_forge_b from forge_request where target_type = 'badge';
  select count(*) into src_res from resource;
  select count(*) into tgt_forge_r from forge_request where target_type = 'resource';
  select count(*) into src_need from open_need;
  select count(*) into tgt_slot_n from project_slot where slot_kind in ('work_labor','work_resource');
  select count(*) into tgt_slot_l from project_slot where slot_kind = 'leader';
  select count(*) into src_proj from project;
  select count(*) into src_period from stater_commitment_period;
  select count(*) into tgt_work from work_commitment;
  select count(*) into unmatched from work_commitment where slot_id is null;

  raise notice '--- phase1-rebuild migration validation ---';
  raise notice 'badge:          member_skill(certified)=%  ->  badge=%', src_badge, tgt_badge;
  raise notice 'forge(badge):   skillcard_request=%        ->  forge_request[badge]=%', src_forge_b, tgt_forge_b;
  raise notice 'forge(resource):resource=%                 ->  forge_request[resource]=%', src_res, tgt_forge_r;
  raise notice 'slot(need):     open_need=%                ->  project_slot[work_*]=%', src_need, tgt_slot_n;
  raise notice 'slot(leader):   project=%                  ->  project_slot[leader]=%', src_proj, tgt_slot_l;
  raise notice 'work:           commitment_period=%        ->  work_commitment=%  (slot_id NULL: %)', src_period, tgt_work, unmatched;
end $$;

commit;

notify pgrst, 'reload schema';
