-- =====================================================================
-- BUILD PLAN P3 — Form a project by matching (the seam)
-- PRD-final §3.1/§4.2/§5.3 · build-plan Phase 3
--
-- Reuses project_slot (= Need) and work_commitment (= Membership) under new
-- concept RPCs, matching on the P2 person_skill + capacity (NOT old badges):
--   * project_slot.desired_level — the new behavioural level a Need wants.
--   * member_free_hours — capacity left this month (the HARD gate).
--   * need_post     — a WG officer posts a labour Need (applies, no review).
--   * match_candidates — roster RANKED by level-fit · evidence · free hours
--                        (capacity gates; under-level still shown, ranked low).
--   * assign        — seat a person into a Need (A matched OR B direct); wraps
--                     work_seat for nominal/ledger correctness, hard-gates capacity.
-- Idempotent.
-- =====================================================================

begin;

alter table project_slot add column if not exists desired_level text
  check (desired_level is null or desired_level in ('learning','independent','lead'));

-- behavioural level → rank (null/unknown = lowest)
create or replace function lvl_rank(p text)
returns int language sql immutable as $$
  select case p when 'lead' then 3 when 'independent' then 2 when 'learning' then 1 else 0 end;
$$;

-- capacity left this month: member.monthly_hours (fallback to Labor cap) minus
-- hours already committed on hour-denominated slots. NULL = undeclared = unconstrained.
create or replace function member_free_hours(p_member uuid, p_ym text)
returns numeric language plpgsql stable security definer set search_path = public as $$
declare capn numeric; used numeric;
begin
  select monthly_hours into capn from member where id = p_member;
  if capn is null then capn := member_labor_cap(p_member); end if;
  if capn is null then return null; end if;
  select coalesce(sum(wc.monthly_amount), 0) into used
    from work_commitment wc join project_slot s on s.id = wc.slot_id
    where wc.member_id = p_member and wc.year_month = p_ym
      and s.slot_kind in ('work_labor','leader');
  return capn - used;
end $$;
grant execute on function member_free_hours(uuid,text) to authenticated;

-- post a labour Need (applies immediately for a trusted project editor)
create or replace function need_post(
  p_project uuid, p_skill uuid, p_level text, p_capacity numeric, p_headcount int default 1)
returns project_slot language plpgsql security definer set search_path = public as $$
declare r project_slot;
begin
  if not can_edit_project(p_project) then raise exception 'not allowed to edit this project'; end if;
  if p_level is not null and p_level not in ('learning','independent','lead') then
    raise exception 'invalid level'; end if;
  insert into project_slot (project_id, slot_kind, skill_id, desired_level, quota, headcount, status)
  values (p_project, 'work_labor', p_skill, p_level, p_capacity, coalesce(p_headcount, 1), 'open')
  returning * into r;
  perform project_log(p_project, 'Need posted'
    || coalesce(' · ' || (select name from skill where id = p_skill), ''));
  return r;
end $$;
grant execute on function need_post(uuid,uuid,text,numeric,int) to authenticated;

-- ranked candidates for a Need: skilled people with capacity, best-fit first.
-- capacity is the hard gate (null cap = unconstrained = passes); under-level
-- people are included but rank below those who meet the desired level.
create or replace function match_candidates(p_slot uuid)
returns table (member_id uuid, full_name text, level text, tasks int, shipped int,
               free_hours numeric, fits boolean, reason text)
language plpgsql stable security definer set search_path = public as $$
declare s project_slot; ym text := to_char(now(), 'YYYY-MM');
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  return query
    select m.id, m.full_name, ps.level,
           coalesce(e.tasks, 0), coalesce(e.shipped, 0),
           member_free_hours(m.id, ym),
           (lvl_rank(ps.level) >= lvl_rank(s.desired_level)) as fits,
           case when lvl_rank(ps.level) >= lvl_rank(s.desired_level) then 'ok'
                else 'below ' || coalesce(s.desired_level, 'any') end
    from member m
    join person_skill ps on ps.member_id = m.id and ps.skill_id = s.skill_id
    left join person_skill_evidence e on e.member_id = m.id and e.skill_id = s.skill_id
    where coalesce(member_free_hours(m.id, ym), 1) > 0          -- hard capacity gate
    order by fits desc, lvl_rank(ps.level) desc,
             coalesce(e.shipped, 0) desc, coalesce(e.tasks, 0) desc, m.full_name;
end $$;
grant execute on function match_candidates(uuid) to authenticated;

-- assign a person into a Need (A = matched, B = direct — same call). Wraps
-- work_seat for nominal/ledger correctness; hard-gates monthly capacity.
create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; labor uuid; ym text := to_char(now(), 'YYYY-MM'); freeh numeric;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('manage_members') or manages_card(p_member)) then
    raise exception 'not allowed to assign';
  end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'hours must be greater than 0'; end if;
  freeh := member_free_hours(p_member, ym);
  if freeh is not null and freeh < p_hours then
    raise exception 'over capacity: only % h free this month', freeh;
  end if;
  -- the member's Labor resource carries the working-hours commitment
  select r.id into labor from resource r join resource_type rt on rt.id = r.type_id
    where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
  return work_seat(p_slot, p_member, labor, ym, p_hours, p_member);
end $$;
grant execute on function assign(uuid,uuid,numeric) to authenticated;

commit;
