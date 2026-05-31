-- =====================================================================
-- The Fin AI Community — RPC functions (run after policies.sql)
-- These are SECURITY DEFINER (run with owner rights) so they must do their
-- own authorization checks. They cover the two write-flows that RLS alone
-- can't express cleanly: claiming an invite, and accepting an application.
-- =====================================================================

-- ---------- invited-registration: link the pre-created member row ----------
-- An admin pre-creates a member row (status='invited', auth_user_id null) with
-- the invitee's email. On first magic-link login the invitee calls this to bind
-- their auth user to that row. No row for their email => they stay unlinked
-- (i.e. not invited). RLS can't express this because the user has no member row
-- yet (so auth.uid() = auth_user_id is false), hence a definer function.
create or replace function claim_membership()
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  update member
     set auth_user_id = auth.uid(), status = 'active'
   where email = auth.email()
     and auth_user_id is null
  returning id into mid;

  -- mark any matching invite accepted (best-effort)
  update invite set accepted_at = now()
   where email = auth.email() and accepted_at is null;

  return mid;  -- null if the email was not invited
end;
$$;
grant execute on function claim_membership() to authenticated;

-- ---------- matching: accept an application ----------
-- Marks the application accepted and adds the applicant to the project with the
-- given role. Caller must manage the project (or hold edit_any_project).
create or replace function accept_application(app_id uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid;
begin
  select n.project_id, na.member_id
    into pid, mid
  from need_application na
  join open_need n on n.id = na.open_need_id
  where na.id = app_id;

  if pid is null then
    raise exception 'application not found';
  end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then
    raise exception 'not authorized to accept for this project';
  end if;

  update need_application set status = 'accepted' where id = app_id;
  insert into project_member (project_id, member_id, project_role_id)
  values (pid, mid, role_id)
  on conflict do nothing;
end;
$$;
grant execute on function accept_application(uuid, uuid) to authenticated;
