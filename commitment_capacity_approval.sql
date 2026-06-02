-- =====================================================================
-- Commitment capacity soft-check + consolidated approval portal.
--
-- A member declares a monthly capacity for what they can bring:
--   * labor   — the numeric capacity on their personal 'Labor' resource
--               (hours / month they can give across ALL projects)
--   * resource — the numeric capacity on that resource (units / month)
-- When the member's cross-project SUM of monthly committed amounts for
-- that labor (by member) or resource (by member+resource) exceeds the
-- declared capacity, every period feeding that month is flagged
-- 'needs_review' and surfaces in the approval portal.  This is a SOFT
-- check: declaring still mints (we never block the member); an officer
-- later approves (keep) or rejects (discounts it out of the pool).
--
-- Builds on contributions.sql (stater_commitment_period) and
-- resource_economy_v2.sql / card_proxy.sql (the 5-arg setters).
-- Idempotent: safe to re-run.  Apply AFTER card_proxy.sql.
-- =====================================================================

-- ---------- 0. per-period approval state ----------
-- 'ok'           — within capacity, nothing to review
-- 'needs_review' — over capacity, awaiting an officer decision
-- 'approved'     — officer kept it (sticky; recalc won't touch)
-- 'rejected'     — officer discounted it (sticky; status -> 'discounted')
alter table stater_commitment_period
  add column if not exists approval text not null default 'ok'
  check (approval in ('ok', 'needs_review', 'approved', 'rejected'));

create index if not exists stater_commitment_period_approval_idx
  on stater_commitment_period (approval);

-- ---------- 1. numeric capacity parsers ----------
-- Pull the first number out of free text (e.g. '100 GPU-hours/mo' -> 100,
-- '20h' -> 20, 'about 5.5 per week' -> 5.5).  NULL = no declared cap.
create or replace function _capacity_num(txt text)
returns numeric language sql immutable set search_path = public as $$
  select nullif((regexp_match(coalesce(txt, ''), '([0-9]+(?:\.[0-9]+)?)'))[1], '')::numeric;
$$;

-- numeric monthly capacity declared on a resource
create or replace function resource_capacity_num(res uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select _capacity_num((select capacity from resource where id = res));
$$;
grant execute on function resource_capacity_num(uuid) to authenticated;

-- a member's monthly LABOR capacity = the largest numeric capacity declared
-- on a 'Labor'-type resource they hold.  NULL = undeclared = no cap.
create or replace function member_labor_cap(p_member uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select max(_capacity_num(r.capacity))
  from resource r
  join resource_type rt on rt.id = r.type_id
  where r.holder_member_id = p_member and rt.name = 'Labor';
$$;
grant execute on function member_labor_cap(uuid) to authenticated;

-- ---------- 2. recalc helpers (set after every upsert) ----------
-- Sum the member's committed LABOR hours for the month across ALL projects.
-- Over cap -> flag every still-open period 'needs_review'; back under cap ->
-- clear them to 'ok'.  Officer decisions ('approved'/'rejected') are sticky.
create or replace function _recalc_labor_approval(p_member uuid, p_ym text)
returns void language plpgsql security definer set search_path = public as $$
declare cap numeric; tot numeric; over boolean;
begin
  cap := member_labor_cap(p_member);
  select coalesce(sum(cp.committed_amount), 0) into tot
  from stater_commitment_period cp
  join stater_project_stake_commitment c on c.id = cp.commitment_id
  where c.member_id = p_member and c.commitment_type = 'labor' and cp.year_month = p_ym;

  over := cap is not null and tot > cap;

  update stater_commitment_period cp
     set approval = case when over then 'needs_review' else 'ok' end
    from stater_project_stake_commitment c
   where c.id = cp.commitment_id
     and c.member_id = p_member and c.commitment_type = 'labor'
     and cp.year_month = p_ym
     and cp.approval in ('ok', 'needs_review');
end; $$;

-- Same, scoped to one resource (units / month for member + resource).
create or replace function _recalc_resource_approval(p_member uuid, p_res uuid, p_ym text)
returns void language plpgsql security definer set search_path = public as $$
declare cap numeric; tot numeric; over boolean;
begin
  cap := resource_capacity_num(p_res);
  select coalesce(sum(cp.committed_amount), 0) into tot
  from stater_commitment_period cp
  join stater_project_stake_commitment c on c.id = cp.commitment_id
  where c.member_id = p_member and c.commitment_type = 'resource'
    and c.resource_id = p_res and cp.year_month = p_ym;

  over := cap is not null and tot > cap;

  update stater_commitment_period cp
     set approval = case when over then 'needs_review' else 'ok' end
    from stater_project_stake_commitment c
   where c.id = cp.commitment_id
     and c.member_id = p_member and c.commitment_type = 'resource'
     and c.resource_id = p_res and cp.year_month = p_ym
     and cp.approval in ('ok', 'needs_review');
end; $$;

-- ---------- 3. re-create the 5-arg setters with the soft check ----------
-- Identical to card_proxy.sql, plus a capacity recalc after the upsert.
create or replace function set_labor_commitment(p uuid, sk uuid, ym text, hours numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; rate integer; equiv integer;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if sk is null then raise exception 'a labor commitment needs a skill'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if hours < 0 then raise exception 'hours cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing labor';
  end if;

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

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, hours, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';

  perform _recalc_labor_approval(me, ym);  -- soft capacity check across projects
  return cid;
end; $$;
grant execute on function set_labor_commitment(uuid, uuid, text, numeric, uuid) to authenticated;

create or replace function set_resource_commitment(p uuid, res uuid, ym text, qty numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; usd numeric; equiv integer; appr text; holder uuid; scp text;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if res is null then raise exception 'a resource commitment needs a resource'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if qty < 0 then raise exception 'quantity cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing a resource';
  end if;

  select approval_status, holder_member_id, scope into appr, holder, scp from resource where id = res;
  if appr is null then raise exception 'resource not found'; end if;
  if appr <> 'approved' then raise exception 'resource is not approved yet'; end if;
  if scp = 'member' and holder is not null and holder <> me then
    raise exception 'only the resource holder can commit it';
  end if;

  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'resource' and resource_id = res
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, resource_id, status)
    values (p, me, 'resource', res, 'verified') returning id into cid;
  end if;

  usd   := resource_value_usd(res, qty);
  equiv := ceil(usd * stater_policy_num('str_per_usd', 0.2));

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, qty, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';

  perform _recalc_resource_approval(me, res, ym);  -- soft capacity check across projects
  return cid;
end; $$;
grant execute on function set_resource_commitment(uuid, uuid, text, numeric, uuid) to authenticated;

-- ---------- 4. officer decision on a flagged period ----------
-- approve = keep it minted; reject = discount it out of the nominal pool.
create or replace function review_commitment_period(p_period uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_stater')
     and not has_capability('manage_resources')
     and not has_capability('manage_members') then
    raise exception 'not authorized to review commitments';
  end if;
  if p_approve then
    update stater_commitment_period
       set approval = 'approved', status = 'minted'
     where id = p_period;
  else
    -- discounted leaves the nominal pool (pool sums status = 'minted' only)
    update stater_commitment_period
       set approval = 'rejected', status = 'discounted'
     where id = p_period;
  end if;
end; $$;
grant execute on function review_commitment_period(uuid, boolean) to authenticated;

-- ---------- 5. review queue view (drives the approval portal) ----------
create or replace view commitment_review_queue as
select cp.id              as period_id,
       cp.year_month,
       cp.committed_amount,
       cp.token_equivalent,
       cp.approval,
       cp.status,
       c.commitment_type,
       c.project_id,
       pr.name            as project_name,
       c.member_id,
       m.full_name        as member_name,
       c.skill_id,
       sk.name            as skill_name,
       c.resource_id,
       rs.name            as resource_name,
       case c.commitment_type
         when 'labor'    then member_labor_cap(c.member_id)
         when 'resource' then resource_capacity_num(c.resource_id)
       end                as capacity,
       case c.commitment_type
         when 'labor' then (
           select coalesce(sum(cp2.committed_amount), 0)
           from stater_commitment_period cp2
           join stater_project_stake_commitment c2 on c2.id = cp2.commitment_id
           where c2.member_id = c.member_id and c2.commitment_type = 'labor'
             and cp2.year_month = cp.year_month)
         when 'resource' then (
           select coalesce(sum(cp2.committed_amount), 0)
           from stater_commitment_period cp2
           join stater_project_stake_commitment c2 on c2.id = cp2.commitment_id
           where c2.member_id = c.member_id and c2.commitment_type = 'resource'
             and c2.resource_id = c.resource_id and cp2.year_month = cp.year_month)
       end                as month_total
from stater_commitment_period cp
join stater_project_stake_commitment c on c.id = cp.commitment_id
join project pr on pr.id = c.project_id
join member  m  on m.id  = c.member_id
left join skill    sk on sk.id = c.skill_id
left join resource rs on rs.id = c.resource_id
where cp.approval = 'needs_review';

grant select on commitment_review_queue to authenticated;

-- ---------- 6. backfill: flag any existing over-capacity months ----------
do $$
declare r record;
begin
  for r in
    select distinct c.member_id, cp.year_month
    from stater_commitment_period cp
    join stater_project_stake_commitment c on c.id = cp.commitment_id
    where c.commitment_type = 'labor'
  loop
    perform _recalc_labor_approval(r.member_id, r.year_month);
  end loop;
  for r in
    select distinct c.member_id, c.resource_id, cp.year_month
    from stater_commitment_period cp
    join stater_project_stake_commitment c on c.id = cp.commitment_id
    where c.commitment_type = 'resource' and c.resource_id is not null
  loop
    perform _recalc_resource_approval(r.member_id, r.resource_id, r.year_month);
  end loop;
end $$;

notify pgrst, 'reload schema';
