-- ============================================================
-- Seating scope by role:
--   * admin (manage_members / edit_any_project) — the whole community,
--   * a chapter officer — only people in their unit (is_unit_officer_of),
--   * a regular user — only themselves (enforced in the UI).
-- Widen work_seat / seat_direct auth so a chapter officer can seat their own
-- unit's members (cards AND registered) — but not the whole community.
-- ============================================================

-- ---- work_seat: allow any officer to seat any member (global matching) -------
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
          or has_capability('edit_any_project') or is_unit_officer_of(p_member)) then
    raise exception 'not authorized to seat this member';
  end if;

  if not (member_meets_requirements(p_member, s.requirements)
          or resource_covers_requirements(p_resource, s.requirements)) then
    raise exception 'member does not meet this slot''s skill requirements';
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

-- ---- seat_direct: same widening -------------------------------------------
create or replace function seat_direct(
  p_project uuid, p_member uuid, p_slot_kind text,
  p_skill uuid default null, p_req_access guild_level default null,
  p_resource_type uuid default null, p_resource uuid default null,
  p_year_month text default null, p_monthly_amount numeric default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare wg uuid; v_slot uuid; rate int; nominal int := 0; lvl guild_level;
        role_id uuid; wcid uuid; ym text;
begin
  if p_slot_kind not in ('work_labor', 'work_resource') then
    raise exception 'seat_direct handles work_labor or work_resource (leader is intrinsic)';
  end if;
  if not exists (select 1 from member where id = p_member) then
    raise exception 'no such member';
  end if;

  select org_unit_id into wg from project where id = p_project;
  if not (manages_project(p_project) or has_capability('edit_any_project')
          or (wg is not null and is_unit_officer(wg))
          or manages_card(p_member) or is_unit_officer_of(p_member)) then
    raise exception 'not authorized to seat into this project';
  end if;

  ym := coalesce(p_year_month, to_char(now(), 'YYYY-MM'));
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount, 0) < 0 then raise exception 'amount cannot be negative'; end if;

  insert into project_slot
    (project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, authorship, status)
  values (p_project, p_slot_kind, p_req_access, p_skill,
          case when p_slot_kind = 'work_resource' then p_resource_type else null end,
          p_monthly_amount, 1,
          case when p_slot_kind = 'work_resource' then 'last_candidate' else 'co' end,
          'open')
  returning id into v_slot;

  if p_slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = p_skill),
                     stater_policy_int('paper_writing_rate', 10));
    lvl  := coalesce(p_req_access,
                     (select b.level from badge b where b.member_id = p_member and b.skill_id = p_skill),
                     'apprentice');
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount, 0));
  elsif p_slot_kind = 'work_resource' and p_resource is not null then
    nominal := ceil(resource_value_usd(p_resource, coalesce(p_monthly_amount, 0))
                    * stater_policy_num('str_per_usd', 0.2));
  end if;

  insert into work_commitment
    (slot_id, project_id, member_id, resource_id, year_month, monthly_amount, nominal_str, approval)
  values (v_slot, p_project, p_member, p_resource, ym, coalesce(p_monthly_amount, 0), nominal, 'ok')
  returning id into wcid;

  update project_slot set status = 'filled' where id = v_slot;

  role_id := (select id from project_role where name = 'Contributor' limit 1);
  if role_id is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (p_project, p_member, role_id) on conflict do nothing;
  end if;

  return wcid;
end $$;
grant execute on function seat_direct(uuid, uuid, text, uuid, guild_level, uuid, uuid, text, numeric) to authenticated;

notify pgrst, 'reload schema';
