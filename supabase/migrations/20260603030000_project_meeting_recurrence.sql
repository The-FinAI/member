-- =====================================================================
-- Project meetings — recurrence (regular meetings)
-- ---------------------------------------------------------------------
-- A meeting can now repeat on a cadence (weekly / biweekly / monthly) or
-- stay one-off ('none'). The row describes the series, anchored at
-- scheduled_at (e.g. "Weekly · Mon 10:00"); we don't materialise每次 occurrence.
-- Idempotent. Apply AFTER 20260603020000_project_meetings_rpc.sql.
-- =====================================================================

begin;

alter table project_meeting
  add column if not exists recurrence text not null default 'none';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'project_meeting_recurrence_chk') then
    alter table project_meeting
      add constraint project_meeting_recurrence_chk
      check (recurrence in ('none', 'weekly', 'biweekly', 'monthly'));
  end if;
end $$;

-- replace the add RPC with a recurrence-aware signature
drop function if exists project_meeting_add(uuid, text, timestamptz, timestamptz, text, text);

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

commit;
