-- ============================================================
-- Milestones — the project card's "credential" (output axis).
--
-- The pool grows on two axes: Work (input, monthly, trust-based → nominal_str)
-- and Milestones (output, event, verified-gated). A milestone is the project's
-- equivalent of a member's badge: claimed → reviewed → verified, and on verify
-- it (1) adds its catalog nominal_value to the project pool and (2) bumps the
-- settlement mint multiplier (Σ multiplier_bonus, capped). contribution-model
-- §4b / whitepaper §13 / §20.2.
--
-- Reuses the (deprecated-but-not-dropped) milestone_catalog / project_milestone
-- tables additively. Idempotent.
-- ============================================================

-- catalog (the §20.2 price table) ----------------------------------------
create table if not exists milestone_catalog (
  id               uuid primary key default gen_random_uuid(),
  category         text not null,
  item             text not null,
  nominal_value    integer not null default 0,
  multiplier_bonus numeric not null default 0,
  rank             int not null default 100,
  unique (category, item)
);
alter table milestone_catalog add column if not exists is_active boolean not null default true;

insert into milestone_catalog (category, item, nominal_value, multiplier_bonus, rank) values
  ('submission',        'arXiv / preprint posted',     20, 0.005,  1),
  ('submission',        'Paper submitted to venue',    30, 0.01,   2),
  ('acceptance',        'Paper accepted',             100, 0.05,   3),
  ('acceptance',        'Accepted at top venue',      200, 0.10,   4),
  ('release',           'Dataset / model released',    50, 0.02,   5),
  ('open_source_impact','1k+ GitHub stars',            80, 0.04,   6),
  ('huggingface_impact','10k+ HF downloads',           80, 0.04,   7),
  ('community_signal',  'Featured / press pickup',     40, 0.02,   8),
  ('benchmark_result',  'State-of-the-art result',    150, 0.08,   9),
  ('governance',        'Standard / protocol adopted',120, 0.06,  10)
on conflict (category, item) do nothing;

-- per-project claimed milestones ----------------------------------------
create table if not exists project_milestone (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references project (id) on delete cascade,
  catalog_id  uuid references milestone_catalog (id) on delete set null,
  title       text,
  status      text not null default 'claimed'
              check (status in ('claimed','under_review','verified','rejected','expired','revoked')),
  claimed_by  uuid references member (id) on delete set null,
  verified_by uuid references member (id) on delete set null,
  verified_at timestamptz,
  created_at  timestamptz not null default now()
);
-- snapshot the catalog values at claim time so later catalog edits don't
-- retroactively change a verified milestone's contribution.
alter table project_milestone add column if not exists nominal_value    integer not null default 0;
alter table project_milestone add column if not exists multiplier_bonus numeric not null default 0;
create index if not exists project_milestone_project_idx on project_milestone (project_id);

-- settlement multiplier cap (policy) ------------------------------------
insert into stater_policy (key, value, description)
values ('milestone_multiplier_cap', 3.0, 'Cap on the settlement mint multiplier from verified milestones')
on conflict (key) do nothing;

-- RLS: everyone reads; catalog editable by economy/taxonomy stewards; the
-- per-project table is written only through the RPCs below (security definer).
alter table milestone_catalog enable row level security;
drop policy if exists read_milestone_catalog on milestone_catalog;
create policy read_milestone_catalog on milestone_catalog for select to authenticated using (true);
drop policy if exists manage_milestone_catalog on milestone_catalog;
create policy manage_milestone_catalog on milestone_catalog for all to authenticated
  using (has_capability('manage_stater') or has_capability('manage_taxonomy'))
  with check (has_capability('manage_stater') or has_capability('manage_taxonomy'));
grant select, insert, update, delete on milestone_catalog to authenticated;

alter table project_milestone enable row level security;
drop policy if exists read_project_milestone on project_milestone;
create policy read_project_milestone on project_milestone for select to authenticated using (true);
grant select on project_milestone to authenticated;

-- ---- verbs: claim (forge) + verify (review) ----
create or replace function forge_milestone(p_project uuid, p_catalog uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; mid uuid; nv int; mb numeric; nm text;
begin
  me := current_member_id();
  if not can_edit_project(p_project) then raise exception 'not authorized to claim a milestone for this project'; end if;
  select nominal_value, multiplier_bonus, item into nv, mb, nm from milestone_catalog where id = p_catalog and is_active;
  if nv is null then raise exception 'no such milestone'; end if;
  insert into project_milestone (project_id, catalog_id, status, nominal_value, multiplier_bonus, claimed_by)
  values (p_project, p_catalog, 'claimed', nv, mb, me) returning id into mid;
  perform log_project_event(p_project, 'milestone_claimed', nm || ' — claimed', jsonb_build_object('milestone_id', mid));
  return mid;
end $$;
grant execute on function forge_milestone(uuid, uuid) to authenticated;

create or replace function verify_milestone(p_milestone uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; pm project_milestone; nm text;
begin
  me := current_member_id();
  if not (has_capability('edit_any_project') or has_capability('manage_stater') or has_capability('manage_resources')) then
    raise exception 'not authorized to verify milestones';
  end if;
  select * into pm from project_milestone where id = p_milestone;
  if pm.id is null then raise exception 'no such milestone'; end if;
  if pm.status not in ('claimed','under_review') then raise exception 'milestone already decided'; end if;
  update project_milestone set status = case when p_approve then 'verified' else 'rejected' end,
         verified_by = me, verified_at = now() where id = p_milestone;
  select item into nm from milestone_catalog where id = pm.catalog_id;
  perform log_project_event(pm.project_id,
    case when p_approve then 'milestone_verified' else 'milestone_rejected' end,
    coalesce(nm, 'Milestone') || (case when p_approve then ' — verified → +' || pm.nominal_value || ' nominal STR' else ' — rejected' end),
    jsonb_build_object('milestone_id', p_milestone));
end $$;
grant execute on function verify_milestone(uuid, boolean) to authenticated;

-- ---- pool / multiplier helpers (settlement + display) ----
create or replace function project_milestone_nominal(p_project uuid)
returns int language sql stable security definer set search_path = public as $$
  select coalesce(sum(nominal_value), 0)::int from project_milestone
   where project_id = p_project and status = 'verified';
$$;
grant execute on function project_milestone_nominal(uuid) to authenticated;

create or replace function project_milestone_multiplier(p_project uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select least(
    1 + coalesce((select sum(multiplier_bonus) from project_milestone
                   where project_id = p_project and status = 'verified'), 0),
    coalesce(stater_policy_num('milestone_multiplier_cap', 3.0), 3.0));
$$;
grant execute on function project_milestone_multiplier(uuid) to authenticated;

notify pgrst, 'reload schema';
