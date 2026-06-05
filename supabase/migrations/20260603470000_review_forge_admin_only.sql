-- ============================================================
-- The forge queue is admin-only to view AND approve (#7 follow-up). Revert the
-- officer-broadening of review_forge: approving badges/resources/needs requires
-- the proper capability again (review_skillcard / manage_resources /
-- edit_any_project / manage_stater / manage_members). Officers forge & match;
-- admins approve.
-- ============================================================

create or replace function review_forge(p_request uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r forge_request; reviewer uuid; fin uuid;
begin
  select * into r from forge_request where id = p_request;
  if r.id is null then raise exception 'no such forge request'; end if;
  if r.status <> 'submitted' then raise exception 'request is not open for review'; end if;
  reviewer := current_member_id();

  if r.target_type = 'badge' then
    if not (has_capability('review_skillcard') or has_capability('manage_members')) then
      raise exception 'requires review_skillcard'; end if;
  elsif r.target_type = 'resource' then
    if not has_capability('manage_resources') then raise exception 'requires manage_resources'; end if;
  elsif r.target_type in ('need','project_done') then
    if not (has_capability('edit_any_project') or has_capability('manage_stater')) then
      raise exception 'requires project/economy authority'; end if;
  elsif r.target_type = 'member_card' then
    if not has_capability('manage_members') then raise exception 'requires manage_members'; end if;
  else
    if not has_capability('manage_members') then raise exception 'not authorized'; end if;
  end if;

  if p_approve then
    if r.target_type = 'badge' then
      insert into badge (member_id, skill_id, level, forge_request_id)
      values ((r.payload->>'member_id')::uuid, (r.payload->>'skill_id')::uuid,
              (r.payload->>'target_level')::guild_level, r.id)
      on conflict (member_id, skill_id) do update
        set level = greatest(badge.level, excluded.level), forge_request_id = excluded.forge_request_id;

    elsif r.target_type = 'resource' then
      update resource set approval_status = 'approved', forge_request_id = r.id where id = r.target_id;

    elsif r.target_type = 'need' then
      insert into project_slot
        (project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, authorship, status, created_via, requirements)
      values ((r.payload->>'project_id')::uuid, r.payload->>'slot_kind',
              nullif(r.payload->>'req_access','')::guild_level,
              nullif(r.payload->>'skill_id','')::uuid,
              nullif(r.payload->>'resource_type_id','')::uuid,
              nullif(r.payload->>'quota','')::numeric,
              coalesce(nullif(r.payload->>'headcount','')::int, 1),
              case when r.payload->>'slot_kind' = 'work_resource' then 'last_candidate' else 'co' end,
              'open', r.id,
              case when jsonb_array_length(coalesce(r.payload->'requirements','[]'::jsonb)) > 0
                   then r.payload->'requirements' else null end)
      returning id into r.target_id;

    elsif r.target_type = 'project_done' then
      select id into fin from project_status where name = 'Finished' limit 1;
      if fin is not null then update project set status_id = fin where id = r.target_id; end if;
    end if;
  else
    if r.fee > 0 and r.target_id is not null then
      perform stater_move(stater_treasury(), stater_member_acc(r.target_id), r.fee, 'forge_refund',
                          'forge request rejected — fee refunded', null, null, null, reviewer);
    end if;
  end if;

  update forge_request
     set status = case when p_approve then 'approved' else 'rejected' end,
         target_id = r.target_id,
         reviewed_by = reviewer,
         review_note = nullif(btrim(coalesce(p_note,'')), ''),
         settled_at = now()
   where id = p_request;
end $$;
grant execute on function review_forge(uuid, boolean, text) to authenticated;

notify pgrst, 'reload schema';
