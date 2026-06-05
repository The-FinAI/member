-- ============================================================
-- Let a member-manager correct a member's email (e.g. a typo in an officer
-- invite that blocks login). Normalised lower/trim; unique-email errors surface.
-- ============================================================

create or replace function set_member_email(p_member uuid, p_email text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_members') then
    raise exception 'requires manage_members';
  end if;
  if coalesce(btrim(p_email), '') = '' then raise exception 'email required'; end if;
  update member set email = lower(btrim(p_email)) where id = p_member;
  if not found then raise exception 'no such member'; end if;
end $$;
grant execute on function set_member_email(uuid, text) to authenticated;

notify pgrst, 'reload schema';
