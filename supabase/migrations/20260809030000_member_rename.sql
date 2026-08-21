-- F7: member.full_name was not editable after creation — no RPC existed.
-- Adds member_rename() so officers/admins can correct a member's name.
create or replace function member_rename(p_member uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_member(p_member) then
    raise exception 'not authorized to edit this member';
  end if;
  if trim(p_name) = '' then raise exception 'name cannot be empty'; end if;
  update member set full_name = trim(p_name) where id = p_member;
end $$;
grant execute on function member_rename(uuid, text) to authenticated;

notify pgrst, 'reload schema';
