-- ============================================================
-- Let a member CLAIM their own skill badges from their profile. The staged
-- raises go in as a normal submitted batch (review_skillcard / manage_members
-- officers approve), so self-claims are reviewed, never self-granted.
-- (Same body as forge_badges; only the auth gains `p_member = current_member_id()`.)
-- ============================================================

create or replace function forge_badges(p_member uuid, p_items jsonb, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; bid uuid := gen_random_uuid(); it record; act text; n int := 0;
begin
  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('mint_skillcard') or p_member = current_member_id()) then
    raise exception 'not authorized to forge badges for this member';
  end if;
  submitter := current_member_id();
  for it in select * from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as x(skill uuid, level guild_level) loop
    if it.skill is null or it.level is null then continue; end if;
    if not exists (select 1 from skill where id = it.skill) then continue; end if;
    if exists (select 1 from skill where parent_id = it.skill) then continue; end if;
    act := case when exists (select 1 from badge b where b.member_id = p_member and b.skill_id = it.skill)
                then 'update' else 'create' end;
    insert into forge_request (target_type, action, target_id, payload, batch_id, fee, submitted_by, submitted_as, status)
    values ('badge', act, p_member,
            jsonb_build_object('member_id', p_member, 'skill_id', it.skill, 'target_level', it.level),
            bid, 0, submitter, p_as, 'submitted');
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'no valid leaf-skill badges to forge'; end if;
  return bid;
end $$;
grant execute on function forge_badges(uuid, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';
