-- ============================================================
-- Leader skill requirements (hard gate) + guild-level need requirements
--
-- A project leader must hold every skill in leader_skill_requirement at or
-- above its minimum *certified* guild level.  Enforced server-side inside
-- create_project_with_leader_stake and claim_leadership.
--
-- Recruiting needs (open_need) may also require a skill at a guild level
-- (min_guild_level), shown to applicants alongside whether they qualify.
--
-- Seed requirement: English / Academic Writing / Project Management ≥ journeyman.
-- Admins (manage_guild) certify members directly via admin_certify_skill
-- (bootstrap / waiver, no exam).  Current project leaders are backfilled so
-- existing projects keep their leader.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1. guild level → ordinal (for >= comparisons) ----------
create or replace function guild_level_rank(g guild_level) returns int
  language sql immutable as $$
  select case g when 'apprentice' then 1 when 'journeyman' then 2
                when 'craftsman'  then 3 when 'master'     then 4 else 0 end;
$$;
grant execute on function guild_level_rank(guild_level) to anon, authenticated;

-- ---------- 2. admin-editable leader requirement ----------
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

-- ---------- 3. does a member meet ALL leader requirements? ----------
create or replace function member_meets_leader_reqs(mid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from leader_skill_requirement r
    left join member_skill ms on ms.member_id = mid and ms.skill_id = r.skill_id
    where coalesce(guild_level_rank(ms.certified_level), 0) < guild_level_rank(r.min_level)
  );
$$;
grant execute on function member_meets_leader_reqs(uuid) to authenticated;

-- requirements a member is still missing (drives UI messages)
create or replace function leader_reqs_missing(mid uuid)
returns table (skill_id uuid, skill_name text, min_level guild_level, have guild_level)
language sql stable security definer set search_path = public as $$
  select r.skill_id, s.name, r.min_level, ms.certified_level
  from leader_skill_requirement r
  join skill s on s.id = r.skill_id
  left join member_skill ms on ms.member_id = mid and ms.skill_id = r.skill_id
  where coalesce(guild_level_rank(ms.certified_level), 0) < guild_level_rank(r.min_level)
  order by r.rank;
$$;
grant execute on function leader_reqs_missing(uuid) to authenticated;

-- ---------- 4. admin certify (bootstrap / waiver, no exam) ----------
create or replace function admin_certify_skill(p_member uuid, p_skill uuid, p_level guild_level)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_guild') then raise exception 'requires manage_guild capability'; end if;
  insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
  values (p_member, p_skill, 'Advanced', p_level, now())
  on conflict (member_id, skill_id) do update
    set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
        certified_at    = now();
end; $$;
grant execute on function admin_certify_skill(uuid, uuid, guild_level) to authenticated;

-- ---------- 5. needs may require a skill at a guild level ----------
alter table open_need add column if not exists min_guild_level guild_level;

-- ---------- 6. enforce the gate in the leader entry points ----------
create or replace function create_project_with_leader_stake(
  p_name text, p_type_id uuid, p_status_id uuid, p_venue text, p_summary text,
  p_stake integer default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; esc uuid; lstake integer; lrole uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if not member_meets_leader_reqs(me) then
    raise exception 'leader requirements not met: certify English, Academic Writing and Project Management to the required guild level before leading a project';
  end if;
  lstake := coalesce(p_stake, (select leader_stake from project_type where id = p_type_id),
                     stater_policy_int('leader_stake_normal', 50));
  vname := coalesce((select name from venue where id = p_venue_id), p_venue);
  insert into project (name, type_id, status_id, target_venue, venue_id, summary)
  values (p_name, p_type_id, p_status_id, vname, p_venue_id, p_summary) returning id into pid;
  esc := stater_project_acc(pid);  -- created by trigger
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader initiation stake', pid, null, null, me);
  select id into lrole from project_role where name = 'Leader' limit 1;
  insert into project_member (project_id, member_id, project_role_id) values (pid, me, lrole) on conflict do nothing;
  insert into stater_project_stake_commitment (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (pid, me, 'leader_initiation', lstake, 'verified', me, now());
  perform seed_first_author_writing(pid, me);
  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;
  return pid;
end; $$;
grant execute on function create_project_with_leader_stake(text, uuid, uuid, text, text, integer, uuid, text) to authenticated;

create or replace function claim_leadership(p uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; lstake integer; lrole uuid; bal numeric; esc uuid; nm text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if not member_meets_leader_reqs(me) then
    raise exception 'leader requirements not met: certify English, Academic Writing and Project Management to the required guild level before leading a project';
  end if;

  if exists (
    select 1 from project_member pm
    join project_role pr on pr.id = pm.project_role_id
    where pm.project_id = p and pr.can_manage
  ) then
    raise exception 'project already has a leader';
  end if;

  lstake := coalesce(
    (select leader_stake from project_type t join project pr on pr.type_id = t.id where pr.id = p),
    stater_policy_int('leader_stake_normal', 50));

  select coalesce(balance, 0) into bal from stater_balance where owner_member_id = me;
  if coalesce(bal, 0) < lstake then
    raise exception 'insufficient STR balance: leading stakes %, you have %', lstake, coalesce(bal, 0);
  end if;

  select id into lrole from project_role where name = 'Leader' limit 1;
  esc := stater_project_acc(p);
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader claim stake', p, null, null, me);

  if exists (select 1 from project_member where project_id = p and member_id = me) then
    update project_member set project_role_id = lrole where project_id = p and member_id = me;
  else
    insert into project_member (project_id, member_id, project_role_id) values (p, me, lrole);
  end if;

  insert into stater_project_stake_commitment
    (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (p, me, 'leader_initiation', lstake, 'verified', me, now());

  perform seed_first_author_writing(p, me);

  select full_name into nm from member where id = me;
  insert into project_event (project_id, actor_member_id, event_type, summary)
  values (p, me, 'member_joined', coalesce(nm, 'A member') || ' staked ' || lstake || ' STR to lead this project');
end; $$;
grant execute on function claim_leadership(uuid) to authenticated;

-- ---------- 7. backfill current leaders so existing projects keep theirs ----------
insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
select l.member_id, r.skill_id, 'Advanced'::skill_level, r.min_level, now()
from (select distinct pm.member_id
        from project_member pm
        join project_role pr on pr.id = pm.project_role_id and pr.can_manage) l
cross join leader_skill_requirement r
on conflict (member_id, skill_id) do update
  set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
      certified_at    = coalesce(member_skill.certified_at, now());

-- ---------- 8. RLS + grants for the requirement table ----------
alter table leader_skill_requirement enable row level security;
drop policy if exists read_leader_req on leader_skill_requirement;
create policy read_leader_req on leader_skill_requirement for select to authenticated using (true);
drop policy if exists manage_leader_req on leader_skill_requirement;
create policy manage_leader_req on leader_skill_requirement for all to authenticated
  using (has_capability('manage_guild')) with check (has_capability('manage_guild'));
grant select on leader_skill_requirement to anon, authenticated;
grant insert, update, delete on leader_skill_requirement to authenticated;

notify pgrst, 'reload schema';
