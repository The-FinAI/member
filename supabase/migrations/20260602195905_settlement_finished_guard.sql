-- Settlement may only be submitted once a project has reached Finished.
-- This is the backend guard mirroring the UI gate (the settlement builder is
-- hidden until Finished). Without it, a manager could still call the RPC
-- directly from a non-Finished project.

create or replace function submit_settlement(p uuid, notes text, items jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid; hrs integer;
begin
  if not manages_project(p) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
  -- settlement can only be drafted once the project has reached Finished
  if not exists (
    select 1 from project pr
    join project_status ps on ps.id = pr.status_id
    where pr.id = p and ps.name = 'Finished'
  ) then
    raise exception 'settlement can only be submitted for a Finished project';
  end if;
  hrs := stater_policy_int('review_window_hours', 72);
  insert into stater_settlement (project_id, submitted_by, status, meeting_notes, review_window_ends_at)
  values (p, current_member_id(), 'submitted', notes, now() + (hrs || ' hours')::interval)
  returning id into sid;
  insert into stater_settlement_item
    (settlement_id, member_id, role, final_payout_weight, is_author, author_order, notes)
  select sid,
         (i->>'member_id')::uuid,
         i->>'role',
         coalesce((i->>'final_payout_weight')::numeric, 0),
         coalesce((i->>'is_author')::boolean, true),
         (i->>'author_order')::int,
         i->>'notes'
  from jsonb_array_elements(items) i;
  return sid;
end; $$;
grant execute on function submit_settlement(uuid, text, jsonb) to authenticated;

-- Revert any settlement that was submitted while its project was NOT Finished.
-- Only pre-payout states (submitted / under_review) are touched, and deleting
-- them (items cascade) lets the manager re-draft cleanly once Finished.
-- Approved/paid settlements move real STR through the ledger and are
-- intentionally left untouched here.
delete from stater_settlement s
 using project pr
 left join project_status ps on ps.id = pr.status_id
 where pr.id = s.project_id
   and s.status in ('submitted', 'under_review')
   and (ps.name is distinct from 'Finished');
