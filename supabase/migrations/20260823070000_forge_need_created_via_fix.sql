-- Live 400 "invalid input syntax for type uuid: 'market'": project_slot.created_via
-- is a uuid (a forge_request reference), but 20260821010000's forge_need wrote the
-- string 'market' into it. Recreate without touching created_via.
create or replace function forge_need(
  p_project uuid, p_kind text, p_level guild_level default null,
  p_skill uuid default null, p_resource_type uuid default null,
  p_capacity numeric default null, p_headcount int default 1,
  p_authorship text default 'normal')
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if p_kind not in ('work_labor','work_resource') then raise exception 'invalid need kind'; end if;
  if p_authorship not in ('first','co','last_candidate','normal','corresponding','last') then
    raise exception 'invalid authorship'; end if;
  if current_member_id() is null then raise exception 'sign in first'; end if;
  insert into project_slot
    (project_id, slot_kind, skill_id, resource_type_id, desired_level,
     quota, headcount, authorship, status)
  values
    (p_project, p_kind, p_skill, p_resource_type, p_level,
     p_capacity, coalesce(p_headcount,1), p_authorship, 'open')
  returning id into sid;
  return sid;
end $$;
grant execute on function forge_need(uuid, text, guild_level, uuid, uuid, numeric, int, text) to authenticated;

notify pgrst, 'reload schema';
