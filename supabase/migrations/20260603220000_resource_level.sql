-- ============================================================
-- A resource carries its expertise LEVEL (custody, unified).
--
-- Everyone's hours are a stewarded resource; "your own hours" is just the case
-- holder = you. So the per-hour rate multiplier should read the resource's
-- declared level. A stewarded external master declares level='master' and mints
-- at the master rate even with no badge on any card. When the resource leaves
-- level null (the self case), fall back to the member's badge level for the
-- slot's skill, then apprentice.
--
-- resource.level is a guild_level (nullable). Idempotent.
-- ============================================================

alter table resource add column if not exists level guild_level;

-- forge_resource: now carries the resource's expertise level
create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null,
  p_skills jsonb default '[]'::jsonb, p_level guild_level default null)
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
  insert into resource (type_id, name, scope, holder_member_id, monthly_quota, unit, usd_per_unit, str_per_unit, skills, level)
  values (p_type, trim(p_name), p_scope, p_holder, p_monthly_quota, p_unit, p_usd_per_unit, p_str_per_unit,
          coalesce(p_skills, '[]'::jsonb), p_level)
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
grant execute on function forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb, guild_level) to authenticated;

-- work_seat: rate multiplier reads the committed resource's level, else the
-- member's badge level for the skill, else apprentice
create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int; lvl guild_level;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such slot'; end if;
  if p_year_month !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount,0) < 0 then raise exception 'amount cannot be negative'; end if;

  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project')) then
    raise exception 'not authorized to seat this member';
  end if;

  -- skill gate: the member's badges OR the committed resource's declared skills
  if not (member_meets_requirements(p_member, s.requirements)
          or resource_covers_requirements(p_resource, s.requirements)) then
    raise exception 'member does not meet this slot''s skill requirements';
  end if;

  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    -- level: the resource's declared level, else the member's badge in the skill
    lvl := coalesce((select level from resource where id = p_resource),
                    (select b.level from badge b where b.member_id = p_member and b.skill_id = s.skill_id));
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'work_resource' and p_resource is not null then
    nominal := ceil(resource_value_usd(p_resource, coalesce(p_monthly_amount,0))
                    * stater_policy_num('str_per_usd', 0.2));
  end if;

  if p_resource is not null then
    select monthly_quota into cap from resource where id = p_resource;
    if cap is not null then
      select coalesce(sum(monthly_amount),0) into tot from work_commitment
       where member_id = p_member and resource_id = p_resource and year_month = p_year_month
         and slot_id is distinct from p_slot;
      if tot + coalesce(p_monthly_amount,0) > cap then appr := 'needs_review'; end if;
    end if;
  end if;

  insert into work_commitment
    (slot_id, project_id, member_id, resource_id, year_month, monthly_amount, nominal_str, approval)
  values (p_slot, s.project_id, p_member, p_resource, p_year_month,
          coalesce(p_monthly_amount,0), nominal, appr)
  on conflict (slot_id, member_id, year_month) do update
    set resource_id = excluded.resource_id,
        monthly_amount = excluded.monthly_amount,
        nominal_str = excluded.nominal_str,
        approval = case when work_commitment.approval in ('approved','rejected')
                        then work_commitment.approval else excluded.approval end
  returning id into wcid;

  role_id := (select id from project_role
              where name = case when s.slot_kind = 'leader' then 'Leader' else 'Contributor' end limit 1);
  if role_id is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (s.project_id, p_member, role_id) on conflict do nothing;
  end if;

  select count(distinct member_id) into filled from work_commitment where slot_id = p_slot;
  if filled >= s.headcount then update project_slot set status = 'filled' where id = p_slot and status = 'open'; end if;

  return wcid;
end $$;
grant execute on function work_seat(uuid, uuid, uuid, text, numeric, uuid) to authenticated;

notify pgrst, 'reload schema';
