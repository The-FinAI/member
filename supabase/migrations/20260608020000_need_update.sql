-- ============================================================
-- GitHub #9 — a project leader/officer can EDIT an open need in place
-- (change its kind, skill, level, resource type, capacity/hours, headcount)
-- instead of deleting and re-posting. Mirrors need_post's validation and
-- permission gate. Refuses if anyone is already committed to the need —
-- those must be released first so accruals stay consistent.
-- ============================================================
create or replace function need_update(
  p_slot uuid, p_kind text, p_skill uuid, p_level text,
  p_resource_type uuid, p_capacity numeric, p_headcount int)
returns project_slot language plpgsql security definer set search_path = public as $$
declare r project_slot; v_proj uuid; v_committed int;
begin
  select project_id into v_proj from project_slot where id = p_slot;
  if v_proj is null then raise exception 'no such need'; end if;
  if not can_edit_project(v_proj) then raise exception 'not allowed to edit this project'; end if;
  if p_kind not in ('work_labor','work_resource') then raise exception 'invalid need kind'; end if;
  if p_kind = 'work_labor'    and p_skill is null then raise exception 'a skill is required'; end if;
  if p_kind = 'work_resource' and p_resource_type is null then raise exception 'a resource type is required'; end if;
  if p_level is not null and p_level not in ('learning','independent','lead') then
    raise exception 'invalid level'; end if;

  select count(*) into v_committed from work_commitment where slot_id = p_slot;
  if v_committed > 0 then
    raise exception 'this need already has people on it — release them before changing it';
  end if;

  update project_slot set
    slot_kind        = p_kind,
    skill_id         = case when p_kind = 'work_labor'    then p_skill end,
    desired_level    = case when p_kind = 'work_labor'    then p_level end,
    resource_type_id = case when p_kind = 'work_resource' then p_resource_type end,
    quota            = p_capacity,
    headcount        = coalesce(p_headcount, 1)
   where id = p_slot
  returning * into r;

  perform project_log(v_proj, 'Need updated'
    || coalesce(' · ' || (select name from skill where id = p_skill), '')
    || coalesce(' · ' || (select name from resource_type where id = p_resource_type), ''));
  return r;
end $$;
grant execute on function need_update(uuid,text,uuid,text,uuid,numeric,int) to authenticated;

notify pgrst, 'reload schema';
