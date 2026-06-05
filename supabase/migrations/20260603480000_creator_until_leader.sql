-- ============================================================
-- The project CREATOR may manage/edit their project only while NO leader has
-- been seated yet (#5 follow-up). Once a leader fills the first-author seat,
-- the leader / WG officer takes over and the creator's created_by rights lapse.
-- ============================================================

create or replace function manages_project(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select has_capability('edit_any_project')
    or (
      (select created_by from project where id = p) = current_member_id()
      and not exists (
        select 1 from project_slot s join work_commitment w on w.slot_id = s.id
         where s.project_id = p and s.slot_kind = 'leader')
    )
    or exists (select 1 from project pj where pj.id = p
                and pj.org_unit_id is not null and is_unit_officer(pj.org_unit_id))
    or exists (
      select 1 from project_member pm join project_role pr on pr.id = pm.project_role_id
      where pm.project_id = p and pr.can_manage
        and (pm.member_id = current_member_id() or manages_card(pm.member_id))
    );
$$;
grant execute on function manages_project(uuid) to authenticated;

create or replace function can_edit_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    has_capability('edit_any_project')
    or has_capability('manage_members')
    or (
      (select created_by from project where id = p_project) = current_member_id()
      and not exists (
        select 1 from project_slot s join work_commitment w on w.slot_id = s.id
         where s.project_id = p_project and s.slot_kind = 'leader')
    )
    or exists (
      select 1 from project p where p.id = p_project
        and p.org_unit_id is not null and is_unit_officer(p.org_unit_id)
    )
    or exists (
      select 1 from project_member pm
      join project_role pr on pr.id = pm.project_role_id
      where pm.project_id = p_project
        and pm.member_id = current_member_id()
        and pr.can_manage
    );
$$;
grant execute on function can_edit_project(uuid) to authenticated;

notify pgrst, 'reload schema';
