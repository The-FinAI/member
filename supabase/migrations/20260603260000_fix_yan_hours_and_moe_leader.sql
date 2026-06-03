-- ============================================================
-- One-off data fix (Yan):
--   1) Cancel Yan's leadership of the MoE project — drop his leader commitment
--      and Leader role row, and reopen that leader slot.
--   2) Recompute Yan's "My time" labour capacity = Σ of the hours he has
--      committed across projects on hour-denominated slots (work_labor + leader),
--      taking the latest year_month per slot (no double-count), AFTER the MoE
--      leader removal.
--
-- Guarded: aborts if "Yan" or "MoE" don't resolve to exactly one row, so it
-- can't touch the wrong person/project. Re-runnable (idempotent).
-- ============================================================

do $$
declare
  v_yan uuid; v_moe uuid; v_labor_type uuid; v_labor uuid;
  v_hours numeric; n int;
begin
  -- locate Yan (must be unique)
  select count(*) into n from member where full_name ilike '%Yan%';
  if n <> 1 then
    raise exception 'Expected exactly 1 member matching "Yan", found % — fix the filter.', n;
  end if;
  select id into v_yan from member where full_name ilike '%Yan%';

  -- locate the MoE project (must be unique)
  select count(*) into n from project where name ilike '%MoE%';
  if n <> 1 then
    raise exception 'Expected exactly 1 project matching "MoE", found % — fix the filter.', n;
  end if;
  select id into v_moe from project where name ilike '%MoE%';

  -- 1) reopen the leader slot Yan sits on, then drop his commitment + Leader role
  update project_slot s set status = 'open'
   where s.project_id = v_moe and s.slot_kind = 'leader'
     and exists (select 1 from work_commitment w where w.slot_id = s.id and w.member_id = v_yan);

  delete from work_commitment w using project_slot s
   where w.slot_id = s.id and s.project_id = v_moe and s.slot_kind = 'leader'
     and w.member_id = v_yan;

  delete from project_member pm using project_role r
   where pm.project_id = v_moe and pm.member_id = v_yan
     and pm.project_role_id = r.id and r.name = 'Leader';

  -- 2) recompute committed hours: latest year_month per slot, labour + leader
  select coalesce(sum(amt), 0) into v_hours from (
    select distinct on (w.slot_id) w.monthly_amount as amt
      from work_commitment w
      join project_slot s on s.id = w.slot_id
     where w.member_id = v_yan and s.slot_kind in ('work_labor', 'leader')
     order by w.slot_id, w.year_month desc
  ) t;

  select id into v_labor_type from resource_type where name = 'Labor' limit 1;
  select id into v_labor from resource
    where holder_member_id = v_yan and scope = 'member' and type_id = v_labor_type
    limit 1;

  if v_labor is null then
    insert into resource (name, type_id, scope, holder_member_id, capacity, availability)
    values ('My time', v_labor_type, 'member', v_yan,
            round(v_hours)::int::text || ' hrs/mo', 'available');
  else
    update resource set capacity = round(v_hours)::int::text || ' hrs/mo'
     where id = v_labor;
  end if;

  raise notice 'Yan=% MoE=% recomputed monthly hours=%', v_yan, v_moe, round(v_hours);
end $$;
