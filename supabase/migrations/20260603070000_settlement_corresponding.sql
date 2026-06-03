-- =====================================================================
-- Settlement — corresponding-author flag
-- ---------------------------------------------------------------------
-- The settlement form needs to record a corresponding author (通讯作者) in
-- addition to author order (first author = 一作). Adds is_corresponding to
-- stater_settlement_item and threads it through submit_settlement. Existing
-- signature is unchanged (items jsonb just carries one more optional key).
-- Idempotent. Apply AFTER 20260602195905_settlement_finished_guard.sql.
-- =====================================================================

begin;

alter table stater_settlement_item
  add column if not exists is_corresponding boolean not null default false;

create or replace function submit_settlement(p uuid, notes text, items jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare sid uuid; hrs integer;
begin
  if not manages_project(p) and not has_capability('edit_any_project') then raise exception 'not authorized'; end if;
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
    (settlement_id, member_id, role, final_payout_weight, is_author, author_order, is_corresponding, notes)
  select sid,
         (i->>'member_id')::uuid,
         i->>'role',
         coalesce((i->>'final_payout_weight')::numeric, 0),
         coalesce((i->>'is_author')::boolean, true),
         (i->>'author_order')::int,
         coalesce((i->>'is_corresponding')::boolean, false),
         i->>'notes'
  from jsonb_array_elements(items) i;
  return sid;
end; $$;
grant execute on function submit_settlement(uuid, text, jsonb) to authenticated;

commit;
