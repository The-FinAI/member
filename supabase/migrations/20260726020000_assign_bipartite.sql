-- #53 decision A (strict bipartite): staffing a person is the job of the
-- member's HOME-CHAPTER officer (or their card's steward, or an admin) — not
-- the project's editors.
--
-- Audit I-4 found the two seat paths CONTRADICTED each other:
--   assign()    gate: can_edit_project ∨ manage_members ∨ manages_card
--   work_seat() gate: manages_card ∨ manage_members ∨ edit_any_project ∨ is_unit_officer_of
-- and since assign() *calls* work_seat(), the effective gate was their
-- INTERSECTION — so on production, via the ledger matcher, a chapter officer
-- could seat their *cards* but NOT their chapter's claimed members (cards
-- worked, people didn't — intermittent, unexplained rejections), and a WG
-- leader passed the outer check only to be rejected by the inner one. Both
-- officer types were broken.
--
-- Fix: assign()'s outer gate now matches work_seat()'s exactly. Body is
-- otherwise verbatim from 20260606050000_notifications.sql (the latest def).
create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; res uuid; ym text := to_char(now(), 'YYYY-MM'); freeh numeric;
        wcid uuid; pname text; what text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project') or is_unit_officer_of(p_member)) then
    raise exception 'only the member''s chapter officer (or an admin) can assign them';
  end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'amount must be greater than 0'; end if;

  if s.slot_kind = 'work_resource' then
    select r.id into res from resource r
      where r.holder_member_id = p_member and r.type_id = s.resource_type_id and r.scope = 'member' limit 1;
    if res is null then raise exception 'this person holds no resource of that type'; end if;
    freeh := resource_free(res, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over quota: only % left this month', freeh; end if;
    what := coalesce((select name from resource_type where id = s.resource_type_id), 'a resource');
  else
    select r.id into res from resource r join resource_type rt on rt.id = r.type_id
      where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
    freeh := member_free_hours(p_member, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over capacity: only % h free this month', freeh; end if;
    what := coalesce((select name from skill where id = s.skill_id), 'work');
  end if;

  wcid := work_seat(p_slot, p_member, res, ym, p_hours, p_member);
  select name into pname from project where id = s.project_id;
  perform notify(p_member, 'assigned',
    'You were assigned to a project', pname || ' · ' || what || ' · ' || p_hours,
    '/projects/' || s.project_id);
  return wcid;
end $$;
grant execute on function assign(uuid,uuid,numeric) to authenticated;
