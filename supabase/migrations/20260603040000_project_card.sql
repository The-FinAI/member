-- =====================================================================
-- Project card — editable details, media links, meetings & history
-- ---------------------------------------------------------------------
-- Turns the project quick-view drawer into the editable project card.
-- All writes go through security-definer RPCs gated by can_edit_project:
--   • the project LEADER (a project_member with a can_manage role)
--   • the project's WORKING-GROUP OFFICER (is_unit_officer of org_unit_id)
--   • an ADMIN (edit_any_project / manage_members capability)
-- Every mutation logs a project_event note, so history is automatic.
--
-- Assumes the earlier project_records tables already exist in the DB:
--   project_link    (id, project_id, kind, title, url, notes, added_by, created_at)
--   project_meeting (id, project_id, title, scheduled_at, ends_at, location,
--                    agenda, created_by, created_at)
--   project_event   (id, project_id, event_type, summary, actor_member_id, created_at)
-- Idempotent: create or replace. Apply to the live DB.
-- =====================================================================

begin;

-- ---------- permission predicate ----------
create or replace function can_edit_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    has_capability('edit_any_project')
    or has_capability('manage_members')
    or exists (
      select 1 from project p where p.id = p_project
        and p.org_unit_id is not null and is_unit_officer(p.org_unit_id)
    )
    or exists (
      select 1 from project_member pm
      join project_role pr on pr.id = pm.project_role_id
      where pm.project_id = p_project
        and pm.member_id = current_member_id()
        and pr.can_manage
    );
$$;
grant execute on function can_edit_project(uuid) to authenticated;

-- ---------- internal: history log helper ----------
create or replace function project_log(p_project uuid, p_summary text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into project_event (project_id, actor_member_id, event_type, summary)
  values (p_project, current_member_id(), 'note', p_summary);
end $$;

-- ---------- editable fields ----------
create or replace function project_rename(p_project uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $$
declare old text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name cannot be empty'; end if;
  select name into old from project where id = p_project;
  if old is distinct from trim(p_name) then
    update project set name = trim(p_name) where id = p_project;
    perform project_log(p_project, format('Renamed “%s” → “%s”', old, trim(p_name)));
  end if;
end $$;
grant execute on function project_rename(uuid, text) to authenticated;

create or replace function project_set_summary(p_project uuid, p_summary text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  update project set summary = nullif(trim(coalesce(p_summary, '')), '') where id = p_project;
  perform project_log(p_project, 'Updated the summary');
end $$;
grant execute on function project_set_summary(uuid, text) to authenticated;

create or replace function project_set_venue(p_project uuid, p_venue uuid)
returns void language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if p_venue is not null and not exists (select 1 from venue where id = p_venue) then
    raise exception 'no such venue';
  end if;
  update project set venue_id = p_venue where id = p_project;
  select name into nm from venue where id = p_venue;
  perform project_log(p_project, 'Target venue set to ' || coalesce(nm, 'none'));
end $$;
grant execute on function project_set_venue(uuid, uuid) to authenticated;

create or replace function project_set_org_unit(p_project uuid, p_unit uuid)
returns void language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if p_unit is not null and not exists (select 1 from org_unit where id = p_unit and kind = 'working_group') then
    raise exception 'projects attach to a working group';
  end if;
  update project set org_unit_id = p_unit where id = p_project;
  select name into nm from org_unit where id = p_unit;
  perform project_log(p_project, 'Working group set to ' || coalesce(nm, 'unattributed'));
end $$;
grant execute on function project_set_org_unit(uuid, uuid) to authenticated;

-- ---------- media links (multiple per project) ----------
create or replace function project_link_add(p_project uuid, p_kind text, p_title text, p_url text, p_notes text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare lid uuid; u text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if coalesce(trim(p_url), '') = '' then raise exception 'a URL is required'; end if;
  u := trim(p_url);
  if u !~* '^https?://' then u := 'https://' || u; end if;
  insert into project_link (project_id, kind, title, url, notes, added_by)
  values (p_project, coalesce(nullif(trim(p_kind), ''), 'other'),
          nullif(trim(coalesce(p_title, '')), ''), u,
          nullif(trim(coalesce(p_notes, '')), ''), current_member_id())
  returning id into lid;
  perform project_log(p_project, 'Added a ' || coalesce(nullif(trim(p_kind), ''), 'link') || ' link');
  return lid;
end $$;
grant execute on function project_link_add(uuid, text, text, text, text) to authenticated;

create or replace function project_link_remove(p_link uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; k text;
begin
  select project_id, kind into pid, k from project_link where id = p_link;
  if pid is null then raise exception 'no such link'; end if;
  if not can_edit_project(pid) then raise exception 'not authorized to edit this project'; end if;
  delete from project_link where id = p_link;
  perform project_log(pid, 'Removed a ' || coalesce(k, 'link') || ' link');
end $$;
grant execute on function project_link_remove(uuid) to authenticated;

-- ---------- free-form history note ----------
create or replace function project_note(p_project uuid, p_text text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if coalesce(trim(p_text), '') = '' then raise exception 'note cannot be empty'; end if;
  perform project_log(p_project, trim(p_text));
end $$;
grant execute on function project_note(uuid, text) to authenticated;

-- ---------- meetings (with recurrence) ----------
alter table project_meeting
  add column if not exists recurrence text not null default 'none';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'project_meeting_recurrence_chk') then
    alter table project_meeting
      add constraint project_meeting_recurrence_chk
      check (recurrence in ('none', 'weekly', 'biweekly', 'monthly'));
  end if;
end $$;

create or replace function project_meeting_add(
  p_project uuid, p_title text, p_scheduled_at timestamptz,
  p_ends_at timestamptz default null, p_location text default null,
  p_agenda text default null, p_recurrence text default 'none')
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid; rec text := coalesce(nullif(trim(p_recurrence), ''), 'none');
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;
  if coalesce(trim(p_title), '') = '' then raise exception 'meeting title required'; end if;
  if p_scheduled_at is null then raise exception 'meeting time required'; end if;
  if rec not in ('none', 'weekly', 'biweekly', 'monthly') then raise exception 'invalid recurrence'; end if;
  insert into project_meeting (project_id, title, scheduled_at, ends_at, location, agenda, recurrence, created_by)
  values (p_project, trim(p_title), p_scheduled_at, p_ends_at,
          nullif(trim(coalesce(p_location, '')), ''), nullif(trim(coalesce(p_agenda, '')), ''),
          rec, current_member_id())
  returning id into mid;
  perform project_log(p_project,
    case when rec = 'none' then 'Scheduled meeting “' || trim(p_title) || '”'
         else 'Scheduled ' || rec || ' meeting “' || trim(p_title) || '”' end);
  return mid;
end $$;
grant execute on function project_meeting_add(uuid, text, timestamptz, timestamptz, text, text, text) to authenticated;

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
