-- Changing a SEATED author's role must work for legacy commitments too:
-- 7/49 live work_commitment rows predate slots (slot_id null), so the role
-- has nowhere to live. seat_set_role updates the slot when there is one and
-- otherwise creates a filled labor slot and attaches the member's commitments.
create or replace function seat_set_role(p_project uuid, p_member uuid, p_authorship text)
returns void language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_authorship not in ('first','co','last_candidate','normal','corresponding','last') then
    raise exception 'invalid authorship'; end if;

  select slot_id into sid from work_commitment
   where project_id = p_project and member_id = p_member and slot_id is not null
   limit 1;

  if sid is not null then
    update project_slot set authorship = p_authorship where id = sid;
  else
    if not exists (select 1 from work_commitment
                    where project_id = p_project and member_id = p_member) then
      raise exception 'this member has no commitment on the project';
    end if;
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values (p_project, 'work_labor', p_authorship, 'filled', 1)
    returning id into sid;
    update work_commitment set slot_id = sid
     where project_id = p_project and member_id = p_member and slot_id is null;
  end if;
end $$;
grant execute on function seat_set_role(uuid, uuid, text) to authenticated;

notify pgrst, 'reload schema';
