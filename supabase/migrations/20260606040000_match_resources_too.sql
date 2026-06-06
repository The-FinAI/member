-- =====================================================================
-- BUILD PLAN P3 (extend) — matching covers RESOURCE needs, not only hours
-- A Need is "a skill@level OR a resource" (PRD §3.2). P3 v1 only matched
-- labour. This makes need_post / match_candidates / assign kind-aware:
--   * work_labor    → match person_skill + free HOURS (as before)
--   * work_resource → match whoever HOLDS that resource type, ranked by
--                     remaining monthly QUOTA (capacity gate = remaining > 0)
-- Idempotent.
-- =====================================================================

begin;

-- remaining quota on a specific held resource this month
create or replace function resource_free(p_resource uuid, p_ym text)
returns numeric language sql stable security definer set search_path = public as $$
  select r.monthly_quota - coalesce(
           (select sum(wc.monthly_amount) from work_commitment wc
             where wc.resource_id = r.id and wc.year_month = p_ym), 0)
  from resource r where r.id = p_resource;
$$;
grant execute on function resource_free(uuid,text) to authenticated;

-- ---------- need_post: kind-aware (skill OR resource) ----------
drop function if exists need_post(uuid,uuid,text,numeric,int);
create or replace function need_post(
  p_project uuid, p_kind text, p_skill uuid, p_level text,
  p_resource_type uuid, p_capacity numeric, p_headcount int default 1)
returns project_slot language plpgsql security definer set search_path = public as $$
declare r project_slot;
begin
  if not can_edit_project(p_project) then raise exception 'not allowed to edit this project'; end if;
  if p_kind not in ('work_labor','work_resource') then raise exception 'invalid need kind'; end if;
  if p_kind = 'work_labor'  and p_skill is null then raise exception 'a skill is required'; end if;
  if p_kind = 'work_resource' and p_resource_type is null then raise exception 'a resource type is required'; end if;
  insert into project_slot (project_id, slot_kind, skill_id, desired_level, resource_type_id, quota, headcount, status)
  values (p_project, p_kind,
          case when p_kind = 'work_labor' then p_skill end,
          case when p_kind = 'work_labor' then p_level end,
          case when p_kind = 'work_resource' then p_resource_type end,
          p_capacity, coalesce(p_headcount, 1), 'open')
  returning * into r;
  perform project_log(p_project, 'Need posted'
    || coalesce(' · ' || (select name from skill where id = p_skill), '')
    || coalesce(' · ' || (select name from resource_type where id = p_resource_type), ''));
  return r;
end $$;
grant execute on function need_post(uuid,text,uuid,text,uuid,numeric,int) to authenticated;

-- ---------- match_candidates: kind-aware, unit-carrying ----------
drop function if exists match_candidates(uuid);
create or replace function match_candidates(p_slot uuid)
returns table (member_id uuid, full_name text, level text, tasks int, shipped int,
               free numeric, unit text, resource_id uuid, fits boolean, reason text)
language plpgsql stable security definer set search_path = public as $$
declare s project_slot; ym text := to_char(now(), 'YYYY-MM');
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;

  if s.slot_kind = 'work_resource' then
    -- candidates = members who HOLD a resource of this type, by remaining quota
    return query
      select m.id, m.full_name, null::text, 0, 0,
             resource_free(r.id, ym) as free,
             coalesce(rt.unit, 'units'), r.id, true, 'holds'::text
      from resource r
      join resource_type rt on rt.id = r.type_id
      join member m on m.id = r.holder_member_id
      where r.type_id = s.resource_type_id and r.scope = 'member'
        and coalesce(resource_free(r.id, ym), 1) > 0          -- hard quota gate
      order by free desc nulls last, m.full_name;
  else
    -- labour: person_skill + free hours (capacity hard gate; under-level shown lower)
    return query
      select m.id, m.full_name, ps.level,
             coalesce(e.tasks, 0), coalesce(e.shipped, 0),
             member_free_hours(m.id, ym), 'h'::text, null::uuid,
             (lvl_rank(ps.level) >= lvl_rank(s.desired_level)) as fits,
             case when lvl_rank(ps.level) >= lvl_rank(s.desired_level) then 'ok'
                  else 'below ' || coalesce(s.desired_level, 'any') end
      from member m
      join person_skill ps on ps.member_id = m.id and ps.skill_id = s.skill_id
      left join person_skill_evidence e on e.member_id = m.id and e.skill_id = s.skill_id
      where coalesce(member_free_hours(m.id, ym), 1) > 0
      order by fits desc, lvl_rank(ps.level) desc,
               coalesce(e.shipped, 0) desc, coalesce(e.tasks, 0) desc, m.full_name;
  end if;
end $$;
grant execute on function match_candidates(uuid) to authenticated;

-- ---------- assign: kind-aware (resolve the right resource, gate the right cap) ----------
create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; res uuid; ym text := to_char(now(), 'YYYY-MM'); freeh numeric;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('manage_members') or manages_card(p_member)) then
    raise exception 'not allowed to assign';
  end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'amount must be greater than 0'; end if;

  if s.slot_kind = 'work_resource' then
    select r.id into res from resource r
      where r.holder_member_id = p_member and r.type_id = s.resource_type_id and r.scope = 'member' limit 1;
    if res is null then raise exception 'this person holds no resource of that type'; end if;
    freeh := resource_free(res, ym);
    if freeh is not null and freeh < p_hours then
      raise exception 'over quota: only % left this month', freeh; end if;
  else
    select r.id into res from resource r join resource_type rt on rt.id = r.type_id
      where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
    freeh := member_free_hours(p_member, ym);
    if freeh is not null and freeh < p_hours then
      raise exception 'over capacity: only % h free this month', freeh; end if;
  end if;

  return work_seat(p_slot, p_member, res, ym, p_hours, p_member);
end $$;
grant execute on function assign(uuid,uuid,numeric) to authenticated;

commit;
