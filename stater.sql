-- =====================================================================
-- The Fin AI Community — Stater (STR) economy, Phase 1
-- Replaces the earlier "Fin Credit" / token_* objects with the staking-
-- based contribution economy from the Stater white paper v0.1:
--   leader initiation stake, member/skill-time/resource commitments,
--   community-reviewed settlement -> weighted payout, monthly allowance,
--   leader slash. Liquid STR lives in stater_ledger (integer units);
--   skill-time / writing / resource valuations are TOKEN-EQUIVALENT and
--   never enter wallets or change supply. Every liquid move is one
--   append-only ledger row written only by SECURITY DEFINER RPCs.
-- Idempotent where practical; safe to re-run.
-- =====================================================================

-- ---------- 0. drop the old token_* economy (no real activity to keep) ----------
drop view  if exists token_balance cascade;
drop view  if exists skill_credit  cascade;
drop function if exists token_mint(numeric, text) cascade;
drop function if exists token_grant(uuid, numeric, text) cascade;
drop function if exists join_project(uuid, uuid) cascade;
drop function if exists endorse_skill(uuid, uuid, numeric, text) cascade;
drop function if exists finish_project(uuid) cascade;
drop function if exists token_balance_of(uuid) cascade;
drop function if exists _stake_join(uuid, uuid) cascade;
drop function if exists ensure_member_account() cascade;
drop function if exists ensure_project_account() cascade;
drop trigger  if exists trg_member_account on member;
drop trigger  if exists trg_project_account on project;
drop table if exists token_ledger  cascade;
drop table if exists token_account  cascade;
drop table if exists token_policy   cascade;

-- ---------- 1. capability ----------
delete from position_capability where capability_key = 'manage_tokens';
delete from capability where key = 'manage_tokens';
insert into capability (key, description) values
  ('manage_stater', 'Mint STR, grant tokens, run allowance, edit policy, approve settlements')
on conflict (key) do update set description = excluded.description;
insert into position_capability (position_id, capability_key)
select p.id, 'manage_stater' from position p where p.name = 'President'
on conflict do nothing;

-- ---------- 2. accounts ----------
create table stater_account (
  id              uuid primary key default gen_random_uuid(),
  account_type    text not null check (account_type in ('member','project_escrow','market_escrow','treasury')),
  owner_member_id uuid unique references member (id)  on delete cascade,
  project_id      uuid unique references project (id) on delete cascade,
  market_id       uuid,
  label           text,
  created_at      timestamptz not null default now()
);
insert into stater_account (account_type, label)
select 'treasury', 'Community Treasury'
where not exists (select 1 from stater_account where account_type = 'treasury');

-- ---------- 3. ledger (append-only, integer STR) ----------
create table stater_ledger (
  id            uuid primary key default gen_random_uuid(),
  entry_type    text not null,  -- mint|transfer|stake|endorse|grant|allowance|finish_bonus|milestone_bonus|payout|refund|slash|burn|market_fee
  from_account  uuid references stater_account (id) on delete set null,  -- null = mint
  to_account    uuid references stater_account (id) on delete set null,  -- null = burn
  amount        integer not null check (amount > 0),
  skill_id      uuid references skill (id)   on delete set null,
  project_id    uuid references project (id) on delete set null,
  market_id     uuid,
  milestone_id  uuid,
  settlement_id uuid,
  reason        text not null,
  created_by    uuid references member (id)  on delete set null,
  created_at    timestamptz not null default now(),
  metadata      jsonb not null default '{}'
);
create index stater_ledger_to_idx    on stater_ledger (to_account);
create index stater_ledger_from_idx  on stater_ledger (from_account);
create index stater_ledger_skill_idx on stater_ledger (skill_id) where entry_type = 'endorse';

-- ---------- 4. policy (tiered parameters) ----------
create table stater_policy (
  key         text primary key,
  value       numeric not null,
  description text
);
insert into stater_policy (key, value, description) values
  ('initial_supply',        100000, 'Initial STR minted to the treasury'),
  ('welcome_grant',            100, 'STR granted when a member first logs in'),
  ('monthly_allowance',         20, 'STR granted to members active in the last 30 days'),
  ('join_stake_small',          10, 'Join stake for small projects'),
  ('join_stake_normal',         20, 'Default join stake'),
  ('join_stake_major',          40, 'Join stake for major projects'),
  ('join_stake_flagship',       80, 'Join stake for flagship projects'),
  ('leader_stake_small',        30, 'Leader initiation stake for small projects'),
  ('leader_stake_normal',       50, 'Default leader initiation stake'),
  ('leader_stake_major',       100, 'Leader initiation stake for major projects'),
  ('leader_stake_flagship',    200, 'Leader initiation stake for flagship projects'),
  ('finish_bonus_small',        30, 'Finish bonus for small projects'),
  ('finish_bonus_normal',       50, 'Default finish bonus minted into escrow on settlement'),
  ('finish_bonus_major',        80, 'Finish bonus for major projects'),
  ('finish_bonus_flagship',    150, 'Finish bonus for flagship projects'),
  ('endorse_min',                1, 'Minimum STR per skill endorsement'),
  ('paper_writing_rate',        10, 'Token-equivalent per hour for Paper Writing'),
  ('default_first_author_writing_hours', 20, 'Default first-author writing hours a leader stakes'),
  ('review_window_hours',       72, 'Settlement community review window (hours)'),
  ('leader_abandon_slash_rate',  0.50, 'Fraction of leader stake slashed on abandonment'),
  ('leader_misconduct_slash_rate', 1.00, 'Fraction of leader stake slashed on misconduct'),
  ('market_fee_rate',           0.02, 'Signal-market fee to treasury (Phase 3)'),
  ('treasury_reserve_min',      0.40, 'Healthy treasury reserve ratio floor'),
  ('monthly_inflation_target',  0.03, 'Target monthly net issuance / circulating supply')
on conflict (key) do nothing;

-- per-project-type staking defaults
alter table project_type add column if not exists join_stake   integer not null default 20;
alter table project_type add column if not exists leader_stake  integer not null default 50;
alter table project_type add column if not exists finish_bonus  integer not null default 50;
update project_type set join_stake=30, leader_stake=80, finish_bonus=80 where name='Model';
update project_type set join_stake=20, leader_stake=60, finish_bonus=60 where name='Trustworthy';
update project_type set join_stake=20, leader_stake=50, finish_bonus=50 where name in ('Dataset & Benchmark','Agent','Application');

-- per-role payout weight (kept from earlier)
alter table project_role add column if not exists payout_weight numeric not null default 1;
update project_role set payout_weight = 3 where name = 'Leader';
update project_role set payout_weight = 2 where name = 'Co-lead';

-- ---------- 5. skill rate (token-equivalent per hour) ----------
create table stater_skill_rate (
  skill_id uuid primary key references skill (id) on delete cascade,
  rate     integer not null default 10
);
insert into stater_skill_rate (skill_id, rate)
select s.id, v.rate from skill s
join (values
  ('Paper Writing',10),('Experiment Design',12),('Benchmark Design',12),('Evaluation & Metrics',12),
  ('Statistical Analysis',12),('Literature Review',8),('Rebuttal / Review',10),
  ('Pretraining',15),('Fine-tuning / SFT',12),('RLHF / Alignment',15),('Distributed Training / GPU',15),
  ('Inference & Serving',12),('Agent / Tool-use / RAG',12),('Multimodal',12),
  ('Data Engineering / Pipelines',12),('Frontend / Backend Dev',12),
  ('Project Management / Coordination',10),('Meeting Facilitation / Hosting',8),('Minutes / Record-keeping',6),
  ('Mentoring / Onboarding',8),('Presentation / Public Speaking',10),('Cross-team Collaboration',8),
  ('Community Building / Outreach',10)
) as v(name, rate) on v.name = s.name
on conflict (skill_id) do nothing;

-- ---------- 6. project stake commitments ----------
create table stater_project_stake_commitment (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid not null references project (id) on delete cascade,
  member_id       uuid not null references member (id)  on delete cascade,
  commitment_type text not null check (commitment_type in
                   ('leader_initiation','join_token','first_author_writing','skill_time','resource')),
  skill_id        uuid references skill (id) on delete set null,
  resource_id     uuid references resource (id) on delete set null,
  hours_committed numeric,
  token_amount    integer not null default 0,     -- liquid STR actually staked
  token_equivalent integer not null default 0,    -- valuation only (NOT liquid)
  status          text not null default 'pledged' check (status in
                   ('pledged','accepted','verified','rewarded','rejected','forfeited')),
  verified_by     uuid references member (id) on delete set null,
  verified_at     timestamptz,
  created_at      timestamptz not null default now(),
  metadata        jsonb not null default '{}'
);
create index stater_commitment_project_idx on stater_project_stake_commitment (project_id);
create index stater_commitment_member_idx  on stater_project_stake_commitment (member_id);

-- ---------- 7. settlement ----------
create table stater_settlement (
  id                   uuid primary key default gen_random_uuid(),
  project_id           uuid not null references project (id) on delete cascade,
  submitted_by         uuid references member (id) on delete set null,
  status               text not null default 'submitted' check (status in
                        ('draft','submitted','under_review','approved','rejected','disputed','paid')),
  meeting_notes        text,
  review_window_ends_at timestamptz,
  approved_by          uuid references member (id) on delete set null,
  approved_at          timestamptz,
  created_at           timestamptz not null default now()
);
create table stater_settlement_item (
  id                            uuid primary key default gen_random_uuid(),
  settlement_id                 uuid not null references stater_settlement (id) on delete cascade,
  member_id                     uuid not null references member (id) on delete cascade,
  role                          text,
  verified_token_stake          integer not null default 0,
  verified_skill_time_equivalent integer not null default 0,
  verified_resource_equivalent  integer not null default 0,
  writing_verified              boolean not null default false,
  milestone_contribution_score  numeric not null default 0,
  final_payout_weight           numeric not null default 0,
  is_author                     boolean not null default true,
  author_order                  integer,
  notes                         text
);

-- ---------- 8. views ----------
create or replace view stater_balance as
select a.id as account_id, a.account_type, a.owner_member_id, a.project_id, a.market_id, a.label,
       coalesce((select sum(amount) from stater_ledger where to_account   = a.id), 0)
     - coalesce((select sum(amount) from stater_ledger where from_account = a.id), 0) as balance
from stater_account a;

create or replace view stater_skill_credit as
select ac.owner_member_id as member_id, l.skill_id,
       sum(l.amount) as credit, count(*) as endorsements
from stater_ledger l
join stater_account ac on ac.id = l.to_account
where l.entry_type = 'endorse' and l.skill_id is not null
group by ac.owner_member_id, l.skill_id;

-- ---------- 9. account provisioning ----------
create or replace function ensure_member_account()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into stater_account (account_type, owner_member_id) values ('member', new.id)
  on conflict do nothing; return new;
end; $$;
create or replace function ensure_project_account()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into stater_account (account_type, project_id) values ('project_escrow', new.id)
  on conflict do nothing; return new;
end; $$;
create trigger trg_member_account  after insert on member  for each row execute function ensure_member_account();
create trigger trg_project_account after insert on project for each row execute function ensure_project_account();

insert into stater_account (account_type, owner_member_id)
select 'member', m.id from member m
where not exists (select 1 from stater_account a where a.owner_member_id = m.id);
insert into stater_account (account_type, project_id)
select 'project_escrow', p.id from project p
where not exists (select 1 from stater_account a where a.project_id = p.id);

-- ---------- 10. helpers ----------
create or replace function stater_balance_of(acc uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select sum(amount) from stater_ledger where to_account   = acc), 0)
       - coalesce((select sum(amount) from stater_ledger where from_account = acc), 0);
$$;

create or replace function stater_policy_int(k text, dflt integer)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select value::integer from stater_policy where key = k), dflt);
$$;

-- internal: move liquid STR between two accounts (balance-checked)
create or replace function stater_move(p_from uuid, p_to uuid, amt integer, etype text, p_reason text,
                                        p_project uuid default null, p_skill uuid default null,
                                        p_settlement uuid default null, p_by uuid default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if amt <= 0 then return; end if;
  if p_from is not null and stater_balance_of(p_from) < amt then
    raise exception 'insufficient STR (need %, have %)', amt, stater_balance_of(p_from);
  end if;
  insert into stater_ledger (entry_type, from_account, to_account, amount, reason, project_id, skill_id, settlement_id, created_by)
  values (etype, p_from, p_to, amt, p_reason, p_project, p_skill, p_settlement, coalesce(p_by, current_member_id()));
end; $$;

create or replace function stater_treasury() returns uuid language sql stable security definer set search_path = public as $$
  select id from stater_account where account_type = 'treasury' limit 1;
$$;
create or replace function stater_member_acc(mid uuid) returns uuid language sql stable security definer set search_path = public as $$
  select id from stater_account where owner_member_id = mid;
$$;
create or replace function stater_project_acc(pid uuid) returns uuid language sql stable security definer set search_path = public as $$
  select id from stater_account where project_id = pid;
$$;

-- ---------- 11. governance RPCs ----------
create or replace function stater_mint(amt integer, reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_stater') then raise exception 'not authorized'; end if;
  if amt <= 0 then raise exception 'amount must be positive'; end if;
  insert into stater_ledger (entry_type, from_account, to_account, amount, reason, created_by)
  values ('mint', null, stater_treasury(), amt, coalesce(reason,'mint'), current_member_id());
end; $$;
grant execute on function stater_mint(integer, text) to authenticated;

create or replace function stater_grant(target uuid, amt integer, reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_stater') then raise exception 'not authorized'; end if;
  if stater_member_acc(target) is null then raise exception 'member has no account'; end if;
  perform stater_move(stater_treasury(), stater_member_acc(target), amt, 'grant', coalesce(reason,'grant'));
end; $$;
grant execute on function stater_grant(uuid, integer, text) to authenticated;

-- monthly allowance to members active in the last 30 days (one per 30-day window)
create or replace function issue_monthly_allowance()
returns integer language plpgsql security definer set search_path = public as $$
declare amt integer; n integer := 0; r record;
begin
  if not has_capability('manage_stater') then raise exception 'not authorized'; end if;
  amt := stater_policy_int('monthly_allowance', 20);
  for r in
    select distinct a.owner_member_id as mid, a.id as acc
    from stater_account a
    where a.account_type = 'member'
      and (
        exists (select 1 from stater_ledger l where l.created_by = a.owner_member_id and l.created_at > now() - interval '30 days')
        or exists (select 1 from stater_project_stake_commitment c
                   where c.member_id = a.owner_member_id and c.status = 'verified' and c.verified_at > now() - interval '30 days')
      )
      and not exists (
        select 1 from stater_ledger l where l.to_account = a.id and l.entry_type = 'allowance'
          and l.created_at > now() - interval '30 days'
      )
  loop
    insert into stater_ledger (entry_type, from_account, to_account, amount, reason, created_by)
    values ('allowance', stater_treasury(), r.acc, amt, 'monthly active allowance', current_member_id());
    n := n + 1;
  end loop;
  return n;
end; $$;
grant execute on function issue_monthly_allowance() to authenticated;

-- ---------- 12. endorsement (liquid transfer, scarce) ----------
create or replace function endorse_skill(target uuid, sk uuid, amt integer, note text)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if me = target then raise exception 'cannot endorse yourself'; end if;
  if amt < stater_policy_int('endorse_min', 1) then raise exception 'amount below minimum'; end if;
  if stater_member_acc(target) is null then raise exception 'target has no account'; end if;
  insert into stater_ledger (entry_type, from_account, to_account, amount, skill_id, reason, created_by)
  select 'endorse', stater_member_acc(me), stater_member_acc(target), amt, sk, coalesce(note,'skill endorsement'), me
  where stater_balance_of(stater_member_acc(me)) >= amt;
  if not found then raise exception 'insufficient STR'; end if;
end; $$;
grant execute on function endorse_skill(uuid, uuid, integer, text) to authenticated;

-- ---------- 13. welcome grant folded into claim ----------
create or replace function claim_membership()
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid; macc uuid; w integer;
begin
  update member set auth_user_id = auth.uid(), status = 'active'
   where email = auth.email() and auth_user_id is null
  returning id into mid;
  update invite set accepted_at = now() where email = auth.email() and accepted_at is null;

  if mid is not null then
    macc := stater_member_acc(mid);
    if macc is null then
      insert into stater_account (account_type, owner_member_id) values ('member', mid) returning id into macc;
    end if;
    w := stater_policy_int('welcome_grant', 100);
    if w > 0 and not exists (select 1 from stater_ledger where to_account = macc and entry_type = 'grant') then
      insert into stater_ledger (entry_type, from_account, to_account, amount, reason, created_by)
      values ('grant', stater_treasury(), macc, w, 'welcome grant', mid);
    end if;
  end if;
  return mid;
end; $$;
grant execute on function claim_membership() to authenticated;

-- ---------- 14. project initiation + joining ----------
-- create a project, stake the leader initiation, and seat the leader
create or replace function create_project_with_leader_stake(
  p_name text, p_type_id uuid, p_status_id uuid, p_venue text, p_summary text, p_stake integer default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; esc uuid; lstake integer; lrole uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  lstake := coalesce(p_stake, (select leader_stake from project_type where id = p_type_id),
                     stater_policy_int('leader_stake_normal', 50));
  insert into project (name, type_id, status_id, target_venue, summary)
  values (p_name, p_type_id, p_status_id, p_venue, p_summary) returning id into pid;
  esc := stater_project_acc(pid);  -- created by trigger
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader initiation stake', pid, null, null, me);
  select id into lrole from project_role where name = 'Leader' limit 1;
  insert into project_member (project_id, member_id, project_role_id) values (pid, me, lrole) on conflict do nothing;
  insert into stater_project_stake_commitment (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (pid, me, 'leader_initiation', lstake, 'verified', me, now());
  return pid;
end; $$;
grant execute on function create_project_with_leader_stake(text, uuid, uuid, text, text, integer) to authenticated;

-- internal: seat a member + record a commitment, optionally staking liquid STR
create or replace function _stater_seat(pid uuid, mid uuid, role_id uuid, ctype text,
                                        liquid integer, equiv integer, sk uuid, res uuid, hrs numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if liquid > 0 then
    perform stater_move(stater_member_acc(mid), stater_project_acc(pid), liquid, 'stake', 'join project stake', pid, null, null, mid);
  end if;
  insert into stater_project_stake_commitment
    (project_id, member_id, commitment_type, skill_id, resource_id, hours_committed, token_amount, token_equivalent, status)
  values (pid, mid, ctype, sk, res, hrs, liquid, equiv,
          case when ctype = 'join_token' then 'verified' else 'pledged' end);
  insert into project_member (project_id, member_id, project_role_id) values (pid, mid, role_id) on conflict do nothing;
end; $$;

create or replace function join_project_with_token_stake(p uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare js integer;
begin
  if current_member_id() is null then raise exception 'no member record'; end if;
  js := coalesce((select join_stake from project_type t join project pr on pr.type_id = t.id where pr.id = p),
                 stater_policy_int('join_stake_normal', 20));
  perform _stater_seat(p, current_member_id(), role_id, 'join_token', js, 0, null, null, null);
end; $$;
grant execute on function join_project_with_token_stake(uuid, uuid) to authenticated;

create or replace function join_project_with_skill_time(p uuid, role_id uuid, sk uuid, hrs numeric)
returns void language plpgsql security definer set search_path = public as $$
declare rate integer; equiv integer;
begin
  if current_member_id() is null then raise exception 'no member record'; end if;
  rate := coalesce((select rate from stater_skill_rate where skill_id = sk), 10);
  equiv := ceil(rate * hrs);
  perform _stater_seat(p, current_member_id(), role_id, 'skill_time', 0, equiv, sk, null, hrs);
end; $$;
grant execute on function join_project_with_skill_time(uuid, uuid, uuid, numeric) to authenticated;

create or replace function join_project_with_resource_stake(p uuid, role_id uuid, res uuid, equiv integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'no member record'; end if;
  perform _stater_seat(p, current_member_id(), role_id, 'resource', 0, coalesce(equiv,0), null, res, null);
end; $$;
grant execute on function join_project_with_resource_stake(uuid, uuid, uuid, integer) to authenticated;

-- verify a pending (skill-time / resource) commitment (manager only)
create or replace function verify_commitment(commitment_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select project_id into pid from stater_project_stake_commitment where id = commitment_id;
  if pid is null then raise exception 'commitment not found'; end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  update stater_project_stake_commitment
     set status = 'verified', verified_by = current_member_id(), verified_at = now()
   where id = commitment_id;
end; $$;
grant execute on function verify_commitment(uuid) to authenticated;

-- accept an application: stake the applicant's join cost, seat them
create or replace function accept_application(app_id uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid; js integer;
begin
  select n.project_id, na.member_id into pid, mid
  from need_application na join open_need n on n.id = na.open_need_id where na.id = app_id;
  if pid is null then raise exception 'application not found'; end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  js := coalesce((select join_stake from project_type t join project pr on pr.type_id = t.id where pr.id = pid),
                 stater_policy_int('join_stake_normal', 20));
  update need_application set status = 'accepted' where id = app_id;
  perform _stater_seat(pid, mid, role_id, 'join_token', js, 0, null, null, null);
end; $$;
grant execute on function accept_application(uuid, uuid) to authenticated;

-- accept a resource offer: record a resource commitment (token-equivalent), seat the contributor
create or replace function accept_resource_offer(offer_id uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid; rid uuid;
begin
  select r.project_id, o.offered_by, o.resource_id into pid, mid, rid
  from resource_offer o join resource_request r on r.id = o.request_id where o.id = offer_id;
  if pid is null then raise exception 'offer not found'; end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  update resource_offer set status = 'accepted' where id = offer_id;
  perform _stater_seat(pid, mid, role_id, 'resource', 0, 0, null, rid, null);
end; $$;
grant execute on function accept_resource_offer(uuid, uuid) to authenticated;

-- ---------- 15. settlement ----------
-- mark a project Finished (opens settlement; no auto-payout)
create or replace function finish_project(p uuid)
returns void language plpgsql security definer set search_path = public as $$
declare fin uuid;
begin
  if not manages_project(p) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  select id into fin from project_status where name = 'Finished' limit 1;
  if fin is not null then update project set status_id = fin where id = p; end if;
end; $$;
grant execute on function finish_project(uuid) to authenticated;

-- leader submits a settlement proposal with per-member payout weights (items = jsonb array)
create or replace function submit_settlement(p uuid, notes text, items jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid; hrs integer;
begin
  if not manages_project(p) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  -- settlement can only be drafted once the project has reached Finished
  if not exists (
    select 1 from project pr
    join project_status ps on ps.id = pr.status_id
    where pr.id = p and ps.name = 'Finished'
  ) then
    raise exception 'settlement can only be submitted for a Finished project';
  end if;
  hrs := stater_policy_int('review_window_hours', 72);
  insert into stater_settlement (project_id, submitted_by, status, meeting_notes, review_window_ends_at)
  values (p, current_member_id(), 'submitted', notes, now() + (hrs || ' hours')::interval)
  returning id into sid;
  insert into stater_settlement_item
    (settlement_id, member_id, role, final_payout_weight, is_author, author_order, notes)
  select sid,
         (i->>'member_id')::uuid,
         i->>'role',
         coalesce((i->>'final_payout_weight')::numeric, 0),
         coalesce((i->>'is_author')::boolean, true),
         (i->>'author_order')::int,
         i->>'notes'
  from jsonb_array_elements(items) i;
  return sid;
end; $$;
grant execute on function submit_settlement(uuid, text, jsonb) to authenticated;

-- approve + pay out in one atomic step (manage_stater governance)
create or replace function approve_settlement(settlement_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; esc uuid; bonus integer; pool integer; wsum numeric; r record;
begin
  if not has_capability('manage_stater') and not has_capability('edit_any_project') then
    raise exception 'not authorized to approve';
  end if;
  select project_id into pid from stater_settlement where id = settlement_id and status in ('submitted','under_review');
  if pid is null then raise exception 'settlement not found or already resolved'; end if;
  esc := stater_project_acc(pid);

  -- mint the finish bonus into escrow
  bonus := coalesce((select finish_bonus from project_type t join project pr on pr.type_id = t.id where pr.id = pid),
                    stater_policy_int('finish_bonus_normal', 50));
  if bonus > 0 then
    insert into stater_ledger (entry_type, from_account, to_account, amount, reason, project_id, settlement_id, created_by)
    values ('finish_bonus', null, esc, bonus, 'project finish bonus', pid, settlement_id, current_member_id());
  end if;

  pool := stater_balance_of(esc);
  select coalesce(sum(final_payout_weight), 0) into wsum from stater_settlement_item where settlement_id = approve_settlement.settlement_id;

  if wsum > 0 and pool > 0 then
    for r in select member_id, final_payout_weight, is_author, author_order
             from stater_settlement_item where settlement_id = approve_settlement.settlement_id loop
      if r.final_payout_weight > 0 then
        insert into stater_ledger (entry_type, from_account, to_account, amount, reason, project_id, settlement_id, created_by)
        values ('payout', esc, stater_member_acc(r.member_id),
                floor(pool * r.final_payout_weight / wsum), 'settlement payout', pid, settlement_id, current_member_id());
      end if;
      -- authorship rule: every credited contributor is seated as an author
      if r.is_author then
        insert into project_member (project_id, member_id, project_role_id)
        select pid, r.member_id, (select id from project_role where name = 'Contributor' limit 1)
        on conflict do nothing;
      end if;
    end loop;
  end if;

  update stater_project_stake_commitment set status = 'rewarded'
   where project_id = pid and status in ('pledged','accepted','verified');
  update stater_settlement set status = 'paid', approved_by = current_member_id(), approved_at = now()
   where id = settlement_id;
end; $$;
grant execute on function approve_settlement(uuid) to authenticated;

create or replace function reject_settlement(settlement_id uuid, reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_stater') and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  update stater_settlement set status = 'rejected' where id = settlement_id and status in ('submitted','under_review');
end; $$;
grant execute on function reject_settlement(uuid, text) to authenticated;

-- slash a leader's initiation stake (escrow -> treasury), forfeit the commitment
create or replace function slash_leader_stake(p uuid, rate numeric, reason text)
returns void language plpgsql security definer set search_path = public as $$
declare c record; amt integer;
begin
  if not has_capability('manage_stater') then raise exception 'not authorized'; end if;
  select * into c from stater_project_stake_commitment
   where project_id = p and commitment_type = 'leader_initiation' and status <> 'forfeited' limit 1;
  if c.id is null then raise exception 'no leader stake to slash'; end if;
  amt := floor(c.token_amount * coalesce(rate, stater_policy_int('leader_abandon_slash_rate', 0.5)::numeric));
  if amt > 0 then
    insert into stater_ledger (entry_type, from_account, to_account, amount, reason, project_id, created_by)
    values ('slash', stater_project_acc(p), stater_treasury(), amt, coalesce(reason,'leader stake slashed'), p, current_member_id());
  end if;
  update stater_project_stake_commitment set status = 'forfeited' where id = c.id;
end; $$;
grant execute on function slash_leader_stake(uuid, numeric, text) to authenticated;

-- ---------- 16. RLS ----------
alter table stater_account                  enable row level security;
alter table stater_ledger                   enable row level security;
alter table stater_policy                   enable row level security;
alter table stater_skill_rate               enable row level security;
alter table stater_project_stake_commitment enable row level security;
alter table stater_settlement               enable row level security;
alter table stater_settlement_item          enable row level security;

create policy read_stater_account    on stater_account                  for select to authenticated using (true);
create policy read_stater_ledger     on stater_ledger                   for select to authenticated using (true);
create policy read_stater_policy     on stater_policy                   for select to authenticated using (true);
create policy read_stater_skill_rate on stater_skill_rate               for select to authenticated using (true);
create policy read_stater_commit     on stater_project_stake_commitment for select to authenticated using (true);
create policy read_stater_settle     on stater_settlement               for select to authenticated using (true);
create policy read_stater_settle_i   on stater_settlement_item          for select to authenticated using (true);

create policy manage_stater_policy   on stater_policy     for all to authenticated
  using (has_capability('manage_stater')) with check (has_capability('manage_stater'));
create policy manage_stater_rate     on stater_skill_rate for all to authenticated
  using (has_capability('manage_stater')) with check (has_capability('manage_stater'));

grant select on stater_account, stater_ledger, stater_policy, stater_skill_rate,
                stater_project_stake_commitment, stater_settlement, stater_settlement_item,
                stater_balance, stater_skill_credit to anon, authenticated;

-- ---------- 17. bootstrap treasury + seed President ----------
do $$
declare tre uuid; macc uuid; sup integer;
begin
  tre := stater_treasury();
  sup := (select value::integer from stater_policy where key = 'initial_supply');
  if stater_balance_of(tre) = 0 then
    insert into stater_ledger (entry_type, from_account, to_account, amount, reason)
    values ('mint', null, tre, sup, 'initial supply');
  end if;
  select a.id into macc from stater_account a join member m on m.id = a.owner_member_id
   where m.email = 'jimin.huang@thefin.ai' limit 1;
  if macc is not null and stater_balance_of(macc) = 0 then
    insert into stater_ledger (entry_type, from_account, to_account, amount, reason)
    values ('grant', tre, macc, (select value::integer from stater_policy where key = 'welcome_grant'), 'welcome grant');
  end if;
end $$;
