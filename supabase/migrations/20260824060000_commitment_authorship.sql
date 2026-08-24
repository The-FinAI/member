-- A SEATED member's author role belongs to the person, not the slot: slots
-- can be shared (headcount>1), members can hold several commitments (7/49
-- are slot-less legacy rows), and the leader slot's authorship is the
-- opening's advert. Role edits were silently lost in those shapes. The role
-- now lives on work_commitment; slot.authorship remains the opening's label
-- and the display fallback.
alter table work_commitment add column if not exists authorship text
  check (authorship is null or authorship in ('first','co','last_candidate','normal','corresponding','last'));

create or replace function seat_set_role(p_project uuid, p_member uuid, p_authorship text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_authorship not in ('first','co','last_candidate','normal','corresponding','last') then
    raise exception 'invalid authorship'; end if;
  if not exists (select 1 from work_commitment
                  where project_id = p_project and member_id = p_member) then
    raise exception 'this member has no commitment on the project';
  end if;
  update work_commitment set authorship = p_authorship
   where project_id = p_project and member_id = p_member;
end $$;
grant execute on function seat_set_role(uuid, uuid, text) to authenticated;

notify pgrst, 'reload schema';
