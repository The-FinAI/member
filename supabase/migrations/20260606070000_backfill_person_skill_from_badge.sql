-- =====================================================================
-- AUDIT FIX — data continuity: the new matching reads person_skill, but every
-- member's already-certified skills live in the old `badge` table. Backfill
-- person_skill from badge so existing skills drive matching from day one.
--
-- Non-destructive: the `badge` table is KEPT (not dropped); this only ADDs
-- person_skill rows where none exist, mapping the 4-tier guild level → the new
-- 3-tier behavioural level. Idempotent (on conflict do nothing).
--   apprentice → learning · journeyman → independent ·
--   craftsman  → independent · master → lead
-- =====================================================================

begin;

insert into person_skill (member_id, skill_id, level)
select b.member_id, b.skill_id,
       case b.level::text
         when 'apprentice' then 'learning'
         when 'journeyman' then 'independent'
         when 'craftsman'  then 'independent'
         when 'master'     then 'lead'
         else 'learning'
       end
from badge b
on conflict (member_id, skill_id) do nothing;

commit;
