-- =====================================================================
-- BUILD PLAN P5 — social spine: notifications + assignment-as-event
-- PRD-final §5/§10 · build-plan Phase 5
--
--   * notification — the async inbox (a person is told what touched them).
--   * notify() — helper to drop a notification.
--   * work_commitment.state — proposal state for P2 (proposed→active); P1
--     assigns ACTIVE (officer proxy) but the assignee is NOTIFIED — no silent
--     conscription.
--   * assign / task_update re-issued to NOTIFY the person on assignment.
-- Idempotent.
-- =====================================================================

begin;

create table if not exists notification (
  id                  uuid primary key default gen_random_uuid(),
  recipient_member_id uuid not null references member (id) on delete cascade,
  kind                text not null,
  title               text not null,
  body                text,
  link                text,
  read_at             timestamptz,
  created_at          timestamptz not null default now()
);
create index if not exists notification_recipient_idx
  on notification (recipient_member_id, read_at, created_at desc);

alter table notification enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='notification' and policyname='read_own_notification') then
    create policy read_own_notification on notification for select to authenticated
      using (recipient_member_id = current_member_id());
  end if;
end $$;
grant select on notification to authenticated;

-- assignment proposal state (P2 accept/decline; P1 = active on assign)
alter table work_commitment add column if not exists state text not null default 'active'
  check (state in ('proposed','active','declined'));

create or replace function notify(
  p_recipient uuid, p_kind text, p_title text, p_body text default null, p_link text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_recipient is null then return; end if;
  insert into notification (recipient_member_id, kind, title, body, link)
  values (p_recipient, p_kind, p_title, p_body, p_link);
end $$;
grant execute on function notify(uuid,text,text,text,text) to authenticated;

create or replace function notification_read(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update notification set read_at = now()
   where id = p_id and recipient_member_id = current_member_id() and read_at is null;
end $$;
grant execute on function notification_read(uuid) to authenticated;

create or replace function notification_read_all()
returns void language plpgsql security definer set search_path = public as $$
begin
  update notification set read_at = now()
   where recipient_member_id = current_member_id() and read_at is null;
end $$;
grant execute on function notification_read_all() to authenticated;

-- ---------- re-issue task_update: notify on owner assignment ----------
create or replace function task_update(p_task uuid, p_patch jsonb)
returns task language plpgsql security definer set search_path = public as $$
declare r task; pid uuid; pname text;
begin
  select project_id into pid from task where id = p_task;
  if pid is null then raise exception 'no such task'; end if;
  if not can_edit_project(pid) then raise exception 'not allowed to edit this project'; end if;

  update task set
    name            = case when p_patch ? 'name'  then coalesce(nullif(btrim(p_patch->>'name'),''), name) else name end,
    grp             = case when p_patch ? 'grp'   then nullif(btrim(p_patch->>'grp'),'') else grp end,
    skill_id        = case when p_patch ? 'skill_id' then (p_patch->>'skill_id')::uuid else skill_id end,
    owner_member_id = case when p_patch ? 'owner_member_id' then (p_patch->>'owner_member_id')::uuid else owner_member_id end,
    state           = case when p_patch ? 'state' then p_patch->>'state' else state end,
    note            = case when p_patch ? 'note'  then nullif(btrim(p_patch->>'note'),'') else note end,
    sort            = case when p_patch ? 'sort'  then (p_patch->>'sort')::double precision else sort end,
    updated_at      = now()
  where id = p_task
  returning * into r;

  if p_patch ? 'owner_member_id' and r.owner_member_id is not null then
    select name into pname from project where id = pid;
    perform notify(r.owner_member_id, 'task_assigned',
      'You were given a task', r.name || ' · ' || coalesce(pname,''), '/projects/' || pid);
    perform project_log(pid, 'Task "' || r.name || '" owner set to ' ||
      coalesce((select full_name from member where id = r.owner_member_id), 'open'));
  end if;
  return r;
end $$;
grant execute on function task_update(uuid,jsonb) to authenticated;

-- ---------- re-issue assign: notify the assignee ----------
create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; res uuid; ym text := to_char(now(), 'YYYY-MM'); freeh numeric;
        wcid uuid; pname text; what text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('manage_members') or manages_card(p_member)) then
    raise exception 'not allowed to assign';
  end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'amount must be greater than 0'; end if;

  if s.slot_kind = 'work_resource' then
    select r.id into res from resource r
      where r.holder_member_id = p_member and r.type_id = s.resource_type_id and r.scope = 'member' limit 1;
    if res is null then raise exception 'this person holds no resource of that type'; end if;
    freeh := resource_free(res, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over quota: only % left this month', freeh; end if;
    what := coalesce((select name from resource_type where id = s.resource_type_id), 'a resource');
  else
    select r.id into res from resource r join resource_type rt on rt.id = r.type_id
      where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
    freeh := member_free_hours(p_member, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over capacity: only % h free this month', freeh; end if;
    what := coalesce((select name from skill where id = s.skill_id), 'work');
  end if;

  wcid := work_seat(p_slot, p_member, res, ym, p_hours, p_member);
  select name into pname from project where id = s.project_id;
  perform notify(p_member, 'assigned',
    'You were assigned to a project', pname || ' · ' || what || ' · ' || p_hours,
    '/projects/' || s.project_id);
  return wcid;
end $$;
grant execute on function assign(uuid,uuid,numeric) to authenticated;

commit;
