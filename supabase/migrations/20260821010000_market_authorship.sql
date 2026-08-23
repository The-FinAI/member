-- Market Phase 1 ①: author-role on every opening (v48 spec).
-- A seat is an AUTHOR POSITION with a price: role (first/normal/corresponding/
-- last) × required contribution. Extends the existing authorship domain and
-- lets forge_need declare the role at posting time.
alter table project_slot drop constraint if exists project_slot_authorship_check;
alter table project_slot add constraint project_slot_authorship_check
  check (authorship in ('first','co','last_candidate','normal','corresponding','last'));

-- the old 7-arg signature must go, or PostgREST sees an ambiguous overload
drop function if exists forge_need(uuid, text, guild_level, uuid, uuid, numeric, int);

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
     quota, headcount, authorship, status, created_via)
  values
    (p_project, p_kind, p_skill, p_resource_type, p_level,
     p_capacity, coalesce(p_headcount,1), p_authorship, 'open', 'market')
  returning id into sid;
  return sid;
end $$;
grant execute on function forge_need(uuid, text, guild_level, uuid, uuid, numeric, int, text) to authenticated;
