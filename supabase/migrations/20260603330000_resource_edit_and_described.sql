-- ============================================================
-- (1) Editing an existing resource re-enters review.
--     - update_resource(): updates the row + raises an 'update' forge_request so
--       it shows in the queue; the approval guard auto-flips a member's edit back
--       to 'pending' whenever a substantive field changes.
-- (2) "Described" resource types (e.g. Dataset / Data Access) take free TEXT, not
--     a metered monthly quota. resource.details holds the description; the form
--     shows a text box instead of a number for these types.
-- ============================================================

alter table resource      add column if not exists details text;
alter table resource_type add column if not exists described boolean not null default false;
update resource_type set described = true where name in ('Dataset / Data Access');

-- guard: a non-steward edit that changes substance → back to pending for review
create or replace function _resource_approval_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if has_capability('manage_resources') then
    return new;                                  -- stewards may set any status
  end if;
  if tg_op = 'INSERT' then
    new.approval_status := 'pending';
  elsif tg_op = 'UPDATE' then
    if new.name is distinct from old.name
       or new.type_id is distinct from old.type_id
       or new.monthly_quota is distinct from old.monthly_quota
       or new.unit is distinct from old.unit
       or new.usd_per_unit is distinct from old.usd_per_unit
       or new.details is distinct from old.details
       or new.skills is distinct from old.skills
       or new.gpu_model_id is distinct from old.gpu_model_id
       or new.api_model_id is distinct from old.api_model_id then
      new.approval_status := 'pending';          -- substantive edit → re-review
    else
      new.approval_status := old.approval_status; -- non-substantive (e.g. forge_request_id)
    end if;
  end if;
  return new;
end; $$;

-- forge_resource gains p_details (described types carry their text here)
drop function if exists forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level, uuid, uuid);
create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null,
  p_skills jsonb default '[]'::jsonb, p_level guild_level default null,
  p_gpu_model uuid default null, p_api_model uuid default null, p_details text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; rid uuid; req uuid;
begin
  if not (has_capability('manage_resources') or manages_card(p_holder)
          or (p_holder = current_member_id())) then
    raise exception 'not authorized to forge this resource';
  end if;
  if p_scope not in ('member','community') then raise exception 'scope must be member|community'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'resource name required'; end if;
  if p_holder is null then raise exception 'a resource needs an in-community holder'; end if;
  if p_monthly_quota is null or p_monthly_quota < 0 then raise exception 'monthly_quota must be >= 0'; end if;

  submitter := current_member_id();
  insert into resource (type_id, name, scope, holder_member_id, monthly_quota, unit,
                        usd_per_unit, str_per_unit, skills, level, gpu_model_id, api_model_id, details)
  values (p_type, trim(p_name), p_scope, p_holder, p_monthly_quota, p_unit,
          p_usd_per_unit, p_str_per_unit, coalesce(p_skills,'[]'::jsonb), p_level, p_gpu_model, p_api_model, p_details)
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
grant execute on function forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level, uuid, uuid, text) to authenticated;

-- update_resource: edit an existing resource and re-submit it for review
create or replace function update_resource(
  p_resource uuid, p_name text, p_monthly_quota numeric,
  p_usd_per_unit numeric default null, p_skills jsonb default '[]'::jsonb,
  p_gpu_model uuid default null, p_api_model uuid default null, p_details text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare holder uuid; submitter uuid; req uuid;
begin
  select holder_member_id into holder from resource where id = p_resource;
  if holder is null then raise exception 'no such resource'; end if;
  if not (has_capability('manage_resources') or manages_card(holder) or holder = current_member_id()) then
    raise exception 'not authorized to edit this resource';
  end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'resource name required'; end if;

  update resource set
      name = trim(p_name),
      monthly_quota = coalesce(p_monthly_quota, 0),
      usd_per_unit = p_usd_per_unit,
      skills = coalesce(p_skills, '[]'::jsonb),
      gpu_model_id = p_gpu_model,
      api_model_id = p_api_model,
      details = p_details
   where id = p_resource;  -- guard flips to pending if substance changed

  submitter := current_member_id();
  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('resource', 'update', p_resource,
          jsonb_build_object('name', trim(p_name), 'monthly_quota', coalesce(p_monthly_quota,0)),
          submitter, 'submitted')
  returning id into req;
  update resource set forge_request_id = req where id = p_resource;
  return req;
end $$;
grant execute on function update_resource(uuid, text, numeric, numeric, jsonb, uuid, uuid, text) to authenticated;

notify pgrst, 'reload schema';
