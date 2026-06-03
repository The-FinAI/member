-- ============================================================
-- seat_direct — an officer/admin places a member straight onto a project WITH a
-- monthly commitment (hours or a resource), even when no open need exists.
--
-- Unlike the apply→approve loop or forge_need (which queues a need for review),
-- this is IMMEDIATE: it forges a project_slot tailored to the person + what the
-- admin declares they bring, then writes the work_commitment directly. Because
-- the slot is *defined around* the member by the admin, there is no separate
-- qualification gate — the admin sets the skill/level/hours (or resource) and
-- the member is seated. nominal_str is computed exactly like work_seat.
--
-- Authorized: project manager (manages_project) OR edit_any_project OR an
-- officer of the project's working group. Idempotent on re-run is NOT a goal —
-- each call seats one commitment into a fresh slot.
-- ============================================================

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
  -- authorized: a project manager, edit_any_project, the project's WG officer,
  -- OR an officer who manages the card being seated (a chapter officer placing
  -- their own member onto any project — the phase-1 seeding path).
  if not (manages_project(p_project) or has_capability('edit_any_project')
          or (wg is not null and is_unit_officer(wg)) or manages_card(p_member)) then
    raise exception 'not authorized to seat into this project';
  end if;

  ym := coalesce(p_year_month, to_char(now(), 'YYYY-MM'));
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount, 0) < 0 then raise exception 'amount cannot be negative'; end if;

  -- forge the slot (trigger seeds requirements + Labor resource_type from skill)
  insert into project_slot
    (project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, authorship, status)
  values (p_project, p_slot_kind, p_req_access, p_skill,
          case when p_slot_kind = 'work_resource' then p_resource_type else null end,
          p_monthly_amount, 1,
          case when p_slot_kind = 'work_resource' then 'last_candidate' else 'co' end,
          'open')
  returning id into v_slot;

  -- nominal_str — same valuation as work_seat
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
