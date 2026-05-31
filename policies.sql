-- =====================================================================
-- The Fin AI Community — Row-Level Security policies (run after schema.sql)
-- Model: every authenticated member can READ the community; WRITE rights
-- derive from (a) capabilities mapped onto community positions, or
-- (b) a managing role within a specific project.
-- =====================================================================

-- ---------- helper functions (security definer, bypass RLS internally) ----------

-- the member row for the currently authenticated user (null if none)
create or replace function current_member_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from member where auth_user_id = auth.uid();
$$;

-- does the current user hold a position granting the given capability?
create or replace function has_capability(cap text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from member m
    join member_position mp on mp.member_id = m.id
    join position_capability pc on pc.position_id = mp.position_id
    where m.auth_user_id = auth.uid()
      and pc.capability_key = cap
  );
$$;

-- does the current user hold a managing role (can_manage) on this project?
create or replace function manages_project(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from member m
    join project_member pm   on pm.member_id = m.id
    join project_role  pr    on pr.id = pm.project_role_id
    where m.auth_user_id = auth.uid()
      and pm.project_id = p
      and pr.can_manage
  );
$$;

-- ---------- enable RLS everywhere ----------
alter table member             enable row level security;
alter table position           enable row level security;
alter table member_position    enable row level security;
alter table capability         enable row level security;
alter table position_capability enable row level security;
alter table project_type       enable row level security;
alter table project_status     enable row level security;
alter table project            enable row level security;
alter table project_role       enable row level security;
alter table project_member     enable row level security;
alter table skill              enable row level security;
alter table member_skill       enable row level security;
alter table skill_endorsement  enable row level security;
alter table open_need          enable row level security;
alter table need_application   enable row level security;
alter table invite             enable row level security;

-- ---------- READ: any authenticated member can read the community ----------
-- (applied to the directory / catalog tables)
create policy read_all_member            on member            for select to authenticated using (true);
create policy read_all_position          on position          for select to authenticated using (true);
create policy read_all_member_position   on member_position   for select to authenticated using (true);
create policy read_all_project_type      on project_type      for select to authenticated using (true);
create policy read_all_project_status    on project_status    for select to authenticated using (true);
create policy read_all_project           on project           for select to authenticated using (true);
create policy read_all_project_role      on project_role      for select to authenticated using (true);
create policy read_all_project_member    on project_member    for select to authenticated using (true);
create policy read_all_skill             on skill             for select to authenticated using (true);
create policy read_all_member_skill      on member_skill      for select to authenticated using (true);
create policy read_all_skill_endorsement on skill_endorsement for select to authenticated using (true);
create policy read_all_open_need         on open_need         for select to authenticated using (true);

-- ---------- MEMBER: a person edits their own profile; managers manage all ----------
create policy member_update_self on member for update to authenticated
  using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());
create policy member_manage on member for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));

-- ---------- POSITIONS / CAPABILITIES: only 'manage_members' holders ----------
create policy position_manage on position for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));
create policy member_position_manage on member_position for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));
create policy capability_manage on capability for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));
create policy position_capability_manage on position_capability for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));

-- ---------- TAXONOMY (types/statuses/roles/skills): 'manage_taxonomy' holders ----------
create policy project_type_manage on project_type for all to authenticated
  using (has_capability('manage_taxonomy')) with check (has_capability('manage_taxonomy'));
create policy project_status_manage on project_status for all to authenticated
  using (has_capability('manage_taxonomy')) with check (has_capability('manage_taxonomy'));
create policy project_role_manage on project_role for all to authenticated
  using (has_capability('manage_taxonomy')) with check (has_capability('manage_taxonomy'));
create policy skill_manage on skill for all to authenticated
  using (has_capability('manage_taxonomy')) with check (has_capability('manage_taxonomy'));

-- ---------- PROJECTS: project managers edit their own; 'edit_any_project' edits all ----------
create policy project_insert on project for insert to authenticated
  with check (has_capability('edit_any_project'));
create policy project_update on project for update to authenticated
  using (manages_project(id) or has_capability('edit_any_project'))
  with check (manages_project(id) or has_capability('edit_any_project'));
create policy project_delete on project for delete to authenticated
  using (has_capability('edit_any_project'));

-- project membership: managers of the project (or global) manage who's on it
create policy project_member_manage on project_member for all to authenticated
  using (manages_project(project_id) or has_capability('edit_any_project'))
  with check (manages_project(project_id) or has_capability('edit_any_project'));

-- ---------- SKILLS: a member owns their own skills & endorses others ----------
create policy member_skill_self on member_skill for all to authenticated
  using (member_id = current_member_id()) with check (member_id = current_member_id());
-- endorsements: the endorser creates/removes their own endorsement
create policy endorsement_by_endorser on skill_endorsement for all to authenticated
  using (endorser_id = current_member_id()) with check (endorser_id = current_member_id());

-- ---------- OPEN NEEDS: project managers post/close needs ----------
create policy open_need_manage on open_need for all to authenticated
  using (manages_project(project_id) or has_capability('edit_any_project'))
  with check (manages_project(project_id) or has_capability('edit_any_project'));

-- ---------- APPLICATIONS: applicant manages own; project manager reviews ----------
create policy application_read on need_application for select to authenticated
  using (
    member_id = current_member_id()
    or exists (select 1 from open_need n where n.id = open_need_id and manages_project(n.project_id))
    or has_capability('edit_any_project')
  );
create policy application_insert on need_application for insert to authenticated
  with check (member_id = current_member_id());
create policy application_withdraw on need_application for delete to authenticated
  using (member_id = current_member_id());
-- project manager accepts/declines (update status)
create policy application_review on need_application for update to authenticated
  using (exists (select 1 from open_need n where n.id = open_need_id and manages_project(n.project_id))
         or has_capability('edit_any_project'))
  with check (exists (select 1 from open_need n where n.id = open_need_id and manages_project(n.project_id))
              or has_capability('edit_any_project'));

-- ---------- INVITES: 'invite_members' holders create; invitee reads by token (via RPC) ----------
create policy invite_manage on invite for all to authenticated
  using (has_capability('invite_members')) with check (has_capability('invite_members'));
-- Note: invitee lookup-by-token should go through a security-definer RPC (the
-- anonymous invitee has no member row yet), not a direct RLS-gated select.
