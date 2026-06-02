-- ============================================================
-- Officer/manager direct-assign: put a member or card straight onto a
-- project's roster, skipping the apply → accept → confirm loop.
--
-- Gated on manages_project(p) (the caller, or a card they manage, holds a
-- can_manage role on the project) OR the edit_any_project capability. Unlike
-- confirm_join this charges NO join bond and creates no stake commitment — an
-- admin-placed contributor shouldn't be forced to stake STR, and the target's
-- balance must not be touched. The member_joined event trigger still fires on
-- the project_member insert, so the roster/history stay consistent.
-- ============================================================

create or replace function assign_member(p_project uuid, p_member uuid, p_role uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare rid uuid;
begin
  if not manages_project(p_project) and not has_capability('edit_any_project') then
    raise exception 'not authorized to assign members to this project';
  end if;
  if not exists (select 1 from member where id = p_member) then
    raise exception 'no such member';
  end if;
  rid := coalesce(
    p_role,
    (select id from project_role where name = 'Contributor' limit 1),
    (select id from project_role order by name limit 1)
  );
  if rid is null then
    raise exception 'no project role available';
  end if;
  insert into project_member (project_id, member_id, project_role_id)
  values (p_project, p_member, rid)
  on conflict do nothing;
end; $$;

grant execute on function assign_member(uuid, uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
