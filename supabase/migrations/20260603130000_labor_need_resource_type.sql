-- ============================================================
-- Every work need is "skill(s) + a resource". A labor need's resource is the
-- 'Labor' (monthly working-hours) type — but work_labor slots historically left
-- resource_type_id NULL (the labor resource was implicit). Make it explicit so
-- qualification is uniform: hold the slot's resource_type (with monthly
-- capacity), plus satisfy any skill requirements.
--
--   * backfill existing work_labor slots → resource_type_id = Labor
--   * extend the seed trigger so future work_labor slots default it too
--
-- Skill stays optional (requirements may be empty); the resource is mandatory.
-- Idempotent.
-- ============================================================

-- backfill: a labor need consumes Labor (working hours)
do $$
declare labor uuid;
begin
  select id into labor from resource_type where name = 'Labor' limit 1;
  if labor is not null then
    update project_slot set resource_type_id = labor
     where slot_kind = 'work_labor' and resource_type_id is null;
  end if;
end $$;

-- seed trigger now also defaults a labor need's resource_type, alongside the
-- requirements seeding from 20260603110000.
create or replace function project_slot_seed_requirements()
returns trigger language plpgsql set search_path = public as $$
declare labor uuid;
begin
  -- every labor need carries the Labor resource type (working hours)
  if new.slot_kind = 'work_labor' and new.resource_type_id is null then
    select id into labor from resource_type where name = 'Labor' limit 1;
    new.resource_type_id := labor;
  end if;

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

notify pgrst, 'reload schema';
