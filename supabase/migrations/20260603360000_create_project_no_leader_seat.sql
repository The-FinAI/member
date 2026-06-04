-- ============================================================
-- Project creation is JUST creation: free (no bond) and it does NOT seat the
-- creator as leader/first author. It creates the project + an OPEN leader slot
-- (first-author seat), left for someone to claim or be seated into later.
-- (Supersedes the earlier create_project_phase1 that auto-seated the creator.)
-- ============================================================

create or replace function create_project_phase1(
  p_name text, p_type_id uuid, p_status_id uuid, p_wg_unit uuid default null,
  p_summary text default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'project name required'; end if;
  if p_wg_unit is not null
     and not (is_unit_officer(p_wg_unit) or has_capability('edit_any_project') or has_capability('manage_stater')) then
    raise exception 'only a working-group officer can create a project for this unit';
  end if;

  vname := (select name from venue where id = p_venue_id);
  insert into project (name, type_id, status_id, org_unit_id, target_venue, venue_id, summary)
  values (trim(p_name), p_type_id, p_status_id, p_wg_unit, vname, p_venue_id, p_summary)
  returning id into pid;
  perform stater_project_acc(pid);  -- ensure the escrow account exists (trigger)

  -- intrinsic leader (first-author) slot, left OPEN — no creator seating
  insert into project_slot (project_id, slot_kind, authorship, status, headcount)
  values (pid, 'leader', 'first', 'open', 1);

  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;

  return pid;
end $$;
grant execute on function create_project_phase1(text, uuid, uuid, uuid, text, uuid, text) to authenticated;

notify pgrst, 'reload schema';
