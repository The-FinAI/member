-- ============================================================
-- resource.skills carries a LEVEL per skill: [{skill_id, level}, …].
--
-- A stewarded labour resource can hold several skills at different levels (a
-- master in Accounting, journeyman in Project Management). So skills is a list
-- of {skill_id, level}, and:
--   * resource_covers_requirements — the resource lists the skill at or above
--     the need's required level;
--   * work_seat's rate multiplier — uses the resource's level for the slot's
--     skill, else the member's badge level, else apprentice.
-- (resource.level becomes unused; the per-skill level lives in skills.)
-- Idempotent.
-- ============================================================

create or replace function resource_covers_requirements(p_resource uuid, p_reqs jsonb)
returns boolean language sql stable security definer set search_path = public as $$
  select p_resource is not null and not exists (
    select 1 from jsonb_array_elements(coalesce(p_reqs, '[]'::jsonb)) r
    where not exists (
      select 1 from jsonb_array_elements(
               coalesce((select skills from resource where id = p_resource), '[]'::jsonb)) rs
      where rs->>'skill_id' = r->>'skill_id'
        and guild_level_rank((rs->>'level')::guild_level) >= guild_level_rank((r->>'min_level')::guild_level)
    )
  );
$$;
grant execute on function resource_covers_requirements(uuid, jsonb) to authenticated;

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

  if not (member_meets_requirements(p_member, s.requirements)
          or resource_covers_requirements(p_resource, s.requirements)) then
    raise exception 'member does not meet this slot''s skill requirements';
  end if;

  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    -- level: the resource's level for this skill, else the member's badge level
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

notify pgrst, 'reload schema';
