-- A seat's author role should be editable after creation (openings and seated
-- authors alike — the role lives on the slot). Narrow update, v0.3 gate.
create or replace function slot_set_role(p_slot uuid, p_authorship text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_authorship not in ('first','co','last_candidate','normal','corresponding','last') then
    raise exception 'invalid authorship'; end if;
  if not exists (select 1 from project_slot where id = p_slot) then raise exception 'no such need'; end if;
  update project_slot set authorship = p_authorship where id = p_slot;
end $$;
grant execute on function slot_set_role(uuid, text) to authenticated;

notify pgrst, 'reload schema';
