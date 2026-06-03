-- ============================================================
-- Unify every need on project_slot.requirements (jsonb).
--
-- A leader is no longer a bespoke subsystem — it's just a slot with a few
-- fixed skill requirements, the same shape any need can carry. So:
--   * project_slot gains  requirements jsonb  = [{skill_id, min_level}, …]
--   * a BEFORE trigger seeds it: leader slots from the admin default
--     (leader_skill_requirement), work_labor slots from their skill_id/req_access
--   * one generic gate — member_meets_requirements(member, reqs) — reads the
--     `badge` table; work_seat and the leader create/claim path both use it
--   * member_skill (deprecated by the Phase-1 rebuild) is no longer read
--
-- leader_skill_requirement stays as the admin-editable DEFAULT leader need
-- (edited from /admin/skills); it's only the seed source now, not a separate
-- enforcement path. Idempotent.
-- ============================================================

-- ---------- the column (added first: SQL functions below reference it) ----------
alter table project_slot add column if not exists requirements jsonb not null default '[]'::jsonb;

-- ---------- generic requirement helpers (read the badge table) ----------
-- a member satisfies a requirement list when, for every {skill_id, min_level},
-- they hold a badge at or above that guild level.
create or replace function member_meets_requirements(p_member uuid, p_reqs jsonb)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from jsonb_array_elements(coalesce(p_reqs, '[]'::jsonb)) r
    where coalesce(
            guild_level_rank((select b.level from badge b
                              where b.member_id = p_member
                                and b.skill_id = (r->>'skill_id')::uuid)), 0)
          < guild_level_rank((r->>'min_level')::guild_level)
  );
$$;
grant execute on function member_meets_requirements(uuid, jsonb) to authenticated;

-- which requirements a member is still missing (drives UI: reasons / dimming)
create or replace function reqs_missing(p_member uuid, p_reqs jsonb)
returns table (skill_id uuid, skill_name text, min_level guild_level, have guild_level)
language sql stable security definer set search_path = public as $$
  select (r->>'skill_id')::uuid, s.name, (r->>'min_level')::guild_level,
         (select b.level from badge b where b.member_id = p_member and b.skill_id = (r->>'skill_id')::uuid)
  from jsonb_array_elements(coalesce(p_reqs, '[]'::jsonb)) r
  join skill s on s.id = (r->>'skill_id')::uuid
  where coalesce(
          guild_level_rank((select b.level from badge b
                            where b.member_id = p_member and b.skill_id = (r->>'skill_id')::uuid)), 0)
        < guild_level_rank((r->>'min_level')::guild_level);
$$;
grant execute on function reqs_missing(uuid, jsonb) to authenticated;

-- ---------- the admin default leader need, as a requirement list ----------
create or replace function default_leader_requirements()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(
    jsonb_agg(jsonb_build_object('skill_id', skill_id, 'min_level', min_level) order by rank),
    '[]'::jsonb)
  from leader_skill_requirement;
$$;
grant execute on function default_leader_requirements() to authenticated;

-- ---------- slot-scoped wrappers ----------
create or replace function slot_reqs_met(p_slot uuid, p_member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select member_meets_requirements(p_member, (select requirements from project_slot where id = p_slot));
$$;
grant execute on function slot_reqs_met(uuid, uuid) to authenticated;

create or replace function slot_reqs_missing(p_slot uuid, p_member uuid)
returns table (skill_id uuid, skill_name text, min_level guild_level, have guild_level)
language sql stable security definer set search_path = public as $$
  select * from reqs_missing(p_member, (select requirements from project_slot where id = p_slot));
$$;
grant execute on function slot_reqs_missing(uuid, uuid) to authenticated;

-- ---------- back-compat leader wrappers (now badge-based) ----------
create or replace function member_meets_leader_reqs(mid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select member_meets_requirements(mid, default_leader_requirements());
$$;
grant execute on function member_meets_leader_reqs(uuid) to authenticated;

create or replace function leader_reqs_missing(mid uuid)
returns table (skill_id uuid, skill_name text, min_level guild_level, have guild_level)
language sql stable security definer set search_path = public as $$
  select * from reqs_missing(mid, default_leader_requirements());
$$;
grant execute on function leader_reqs_missing(uuid) to authenticated;

-- ---------- seed trigger: every slot carries its requirements ----------
-- leader  → the admin default leader need
-- work_labor (has skill_id) → that single skill at its req_access (def apprentice)
-- only fills when empty, so manual / multi-skill requirements are never clobbered.
create or replace function project_slot_seed_requirements()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.requirements is null or new.requirements = '[]'::jsonb then
    if new.slot_kind = 'leader' then
      new.requirements := default_leader_requirements();
    elsif new.skill_id is not null then
      new.requirements := jsonb_build_array(jsonb_build_object(
        'skill_id', new.skill_id,
        'min_level', coalesce(new.req_access::text, 'apprentice')));
    else
      new.requirements := '[]'::jsonb;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists project_slot_seed_requirements_t on project_slot;
create trigger project_slot_seed_requirements_t
  before insert or update on project_slot
  for each row execute function project_slot_seed_requirements();

-- ---------- backfill existing slots ----------
update project_slot
   set requirements = jsonb_build_array(jsonb_build_object(
         'skill_id', skill_id, 'min_level', coalesce(req_access::text, 'apprentice')))
 where slot_kind = 'work_labor' and skill_id is not null
   and (requirements is null or requirements = '[]'::jsonb);

update project_slot
   set requirements = default_leader_requirements()
 where slot_kind = 'leader'
   and (requirements is null or requirements = '[]'::jsonb);

-- ---------- work_seat: gate on the unified requirements ----------
create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int;
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
    nominal := ceil(rate * coalesce(p_monthly_amount,0));
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
