-- F8: member.availability was completely orphaned — never read, displayed, or updated.
-- Adds member_set_availability() RPC so members and officers can set work-seeking status.
create or replace function member_set_availability(p_member uuid, p_availability text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_availability not in ('looking', 'limited', 'full') then
    raise exception 'availability must be looking, limited, or full';
  end if;
  if auth.uid() = (select auth_user_id from member where id = p_member) then
    -- member editing their own status: allowed directly
  elsif can_edit_member(p_member) then
    -- officer or admin: allowed
  else
    raise exception 'not authorized to edit this member';
  end if;
  update member set availability = p_availability where id = p_member;
end $$;
grant execute on function member_set_availability(uuid, text) to authenticated;

notify pgrst, 'reload schema';
