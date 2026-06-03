-- ============================================================
-- Yan data fix (part 2) — RESTORE his real committed hours from the deprecated
-- stake tables. The phase-1 rebuild never carried his stake commitments into
-- work_commitment (his leader slots got re-seated via the new UI at 0 hours),
-- so "我们之前设定过" the hours, they just never migrated.
--
-- Source of truth = stater_project_stake_commitment + stater_commitment_period:
--   first_author_writing -> the LEADER slot  (the leader's own writing hours)
--   labor                -> a work_labor slot (prefer same skill)
--   resource             -> a work_resource slot
--   leader_initiation    -> the 50 STR bond, no hours (skipped)
-- monthly_amount := committed_amount, nominal_str := token_equivalent
-- (same mapping the F1 migration used), upserted (no faulty dedup this time).
--
-- Then: mark the projects he leads filled + Leader role, and set his "My time"
-- capacity = Σ his committed labour+leader hours straight from the old tables
-- (so the number is right even where a target slot is missing).
-- Scoped to Yan; idempotent.
-- ============================================================

do $$
declare
  v_yan  uuid := '422ee34e-c932-46a7-b913-4532a1597147';  -- Yan
  v_role uuid; v_total numeric;
begin
  -- 1) import his labour-type monthly commitments into work_commitment
  with src as (
    select
      ( select s.id from project_slot s
         where s.project_id = c.project_id
           and s.slot_kind = case
                 when c.commitment_type = 'first_author_writing' then 'leader'
                 when c.commitment_type = 'resource'             then 'work_resource'
                 else 'work_labor' end
           and (c.skill_id is null or s.skill_id is null or s.skill_id = c.skill_id)
         order by case when s.skill_id = c.skill_id then 0 else 1 end, s.created_at
         limit 1 )                                   as slot_id,
      c.project_id, c.member_id, c.resource_id, cp.year_month,
      coalesce(cp.committed_amount, 0)               as hours,
      coalesce(cp.token_equivalent, 0)               as nom,
      coalesce(cp.approval, 'ok')                    as appr
    from stater_commitment_period cp
    join stater_project_stake_commitment c on c.id = cp.commitment_id
    where c.member_id = v_yan
      and c.commitment_type in ('first_author_writing', 'labor', 'resource')
      and coalesce(cp.committed_amount, 0) > 0
  )
  insert into work_commitment
    (slot_id, project_id, member_id, resource_id, year_month, monthly_amount, nominal_str, approval)
  select slot_id, project_id, member_id, resource_id, year_month, hours, nom, appr
    from src where slot_id is not null
  on conflict (slot_id, member_id, year_month) do update
     set monthly_amount = excluded.monthly_amount,
         nominal_str    = excluded.nominal_str;

  -- 2) projects he now leads -> slot filled + Leader role
  update project_slot s set status = 'filled'
   where s.slot_kind = 'leader'
     and exists (select 1 from work_commitment w where w.slot_id = s.id and w.member_id = v_yan);

  select id into v_role from project_role where name = 'Leader' limit 1;
  if v_role is not null then
    insert into project_member (project_id, member_id, project_role_id)
    select distinct s.project_id, v_yan, v_role
      from project_slot s join work_commitment w on w.slot_id = s.id
     where s.slot_kind = 'leader' and w.member_id = v_yan
    on conflict do nothing;
  end if;

  -- 3) "My time" capacity = Σ committed labour+leader hours from the old tables
  --    (latest year_month per commitment), authoritative regardless of slots.
  select coalesce(sum(amt), 0) into v_total from (
    select distinct on (c.id) cp.committed_amount as amt
      from stater_commitment_period cp
      join stater_project_stake_commitment c on c.id = cp.commitment_id
     where c.member_id = v_yan
       and c.commitment_type in ('first_author_writing', 'labor')
       and coalesce(cp.committed_amount, 0) > 0
     order by c.id, cp.year_month desc
  ) t;

  update resource set capacity = round(v_total)::int::text || ' hrs/mo'
   where holder_member_id = v_yan and scope = 'member'
     and type_id = (select id from resource_type where name = 'Labor' limit 1);

  raise notice 'Yan: restored from stake tables; My time = % hrs/mo', round(v_total);
end $$;
