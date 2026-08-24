-- RPC smoke against a REAL postgres with the full migration chain applied.
-- Purpose: catch the class the mock e2e cannot — column types, enums,
-- constraints, gate regressions ("invalid input syntax for type uuid" etc).
-- Runs in CI (schema-smoke.yml) after `supabase migration up`. Any exception
-- aborts with non-zero via ON_ERROR_STOP.
\set ON_ERROR_STOP on
begin;

-- ── a signed-in market user (current_member_id = member.auth_user_id = auth.uid) ──
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'smoke@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'orphan@test.local');
-- bootstrap member first: every gate needs current_member_id() non-null
insert into member (full_name, email, kind, status, auth_user_id)
values ('Smoke Officer', 'smoke@test.local', 'operator', 'active',
        '11111111-1111-1111-1111-111111111111');
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- org + people
select unit_create('Smoke WG', 'working_group') as wg \gset
select unit_create('Smoke Chapter', 'chapter') as ch \gset
select forge_member_card('Smoke Worker', 'worker@test.local', :'ch') as worker \gset
select member_set_home_unit(:'worker', :'ch');
select person_set_capacity(20, :'worker');
insert into skill (id, name) values ('33333333-3333-3333-3333-333333333333', 'SmokeSkill');
select person_skill_set('33333333-3333-3333-3333-333333333333', 'independent', :'worker');
select person_skill_set('33333333-3333-3333-3333-333333333333', 'lead', :'worker');       -- U
select person_skill_set('33333333-3333-3333-3333-333333333333', null, :'worker');         -- D

-- venue
select venue_create('SMOKECONF', 'conference', current_date + 90) as ven \gset

-- project lifecycle
select create_project_phase1('Smoke Paper',
         (select id from project_type limit 1),
         (select id from project_status where name = 'Proposal'), :'wg') as prj \gset
select project_rename(:'prj', 'Smoke Paper v2');
select project_set_venue(:'prj', :'ven');
select project_set_org_unit(:'prj', null);
select project_set_org_unit(:'prj', :'wg');

-- THE regression this file exists for: forge_need must insert cleanly
select forge_need(:'prj', 'work_labor', null,
                  '33333333-3333-3333-3333-333333333333', null, 8, 1, 'corresponding') as slot \gset

-- seat, edit hours (upsert), unseat; then close the opening
select assign(:'worker', :'slot', 5);
select assign(:'worker', :'slot', 8);
select unassign(:'slot', :'worker');
select slot_close(:'slot');

-- stages: forward, backward, hold, finished and back (all must be legal now)
select project_set_status(:'prj', (select id from project_status where name = 'Work in progress'));
select project_set_status(:'prj', (select id from project_status where name = 'Under review'));
select project_set_deadline(:'prj', current_date + 30);
select project_set_status(:'prj', (select id from project_status where name = 'Finished'));
select project_set_meta(:'prj', null, null, 'main', null);
select project_set_status(:'prj', (select id from project_status where name = 'Hold'));
select project_archive(:'prj', true);
select project_archive(:'prj', false);

-- resources
select forge_resource((select id from resource_type where name <> 'Labor' limit 1),
                      'Smoke GPU', :'worker', 'member', 100);
select resource_set_quota((select id from resource where name = 'Smoke GPU'), 150);

-- accounts
select count(*) from orphan_accounts();
select member_link_account(:'worker', '22222222-2222-2222-2222-222222222222');
select member_archive(:'worker', true);
select member_archive(:'worker', false);

rollback;
\echo rpc_smoke: all market RPCs executed cleanly against the real schema
