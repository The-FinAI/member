-- =====================================================================
-- The Fin AI Community — Migration A: contribution = minted stake
-- Builds the contribution-model.md spec on top of stater.sql:
--   * Labor as a monthly, rolling, declare=mint commitment (nominal STR)
--   * Two real bonds (contributor 20 / leader 50) seed nominal + fund pool
--   * Milestones = outcome minting (catalog: nominal_value + multiplier_bonus)
--   * Settlement mints work-backed finish bonus = nominal_pool × multiplier
--   * Folds in resource_approval.sql (labor pledges are resources too)
-- NOMINAL STR is accounting only — it never enters stater_balance (liquid).
-- Real liquid mint happens once, at approve_settlement. Idempotent where
-- practical; safe to re-run.
-- =====================================================================

-- ---------- 0. new policy keys + numeric policy helper ----------
insert into stater_policy (key, value, description) values
  ('genesis_float',            500, 'Liquid STR floated to bootstrap bonds + early exam fees'),
  ('finish_bonus_ratio',       1.0, 'Base settlement mint multiplier (×1 = labor at face value)'),
  ('milestone_multiplier_cap', 3.0, 'Hard cap on the settlement mint multiplier'),
  ('exam_fee_treasury_cut',    0.2, 'Treasury cut of a skill-exam fee (Migration B)')
on conflict (key) do nothing;

-- numeric (decimal) policy reader — stater_policy_int truncates to int
create or replace function stater_policy_num(k text, dflt numeric)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select value from stater_policy where key = k), dflt);
$$;

-- ---------- 1. Labor resource type (a member's time is a resource) ----------
insert into resource_type (name, rank) values ('Labor', 0)
on conflict (name) do nothing;

-- ---------- 2. resource approval gate (folded in from resource_approval.sql) -
alter table resource
  add column if not exists approval_status text not null default 'pending'
  check (approval_status in ('pending', 'approved', 'rejected'));
update resource set approval_status = 'approved' where approval_status = 'pending';

create or replace function _resource_approval_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if has_capability('manage_resources') then return new; end if;
  if tg_op = 'INSERT' then new.approval_status := 'pending';
  elsif tg_op = 'UPDATE' then new.approval_status := old.approval_status; end if;
  return new;
end; $$;
drop trigger if exists resource_approval_guard on resource;
create trigger resource_approval_guard
  before insert or update on resource
  for each row execute function _resource_approval_guard();

-- ---------- 3. needs become contribution-typed ----------
alter table open_need add column if not exists contribution_kind text not null default 'seat'
  check (contribution_kind in ('seat', 'labor', 'resource'));
alter table open_need add column if not exists hours_per_month numeric;

-- ---------- 4. labor commitments: allow 'labor' type + monthly periods ------
alter table stater_project_stake_commitment drop constraint if exists stater_project_stake_commitment_commitment_type_check;
alter table stater_project_stake_commitment add constraint stater_project_stake_commitment_commitment_type_check
  check (commitment_type in
    ('leader_initiation','join_token','first_author_writing','skill_time','labor','resource'));

-- one row per (commitment, month). declare = mint → status defaults 'minted'.
create table if not exists stater_commitment_period (
  id               uuid primary key default gen_random_uuid(),
  commitment_id    uuid not null references stater_project_stake_commitment (id) on delete cascade,
  year_month       text not null,                       -- 'YYYY-MM'
  committed_amount numeric not null default 0,           -- hours (labor) or units
  token_equivalent integer not null default 0,           -- minted nominal STR for the month
  status           text not null default 'minted'
                   check (status in ('declared','minted','discounted')),
  created_at       timestamptz not null default now(),
  unique (commitment_id, year_month)
);
create index if not exists stater_commitment_period_cid_idx on stater_commitment_period (commitment_id);

-- ---------- 5. milestone catalog + per-project claims ----------
create table if not exists milestone_catalog (
  id               uuid primary key default gen_random_uuid(),
  category         text not null,
  item             text not null,
  nominal_value    integer not null default 0,    -- §20.2 STR added to the pool
  multiplier_bonus numeric not null default 0,     -- bump to the settlement multiplier
  rank             int not null default 100,
  unique (category, item)
);
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
create index if not exists project_milestone_project_idx on project_milestone (project_id);

-- ---------- 6. nominal-accounting helpers (NOT liquid) ----------
-- a member's nominal claim on a project = bonds + resource valuations + labor mints
create or replace function stater_member_nominal(p uuid, mid uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select
    coalesce((select sum(token_amount) + sum(token_equivalent)
              from stater_project_stake_commitment
              where project_id = p and member_id = mid), 0)
  + coalesce((select sum(cp.token_equivalent)
              from stater_commitment_period cp
              join stater_project_stake_commitment c on c.id = cp.commitment_id
              where c.project_id = p and c.member_id = mid and cp.status = 'minted'), 0);
$$;

-- total nominal pool = Σ member nominal + Σ verified-milestone nominal
create or replace function stater_project_nominal_pool(p uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select
    coalesce((select sum(token_amount) + sum(token_equivalent)
              from stater_project_stake_commitment where project_id = p), 0)
  + coalesce((select sum(cp.token_equivalent)
              from stater_commitment_period cp
              join stater_project_stake_commitment c on c.id = cp.commitment_id
              where c.project_id = p and cp.status = 'minted'), 0)
  + coalesce((select sum(mc.nominal_value)
              from project_milestone pm join milestone_catalog mc on mc.id = pm.catalog_id
              where pm.project_id = p and pm.status = 'verified'), 0);
$$;

-- settlement multiplier = base + Σ verified milestone bonuses, capped
create or replace function stater_milestone_mult(p uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select least(
    stater_policy_num('finish_bonus_ratio', 1.0)
    + coalesce((select sum(mc.multiplier_bonus)
                from project_milestone pm join milestone_catalog mc on mc.id = pm.catalog_id
                where pm.project_id = p and pm.status = 'verified'), 0),
    stater_policy_num('milestone_multiplier_cap', 3.0));
$$;

-- per-member nominal view (drives roster accrued + share % in the UI)
create or replace view stater_project_member_nominal as
select pm.project_id, pm.member_id, stater_member_nominal(pm.project_id, pm.member_id) as nominal
from (select distinct project_id, member_id from project_member) pm;

-- ---------- 7. rolling monthly labor: declare = mint ----------
create or replace function set_labor_commitment(p uuid, sk uuid, ym text, hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; rate integer; equiv integer;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if sk is null then raise exception 'a labor commitment needs a skill'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if hours < 0 then raise exception 'hours cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing labor';
  end if;

  -- find or create the standing labor commitment for this member + skill
  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'labor' and skill_id = sk
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, skill_id, status)
    values (p, me, 'labor', sk, 'verified') returning id into cid;
  end if;

  rate  := coalesce((select s.rate from stater_skill_rate s where s.skill_id = sk),
                    stater_policy_int('paper_writing_rate', 10));
  equiv := ceil(rate * hours);

  -- declare = mint: write the month's nominal straight into the pool accounting
  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, hours, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';
  return cid;
end; $$;
grant execute on function set_labor_commitment(uuid, uuid, text, numeric) to authenticated;

-- ---------- 8. confirm_join: 20 bond + open this month's labor period --------
-- Charges the join bond (real STR into escrow) and, for a labor-typed need,
-- opens the current month's commitment (declare = mint).
create or replace function confirm_join(app_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid; rid uuid; nid uuid; hc integer; js integer; bal numeric;
        joined_cnt integer; kind text; need_skill uuid; hpm numeric; ym text;
begin
  select n.project_id, na.member_id, n.project_role_id, n.id, n.headcount,
         n.contribution_kind, n.skill_id, n.hours_per_month
    into pid, mid, rid, nid, hc, kind, need_skill, hpm
  from need_application na join open_need n on n.id = na.open_need_id
  where na.id = app_id and na.status = 'accepted';
  if mid is null then raise exception 'no accepted application to confirm'; end if;
  if mid <> current_member_id() then raise exception 'not your application'; end if;

  js := coalesce(
    (select join_stake from project_type t join project pr on pr.type_id = t.id where pr.id = pid),
    stater_policy_int('join_stake_normal', 20));
  select coalesce(balance, 0) into bal from stater_balance where owner_member_id = mid;
  if coalesce(bal, 0) < js then
    raise exception 'insufficient STR balance: joining stakes %, you have %', js, coalesce(bal, 0);
  end if;

  update need_application set status = 'joined' where id = app_id;
  perform _stater_seat(pid, mid, rid, 'join_token', js, 0, null, null, null);

  -- labor need: open the current month's commitment immediately (declare = mint)
  if kind = 'labor' and need_skill is not null and coalesce(hpm, 0) > 0 then
    ym := to_char(now(), 'YYYY-MM');
    perform set_labor_commitment(pid, need_skill, ym, hpm);
  end if;

  select count(*) into joined_cnt from need_application where open_need_id = nid and status = 'joined';
  if joined_cnt >= hc then update open_need set status = 'filled' where id = nid; end if;
end; $$;
grant execute on function confirm_join(uuid) to authenticated;

-- ---------- 9. milestones: claim → verify (mints nominal, bumps multiplier) --
create or replace function claim_milestone(p uuid, p_catalog_id uuid, p_title text)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; msid uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me)
     and not has_capability('edit_any_project') then
    raise exception 'only project members can claim a milestone';
  end if;
  insert into project_milestone (project_id, catalog_id, title, status, claimed_by)
  values (p, p_catalog_id, p_title, 'claimed', me) returning id into msid;
  return msid;
end; $$;
grant execute on function claim_milestone(uuid, uuid, text) to authenticated;

-- verify: nominal_value accrues to the pool (via the verified status) and the
-- catalog item's multiplier_bonus accrues to the project multiplier (no liquid
-- mint here — real STR is minted once, at settlement).
create or replace function verify_milestone(milestone_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select project_id into pid from project_milestone where id = milestone_id;
  if pid is null then raise exception 'milestone not found'; end if;
  if not has_capability('manage_stater') and not has_capability('manage_resources')
     and not has_capability('edit_any_project') then
    raise exception 'not authorized to verify milestones';
  end if;
  update project_milestone
     set status = 'verified', verified_by = current_member_id(), verified_at = now()
   where id = milestone_id and status in ('claimed','under_review');
end; $$;
grant execute on function verify_milestone(uuid) to authenticated;

create or replace function reject_milestone(milestone_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_stater') and not has_capability('manage_resources')
     and not has_capability('edit_any_project') then
    raise exception 'not authorized';
  end if;
  update project_milestone set status = 'rejected'
   where id = milestone_id and status in ('claimed','under_review');
end; $$;
grant execute on function reject_milestone(uuid) to authenticated;

-- ---------- 10. settlement: work-backed finish mint = nominal_pool × mult ----
-- Replaces the flat per-type finish_bonus with a mint tied to delivered nominal
-- value, scaled by the verified-milestone multiplier (capped). Distribution by
-- the leader's drafted weights (final_payout_weight) is unchanged.
create or replace function approve_settlement(settlement_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; esc uuid; mult numeric; nominal numeric;
        target integer; escbal integer; mint_amt integer; pool integer; wsum numeric; r record;
begin
  if not has_capability('manage_stater') and not has_capability('edit_any_project') then
    raise exception 'not authorized to approve';
  end if;
  select project_id into pid from stater_settlement
   where id = settlement_id and status in ('submitted','under_review');
  if pid is null then raise exception 'settlement not found or already resolved'; end if;
  esc := stater_project_acc(pid);

  mult    := stater_milestone_mult(pid);
  nominal := stater_project_nominal_pool(pid);
  target  := floor(nominal * mult);               -- total payout pool target
  escbal  := stater_balance_of(esc);              -- real STR already escrowed (bonds)
  mint_amt := target - escbal;                    -- mint only the work-backed difference
  if mint_amt > 0 then
    insert into stater_ledger
      (entry_type, from_account, to_account, amount, reason, project_id, settlement_id, created_by, metadata)
    values ('finish_bonus', null, esc, mint_amt, 'work-backed finish mint', pid, settlement_id,
            current_member_id(), jsonb_build_object('nominal_pool', nominal, 'multiplier', mult));
  end if;

  pool := stater_balance_of(esc);
  select coalesce(sum(final_payout_weight), 0) into wsum
    from stater_settlement_item where settlement_id = approve_settlement.settlement_id;

  if wsum > 0 and pool > 0 then
    for r in select member_id, final_payout_weight, is_author
             from stater_settlement_item where settlement_id = approve_settlement.settlement_id loop
      if r.final_payout_weight > 0 then
        insert into stater_ledger
          (entry_type, from_account, to_account, amount, reason, project_id, settlement_id, created_by)
        values ('payout', esc, stater_member_acc(r.member_id),
                floor(pool * r.final_payout_weight / wsum), 'settlement payout', pid,
                settlement_id, current_member_id());
      end if;
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

-- ---------- 11. RLS for new tables ----------
alter table stater_commitment_period enable row level security;
alter table milestone_catalog        enable row level security;
alter table project_milestone        enable row level security;

drop policy if exists read_commitment_period on stater_commitment_period;
create policy read_commitment_period on stater_commitment_period for select to authenticated using (true);

drop policy if exists read_milestone_catalog on milestone_catalog;
create policy read_milestone_catalog on milestone_catalog for select to authenticated using (true);
drop policy if exists manage_milestone_catalog on milestone_catalog;
create policy manage_milestone_catalog on milestone_catalog for all to authenticated
  using (has_capability('manage_stater')) with check (has_capability('manage_stater'));

drop policy if exists read_project_milestone on project_milestone;
create policy read_project_milestone on project_milestone for select to authenticated using (true);

grant select on stater_commitment_period, milestone_catalog, project_milestone,
                stater_project_member_nominal to anon, authenticated;

notify pgrst, 'reload schema';
