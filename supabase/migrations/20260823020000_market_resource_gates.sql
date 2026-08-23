-- Market member editor: resource CRUD under governance v0.3.
-- forge_resource: verbatim from 20260603230000, gate → signed-in.
-- resource_set_quota: narrow update (quota only) — update_resource would clobber
-- gpu_model/skills when called with defaults, so the market uses this instead.

create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null,
  p_skills jsonb default '[]'::jsonb, p_level guild_level default null,
  p_gpu_model uuid default null, p_api_model uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; rid uuid; req uuid;
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_scope not in ('member','community') then raise exception 'scope must be member|community'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'resource name required'; end if;
  if p_holder is null then raise exception 'a resource needs an in-community holder'; end if;
  if p_monthly_quota is null or p_monthly_quota < 0 then raise exception 'monthly_quota must be >= 0'; end if;

  submitter := current_member_id();
  insert into resource (type_id, name, scope, holder_member_id, monthly_quota, unit,
                        usd_per_unit, str_per_unit, skills, level, gpu_model_id, api_model_id)
  values (p_type, trim(p_name), p_scope, p_holder, p_monthly_quota, p_unit,
          p_usd_per_unit, p_str_per_unit, coalesce(p_skills,'[]'::jsonb), p_level, p_gpu_model, p_api_model)
  returning id into rid;

  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('resource', 'create', rid,
          jsonb_build_object('name', trim(p_name), 'scope', p_scope, 'holder_member_id', p_holder,
                             'monthly_quota', p_monthly_quota, 'skills', coalesce(p_skills,'[]'::jsonb), 'level', p_level),
          submitter, 'submitted')
  returning id into req;
  update resource set forge_request_id = req where id = rid;
  return req;
end $$;
grant execute on function forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level, uuid, uuid) to authenticated;

create or replace function resource_set_quota(p_resource uuid, p_quota numeric)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_quota is null or p_quota < 0 then raise exception 'quota must be >= 0'; end if;
  if not exists (select 1 from resource where id = p_resource) then raise exception 'no such resource'; end if;
  update resource set monthly_quota = p_quota where id = p_resource;
  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('resource', 'update', p_resource,
          jsonb_build_object('monthly_quota', p_quota), current_member_id(), 'approved');
end $$;
grant execute on function resource_set_quota(uuid, numeric) to authenticated;

-- project_set_venue: verbatim from 20260603040000 + keep the legacy
-- target_venue text column in sync (the UI and older surfaces read it).
create or replace function project_set_venue(p_project uuid, p_venue uuid)
returns void language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if p_venue is not null and not exists (select 1 from venue where id = p_venue) then
    raise exception 'no such venue';
  end if;
  select name into nm from venue where id = p_venue;
  update project set venue_id = p_venue, target_venue = nm where id = p_project;
  perform project_log(p_project, 'Target venue set to ' || coalesce(nm, 'none'));
end $$;
grant execute on function project_set_venue(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
