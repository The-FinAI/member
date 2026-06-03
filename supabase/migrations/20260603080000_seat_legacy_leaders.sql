-- =====================================================================
-- Backfill — seat legacy project leaders into their new leader slot
-- ---------------------------------------------------------------------
-- The Phase 1 rebuild created a leader slot per project and even marked it
-- 'filled' when a legacy leader existed (project_member with a can_manage
-- role) — but it never created the work_commitment that actually seats the
-- person. The UI reads the leader from the slot's work_commitment, so those
-- projects showed "lead open" / no first author. This backfills the missing
-- work_commitment for each project's existing leader.
-- Idempotent: only seats a leader slot that has no commitment yet.
-- =====================================================================

begin;

-- one leader per project: prefer the 'Leader' role, else any can_manage member
with leader_pick as (
  select distinct on (pm.project_id)
         pm.project_id, pm.member_id
  from project_member pm
  join project_role pr on pr.id = pm.project_role_id
  where pr.can_manage
  order by pm.project_id, (pr.name = 'Leader') desc, pm.member_id
)
insert into work_commitment
  (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval)
select ls.id, lp.project_id, lp.member_id, to_char(now(), 'YYYY-MM'), 0, 0, 'ok'
from leader_pick lp
join project_slot ls
  on ls.project_id = lp.project_id and ls.slot_kind = 'leader'
where not exists (select 1 from work_commitment w where w.slot_id = ls.id)
on conflict (slot_id, member_id, year_month) do nothing;

-- reflect the seating in the slot status
update project_slot s
   set status = 'filled'
 where s.slot_kind = 'leader'
   and s.status is distinct from 'filled'
   and exists (select 1 from work_commitment w where w.slot_id = s.id);

commit;
