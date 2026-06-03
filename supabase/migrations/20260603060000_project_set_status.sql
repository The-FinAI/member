-- =====================================================================
-- Project card — direct status transitions (non-terminal)
-- ---------------------------------------------------------------------
-- Move a project through its pipeline (Proposal → Data Collecting → Work
-- in progress → Under review) and Hold/resume, directly from the card.
-- Same gate as the rest of the card (can_edit_project: leader / WG officer
-- / admin) and every change is logged to history.
--
-- Finishing is NOT allowed here — that stays the reviewed forge_project_done
-- flow (review queue → settlement). Reopening a finished project is blocked.
-- Hold stores the prior status in held_from_status_id so the UI can suggest
-- where to resume; any non-Hold target clears it.
-- Idempotent. Apply AFTER 20260603040000_project_card.sql.
-- =====================================================================

begin;

create or replace function project_set_status(p_project uuid, p_status uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cur uuid; old_name text; new_name text;
begin
  if not can_edit_project(p_project) then raise exception 'not authorized to edit this project'; end if;

  select status_id into cur from project where id = p_project;
  select name into old_name from project_status where id = cur;
  select name into new_name from project_status where id = p_status;
  if new_name is null then raise exception 'no such status'; end if;

  if new_name = 'Finished' then
    raise exception 'completion goes through Mint done (review + settlement), not a direct status change';
  end if;
  if old_name = 'Finished' then
    raise exception 'a finished project cannot be reopened here';
  end if;
  if cur is not distinct from p_status then return; end if;  -- no-op

  if new_name = 'Hold' then
    -- remember where we held from (unless already on Hold)
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

commit;
