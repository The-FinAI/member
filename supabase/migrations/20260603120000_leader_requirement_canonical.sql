-- ============================================================
-- Canonical home for the leader skill-requirement subsystem.
--
-- These objects (guild_level_rank, the leader_skill_requirement table, and the
-- member_meets_leader_reqs / leader_reqs_missing gate) previously lived ONLY in
-- the un-tracked root file leader_requirements.sql, even though the tracked
-- migration 20260603110000 depends on them. Worse, that root file defines the
-- gate against the DEPRECATED member_skill table — re-running it would regress
-- the DB back off the badge model.
--
-- This migration makes the tracked chain the single source of truth: it
-- (re)creates everything idempotently in its correct, badge-based form, so the
-- root file can be deleted. Matches the live DB — no behaviour change.
--
-- NOTE: the first-author writing duty (set_/seed_first_author_writing,
-- writing_laggards in first_author_writing.sql) still writes to
-- stater_project_stake_commitment / stater_commitment_period, which the
-- Phase-1 rebuild merged into work_commitment. That subsystem needs a real
-- rebuild on work_commitment and is intentionally NOT reconciled here.
-- ============================================================

-- guild level → ordinal (for >= comparisons)
create or replace function guild_level_rank(g guild_level) returns int
  language sql immutable as $$
  select case g when 'apprentice' then 1 when 'journeyman' then 2
                when 'craftsman'  then 3 when 'master'     then 4 else 0 end;
$$;
grant execute on function guild_level_rank(guild_level) to anon, authenticated;

-- admin-editable default leader requirement (the "fixed leader need")
create table if not exists leader_skill_requirement (
  skill_id  uuid primary key references skill (id) on delete cascade,
  min_level guild_level not null default 'journeyman',
  rank      int not null default 100
);

insert into leader_skill_requirement (skill_id, min_level, rank)
select s.id, 'journeyman'::guild_level, x.rank
from (values ('English', 10), ('Academic Writing', 20), ('Project Management', 30)) x(nm, rank)
join skill s on s.name = x.nm
on conflict (skill_id) do nothing;

alter table leader_skill_requirement enable row level security;
drop policy if exists read_leader_req on leader_skill_requirement;
create policy read_leader_req on leader_skill_requirement for select to authenticated using (true);
drop policy if exists manage_leader_req on leader_skill_requirement;
create policy manage_leader_req on leader_skill_requirement for all to authenticated
  using (has_capability('manage_guild')) with check (has_capability('manage_guild'));
grant select on leader_skill_requirement to anon, authenticated;
grant insert, update, delete on leader_skill_requirement to authenticated;

-- the leader gate, badge-based (canonical; same as 20260603110000) ----------
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

notify pgrst, 'reload schema';
