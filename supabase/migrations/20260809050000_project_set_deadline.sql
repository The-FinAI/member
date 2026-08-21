-- F11: project.deadline had no direct edit UI — it only inherited from venue.
-- Adds project_set_deadline() so editors can set a project-specific deadline.
create or replace function project_set_deadline(p_project uuid, p_deadline date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  update project set deadline = p_deadline where id = p_project;
  perform project_log(p_project, 'Deadline set to ' || coalesce(p_deadline::text, 'none'));
end $$;
grant execute on function project_set_deadline(uuid, date) to authenticated;

notify pgrst, 'reload schema';
