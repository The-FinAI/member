-- ① project_set_status: verbatim from 20260603060000 minus two v0.2 blocks —
--   the market's stage dropdown legitimately sets Finished (outcome+archive
--   flow) and reopens from it (the dropdown IS the reversal path).
-- ② drop the pre-market forge_need(jsonb) overload that migration
--   20260821010000 failed to remove (its drop listed the wrong signature),
--   so only the authorship version remains.

create or replace function project_set_status(p_project uuid, p_status uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cur uuid; old_name text; new_name text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;

  select status_id into cur from project where id = p_project;
  select name into old_name from project_status where id = cur;
  select name into new_name from project_status where id = p_status;
  if new_name is null then raise exception 'no such status'; end if;
  if cur is not distinct from p_status then return; end if;  -- no-op

  if new_name = 'Hold' then
    update project
      set held_from_status_id = case when old_name = 'Hold' then held_from_status_id else status_id end,
          status_id = p_status
      where id = p_project;
  else
    update project set status_id = p_status, held_from_status_id = null where id = p_project;
  end if;

  perform project_log(p_project, format('Status: %s → %s', coalesce(old_name, '—'), new_name));
end $$;
grant execute on function project_set_status(uuid, uuid) to authenticated;

drop function if exists forge_need(uuid, text, guild_level, uuid, uuid, numeric, integer, jsonb);

notify pgrst, 'reload schema';
