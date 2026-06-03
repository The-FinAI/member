-- ============================================================
-- Fix: leader skill-requirement gate must read the `badge` table.
--
-- leader_requirements.sql defined member_meets_leader_reqs() /
-- leader_reqs_missing() against member_skill.certified_level. The Phase-1
-- rebuild (20260602201500) migrated skills into the `badge` table and marked
-- member_skill DEPRECATED ("Do not write"). Since then every badge is forged
-- into `badge`, so the leader gate has been reading frozen data — a member who
-- certifies English / Academic Writing / Project Management AFTER the rebuild
-- still fails member_meets_leader_reqs and cannot create or claim a project.
--
-- Repoint both functions at `badge` (badge.level is the same guild_level type
-- as member_skill.certified_level, so guild_level_rank() comparison is identical).
-- Idempotent.
-- ============================================================

-- does a member meet ALL leader skill requirements? (reads `badge`)
create or replace function member_meets_leader_reqs(mid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from leader_skill_requirement r
    left join badge b on b.member_id = mid and b.skill_id = r.skill_id
    where coalesce(guild_level_rank(b.level), 0) < guild_level_rank(r.min_level)
  );
$$;
grant execute on function member_meets_leader_reqs(uuid) to authenticated;

-- requirements a member is still missing (drives UI messages) (reads `badge`)
create or replace function leader_reqs_missing(mid uuid)
returns table (skill_id uuid, skill_name text, min_level guild_level, have guild_level)
language sql stable security definer set search_path = public as $$
  select r.skill_id, s.name, r.min_level, b.level
  from leader_skill_requirement r
  join skill s on s.id = r.skill_id
  left join badge b on b.member_id = mid and b.skill_id = r.skill_id
  where coalesce(guild_level_rank(b.level), 0) < guild_level_rank(r.min_level)
  order by r.rank;
$$;
grant execute on function leader_reqs_missing(uuid) to authenticated;

notify pgrst, 'reload schema';
