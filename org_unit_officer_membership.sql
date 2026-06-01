-- ============================================================
-- Officers are members of their unit.
--
-- 1. assign_org_officer() now also makes the officer an ACTIVE member of
--    the unit (via decide_unit_member, which syncs home chapter for a
--    chapter and retires any other active chapter membership).
-- 2. Backfill: every currently-serving officer becomes an active member,
--    and chapter officers without a home chapter get one.
--
-- Admins already manage membership directly: is_unit_officer() returns
-- true for manage_members, so decide_unit_member / officer_add_unit_member
-- work for admins on any unit.
-- Idempotent: safe to re-run.
-- ============================================================

create or replace function assign_org_officer(p_unit uuid, p_member uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare ukind text;
begin
  if not has_capability('manage_members') then raise exception 'requires manage_members capability'; end if;
  select kind into ukind from org_unit where id = p_unit;
  if ukind is null then raise exception 'no such org unit'; end if;
  if ukind = 'chapter'        and p_role not in ('chair', 'secretary') then
    raise exception 'chapters take chair or secretary'; end if;
  if ukind = 'working_group'  and p_role <> 'leader' then
    raise exception 'working groups take a leader'; end if;
  insert into org_unit_officer (org_unit_id, member_id, role)
  values (p_unit, p_member, p_role)
  on conflict (org_unit_id, member_id, role) do update set ended_on = null, started_on = current_date;
  -- an officer is a member of the unit they serve
  perform decide_unit_member(p_unit, p_member, true);
end; $$;
grant execute on function assign_org_officer(uuid, uuid, text) to authenticated;

-- ---------- backfill existing officers as active members ----------
insert into org_unit_member (org_unit_id, member_id, status, decided_on)
select o.org_unit_id, o.member_id, 'active', now()
from org_unit_officer o
where o.ended_on is null
on conflict (org_unit_id, member_id) do update set status = 'active', decided_on = now();

-- chapter officers without a home chapter adopt the chapter they serve
update member m set home_unit_id = o.org_unit_id
from org_unit_officer o
join org_unit u on u.id = o.org_unit_id
where o.member_id = m.id and o.ended_on is null
  and u.kind = 'chapter' and m.home_unit_id is null;

notify pgrst, 'reload schema';
