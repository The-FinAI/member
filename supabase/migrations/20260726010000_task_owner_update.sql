-- G3 (#49 §7, approved): a task's OWNER may update their own task — but only its
-- state and note. Reassigning, renaming, regrouping or deleting still require
-- can_edit_project. Closes the gap where /my offered Start/Reopen/Done controls
-- the backend rejected ("UI offers it, backend forbids it").
create or replace function task_update(p_task uuid, p_patch jsonb)
returns task language plpgsql security definer set search_path = public as $$
declare r task; pid uuid; own uuid;
begin
  select project_id, owner_member_id into pid, own from task where id = p_task;
  if pid is null then raise exception 'no such task'; end if;

  if not can_edit_project(pid) then
    -- owner exception: the person a task is assigned to may move it along
    -- (state) and annotate it (note) — nothing else.
    if own is not null and own = current_member_id()
       and (p_patch - 'state' - 'note') = '{}'::jsonb then
      null; -- allowed
    else
      raise exception 'not allowed to edit this project';
    end if;
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

  return r;
end $$;
grant execute on function task_update(uuid,jsonb) to authenticated;
