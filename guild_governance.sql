-- Guild governance: master is an APPOINTED role, not self-claimed.
-- Adds a dedicated `manage_guild` capability, drops the cold-start auto-master
-- trigger, adds appoint_skill_master(), and makes tree-shaping admin-only by
-- revoking member self-branching. Additive + idempotent where possible.

begin;

-- 1. Dedicated capability: appointing skill masters / overseeing the ladder.
--    Kept separate from manage_taxonomy so it can be granted independently.
insert into capability (key, description) values
  ('manage_guild', 'Appoint skill masters and oversee the guild certification ladder')
on conflict (key) do nothing;

-- Grant it to whoever already holds manage_taxonomy (sensible default; admins
-- can re-grant via the capability matrix afterwards).
insert into position_capability (position_id, capability_key)
select pc.position_id, 'manage_guild'
from position_capability pc
where pc.capability_key = 'manage_taxonomy'
on conflict do nothing;

-- 2. Master is appointed, not auto-claimed: drop the first-holder trigger so a
--    plain member_skill insert no longer mints a Master.
drop trigger if exists skill_first_holder_master on member_skill;
drop function if exists _skill_first_holder_is_master();

-- 3. appoint_skill_master — a manage_guild holder names a leaf skill's master and
--    certifies them at the top level (seeding the qualified-reviewer pool).
create or replace function appoint_skill_master(p_skill uuid, p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_guild') then
    raise exception 'requires the manage_guild capability';
  end if;
  if not exists (select 1 from skill where id = p_skill) then
    raise exception 'no such skill';
  end if;
  if exists (select 1 from skill where parent_id = p_skill) then
    raise exception 'masters are appointed on leaf skills, not domains';
  end if;
  if not exists (select 1 from member where id = p_member) then
    raise exception 'no such member';
  end if;

  update skill set master_member_id = p_member where id = p_skill;

  -- certify the appointed master at top level so they own the rubric & can review
  insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
  values (p_member, p_skill, 'Expert', 'master', now())
  on conflict (member_id, skill_id) do update
    set certified_level = 'master', certified_at = now();
end $$;
grant execute on function appoint_skill_master(uuid, uuid) to authenticated;

-- 4. Tree shape is admin-only (manage_taxonomy via /admin/skills). Revoke the
--    master self-branching path so authority isn't split.
revoke execute on function branch_skill(uuid, text) from authenticated;

commit;
