-- =====================================================================
-- The Fin AI Community — Phase 1 schema (Supabase / PostgreSQL)
-- Audience: researchers. Focus: member system + projects + collaboration matching.
-- Principles: invite-only; nothing about identity is hard-coded —
--   Position (community-level) and Role (project-level) are data, not enums;
--   permissions derive from capabilities mapped onto positions.
-- =====================================================================

-- ---------- MEMBERS (decoupled from auth so people can be imported pre-login) ----------
-- A member row can exist before the person ever logs in (status='invited',
-- auth_user_id null). When they accept an invite and authenticate, their
-- Supabase auth user binds to the existing row (matched by email).
create table member (
  id           uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete set null,
  full_name    text not null,
  email        text unique not null,
  affiliation  text,
  avatar_url   text,
  bio          text,
  links        jsonb not null default '{}',      -- {scholar, hf, github, homepage}
  availability text not null default 'looking',   -- 'looking' | 'limited' | 'full'
  status       text not null default 'invited',   -- 'invited' (imported, not yet logged in) | 'active'
  created_at   timestamptz not null default now()
);

-- ---------- COMMUNITY POSITION (configurable, NOT an enum) ----------
create table position (
  id          uuid primary key default gen_random_uuid(),
  name        text unique not null,    -- President, Board, Steering, Executive Chair, Executive, Researcher
  rank        int  not null default 100,
  description text
);

create table member_position (
  member_id   uuid references member (id)  on delete cascade,
  position_id uuid references position (id) on delete cascade,
  started_on  date,
  ended_on    date,
  primary key (member_id, position_id)
);

-- ---------- PERMISSIONS (derive from data, not code) ----------
create table capability (
  key         text primary key,        -- invite_members, manage_members, manage_taxonomy, edit_any_project
  description text
);

create table position_capability (
  position_id    uuid references position (id) on delete cascade,
  capability_key text references capability (key) on delete cascade,
  primary key (position_id, capability_key)
);

-- ---------- PROJECT LOOKUPS (configurable) ----------
create table project_type (        -- Dataset & Benchmark, Model, Agent, Application, Trustworthy
  id   uuid primary key default gen_random_uuid(),
  name text unique not null,
  rank int not null default 100
);

create table project_status (      -- Proposal, Data Collecting, Work in progress, Under review, Finished, Hold
  id        uuid primary key default gen_random_uuid(),
  name      text unique not null,
  rank      int not null default 100,
  is_active boolean not null default true   -- Hold/Finished can be flagged inactive
);

-- ---------- PROJECTS ----------
create table project (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  type_id      uuid references project_type (id),
  status_id    uuid references project_status (id),
  target_venue text,                         -- NeurIPS, EMNLP, ACL, COLM, IPM, ...
  deadline     date,
  summary      text,
  links        jsonb not null default '{}',  -- {openreview, hf, repo, paper}
  created_at   timestamptz not null default now()
);

-- ---------- PROJECT ROLE (per-project, configurable) ----------
create table project_role (
  id          uuid primary key default gen_random_uuid(),
  name        text unique not null,   -- Leader, Co-lead, Contributor, Annotator, Financial Expert, Advisor
  can_manage  boolean not null default false  -- Leader/Co-lead => edit this project, post needs, accept applications
);

create table project_member (
  project_id      uuid references project (id)      on delete cascade,
  member_id       uuid references member (id)       on delete cascade,
  project_role_id uuid references project_role (id),
  joined_at       timestamptz not null default now(),
  primary key (project_id, member_id, project_role_id)
);

-- ---------- SKILL TREE + 4-LEVEL RATING ----------
create type skill_level as enum ('Beginner', 'Intermediate', 'Advanced', 'Expert');

create table skill (
  id        uuid primary key default gen_random_uuid(),
  parent_id uuid references skill (id) on delete cascade,  -- self-referencing tree
  name      text not null,
  unique (parent_id, name)
);

-- self-assessed level
create table member_skill (
  member_id  uuid references member (id) on delete cascade,
  skill_id   uuid references skill (id)  on delete cascade,
  self_level skill_level not null,
  primary key (member_id, skill_id)
);

-- endorsements from collaborators add credibility to a self-rated skill
create table skill_endorsement (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references member (id) on delete cascade,   -- who is endorsed
  skill_id    uuid references skill (id)  on delete cascade,
  endorser_id uuid references member (id) on delete cascade,   -- who endorses
  level       skill_level,                                     -- optional: level the endorser attests to
  note        text,
  created_at  timestamptz not null default now(),
  unique (member_id, skill_id, endorser_id),
  check (member_id <> endorser_id)
);

-- ---------- COLLABORATION MATCHING ----------
create table open_need (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid references project (id)      on delete cascade,
  project_role_id uuid references project_role (id),  -- the role being recruited
  skill_id        uuid references skill (id),         -- optional required skill
  min_level       skill_level,                        -- optional minimum level
  headcount       int  not null default 1,
  description     text,
  status          text not null default 'open',       -- open | filled | closed
  created_at      timestamptz not null default now()
);

create table need_application (
  id           uuid primary key default gen_random_uuid(),
  open_need_id uuid references open_need (id) on delete cascade,
  member_id    uuid references member (id)    on delete cascade,
  message      text,
  status       text not null default 'pending',   -- pending | accepted | declined
  created_at   timestamptz not null default now(),
  unique (open_need_id, member_id)
);

-- ---------- INVITES (invite-only registration) ----------
create table invite (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  invited_by  uuid references member (id),
  token       text unique not null,
  position_id uuid references position (id),   -- optional pre-assigned community position
  accepted_at timestamptz,
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- NOTES
--  * Enable Row-Level Security on every table, then derive policies:
--      - read: any authenticated member;
--      - edit project: project_member with a can_manage role, OR a position
--        holding the 'edit_any_project' capability;
--      - invite/manage: positions holding 'invite_members'/'manage_members'.
--  * Recommended helper: a SQL function has_capability(key) that resolves
--    auth.uid() -> member.auth_user_id -> member_position -> position_capability,
--    used inside RLS policies. (See policies.sql.)
--  * Status/type kept as lookup tables (not enums) to stay configurable,
--    matching the "nothing hard-coded" principle for identity.
-- =====================================================================
