-- =====================================================================
-- BUILD PLAN P2 — People: capacity attribute + redesigned skills
-- PRD-final §3.2 · redesign-hci §15 · build-plan Phase 2
--
--  * member.monthly_hours — capacity as a PERSON ATTRIBUTE (backfilled from
--    each member's "My time" Labor resource), so hours stop being a forged
--    resource and become a plain field.
--  * person_skill — a flat tag + a 3-level BEHAVIORALLY-ANCHORED proficiency
--    (learning | independent | lead). No badge tree, no certification queue.
--  * person_skill_evidence — proficiency BACKED BY THE RECORD: tasks owned +
--    shipped projects per (member, skill). Evidence IS the certification.
--  * RPCs: person_skill_set · person_set_capacity · skill_raise_suggestions
--    (suggest a raise once the record earns it).
-- Idempotent.
-- =====================================================================

begin;

-- ---------- capacity as a person attribute ----------
alter table member add column if not exists monthly_hours integer;

-- backfill from each member's Labor ("My time") resource quota, once
update member m set monthly_hours = floor(member_labor_cap(m.id))::int
 where m.monthly_hours is null and member_labor_cap(m.id) is not null;

-- ---------- person_skill: tag + behavioral level ----------
create table if not exists person_skill (
  member_id uuid not null references member (id) on delete cascade,
  skill_id  uuid not null references skill (id)  on delete cascade,
  level     text not null check (level in ('learning','independent','lead')),
  set_at    timestamptz not null default now(),
  primary key (member_id, skill_id)
);
create index if not exists person_skill_member_idx on person_skill (member_id);
create index if not exists person_skill_skill_idx  on person_skill (skill_id);

alter table person_skill enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='person_skill' and policyname='read_person_skill') then
    create policy read_person_skill on person_skill for select to authenticated using (true);
  end if;
end $$;
grant select on person_skill to authenticated;

-- ---------- evidence from the record (read-only view) ----------
-- per (member, skill): tasks owned + distinct shipped (Finished) projects.
create or replace view person_skill_evidence as
  select t.owner_member_id as member_id,
         t.skill_id,
         count(*)::int as tasks,
         count(distinct t.project_id) filter (where ps.name = 'Finished')::int as shipped
  from task t
  join project pr on pr.id = t.project_id
  left join project_status ps on ps.id = pr.status_id
  where t.owner_member_id is not null and t.skill_id is not null
  group by t.owner_member_id, t.skill_id;
grant select on person_skill_evidence to authenticated;

-- =====================================================================
-- write authorization: self · the card's chapter steward · manage_members
-- =====================================================================
create or replace function can_edit_member(p_member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_member = current_member_id()
      or manages_card(p_member)
      or has_capability('manage_members');
$$;
grant execute on function can_edit_member(uuid) to authenticated;

-- set/clear a person's skill level (null level = remove the skill)
create or replace function person_skill_set(p_skill uuid, p_level text, p_member uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare m uuid := coalesce(p_member, current_member_id());
begin
  if not can_edit_member(m) then raise exception 'not allowed to edit this person'; end if;
  if p_level is null or btrim(p_level) = '' then
    delete from person_skill where member_id = m and skill_id = p_skill;
    return;
  end if;
  if p_level not in ('learning','independent','lead') then raise exception 'invalid level'; end if;
  insert into person_skill (member_id, skill_id, level)
  values (m, p_skill, p_level)
  on conflict (member_id, skill_id) do update set level = excluded.level, set_at = now();
end $$;
grant execute on function person_skill_set(uuid,text,uuid) to authenticated;

-- set a person's monthly capacity (hours)
create or replace function person_set_capacity(p_hours integer, p_member uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare m uuid := coalesce(p_member, current_member_id());
begin
  if not can_edit_member(m) then raise exception 'not allowed to edit this person'; end if;
  update member set monthly_hours = greatest(0, coalesce(p_hours, 0)) where id = m;
end $$;
grant execute on function person_set_capacity(integer,uuid) to authenticated;

-- suggest a level raise the record has earned (evidence > current claim)
--   independent: ≥3 tasks owned and not yet independent/lead
--   lead:        ≥2 shipped projects and currently independent
create or replace function skill_raise_suggestions(p_member uuid)
returns table (skill_id uuid, skill_name text, current_level text, suggested_level text, tasks int, shipped int)
language sql stable security definer set search_path = public as $$
  select e.skill_id, s.name, ps.level,
    case
      when e.shipped >= 2 and ps.level = 'independent' then 'lead'
      when e.tasks  >= 3 and coalesce(ps.level,'learning') = 'learning' then 'independent'
      else null
    end as suggested_level,
    e.tasks, e.shipped
  from person_skill_evidence e
  join skill s on s.id = e.skill_id
  left join person_skill ps on ps.member_id = e.member_id and ps.skill_id = e.skill_id
  where e.member_id = p_member
    and (
      (e.shipped >= 2 and ps.level = 'independent')
      or (e.tasks >= 3 and coalesce(ps.level,'learning') = 'learning')
    );
$$;
grant execute on function skill_raise_suggestions(uuid) to authenticated;

commit;
