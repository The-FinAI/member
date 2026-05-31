-- =====================================================================
-- The Fin AI Community — Token economy ("Fin Credit")
-- Run after schema/policies/functions/resources. Idempotent.
--
-- Academic credit becomes a scarce, auditable currency. Every movement is
-- one immutable ledger row between accounts (member wallet / project escrow
-- / community treasury). Tokens are earned by finishing projects and spent
-- by joining projects (a bonded stake) and endorsing peers. All flows go
-- through SECURITY DEFINER functions that enforce balances; direct ledger
-- writes are denied by RLS, so supply stays conserved and forge-proof.
-- =====================================================================

-- ---------- capability ----------
insert into capability (key, description) values
  ('manage_tokens', 'Mint Fin Credit, grant tokens, and edit token policy')
on conflict (key) do nothing;

insert into position_capability (position_id, capability_key)
select p.id, 'manage_tokens' from position p where p.name = 'President'
on conflict do nothing;

-- ---------- accounts ----------
create table if not exists token_account (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('member', 'project', 'treasury')),
  member_id  uuid unique references member (id)  on delete cascade,
  project_id uuid unique references project (id) on delete cascade,
  label      text,
  created_at timestamptz not null default now()
);

-- the single community treasury
insert into token_account (kind, label)
select 'treasury', 'Community Treasury'
where not exists (select 1 from token_account where kind = 'treasury');

-- ---------- ledger (append-only) ----------
-- from null  => minted (new supply enters from the treasury policy)
-- to   null  => burned
create table if not exists token_ledger (
  id           uuid primary key default gen_random_uuid(),
  from_account uuid references token_account (id) on delete set null,
  to_account   uuid references token_account (id) on delete set null,
  amount       numeric(20,2) not null check (amount > 0),
  kind         text not null,   -- mint | grant | stake | payout | endorse | transfer
  reason       text not null,
  skill_id     uuid references skill (id)   on delete set null,
  project_id   uuid references project (id) on delete set null,
  created_by   uuid references member (id)  on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists token_ledger_to_idx   on token_ledger (to_account);
create index if not exists token_ledger_from_idx on token_ledger (from_account);
create index if not exists token_ledger_skill_idx on token_ledger (skill_id) where kind = 'endorse';

-- ---------- policy (admin-editable parameters) ----------
create table if not exists token_policy (
  key         text primary key,
  value       numeric not null,
  description text
);
insert into token_policy (key, value, description) values
  ('welcome_grant', 100, 'Starting balance granted when a member first logs in'),
  ('join_stake',     20, 'Tokens staked into a project escrow to join it'),
  ('finish_bonus',   50, 'Tokens minted into the escrow when a project is finished'),
  ('endorse_min',     1, 'Minimum tokens per skill endorsement')
on conflict (key) do nothing;

-- per-role share of a completed project's payout
alter table project_role add column if not exists payout_weight numeric not null default 1;
update project_role set payout_weight = 3 where name in ('Leader');
update project_role set payout_weight = 2 where name in ('Co-lead');
update project_role set payout_weight = 1 where payout_weight is null;

-- ---------- balance + skill-credit views ----------
create or replace view token_balance as
select a.id as account_id, a.kind, a.member_id, a.project_id, a.label,
       coalesce((select sum(amount) from token_ledger where to_account   = a.id), 0)
     - coalesce((select sum(amount) from token_ledger where from_account = a.id), 0) as balance
from token_account a;

-- credibility a member has accrued per skill, from endorsement tokens received
create or replace view skill_credit as
select ta.member_id, l.skill_id,
       sum(l.amount)        as credit,
       count(*)             as endorsements
from token_ledger l
join token_account ta on ta.id = l.to_account
where l.kind = 'endorse' and l.skill_id is not null
group by ta.member_id, l.skill_id;

-- ---------- account provisioning (trigger, definer to bypass RLS) ----------
create or replace function ensure_member_account()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into token_account (kind, member_id) values ('member', new.id)
  on conflict do nothing;
  return new;
end; $$;

create or replace function ensure_project_account()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into token_account (kind, project_id) values ('project', new.id)
  on conflict do nothing;
  return new;
end; $$;

drop trigger if exists trg_member_account on member;
create trigger trg_member_account after insert on member
  for each row execute function ensure_member_account();

drop trigger if exists trg_project_account on project;
create trigger trg_project_account after insert on project
  for each row execute function ensure_project_account();

-- backfill accounts for rows that predate the triggers
insert into token_account (kind, member_id)
select 'member', m.id from member m
where not exists (select 1 from token_account a where a.member_id = m.id);
insert into token_account (kind, project_id)
select 'project', p.id from project p
where not exists (select 1 from token_account a where a.project_id = p.id);

-- ---------- helpers ----------
create or replace function token_balance_of(acc uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select sum(amount) from token_ledger where to_account   = acc), 0)
       - coalesce((select sum(amount) from token_ledger where from_account = acc), 0);
$$;

-- internal: stake the join cost from a member into a project escrow.
-- NOT granted to clients — only called by definer functions below.
create or replace function _stake_join(p uuid, mid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cost numeric; macc uuid; esc uuid;
begin
  select value into cost from token_policy where key = 'join_stake';
  if coalesce(cost, 0) = 0 then return; end if;
  select id into macc from token_account where member_id = mid;
  select id into esc  from token_account where project_id = p;
  if macc is null or esc is null then raise exception 'token account missing'; end if;
  if token_balance_of(macc) < cost then
    raise exception 'insufficient tokens to join (need %, have %)', cost, token_balance_of(macc);
  end if;
  insert into token_ledger (from_account, to_account, amount, kind, reason, project_id, created_by)
  values (macc, esc, cost, 'stake', 'join project', p, mid);
end; $$;

-- ---------- public RPCs ----------

-- mint new supply into the treasury (governance only)
create or replace function token_mint(amt numeric, reason text)
returns void language plpgsql security definer set search_path = public as $$
declare tre uuid;
begin
  if not has_capability('manage_tokens') then raise exception 'not authorized'; end if;
  if amt is null or amt <= 0 then raise exception 'amount must be positive'; end if;
  select id into tre from token_account where kind = 'treasury' limit 1;
  insert into token_ledger (from_account, to_account, amount, kind, reason, created_by)
  values (null, tre, amt, 'mint', coalesce(reason, 'mint'), current_member_id());
end; $$;
grant execute on function token_mint(numeric, text) to authenticated;

-- grant tokens from the treasury to a member (governance only)
create or replace function token_grant(target uuid, amt numeric, reason text)
returns void language plpgsql security definer set search_path = public as $$
declare tre uuid; tacc uuid;
begin
  if not has_capability('manage_tokens') then raise exception 'not authorized'; end if;
  if amt is null or amt <= 0 then raise exception 'amount must be positive'; end if;
  select id into tre  from token_account where kind = 'treasury' limit 1;
  select id into tacc from token_account where member_id = target;
  if tacc is null then raise exception 'member has no account'; end if;
  insert into token_ledger (from_account, to_account, amount, kind, reason, created_by)
  values (tre, tacc, amt, 'grant', coalesce(reason, 'grant'), current_member_id());
end; $$;
grant execute on function token_grant(uuid, numeric, text) to authenticated;

-- join a project (stakes the join cost) and become a member of it
create or replace function join_project(p uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  mid := current_member_id();
  if mid is null then raise exception 'no member record'; end if;
  perform _stake_join(p, mid);
  insert into project_member (project_id, member_id, project_role_id)
  values (p, mid, role_id) on conflict do nothing;
end; $$;
grant execute on function join_project(uuid, uuid) to authenticated;

-- endorse a peer's skill by transferring your own tokens to them
create or replace function endorse_skill(target uuid, sk uuid, amt numeric, note text)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; minamt numeric; macc uuid; tacc uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if me = target then raise exception 'cannot endorse yourself'; end if;
  select value into minamt from token_policy where key = 'endorse_min';
  if amt is null or amt < coalesce(minamt, 1) then
    raise exception 'amount below minimum (%)', coalesce(minamt, 1);
  end if;
  select id into macc from token_account where member_id = me;
  select id into tacc from token_account where member_id = target;
  if tacc is null then raise exception 'target has no account'; end if;
  if token_balance_of(macc) < amt then
    raise exception 'insufficient tokens (have %)', token_balance_of(macc);
  end if;
  insert into token_ledger (from_account, to_account, amount, kind, reason, skill_id, created_by)
  values (macc, tacc, amt, 'endorse', coalesce(note, 'skill endorsement'), sk, me);
end; $$;
grant execute on function endorse_skill(uuid, uuid, numeric, text) to authenticated;

-- finish a project: mint the bonus into escrow, split escrow among authors by role weight
create or replace function finish_project(p uuid)
returns void language plpgsql security definer set search_path = public as $$
declare esc uuid; bonus numeric; pool numeric; wsum numeric; fin uuid;
begin
  if not manages_project(p) and not has_capability('edit_any_project') then
    raise exception 'not authorized';
  end if;
  select id into esc from token_account where project_id = p;
  if esc is null then raise exception 'project account missing'; end if;

  select value into bonus from token_policy where key = 'finish_bonus';
  if coalesce(bonus, 0) > 0 then
    insert into token_ledger (from_account, to_account, amount, kind, reason, project_id, created_by)
    values (null, esc, bonus, 'mint', 'project completion bonus', p, current_member_id());
  end if;

  pool := token_balance_of(esc);
  select coalesce(sum(pr.payout_weight), 0) into wsum
  from project_member pm join project_role pr on pr.id = pm.project_role_id
  where pm.project_id = p;

  if wsum > 0 and pool > 0 then
    insert into token_ledger (from_account, to_account, amount, kind, reason, project_id, created_by)
    select esc, ta.id, round(pool * pr.payout_weight / wsum, 2),
           'payout', 'project completion payout', p, current_member_id()
    from project_member pm
    join project_role pr on pr.id = pm.project_role_id
    join token_account ta on ta.member_id = pm.member_id
    where pm.project_id = p;
  end if;

  select id into fin from project_status where name = 'Finished' limit 1;
  if fin is not null then update project set status_id = fin where id = p; end if;
end; $$;
grant execute on function finish_project(uuid) to authenticated;

-- accept an application: stake the applicant's join cost, then add them as author
create or replace function accept_application(app_id uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid;
begin
  select n.project_id, na.member_id into pid, mid
  from need_application na
  join open_need n on n.id = na.open_need_id
  where na.id = app_id;

  if pid is null then raise exception 'application not found'; end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then
    raise exception 'not authorized to accept for this project';
  end if;

  perform _stake_join(pid, mid);
  update need_application set status = 'accepted' where id = app_id;
  insert into project_member (project_id, member_id, project_role_id)
  values (pid, mid, role_id) on conflict do nothing;
end; $$;
grant execute on function accept_application(uuid, uuid) to authenticated;

-- welcome grant on first login (folded into membership claim)
create or replace function claim_membership()
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid; tre uuid; macc uuid; w numeric;
begin
  update member
     set auth_user_id = auth.uid(), status = 'active'
   where email = auth.email() and auth_user_id is null
  returning id into mid;

  update invite set accepted_at = now()
   where email = auth.email() and accepted_at is null;

  if mid is not null then
    select id into macc from token_account where member_id = mid;
    if macc is null then
      insert into token_account (kind, member_id) values ('member', mid) returning id into macc;
    end if;
    select id into tre from token_account where kind = 'treasury' limit 1;
    select value into w from token_policy where key = 'welcome_grant';
    if coalesce(w, 0) > 0
       and not exists (select 1 from token_ledger where to_account = macc and kind = 'grant') then
      insert into token_ledger (from_account, to_account, amount, kind, reason, created_by)
      values (tre, macc, w, 'grant', 'welcome grant', mid);
    end if;
  end if;

  return mid;
end; $$;
grant execute on function claim_membership() to authenticated;

-- ---------- RLS ----------
alter table token_account enable row level security;
alter table token_ledger  enable row level security;
alter table token_policy  enable row level security;

-- full transparency: everyone reads accounts + ledger; writes only via RPCs
drop policy if exists read_token_account on token_account;
create policy read_token_account on token_account for select to authenticated using (true);

drop policy if exists read_token_ledger on token_ledger;
create policy read_token_ledger on token_ledger for select to authenticated using (true);

-- policy table: everyone reads; manage_tokens edits
drop policy if exists read_token_policy on token_policy;
create policy read_token_policy on token_policy for select to authenticated using (true);
drop policy if exists manage_token_policy on token_policy;
create policy manage_token_policy on token_policy for all to authenticated
  using (has_capability('manage_tokens')) with check (has_capability('manage_tokens'));

-- ---------- bootstrap: fund treasury + seed the President ----------
do $$
declare tre uuid; macc uuid;
begin
  select id into tre from token_account where kind = 'treasury' limit 1;
  -- initial supply so the economy can run
  if token_balance_of(tre) = 0 then
    insert into token_ledger (from_account, to_account, amount, kind, reason)
    values (null, tre, 100000, 'mint', 'initial supply');
  end if;
  -- give the seeded President a starting balance if they have none
  select a.id into macc from token_account a
  join member m on m.id = a.member_id
  where m.email = 'jimin.huang@thefin.ai' limit 1;
  if macc is not null and token_balance_of(macc) = 0 then
    insert into token_ledger (from_account, to_account, amount, kind, reason)
    values (tre, macc, (select value from token_policy where key = 'welcome_grant'),
            'grant', 'welcome grant');
  end if;
end $$;

-- drop the superseded free-endorsement table (folded into the ledger)
drop table if exists skill_endorsement cascade;
