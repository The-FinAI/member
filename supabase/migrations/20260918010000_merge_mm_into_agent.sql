-- Working-group merge (President's call, 2026-09-18): Multilingual & Multimodal
-- folds into Agent. The Agent unit survives; M&M's projects move into it and the
-- M&M unit is removed. Leaders become Yupeng Cao, Haohang Li and Yangyang Yu;
-- the outgoing M&M leaders keep their history with today as the end of term.
-- Guarded data migration: a no-op on clones that carry schema only.
do $$
declare
  keep uuid := '3b556041-7cff-4f43-9542-2c6c8eae7120'; -- Agent
  gone uuid := '26401e8a-4eac-4533-adcf-760df14d3082'; -- Multilingual & Multimodal
  lead uuid;
begin
  if not exists (select 1 from org_unit where id = keep)
     or not exists (select 1 from org_unit where id = gone) then return; end if;

  update project set org_unit_id = keep where org_unit_id = gone;

  -- memberships: pk (org_unit_id, member_id) — drop what would collide, move the rest
  delete from org_unit_member g using org_unit_member k
   where g.org_unit_id = gone and k.org_unit_id = keep and k.member_id = g.member_id;
  update org_unit_member set org_unit_id = keep where org_unit_id = gone;

  -- outgoing officers: history moves with the unit, term ends today
  delete from org_unit_officer g using org_unit_officer k
   where g.org_unit_id = gone and k.org_unit_id = keep
     and k.member_id = g.member_id and k.role = g.role;
  update org_unit_officer set org_unit_id = keep, ended_on = coalesce(ended_on, current_date)
   where org_unit_id = gone;

  -- the three leaders of the merged group (Haohang already leads Agent)
  foreach lead in array array[
    'f13ee5e2-e362-4082-9e66-e2ebe1216ebb'::uuid,  -- Yupeng Cao
    '8e0877f9-b60a-4110-98e0-02b0c3740086'::uuid,  -- Haohang Li
    '51c6a2c8-d3a7-4aab-ad24-7d88005e80ce'::uuid   -- Yangyang Yu
  ] loop
    if exists (select 1 from member where id = lead) then
      insert into org_unit_officer (org_unit_id, member_id, role, started_on)
      values (keep, lead, 'leader', current_date)
      on conflict (org_unit_id, member_id, role) do update set ended_on = null;
    end if;
  end loop;

  update member set home_unit_id = null where home_unit_id = gone; -- none today; keeps the delete safe
  delete from org_unit where id = gone;
end $$;
