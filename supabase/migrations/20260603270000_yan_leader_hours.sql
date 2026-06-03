-- ============================================================
-- Yan data fix (part 2):
--   1) Re-add Yan as LEADER of "MoE post training" — the previous fix removed it,
--      but he really does lead it. Restore the leader commitment + Leader role +
--      mark the slot filled.
--   2) Backfill the standard leader monthly hours on ALL his leader commitments
--      (they were seated with monthly_amount = 0). Standard = 40 hrs/mo per the
--      contribution model's canonical example (docs/contribution-model.md:164).
--   3) Recompute his "My time" labour capacity = Σ committed hours across
--      work_labor + leader slots (latest year_month per slot).
--
-- Uses the ids confirmed from the prior migration's NOTICE output. Re-runnable.
-- ============================================================

do $$
declare
  v_yan   uuid := '422ee34e-c932-46a7-b913-4532a1597147';  -- Yan
  v_moe   uuid := 'f07f782c-748b-491e-af94-2f80c20c9d08';  -- MoE post training
  v_hrs   int  := 40;        -- our standard leader monthly hours (change here if 20)
  v_ym    text := '2026-06'; -- current commitment month
  v_slot  uuid; v_role uuid; v_total numeric;
begin
  -- 1) re-add Yan as leader of MoE post training
  select id into v_slot from project_slot
    where project_id = v_moe and slot_kind = 'leader' order by created_at limit 1;
  if v_slot is null then
    raise exception 'MoE post training has no leader slot';
  end if;

  insert into work_commitment
    (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval)
  values (v_slot, v_moe, v_yan, v_ym, v_hrs, 0, 'ok')
  on conflict (slot_id, member_id, year_month)
    do update set monthly_amount = excluded.monthly_amount;

  update project_slot set status = 'filled' where id = v_slot;

  select id into v_role from project_role where name = 'Leader' limit 1;
  if v_role is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (v_moe, v_yan, v_role) on conflict do nothing;
  end if;

  -- 2) backfill the standard hours on every leader commitment of his that is 0
  update work_commitment w
     set monthly_amount = v_hrs
    from project_slot s
   where w.slot_id = s.id and s.slot_kind = 'leader' and w.member_id = v_yan
     and coalesce(w.monthly_amount, 0) = 0;

  -- 3) recompute "My time" capacity = Σ latest-month hours over labour + leader
  select coalesce(sum(amt), 0) into v_total from (
    select distinct on (w.slot_id) w.monthly_amount as amt
      from work_commitment w
      join project_slot s on s.id = w.slot_id
     where w.member_id = v_yan and s.slot_kind in ('work_labor', 'leader')
     order by w.slot_id, w.year_month desc
  ) t;

  update resource set capacity = round(v_total)::int::text || ' hrs/mo'
   where holder_member_id = v_yan and scope = 'member'
     and type_id = (select id from resource_type where name = 'Labor' limit 1);

  raise notice 'Yan: re-added MoE leader; leader hours=%; My time total=% hrs/mo',
    v_hrs, round(v_total);
end $$;
