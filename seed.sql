-- =====================================================================
-- The Fin AI Community — seed data (run after schema.sql; policies.sql optional)
-- Idempotent-ish: uses ON CONFLICT on natural keys where possible.
-- NOTE: only Jimin Huang's email is known; all other emails below are
--       PLACEHOLDERS (@placeholder.thefin.ai) — replace with real ones.
-- =====================================================================

-- ---------- capabilities ----------
insert into capability (key, description) values
  ('invite_members',  'Send invites to new members'),
  ('manage_members',  'Manage member records, positions, and capability mappings'),
  ('manage_taxonomy', 'Manage project types, statuses, roles, and the skill tree'),
  ('edit_any_project','Create/edit/delete any project and its needs')
on conflict (key) do nothing;

-- ---------- community positions ----------
insert into position (name, rank, description) values
  ('President',        10, 'Org president / board member'),
  ('Board',            20, 'Board member'),
  ('Steering',         30, 'Steering committee'),
  ('Executive Chair',  40, 'Chair of the executive committee'),
  ('Executive',        50, 'Executive committee'),
  ('Researcher',      100, 'Community researcher / contributor')
on conflict (name) do nothing;

-- capability grants per position
insert into position_capability (position_id, capability_key)
select p.id, c.key from position p cross join capability c
where p.name in ('President','Board','Executive Chair')
on conflict do nothing;

insert into position_capability (position_id, capability_key)
select p.id, c.key from position p join capability c on c.key = 'invite_members'
where p.name = 'Steering'
on conflict do nothing;

insert into position_capability (position_id, capability_key)
select p.id, c.key from position p join capability c
  on c.key in ('invite_members','manage_taxonomy','edit_any_project')
where p.name = 'Executive'
on conflict do nothing;
-- Researcher: no capabilities.

-- ---------- governance members (only Jimin; invite the rest via the admin UI) ----------
insert into member (full_name, email, affiliation, status) values
  ('Jimin Huang',         'jimin.huang@thefin.ai',                 'University of Manchester / The Fin AI', 'active')
on conflict (email) do nothing;

-- assign positions
insert into member_position (member_id, position_id)
select m.id, p.id from member m, position p where
   (m.email = 'jimin.huang@thefin.ai'                   and p.name = 'President')
on conflict do nothing;

-- ---------- project types ----------
insert into project_type (name, rank) values
  ('Dataset & Benchmark', 10),
  ('Model',               20),
  ('Agent',               30),
  ('Application',         40),
  ('Trustworthy',         50)
on conflict (name) do nothing;

-- ---------- project statuses ----------
insert into project_status (name, rank, is_active) values
  ('Proposal',         10, true),
  ('Data Collecting',  20, true),
  ('Work in progress', 30, true),
  ('Under review',     40, true),
  ('Finished',         50, false),
  ('Hold',             60, false)
on conflict (name) do nothing;

-- ---------- project roles ----------
insert into project_role (name, can_manage) values
  ('Leader',          true),
  ('Co-lead',         true),
  ('Contributor',     false),
  ('Annotator',       false),
  ('Financial Expert',false),
  ('Advisor',         false)
on conflict (name) do nothing;

-- ---------- skill tree (5 skill-type categories) ----------
-- top-level categories
insert into skill (parent_id, name) values
  (null, 'Domain'), (null, 'Language'), (null, 'Research'),
  (null, 'Engineering'), (null, 'Organization & Communication')
on conflict (parent_id, name) do nothing;

-- children (resolve parent by name)
insert into skill (parent_id, name)
select s.id, child.name from skill s
join (values
  ('Domain','Equities / Trading'), ('Domain','Risk Management'),
  ('Domain','Audit / Accounting / XBRL'), ('Domain','Portfolio / Asset Management'),
  ('Domain','Banking / Credit'), ('Domain','RegTech / Compliance'),
  ('Domain','Macroeconomics'), ('Domain','ESG / Sustainable Finance'),

  ('Language','English'), ('Language','Chinese'), ('Language','Japanese'),
  ('Language','Korean'), ('Language','Spanish'), ('Language','French'),
  ('Language','German'), ('Language','Portuguese'), ('Language','Arabic'),
  ('Language','Russian'), ('Language','Hindi'),

  ('Research','Paper Writing'), ('Research','Rebuttal / Review'),
  ('Research','Literature Review'), ('Research','Experiment Design'),
  ('Research','Benchmark Design'), ('Research','Evaluation & Metrics'),
  ('Research','Statistical Analysis'),

  ('Engineering','Pretraining'), ('Engineering','Fine-tuning / SFT'),
  ('Engineering','RLHF / Alignment'), ('Engineering','Inference & Serving'),
  ('Engineering','Data Engineering / Pipelines'), ('Engineering','Agent / Tool-use / RAG'),
  ('Engineering','Multimodal'), ('Engineering','Frontend / Backend Dev'),
  ('Engineering','Distributed Training / GPU'),

  ('Organization & Communication','Project Management / Coordination'),
  ('Organization & Communication','Meeting Facilitation / Hosting'),
  ('Organization & Communication','Minutes / Record-keeping'),
  ('Organization & Communication','Mentoring / Onboarding'),
  ('Organization & Communication','Presentation / Public Speaking'),
  ('Organization & Communication','Community Building / Outreach'),
  ('Organization & Communication','Cross-team Collaboration')
) as child(parent_name, name) on s.name = child.parent_name and s.parent_id is null
on conflict (parent_id, name) do nothing;

-- ---------- projects (34, migrated from the tracking doc) ----------
insert into project (name, type_id, status_id, target_venue)
select v.name, t.id, st.id, nullif(v.venue,'TBD')
from (values
  ('Herculean',                                                              'Agent',               'Under review',     'NeurIPS'),
  ('FinMoE',                                                                 'Model',               'Data Collecting',  'TBD'),
  ('FinCritic',                                                              'Dataset & Benchmark', 'Under review',     'EMNLP'),
  ('Japanese (Financial benchmark)',                                         'Dataset & Benchmark', 'Under review',     'EMNLP'),
  ('Multimodal Financial OCR',                                               'Dataset & Benchmark', 'Under review',     'MM'),
  ('Multi-Agent application with Report Generation',                         'Agent',               'Hold',             'TBD'),
  ('Financial LLMs survey',                                                  'Dataset & Benchmark', 'Hold',             'ACM Computing Survey'),
  ('AI-as-CEO',                                                              'Dataset & Benchmark', 'Under review',     'EMNLP'),
  ('Hindi (Lakshmi)',                                                        'Dataset & Benchmark', 'Data Collecting',  'TBD'),
  ('FinReporting',                                                           'Dataset & Benchmark', 'Finished',         'ACL'),
  ('IslamicBias',                                                            'Dataset & Benchmark', 'Under review',     'EMNLP'),
  ('Finpersona',                                                             'Dataset & Benchmark', 'Under review',     'COLM'),
  ('Multilingual FMD',                                                       'Dataset & Benchmark', 'Finished',         'ACL'),
  ('Network-Aware Reasoning Framework for Financial Rumor Detection',        'Dataset & Benchmark', 'Data Collecting',  'ARR'),
  ('FINMCP-BENCH',                                                           'Agent',               'Under review',     'COLM'),
  ('FINAUDIO2.0',                                                            'Dataset & Benchmark', 'Proposal',         'TBD'),
  ('FinAudio1.0',                                                            'Dataset & Benchmark', 'Hold',             'IPM'),
  ('Federated Learning',                                                     'Application',         'Under review',     'EMNLP'),
  ('LongFin',                                                                'Dataset & Benchmark', 'Under review',     'IPM'),
  ('Government LLMs survey (General)',                                       'Dataset & Benchmark', 'Proposal',         'ACM Computing Survey'),
  ('FinEdit',                                                                'Dataset & Benchmark', 'Data Collecting',  'EMNLP'),
  ('Multi-Agent application with XBRL Tagging',                              'Agent',               'Proposal',         'AAAI'),
  ('Bridging the Cognitive Chasm (LLM human simulation)',                    'Agent',               'Hold',             'ICML'),
  ('FinT1',                                                                  'Agent',               'Proposal',         'ARR'),
  ('Towards Explainable and Adaptive Pair Trading with Multi-Agent LLMs',    'Agent',               'Work in progress', 'NeurIPS'),
  ('An Adaptive AI Trading System with Test-Time Training',                  'Agent',               'Hold',             'TBD'),
  ('LongContext Reasoning',                                                  'Model',               'Hold',             'TBD'),
  ('Fin O1 Reasoning Model',                                                 'Model',               'Under review',     'IPM'),
  ('Affective Analysis Benchmark (sentiment)',                               'Dataset & Benchmark', 'Work in progress', 'IPM'),
  ('XBRL Tagging',                                                           'Dataset & Benchmark', 'Work in progress', 'IPM'),
  ('Enterprise Finance Operations Benchmark',                                'Dataset & Benchmark', 'Work in progress', 'NeurIPS'),
  ('Auditflow',                                                              'Agent',               'Under review',     'EMNLP'),
  ('Multi-lingual Tagging',                                                  'Dataset & Benchmark', 'Proposal',         'WWW'),
  ('MoE Post-training',                                                      'Model',               'Proposal',         'ICLR')
) as v(name, type_name, status_name, venue)
join project_type   t  on t.name  = v.type_name
join project_status st on st.name = v.status_name
where not exists (select 1 from project p where p.name = v.name);

-- =====================================================================
-- Not seeded (created through the app, via invite-only flow):
--   project_member, open_need, need_application, member_skill, skill_endorsement, invite.
-- Project participants from the tracking doc (Xueqing Peng, Lingfei Qian, Yan Wang,
-- Zhuohan Xie, Yupeng Cao, Haohang Li, ...) can be bulk-imported as 'invited'
-- members + project_member links in a follow-up if desired.
-- =====================================================================
