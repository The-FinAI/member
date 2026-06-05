-- ============================================================
-- A project creator couldn't edit their own project (GH #5): creation no longer
-- seats them as leader, the project is unclaimed (no WG), so manages_project /
-- can_edit_project returned false. Track project.created_by and let the creator
-- manage/edit it. create_project_phase1 stamps created_by.
-- ============================================================

alter table project add column if not exists created_by uuid references member (id) on delete set null;

-- create_project_phase1: stamp the creator (otherwise unchanged from 360000)
create or replace function create_project_phase1(
  p_name text, p_type_id uuid, p_status_id uuid, p_wg_unit uuid default null,
  p_summary text default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'project name required'; end if;
  if p_wg_unit is not null
     and not (is_unit_officer(p_wg_unit) or has_capability('edit_any_project') or has_capability('manage_stater')) then
    raise exception 'only a working-group officer can create a project for this unit';
  end if;

  vname := (select name from venue where id = p_venue_id);
  insert into project (name, type_id, status_id, org_unit_id, target_venue, venue_id, summary, created_by)
  values (trim(p_name), p_type_id, p_status_id, p_wg_unit, vname, p_venue_id, p_summary, me)
  returning id into pid;
  perform stater_project_acc(pid);

  insert into project_slot (project_id, slot_kind, authorship, status, headcount)
  values (pid, 'leader', 'first', 'open', 1);

  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;
  return pid;
end $$;
grant execute on function create_project_phase1(text, uuid, uuid, uuid, text, uuid, text) to authenticated;

-- the creator counts as a manager/editor of their project
create or replace function manages_project(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select has_capability('edit_any_project')
    or (select created_by from project where id = p) = current_member_id()
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
    or (select created_by from project where id = p_project) = current_member_id()
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
