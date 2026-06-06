-- =====================================================================
-- BUILD PLAN P7A fix — the LEADER (first author) is a NEED, matched like any
-- other, not a hand-pick. match_candidates now handles the leader slot:
--   * leader / labour with a skill → match person_skill (as before)
--   * leader / labour with NO skill → match by free capacity only (anyone with
--     hours), since a first-author seat may carry no skill requirement.
-- assign already handles the leader slot (falls to the labour branch →
-- work_seat mints first-author writing hours). Idempotent.
-- =====================================================================

begin;

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
    return query
      select m.id, m.full_name, null::text, 0, 0,
             resource_free(r.id, ym) as free,
             coalesce(rt.unit, 'units'), r.id, true, 'holds'::text
      from resource r
      join resource_type rt on rt.id = r.type_id
      join member m on m.id = r.holder_member_id
      where r.type_id = s.resource_type_id and r.scope = 'member'
        and coalesce(resource_free(r.id, ym), 1) > 0
      order by free desc nulls last, m.full_name;
  else
    -- work_labor OR leader. A skill requirement (s.skill_id) filters to people
    -- who hold that skill; without one (e.g. a plain first-author seat), anyone
    -- with free capacity qualifies.
    return query
      select m.id, m.full_name, ps.level,
             coalesce(e.tasks, 0), coalesce(e.shipped, 0),
             member_free_hours(m.id, ym), 'h'::text, null::uuid,
             (s.skill_id is null or lvl_rank(ps.level) >= lvl_rank(s.desired_level)) as fits,
             case when s.skill_id is null then 'ok'
                  when lvl_rank(ps.level) >= lvl_rank(s.desired_level) then 'ok'
                  else 'below ' || coalesce(s.desired_level, 'any') end
      from member m
      left join person_skill ps on ps.member_id = m.id and ps.skill_id = s.skill_id
      left join person_skill_evidence e on e.member_id = m.id and e.skill_id = s.skill_id
      where coalesce(member_free_hours(m.id, ym), 1) > 0
        and (s.skill_id is null or ps.skill_id is not null)   -- skill needs require the skill
      order by fits desc, lvl_rank(ps.level) desc,
               coalesce(e.shipped, 0) desc, coalesce(e.tasks, 0) desc, m.full_name;
  end if;
end $$;
grant execute on function match_candidates(uuid) to authenticated;

commit;
