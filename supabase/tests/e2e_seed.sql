-- E2E world for the real-DB run: the same names/numbers the specs assert,
-- but living in actual postgres under the dumped prod schema.
\set ON_ERROR_STOP on

insert into org_unit (id, code, name, kind, rank) values
  ('a0000000-0000-0000-0000-00000000000a', 'BJ', 'Beijing Chapter', 'chapter', 1),
  ('a0000000-0000-0000-0000-00000000000b', 'MM', 'Multilingual & Multimodal', 'working_group', 1);

insert into venue (name, kind, deadline, notification, rank) values
  ('ACL', 'conference', '2026-01-05', '2026-11-20', 1),
  ('ICLR', 'conference', '2025-09-24', null, 2),
  ('IPM', 'journal', null, null, 3),
  ('ARR', 'rolling', null, null, 4);

insert into skill (id, name, parent_id) values
  ('b0000000-0000-0000-0000-00000000000d', 'Data', null),
  ('b0000000-0000-0000-0000-00000000000a', 'Annotation', 'b0000000-0000-0000-0000-00000000000d'),
  ('b0000000-0000-0000-0000-00000000000b', 'Writing', 'b0000000-0000-0000-0000-00000000000d'),
  ('b0000000-0000-0000-0000-00000000000c', 'OCR', 'b0000000-0000-0000-0000-00000000000d');

insert into member (id, full_name, email, kind, status, home_unit_id, monthly_hours) values
  ('c0000000-0000-0000-0000-000000000001', 'Chen Wei', 'chen@e2e.local', 'operator', 'active', 'a0000000-0000-0000-0000-00000000000a', 20),
  ('c0000000-0000-0000-0000-000000000002', 'Li Hua', 'li@e2e.local', 'operator', 'active', 'a0000000-0000-0000-0000-00000000000a', 10),
  ('c0000000-0000-0000-0000-000000000003', 'Wang Fang', 'wang@e2e.local', 'card', 'active', 'a0000000-0000-0000-0000-00000000000a', 30),
  ('c0000000-0000-0000-0000-000000000004', 'Zhao Lei', 'zhao@e2e.local', 'card', 'active', 'a0000000-0000-0000-0000-00000000000a', 8),
  ('c0000000-0000-0000-0000-000000000005', 'Wu Jing', 'wu@e2e.local', 'operator', 'active', 'a0000000-0000-0000-0000-00000000000b', 20),
  ('c0000000-0000-0000-0000-000000000006', 'Chan Min', 'chan@e2e.local', 'operator', 'active', 'a0000000-0000-0000-0000-00000000000a', 20),
  ('c0000000-0000-0000-0000-000000000007', 'Sai Tan', 'admin@e2e.local', 'operator', 'active', 'a0000000-0000-0000-0000-00000000000a', 0);

insert into person_skill (member_id, skill_id, level) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b', 'lead'),
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-00000000000a', 'independent'),
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-00000000000a', 'lead'),
  ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-00000000000a', 'learning');

-- Wang Fang holds a non-Labor resource (quota 200) for the chip + quota edit
insert into resource (id, type_id, name, scope, holder_member_id, monthly_quota)
select 'd0000000-0000-0000-0000-000000000001', id, 'Wang GPU', 'member', 'c0000000-0000-0000-0000-000000000003', 200
from resource_type where name <> 'Labor' order by rank limit 1;

insert into project (id, name, status_id, type_id, org_unit_id, target_venue, venue_id) values
  ('e0000000-0000-0000-0000-000000000001', 'ml-Tagging',
   (select id from project_status where name = 'Work in progress'),
   (select id from project_type order by name limit 1),
   'a0000000-0000-0000-0000-00000000000b', 'ACL', (select id from venue where name = 'ACL')),
  ('e0000000-0000-0000-0000-000000000002', 'fin-Sentiment',
   (select id from project_status where name = 'Proposal'),
   (select id from project_type order by name limit 1),
   null, null, null);

insert into project_slot (id, project_id, slot_kind, authorship, skill_id, resource_type_id, desired_level, quota, headcount, status) values
  ('f0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'leader', 'first', null, null, null, 20, 1, 'open'),
  ('f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 'work_labor', 'normal', 'b0000000-0000-0000-0000-00000000000a', null, 'independent', 10, 3, 'open'),
  ('f0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 'work_resource', 'normal', null,
   (select id from resource_type where name <> 'Labor' order by rank limit 1), null, null, 1, 'open'),
  ('f0000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000002', 'leader', 'first', null, null, null, null, 1, 'open');

insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval) values
  ('f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001',
   'c0000000-0000-0000-0000-000000000001', to_char(now(), 'YYYY-MM'), 34, 340, 'ok'),
  ('f0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001',
   'c0000000-0000-0000-0000-000000000004', to_char(now(), 'YYYY-MM'), 5, 50, 'ok');
