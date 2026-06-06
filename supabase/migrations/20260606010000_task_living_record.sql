-- =====================================================================
-- BUILD PLAN P0 — The living record (Task model + project record fields)
-- PRD-final §1/§4.1 · build-plan.md Phase 0
--
-- Adds the EXECUTION primitive `task` (name · work-type · owner · state ·
-- note, optionally grouped) — the thing that replaces a WG's Google Doc —
-- plus project record fields (emoji · code · tag · body).
--
-- Writes go through SECURITY DEFINER RPCs guarded by can_edit_project();
-- reads are RLS-open to authenticated members. Idempotent.
-- =====================================================================

begin;

-- ---------- project record fields ----------
alter table project add column if not exists emoji text;
alter table project add column if not exists code  text;  -- e.g. ml-Tagging
alter table project add column if not exists tag   text;  -- modality / language
alter table project add column if not exists body  text;  -- rich free-form record

-- ---------- task: the execution unit ----------
create table if not exists task (
  id               uuid primary key default gen_random_uuid(),
  project_id       uuid not null references project (id) on delete cascade,
  grp              text,                         -- optional group, e.g. "XBRL Coverage"
  name             text not null,
  skill_id         uuid references skill (id) on delete set null,  -- = work-type
  owner_member_id  uuid references member (id) on delete set null, -- null = open / TBD
  state            text not null default 'open'
                     check (state in ('open','doing','done',          -- normal tasks
                                      'confirmed','checking','potential')), -- coverage groups
  note             text,
  sort             double precision not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists task_project_idx on task (project_id);
create index if not exists task_owner_idx   on task (owner_member_id) where owner_member_id is not null;
create index if not exists task_sort_idx     on task (project_id, sort);

alter table task enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='task' and policyname='read_task') then
    create policy read_task on task for select to authenticated using (true);
  end if;
end $$;
grant select on task to authenticated;

-- =====================================================================
-- RPCs — all guarded by can_edit_project(project)
-- =====================================================================

-- add a task (sort = end of the project's list)
create or replace function task_add(
  p_project uuid,
  p_name    text,
  p_grp     text default null,
  p_skill   uuid default null,
  p_owner   uuid default null,
  p_state   text default 'open',
  p_note    text default null
) returns task language plpgsql security definer set search_path = public as $$
declare r task;
begin
  if not can_edit_project(p_project) then
    raise exception 'not allowed to edit this project';
  end if;
  if coalesce(btrim(p_name),'') = '' then
    raise exception 'task name is required';
  end if;
  insert into task (project_id, grp, name, skill_id, owner_member_id, state, note, sort)
  values (p_project, nullif(btrim(p_grp),''), btrim(p_name), p_skill, p_owner,
          coalesce(nullif(p_state,''),'open'),
          nullif(btrim(p_note),''),
          coalesce((select max(sort) from task where project_id = p_project), 0) + 1)
  returning * into r;
  perform project_log(p_project, 'Task added: ' || r.name);
  return r;
end $$;
grant execute on function task_add(uuid,text,text,uuid,uuid,text,text) to authenticated;

-- patch a task: apply only the keys present in p_patch
--   keys: name, grp, skill_id, owner_member_id, state, note, sort
--   (key present with null value = clear; key absent = unchanged)
create or replace function task_update(p_task uuid, p_patch jsonb)
returns task language plpgsql security definer set search_path = public as $$
declare r task; pid uuid;
begin
  select project_id into pid from task where id = p_task;
  if pid is null then raise exception 'no such task'; end if;
  if not can_edit_project(pid) then
    raise exception 'not allowed to edit this project';
  end if;

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

  if p_patch ? 'owner_member_id' then
    perform project_log(pid, 'Task "' || r.name || '" owner set to ' ||
      coalesce((select full_name from member where id = r.owner_member_id), 'open'));
  end if;
  return r;
end $$;
grant execute on function task_update(uuid,jsonb) to authenticated;

-- remove a task
create or replace function task_remove(p_task uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; nm text;
begin
  select project_id, name into pid, nm from task where id = p_task;
  if pid is null then return; end if;
  if not can_edit_project(pid) then
    raise exception 'not allowed to edit this project';
  end if;
  delete from task where id = p_task;
  perform project_log(pid, 'Task removed: ' || nm);
end $$;
grant execute on function task_remove(uuid) to authenticated;

-- reorder: place a task at a new sort key (caller computes between-neighbours)
create or replace function task_reorder(p_task uuid, p_sort double precision)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select project_id into pid from task where id = p_task;
  if pid is null then raise exception 'no such task'; end if;
  if not can_edit_project(pid) then
    raise exception 'not allowed to edit this project';
  end if;
  update task set sort = p_sort, updated_at = now() where id = p_task;
end $$;
grant execute on function task_reorder(uuid,double precision) to authenticated;

-- set project record meta (emoji · code · tag · body)
create or replace function project_set_meta(
  p_project uuid,
  p_emoji   text default null,
  p_code    text default null,
  p_tag     text default null,
  p_body    text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_project(p_project) then
    raise exception 'not allowed to edit this project';
  end if;
  update project set
    emoji = case when p_emoji is not null then nullif(btrim(p_emoji),'') else emoji end,
    code  = case when p_code  is not null then nullif(btrim(p_code),'')  else code  end,
    tag   = case when p_tag   is not null then nullif(btrim(p_tag),'')   else tag   end,
    body  = case when p_body  is not null then nullif(btrim(p_body),'')  else body  end
  where id = p_project;
end $$;
grant execute on function project_set_meta(uuid,text,text,text,text) to authenticated;

commit;
