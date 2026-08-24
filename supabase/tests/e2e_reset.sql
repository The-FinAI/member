-- Per-test reset for the real-DB e2e lane: wipe the market world, re-seed,
-- re-link auth users by email (auth.users survives resets).
\set ON_ERROR_STOP on
truncate work_commitment, project_slot, project_member, project, person_skill,
         resource, member, org_unit, venue, skill, notification, forge_request
  restart identity cascade;
\i supabase/tests/e2e_seed.sql
update member m set auth_user_id = u.id
  from auth.users u where u.email = m.email;
