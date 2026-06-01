-- =====================================================================
-- skillcard_review.sql — route the 铸 (mint) action through review too
-- ---------------------------------------------------------------------
-- Change of policy: NObody certifies a role card instantly any more.
-- Holders of mint_skillcard no longer write member_skill directly; the
-- talent-tree "mint" action now SUBMITS a zero-fee request that a
-- review_skillcard holder (admin) must approve, exactly like a member's
-- own submission.  This makes every certification pass through review.
--
--   * mint_skillcard(p_member, p_skill, p_level)
--       requires mint_skillcard; enqueues a 'submitted', fee = 0 request
--       for an arbitrary member (the talent-tree pick).  Returns the
--       request id.  Approval/rejection flows through
--       review_skillcard_request unchanged (fee 0 ⇒ refund is a no-op).
--
-- Depends on: skillcard.sql.  Idempotent: safe to re-run.
-- =====================================================================

begin;

-- return type changes (void -> uuid), so drop the old signature first
drop function if exists mint_skillcard(uuid, uuid, guild_level);

create or replace function mint_skillcard(p_member uuid, p_skill uuid, p_level guild_level)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; have guild_level; knd text; req_id uuid;
begin
  if not has_capability('mint_skillcard') then
    raise exception 'requires the mint_skillcard capability';
  end if;
  minter := current_member_id();
  if not exists (select 1 from member where id = p_member) then raise exception 'no such member'; end if;
  if not exists (select 1 from skill where id = p_skill) then raise exception 'no such skill'; end if;
  if exists (select 1 from skill where parent_id = p_skill) then
    raise exception 'role cards are minted on leaf skills, not domains';
  end if;

  select certified_level into have from member_skill where member_id = p_member and skill_id = p_skill;
  if have is not null and guild_level_rank(have) >= guild_level_rank(p_level) then
    raise exception 'this member is already at % or higher', have;
  end if;
  if exists (select 1 from skillcard_request
             where member_id = p_member and skill_id = p_skill and status = 'submitted') then
    raise exception 'this member already has an open request for this skill';
  end if;
  knd := case when have is null then 'mint' else 'update' end;

  -- admin-proposed, zero-fee request — must be approved by a reviewer
  insert into skillcard_request (member_id, skill_id, target_level, kind, fee, status, submitted_by)
  values (p_member, p_skill, p_level, knd, 0, 'submitted', minter)
  returning id into req_id;

  return req_id;
end $$;
grant execute on function mint_skillcard(uuid, uuid, guild_level) to authenticated;

commit;

notify pgrst, 'reload schema';
