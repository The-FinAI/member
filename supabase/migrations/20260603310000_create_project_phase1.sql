-- ============================================================
-- Phase-1 project creation — FREE (no 50 STR leader bond) and available to a
-- working-group officer. The legacy create_project_with_leader_stake moves a
-- bond the officer doesn't have, and nothing in the new UI created projects at
-- all. This RPC:
--   * authorizes a WG officer of the target unit (or edit_any_project / manage_stater),
--   * creates the project attached to that working group,
--   * forges the intrinsic LEADER slot (new projects had none — the rebuild only
--     backfilled existing ones) and seats the creator at the standard first-author
--     writing hours, no bond,
--   * records the proposal link if given.
-- ============================================================

create or replace function create_project_phase1(
  p_name text, p_type_id uuid, p_status_id uuid, p_wg_unit uuid default null,
  p_summary text default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; lrole uuid; lslot uuid; vname text; hrs int; ym text;
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

  select id into lrole from project_role where name = 'Leader' limit 1;
  if lrole is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (pid, me, lrole) on conflict do nothing;
  end if;

  -- intrinsic leader slot, seated by the creator at the standard writing hours
  insert into project_slot (project_id, slot_kind, authorship, status, headcount)
  values (pid, 'leader', 'first', 'filled', 1) returning id into lslot;

  hrs := stater_policy_int('default_first_author_writing_hours', 20);
  ym  := to_char(now(), 'YYYY-MM');
  insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval)
  values (lslot, pid, me, ym, hrs, 0, 'ok');

  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;

  return pid;
end $$;
grant execute on function create_project_phase1(text, uuid, uuid, uuid, text, uuid, text) to authenticated;

notify pgrst, 'reload schema';
