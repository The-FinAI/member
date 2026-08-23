-- Governance v0.3: seating is the officer's call. A member who does not meet a
-- need's skill/level, or would exceed their monthly capacity, is SEATED ANYWAY
-- and the commitment is marked needs_review (openness + history +
-- reversibility) instead of being hard-rejected. Bodies verbatim from
-- 20260821020000 with only those checks softened.

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

  if current_member_id() is null then raise exception 'sign in first'; end if;

  -- fit is advisory under v0.3: mismatch seats with needs_review, not an error
  if s.slot_kind = 'work_resource' then
    if not resource_covers_requirements(p_resource, s.requirements) then appr := 'needs_review'; end if;
  else
    if not member_fits_labour_slot(p_member, p_slot) then appr := 'needs_review'; end if;
  end if;

  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    lvl := coalesce(
      (select (rs->>'level')::guild_level
         from jsonb_array_elements(coalesce((select skills from resource where id = p_resource), '[]'::jsonb)) rs
        where rs->>'skill_id' = s.skill_id::text limit 1),
      (select b.level from badge b where b.member_id = p_member and b.skill_id = s.skill_id));
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'leader' then
    rate := coalesce(stater_policy_int('first_author_writing_rate',
                     stater_policy_int('paper_writing_rate', 10)), 10);
    nominal := ceil(rate * coalesce(p_monthly_amount,0));
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

create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; res uuid; ym text := to_char(now(), 'YYYY-MM');
        wcid uuid; pname text; what text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'amount must be greater than 0'; end if;

  if s.slot_kind = 'work_resource' then
    select r.id into res from resource r
      where r.holder_member_id = p_member and r.type_id = s.resource_type_id and r.scope = 'member' limit 1;
    if res is null then raise exception 'this person holds no resource of that type'; end if;
    what := coalesce((select name from resource_type where id = s.resource_type_id), 'a resource');
  else
    select r.id into res from resource r join resource_type rt on rt.id = r.type_id
      where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
    what := coalesce((select name from skill where id = s.skill_id), 'work');
  end if;
  -- over-capacity no longer hard-rejects: work_seat marks it needs_review

  wcid := work_seat(p_slot, p_member, res, ym, p_hours, p_member);
  select name into pname from project where id = s.project_id;
  perform notify(p_member, 'assigned',
    'You were assigned to a project', pname || ' · ' || what || ' · ' || p_hours,
    '/projects/' || s.project_id);
  return wcid;
end $$;
grant execute on function assign(uuid, uuid, numeric) to authenticated;

notify pgrst, 'reload schema';
