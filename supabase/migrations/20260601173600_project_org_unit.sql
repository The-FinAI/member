-- ============================================================
-- Link a project to a Working Group (org_unit of kind 'working_group').
-- Optional FK; powers the Working-Group leaderboard and project
-- attribution. A project with org_unit_id NULL is simply unattributed.
-- Idempotent: safe to re-run.
-- ============================================================

alter table project add column if not exists org_unit_id uuid references org_unit (id);

create index if not exists project_org_unit_idx on project (org_unit_id);

comment on column project.org_unit_id is
  'Optional Working Group (org_unit kind=working_group) this project belongs to.';
