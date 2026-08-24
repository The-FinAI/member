-- Caught by the CI schema smoke on its first green path: slot_close wrote
-- status='cancelled' but project_slot_status_check allows open|filled|closed.
-- Closing an opening on prod therefore 400'd. Verbatim body, legal value.
create or replace function slot_close(p_slot uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s project_slot; filled int;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if not (can_edit_project(s.project_id) or has_capability('edit_any_project')) then
    raise exception 'not allowed to change this need';
  end if;
  select count(distinct member_id) into filled from work_commitment where slot_id = p_slot;
  if filled > 0 then raise exception 'this need has people on it — remove them first'; end if;
  update project_slot set status = 'closed' where id = p_slot;
end $$;

notify pgrst, 'reload schema';
