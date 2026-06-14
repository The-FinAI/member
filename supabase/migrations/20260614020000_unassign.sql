-- =====================================================================
-- Issue #33/#34: every assign needs a matching un-assign. There was only
-- assign() / work_seat() and release_claim() (which frees just the leader seat).
-- unassign() removes a member from a specific need (slot), re-opening it if it
-- drops below headcount, and clearing their project_member role for that project
-- if they hold no other commitment there. Authorised like assign().
-- =====================================================================

begin;

create or replace function unassign(p_slot uuid, p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s project_slot; remaining int; pname text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('manage_members') or manages_card(p_member)) then
    raise exception 'not allowed to change this assignment';
  end if;

  delete from work_commitment where slot_id = p_slot and member_id = p_member;

  -- re-open the slot if it's now below headcount
  select count(distinct member_id) into remaining from work_commitment where slot_id = p_slot;
  if remaining < s.headcount then
    update project_slot set status = 'open' where id = p_slot and status = 'filled';
  end if;

  -- drop their project_member role if they no longer hold any commitment here
  if not exists (select 1 from work_commitment where project_id = s.project_id and member_id = p_member) then
    delete from project_member where project_id = s.project_id and member_id = p_member;
  end if;

  select name into pname from project where id = s.project_id;
  perform notify(p_member, 'unassigned',
    'You were removed from a project role', pname,
    '/projects/' || s.project_id);
end $$;
grant execute on function unassign(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
