-- F5: project.type_id was not editable after creation — no RPC existed.
-- Adds project_set_type() so officers/admins can correct the type after creation.
create or replace function project_set_type(p_project uuid, p_type uuid)
returns void language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if p_type is not null and not exists (select 1 from project_type where id = p_type) then
    raise exception 'no such project type';
  end if;
  update project set type_id = p_type where id = p_project;
  select name into nm from project_type where id = p_type;
  perform project_log(p_project, 'Type set to ' || coalesce(nm, 'none'));
end $$;
grant execute on function project_set_type(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
