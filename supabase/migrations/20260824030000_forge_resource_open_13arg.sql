-- Completes the overload cleanup: 20260824020000 dropped the 12-arg version,
-- which was where 20260823020000 had opened the gate — leaving the still-gated
-- 13-arg (p_details) as the only overload. Recreate the 13-arg verbatim from
-- 20260603330000 with the v0.3 gate (signed-in).
create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null,
  p_skills jsonb default '[]'::jsonb, p_level guild_level default null,
  p_gpu_model uuid default null, p_api_model uuid default null, p_details text default null)
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

notify pgrst, 'reload schema';
