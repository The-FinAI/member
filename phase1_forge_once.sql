-- =====================================================================
-- Phase 1: a person is forged into a card exactly ONCE.
--
-- In Phase 1 only officers are in the system; ordinary researchers are
-- not invited yet. An officer turns each person who works under them
-- into a member-card (identity + skills + resources) and claims the
-- chapter's projects. The one rule we enforce in the database: the same
-- person must not be minted twice. Email is the claim key — it is how
-- the real person later signs up and inherits the card — so we dedupe on
-- it. If a member (card OR a real invited account) already exists for an
-- email, forging is refused with a clear message.
--
-- Builds on card_unify.sql. forge_card keeps its signature; only the
-- duplicate guard is added. Resources are attached frontend-side after
-- the card is created (RLS manages_card already permits it). Idempotent.
-- =====================================================================

create or replace function forge_card(p_full_name text, p_email text, p_unit uuid,
                                      p_affiliation text default null, p_items jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; new_id uuid; bid uuid := gen_random_uuid(); it record; norm_email text;
begin
  if not (is_chapter_officer(p_unit) or has_capability('manage_members')) then
    raise exception 'only a chapter chair/secretary (or member-manager) can forge cards';
  end if;
  if not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'cards belong to a chapter, not a working group';
  end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'full_name required'; end if;
  if coalesce(trim(p_email), '') = '' then raise exception 'email required (used to claim the card later)'; end if;

  -- a person is forged exactly once: refuse a second member for the same email
  norm_email := lower(trim(p_email));
  if exists (select 1 from member where lower(email) = norm_email) then
    raise exception 'a member already exists for % — each person is forged only once', norm_email
      using errcode = 'unique_violation';
  end if;

  minter := current_member_id();
  insert into member (full_name, email, affiliation, kind, home_unit_id, status)
  values (trim(p_full_name), norm_email, p_affiliation, 'card', p_unit, 'invited')
  returning id into new_id;

  -- stage the picked skills as ONE batch awaiting review (zero fee, leaves only)
  for it in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(skill uuid, level guild_level) loop
    if it.skill is null or it.level is null then continue; end if;
    if not exists (select 1 from skill where id = it.skill) then continue; end if;
    if exists (select 1 from skill where parent_id = it.skill) then continue; end if;
    insert into skillcard_request (member_id, skill_id, target_level, kind, fee, status, submitted_by, batch_id)
    values (new_id, it.skill, it.level, 'mint', 0, 'submitted', minter, bid);
  end loop;

  return new_id;
end $$;
grant execute on function forge_card(text, text, uuid, text, jsonb) to authenticated;

notify pgrst, 'reload schema';
