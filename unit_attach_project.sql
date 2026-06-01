-- ============================================================
-- Working-group officers attach / detach projects to their group.
--
-- attach_project_to_unit(p_project, p_unit): set project.org_unit_id to
--   p_unit. Allowed for an officer of the TARGET unit (leader, or admin),
--   or the project's own leader/manager. Runs as definer so a WG leader can
--   attribute a project they don't otherwise own.
-- detach_project_from_unit(p_project): clear org_unit_id. Allowed for an
--   officer of the project's CURRENT unit, or admin.
-- Idempotent: safe to re-run.
-- ============================================================

create or replace function attach_project_to_unit(p_project uuid, p_unit uuid)
returns void language plpgsql security definer set search_path = public as $$
declare ukind text;
begin
  select kind into ukind from org_unit where id = p_unit;
  if ukind is null then raise exception 'no such org unit'; end if;
  if ukind <> 'working_group' then raise exception 'only working groups carry projects'; end if;
  if not exists (select 1 from project where id = p_project) then raise exception 'no such project'; end if;
  if not (is_unit_officer(p_unit) or (manages_project(p_project) or has_capability('edit_any_project'))) then
    raise exception 'only a leader of this group (or the project lead / admin) can attach it';
  end if;
  update project set org_unit_id = p_unit where id = p_project;
end; $$;
grant execute on function attach_project_to_unit(uuid, uuid) to authenticated;

create or replace function detach_project_from_unit(p_project uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cur uuid;
begin
  select org_unit_id into cur from project where id = p_project;
  if cur is null then return; end if;
  if not (is_unit_officer(cur) or (manages_project(p_project) or has_capability('edit_any_project'))) then
    raise exception 'only a leader of this group (or the project lead / admin) can detach it';
  end if;
  update project set org_unit_id = null where id = p_project;
end; $$;
grant execute on function detach_project_from_unit(uuid) to authenticated;

notify pgrst, 'reload schema';
