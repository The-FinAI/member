-- =====================================================================
-- Project card — meetings
-- ---------------------------------------------------------------------
-- Schedule/cancel project meetings from the editable project card. Same
-- permission model as the rest of the card (can_edit_project: project
-- leader, the project's WG officer, or an admin). Each change logs a
-- project_event so it shows up in history.
--
-- Assumes project_meeting already exists in the DB:
--   project_meeting (id, project_id, title, scheduled_at, ends_at,
--                    location, agenda, created_by, created_at)
-- Idempotent: create or replace. Apply to the live DB.
-- =====================================================================

begin;

create or replace function project_meeting_add(
  p_project uuid, p_title text, p_scheduled_at timestamptz,
  p_ends_at timestamptz default null, p_location text default null, p_agenda text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if coalesce(trim(p_title), '') = '' then raise exception 'meeting title required'; end if;
  if p_scheduled_at is null then raise exception 'meeting time required'; end if;
  insert into project_meeting (project_id, title, scheduled_at, ends_at, location, agenda, created_by)
  values (p_project, trim(p_title), p_scheduled_at, p_ends_at,
          nullif(trim(coalesce(p_location, '')), ''), nullif(trim(coalesce(p_agenda, '')), ''),
          current_member_id())
  returning id into mid;
  perform project_log(p_project, 'Scheduled meeting “' || trim(p_title) || '”');
  return mid;
end $$;
grant execute on function project_meeting_add(uuid, text, timestamptz, timestamptz, text, text) to authenticated;

create or replace function project_meeting_remove(p_meeting uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; ttl text;
begin
  select project_id, title into pid, ttl from project_meeting where id = p_meeting;
  if pid is null then raise exception 'no such meeting'; end if;
  if not can_edit_project(pid) then raise exception 'not authorized to edit this project'; end if;
  delete from project_meeting where id = p_meeting;
  perform project_log(pid, 'Cancelled meeting “' || coalesce(ttl, '') || '”');
end $$;
grant execute on function project_meeting_remove(uuid) to authenticated;

commit;
