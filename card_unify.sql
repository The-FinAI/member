-- =====================================================================
-- card_unify.sql — one card = identity + skills; remove the exam system
-- ---------------------------------------------------------------------
-- Consolidates the role-card model per the 2026-06 redesign:
--
--   * A "card" is one researcher = identity + skill profile, forged in a
--     single action.  forge_card(name,email,unit,affiliation,items) lets a
--     chapter officer create a member-card AND stage its initial skills as
--     ONE batch awaiting review — the whole card is approved at once.
--
--   * self_level (self-rating, Beginner..Expert) is RETIRED.  Only the
--     certified card ladder (Apprentice..Master) remains.  member_skill
--     .self_level is made nullable and the certification RPCs stop writing
--     it.  (The column is kept, unused, to avoid touching legacy seeds.)
--
--   * The paid peer-exam system is REMOVED entirely: exams, skill masters,
--     rubrics, sub-skill branching, and the "first holder becomes master"
--     trigger.  Certification now flows ONLY through forge / request →
--     review.  A member self-upgrade still pays the mint/update fee.
--
-- Depends on: card_membership.sql, skillcard.sql, skillcard_batch.sql,
--             skill_exam.sql + guild_governance.sql (being torn down).
-- Idempotent: safe to re-run.
-- =====================================================================

begin;

-- ---- 1. drop the "first holder = master" trigger FIRST -------------
--    (it writes skill.master_member_id, which we drop below, and it
--     silently promotes any first holder to master — both unwanted.)
drop trigger if exists skill_first_holder_master on member_skill;
drop function if exists _skill_first_holder_is_master();

-- ---- 2. retire self_level: stop requiring it ----------------------
alter table member_skill alter column self_level drop not null;

-- ---- 3. tear down the exam / master / rubric system ---------------
drop function if exists settle_exam(uuid);
drop function if exists cast_exam_vote(uuid, boolean, text);
drop function if exists request_skill_exam(uuid, guild_level);
drop function if exists set_exam_rubric(uuid, guild_level, text);
drop function if exists branch_skill(uuid, text);
drop function if exists appoint_skill_master(uuid, uuid);
drop table if exists skill_exam_vote cascade;
drop table if exists skill_exam cascade;
drop table if exists skill_exam_rubric cascade;
delete from stater_policy where key like 'skill_exam_fee_%' or key = 'skill_exam_panel_size';
alter table skill drop column if exists master_member_id;

-- ---- 4. certification RPCs no longer write self_level -------------
create or replace function review_skillcard_request(p_request uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r record; reviewer uuid;
begin
  if not has_capability('review_skillcard') then
    raise exception 'requires the review_skillcard capability';
  end if;
  reviewer := current_member_id();
  select * into r from skillcard_request where id = p_request;
  if r is null then raise exception 'no such request'; end if;
  if r.status <> 'submitted' then raise exception 'request is not open for review'; end if;

  if p_approve then
    insert into member_skill (member_id, skill_id, certified_level, certified_at)
    values (r.member_id, r.skill_id, r.target_level, now())
    on conflict (member_id, skill_id) do update
      set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
          certified_at = now();
  elsif r.fee > 0 then
    perform stater_move(stater_treasury(), stater_member_acc(r.member_id), r.fee, 'skillcard_refund',
                        'role card request rejected — fee refunded', null, r.skill_id, null, reviewer);
  end if;

  update skillcard_request
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = reviewer,
         review_note = nullif(btrim(coalesce(p_note, '')), ''),
         settled_at = now()
   where id = p_request;
end $$;
grant execute on function review_skillcard_request(uuid, boolean, text) to authenticated;

create or replace function review_skillcard_batch(p_batch uuid, p_approve boolean, p_note text default null)
returns integer language plpgsql security definer set search_path = public as $$
declare reviewer uuid; r record; n integer := 0;
begin
  if not has_capability('review_skillcard') then
    raise exception 'requires the review_skillcard capability';
  end if;
  reviewer := current_member_id();

  for r in select * from skillcard_request where batch_id = p_batch and status = 'submitted' loop
    if p_approve then
      insert into member_skill (member_id, skill_id, certified_level, certified_at)
      values (r.member_id, r.skill_id, r.target_level, now())
      on conflict (member_id, skill_id) do update
        set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
            certified_at = now();
    elsif r.fee > 0 then
      perform stater_move(stater_treasury(), stater_member_acc(r.member_id), r.fee, 'skillcard_refund',
                          'role card request rejected — fee refunded', null, r.skill_id, null, reviewer);
    end if;
    update skillcard_request
       set status = case when p_approve then 'approved' else 'rejected' end,
           reviewed_by = reviewer,
           review_note = nullif(btrim(coalesce(p_note, '')), ''),
           settled_at = now()
     where id = r.id;
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'no open requests in this batch'; end if;
  return n;
end $$;
grant execute on function review_skillcard_batch(uuid, boolean, text) to authenticated;

-- ---- 5. forge_card — identity + skills in one reviewed batch ------
create or replace function forge_card(p_full_name text, p_email text, p_unit uuid,
                                      p_affiliation text default null, p_items jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; new_id uuid; bid uuid := gen_random_uuid(); it record;
begin
  if not (is_chapter_officer(p_unit) or has_capability('manage_members')) then
    raise exception 'only a chapter chair/secretary (or member-manager) can forge cards';
  end if;
  if not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'cards belong to a chapter, not a working group';
  end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'full_name required'; end if;
  if coalesce(trim(p_email), '') = '' then raise exception 'email required (used to claim the card later)'; end if;

  minter := current_member_id();
  insert into member (full_name, email, affiliation, kind, home_unit_id, status)
  values (trim(p_full_name), lower(trim(p_email)), p_affiliation, 'card', p_unit, 'invited')
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

commit;

notify pgrst, 'reload schema';
