-- =====================================================================
-- Issue #32 (and the enforcement half of #21): the candidate matcher and the
-- seating gate were checking DIFFERENT competency scales, so a person could
-- show as a qualified candidate (Assign enabled) yet fail on assign with an
-- opaque "member does not meet this slot's skill requirements".
--
--   * match_candidates() ranks people by person_skill level (the CURRENT scale:
--     Learning / Independent / Lead), comparing to project_slot.desired_level.
--   * work_seat() enforced project_slot.requirements (jsonb) against the LEGACY
--     `badge` table (guild levels: apprentice … master).
--
-- A member with a declared person_skill but no legacy badge therefore looked
-- assignable but wasn't. Per the redesign, person_skill (Learning/Independent/
-- Lead) is the authoritative scale; badges are legacy. So the seating gate is
-- moved onto the SAME person_skill predicate the matcher shows, and the error
-- now names the missing skill + level.
--
-- Unchanged: resource slots still gate on resource_covers_requirements; the STR
-- multiplier still reads the badge level (a missing badge just yields the base
-- rate). Idempotent. (Same work_seat body as 20260603370000 + the gate swap.)
-- =====================================================================

begin;

-- human-readable "Skill · Level" for a labour/leader slot's requirement, for messages/UI
create or replace function slot_skill_need_text(p_slot uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when s.skill_id is null then null
    else coalesce((select name from skill where id = s.skill_id), 'a skill')
         || ' · ' || coalesce(s.desired_level::text, 'any level')
  end
  from project_slot s where s.id = p_slot;
$$;
grant execute on function slot_skill_need_text(uuid) to authenticated;

-- the labour/leader fit gate, on person_skill — IDENTICAL to match_candidates.fits
create or replace function member_fits_labour_slot(p_member uuid, p_slot uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (s.skill_id is null) or exists (
    select 1 from person_skill ps
     where ps.member_id = p_member and ps.skill_id = s.skill_id
       and lvl_rank(ps.level) >= lvl_rank(s.desired_level)
  )
  from project_slot s where s.id = p_slot;
$$;
grant execute on function member_fits_labour_slot(uuid, uuid) to authenticated;

create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int; lvl guild_level;
        need text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such slot'; end if;
  if p_year_month !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount,0) < 0 then raise exception 'amount cannot be negative'; end if;

  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project') or is_unit_officer_of(p_member)) then
    raise exception 'not authorized to seat this member';
  end if;

  -- requirement gate (issue #32): resources by capability; labour/leader by
  -- person_skill — the same scale the candidate matcher shows. Name the gap.
  if s.slot_kind = 'work_resource' then
    if not resource_covers_requirements(p_resource, s.requirements) then
      raise exception 'this resource does not meet the need''s requirements';
    end if;
  else
    if not member_fits_labour_slot(p_member, p_slot) then
      need := slot_skill_need_text(p_slot);
      raise exception 'member does not meet this need: requires %', coalesce(need, 'a higher skill level');
    end if;
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

notify pgrst, 'reload schema';

commit;
