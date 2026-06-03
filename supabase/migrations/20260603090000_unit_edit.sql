-- =====================================================================
-- Org unit — editable name & description (officers / admins)
-- ---------------------------------------------------------------------
-- Lets a unit's officer (is_unit_officer) or an admin (manage_members /
-- manage_taxonomy) rename it and edit its description right from the
-- community quick-view drawer. Unit metadata isn't value-minting, so this
-- is a direct edit (no forge review). can_edit_unit lets the UI show the
-- inline ✎ affordances; the mutating RPCs enforce the same rule.
-- Idempotent. Apply to the live DB.
-- =====================================================================

begin;

create or replace function can_edit_unit(p_unit uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select has_capability('manage_members')
      or has_capability('manage_taxonomy')
      or is_unit_officer(p_unit);
$$;
grant execute on function can_edit_unit(uuid) to authenticated;

create or replace function unit_rename(p_unit uuid, p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_unit(p_unit) then raise exception 'not authorized to edit this unit'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name cannot be empty'; end if;
  update org_unit set name = trim(p_name) where id = p_unit;
end $$;
grant execute on function unit_rename(uuid, text) to authenticated;

create or replace function unit_set_description(p_unit uuid, p_desc text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_unit(p_unit) then raise exception 'not authorized to edit this unit'; end if;
  update org_unit set description = nullif(trim(coalesce(p_desc, '')), '') where id = p_unit;
end $$;
grant execute on function unit_set_description(uuid, text) to authenticated;

commit;
