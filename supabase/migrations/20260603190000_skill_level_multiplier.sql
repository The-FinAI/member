-- ============================================================
-- Skill-level multiplier on labor minting.
--
-- A work_labor hour mints  rate(skill) × hours  nominal STR. The rate is flat
-- per skill and didn't reflect how senior the contributor is — a master and an
-- apprentice of the same skill earned the same per hour. Add a per-level
-- coefficient (admin-tunable policy) so a higher badge in the slot's skill earns
-- more per hour:
--
--   nominal = ceil( rate(skill) × level_mult(member's badge level) × hours )
--
-- req_access still gates ENTRY; this only scales the per-hour value once in.
-- ============================================================

insert into stater_policy (key, value, description) values
  ('skill_level_mult_apprentice', 1.0,  'Labor rate multiplier for an apprentice-level contributor'),
  ('skill_level_mult_journeyman', 1.25, 'Labor rate multiplier for a journeyman-level contributor'),
  ('skill_level_mult_craftsman',  1.5,  'Labor rate multiplier for a craftsman-level contributor'),
  ('skill_level_mult_master',     2.0,  'Labor rate multiplier for a master-level contributor')
on conflict (key) do nothing;

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

  -- chapter officer pushes a card they manage (consent is offline in Phase 1)
  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project')) then
    raise exception 'not authorized to seat this member';
  end if;

  -- unified skill gate: member must satisfy the slot's requirements (badges)
  if not member_meets_requirements(p_member, s.requirements) then
    raise exception 'member does not meet this slot''s skill requirements';
  end if;

  -- nominal STR for the month
  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    -- a higher badge in the slot's skill earns a higher per-hour rate
    lvl := (select b.level from badge b where b.member_id = p_member and b.skill_id = s.skill_id);
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'work_resource' and p_resource is not null then
    nominal := ceil(resource_value_usd(p_resource, coalesce(p_monthly_amount,0))
                    * stater_policy_num('str_per_usd', 0.2));
  end if;

  -- capacity check against the committing resource's monthly_quota
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
