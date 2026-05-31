-- ============================================================
-- Project records — external links, meetings, and an automatic
-- history event stream.  Links-only (no file storage): PDFs,
-- Overleaf, OpenReview, Drive, repos, datasets are all URLs.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- helper: is the current user a participant on project p? ----------
create or replace function in_project(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from member m
    join project_member pm on pm.member_id = m.id
    where m.auth_user_id = auth.uid() and pm.project_id = p
  );
$$;

-- ---------- PROJECT LINK (external records) ----------
create table if not exists project_link (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references project(id) on delete cascade,
  kind       text not null default 'other',  -- proposal|overleaf|openreview|repo|dataset|paper|slides|drive|media|other
  title      text not null,
  url        text not null,
  notes      text,
  added_by   uuid references member(id),
  created_at timestamptz not null default now()
);
create index if not exists project_link_project_idx on project_link(project_id, created_at desc);

-- ---------- PROJECT MEETING ----------
create table if not exists project_meeting (
  id           uuid primary key default gen_random_uuid(),
  project_id   uuid not null references project(id) on delete cascade,
  title        text not null,
  scheduled_at timestamptz not null,
  ends_at      timestamptz,
  location     text,          -- zoom/meet/teams link or physical place
  agenda       text,
  created_by   uuid references member(id),
  created_at   timestamptz not null default now()
);
create index if not exists project_meeting_project_idx on project_meeting(project_id, scheduled_at desc);

-- ---------- PROJECT EVENT (append-only history) ----------
create table if not exists project_event (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid not null references project(id) on delete cascade,
  actor_member_id uuid references member(id),
  event_type      text not null,    -- project_created|member_joined|need_posted|application_accepted|
                                     -- stake_committed|settlement_*|status_changed|record_added|
                                     -- meeting_scheduled|note
  summary         text not null,
  meta            jsonb not null default '{}',
  created_at      timestamptz not null default now()
);
create index if not exists project_event_project_idx on project_event(project_id, created_at desc);

-- internal logger (definer => inserts bypass RLS from triggers)
create or replace function log_project_event(p uuid, etype text, summ text, m jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into project_event (project_id, actor_member_id, event_type, summary, meta)
  values (p, current_member_id(), etype, summ, coalesce(m, '{}'));
$$;

-- default added_by/created_by to the acting member when omitted
create or replace function trg_set_link_author() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  if new.added_by is null then new.added_by := current_member_id(); end if;
  return new;
end; $$;
drop trigger if exists set_link_author on project_link;
create trigger set_link_author before insert on project_link
  for each row execute function trg_set_link_author();

create or replace function trg_set_meeting_author() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  if new.created_by is null then new.created_by := current_member_id(); end if;
  return new;
end; $$;
drop trigger if exists set_meeting_author on project_meeting;
create trigger set_meeting_author before insert on project_meeting
  for each row execute function trg_set_meeting_author();

-- ============================================================
-- AUTOMATIC EVENT TRIGGERS
-- ============================================================

-- project created
create or replace function trg_event_project_created() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  perform log_project_event(new.id, 'project_created', 'Project created', '{}');
  return new;
end; $$;
drop trigger if exists ev_project_created on project;
create trigger ev_project_created after insert on project
  for each row execute function trg_event_project_created();

-- project status changed
create or replace function trg_event_project_status() returns trigger language plpgsql
  security definer set search_path = public as $$
declare oldn text; newn text;
begin
  if new.status_id is distinct from old.status_id then
    select name into oldn from project_status where id = old.status_id;
    select name into newn from project_status where id = new.status_id;
    perform log_project_event(new.id, 'status_changed',
      'Status: ' || coalesce(oldn, '—') || ' → ' || coalesce(newn, '—'),
      jsonb_build_object('from', oldn, 'to', newn));
  end if;
  return new;
end; $$;
drop trigger if exists ev_project_status on project;
create trigger ev_project_status after update on project
  for each row execute function trg_event_project_status();

-- member joined
create or replace function trg_event_member_joined() returns trigger language plpgsql
  security definer set search_path = public as $$
declare nm text; rl text;
begin
  select full_name into nm from member where id = new.member_id;
  select name into rl from project_role where id = new.project_role_id;
  perform log_project_event(new.project_id, 'member_joined',
    coalesce(nm, 'Someone') || ' joined as ' || coalesce(rl, 'member'),
    jsonb_build_object('member_id', new.member_id, 'role', rl));
  return new;
end; $$;
drop trigger if exists ev_member_joined on project_member;
create trigger ev_member_joined after insert on project_member
  for each row execute function trg_event_member_joined();

-- need posted
create or replace function trg_event_need() returns trigger language plpgsql
  security definer set search_path = public as $$
declare rl text;
begin
  select name into rl from project_role where id = new.project_role_id;
  perform log_project_event(new.project_id, 'need_posted',
    'Posted a need: ' || coalesce(rl, 'Contributor') || ' ×' || coalesce(new.headcount, 1),
    jsonb_build_object('role', rl, 'headcount', new.headcount));
  return new;
end; $$;
drop trigger if exists ev_need on open_need;
create trigger ev_need after insert on open_need
  for each row execute function trg_event_need();

-- application accepted
create or replace function trg_event_application() returns trigger language plpgsql
  security definer set search_path = public as $$
declare nm text; pid uuid;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    select full_name into nm from member where id = new.member_id;
    select project_id into pid from open_need where id = new.open_need_id;
    if pid is not null then
      perform log_project_event(pid, 'application_accepted',
        coalesce(nm, 'Applicant') || ' was accepted onto a need',
        jsonb_build_object('member_id', new.member_id));
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists ev_application on need_application;
create trigger ev_application after update on need_application
  for each row execute function trg_event_application();

-- stake committed
create or replace function trg_event_commitment() returns trigger language plpgsql
  security definer set search_path = public as $$
declare nm text;
begin
  select full_name into nm from member where id = new.member_id;
  perform log_project_event(new.project_id, 'stake_committed',
    coalesce(nm, 'Member') || ' staked ' || coalesce(new.token_amount, 0) || ' STR ('
      || replace(new.commitment_type, '_', ' ') || ')',
    jsonb_build_object('member_id', new.member_id, 'amount', new.token_amount,
                       'type', new.commitment_type));
  return new;
end; $$;
drop trigger if exists ev_commitment on stater_project_stake_commitment;
create trigger ev_commitment after insert on stater_project_stake_commitment
  for each row execute function trg_event_commitment();

-- settlement submitted / status change
create or replace function trg_event_settlement() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform log_project_event(new.project_id, 'settlement_submitted',
      'Settlement proposed for review', '{}');
  elsif new.status is distinct from old.status then
    perform log_project_event(new.project_id, 'settlement_' || new.status,
      'Settlement ' || new.status, jsonb_build_object('status', new.status));
  end if;
  return new;
end; $$;
drop trigger if exists ev_settlement on stater_settlement;
create trigger ev_settlement after insert or update on stater_settlement
  for each row execute function trg_event_settlement();

-- record (external link) added
create or replace function trg_event_link() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  perform log_project_event(new.project_id, 'record_added',
    'Added ' || new.kind || ': ' || new.title,
    jsonb_build_object('kind', new.kind, 'url', new.url));
  return new;
end; $$;
drop trigger if exists ev_link on project_link;
create trigger ev_link after insert on project_link
  for each row execute function trg_event_link();

-- meeting scheduled
create or replace function trg_event_meeting() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  perform log_project_event(new.project_id, 'meeting_scheduled',
    'Meeting: ' || new.title || ' @ ' || to_char(new.scheduled_at, 'YYYY-MM-DD HH24:MI'),
    jsonb_build_object('at', new.scheduled_at, 'location', new.location));
  return new;
end; $$;
drop trigger if exists ev_meeting on project_meeting;
create trigger ev_meeting after insert on project_meeting
  for each row execute function trg_event_meeting();

-- ============================================================
-- RLS
-- ============================================================
alter table project_link    enable row level security;
alter table project_meeting enable row level security;
alter table project_event   enable row level security;

-- community-wide read (consistent with other project-scoped tables)
drop policy if exists read_project_link on project_link;
create policy read_project_link on project_link for select to authenticated using (true);
drop policy if exists read_project_meeting on project_meeting;
create policy read_project_meeting on project_meeting for select to authenticated using (true);
drop policy if exists read_project_event on project_event;
create policy read_project_event on project_event for select to authenticated using (true);

-- participants / managers / global editors may add & edit links and meetings
drop policy if exists write_project_link on project_link;
create policy write_project_link on project_link for all to authenticated
  using (in_project(project_id) or manages_project(project_id) or has_capability('edit_any_project'))
  with check (in_project(project_id) or manages_project(project_id) or has_capability('edit_any_project'));

drop policy if exists write_project_meeting on project_meeting;
create policy write_project_meeting on project_meeting for all to authenticated
  using (in_project(project_id) or manages_project(project_id) or has_capability('edit_any_project'))
  with check (in_project(project_id) or manages_project(project_id) or has_capability('edit_any_project'));

-- members may post manual notes; all other events are written by triggers (definer)
drop policy if exists note_project_event on project_event;
create policy note_project_event on project_event for insert to authenticated
  with check (event_type = 'note' and actor_member_id = current_member_id()
              and (in_project(project_id) or manages_project(project_id)
                   or has_capability('edit_any_project')));

-- ============================================================
-- GRANTS (PostgREST) + reload
-- ============================================================
grant select on project_link, project_meeting, project_event to anon, authenticated;
grant insert, update, delete on project_link, project_meeting to authenticated;
grant insert on project_event to authenticated;
grant execute on function in_project(uuid) to authenticated;
grant execute on function log_project_event(uuid, text, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
