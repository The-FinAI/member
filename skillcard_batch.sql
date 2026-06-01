-- =====================================================================
-- skillcard_batch.sql — batch role-card requests + one-shot review
-- ---------------------------------------------------------------------
-- Group several role-card requests into a single BATCH so a reviewer
-- approves/rejects the whole set in one action (rather than one node at
-- a time).  The talent-tree mint now stages several skills and submits
-- them as one batch; a member's own paid submission is a batch of one.
--
--   * skillcard_request.batch_id — groups requests submitted together.
--   * mint_skillcard_batch(p_member, p_items jsonb)  — 铸, zero-fee,
--       p_items = [{"skill":uuid,"level":guild_level}, …]; one batch_id.
--   * review_skillcard_batch(p_batch, p_approve, p_note) — approve /
--       reject every open request in the batch at once.
--
-- Depends on: skillcard.sql, skillcard_review.sql.  Idempotent.
-- =====================================================================

begin;

alter table skillcard_request add column if not exists batch_id uuid;
update skillcard_request set batch_id = id where batch_id is null;
create index if not exists skillcard_request_batch_idx on skillcard_request (batch_id);

-- ---- member self-submit: tag it as a single-item batch -------------
create or replace function submit_skillcard_request(p_skill uuid, p_level guild_level, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; have guild_level; knd text; fee integer; req_id uuid; bid uuid := gen_random_uuid();
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;

  if not exists (select 1 from skill where id = p_skill) then raise exception 'no such skill'; end if;
  if exists (select 1 from skill where parent_id = p_skill) then
    raise exception 'role cards are minted on leaf skills, not domains';
  end if;

  select certified_level into have from member_skill where member_id = me and skill_id = p_skill;
  if have is not null and guild_level_rank(have) >= guild_level_rank(p_level) then
    raise exception 'this card is already at % or higher', have;
  end if;
  knd := case when have is null then 'mint' else 'update' end;

  fee := stater_policy_int(case when knd = 'mint' then 'skillcard_mint_fee' else 'skillcard_update_fee' end,
                           case when knd = 'mint' then 10 else 5 end);

  if stater_balance_of(stater_member_acc(me)) < fee then
    raise exception 'insufficient STR: % fee is %, the card has %',
      knd, fee, stater_balance_of(stater_member_acc(me));
  end if;

  insert into skillcard_request (member_id, skill_id, target_level, kind, fee, status, submitted_by, batch_id)
  values (me, p_skill, p_level, knd, fee, 'submitted', current_member_id(), bid)
  returning id into req_id;

  if fee > 0 then
    perform stater_move(stater_member_acc(me), stater_treasury(), fee, 'skillcard_fee',
                        'role card ' || knd || ' fee', null, p_skill, null, current_member_id());
  end if;

  return req_id;
end $$;
grant execute on function submit_skillcard_request(uuid, guild_level, uuid) to authenticated;

-- ---- 铸: stage many skills, submit as one batch (zero fee) ----------
create or replace function mint_skillcard_batch(p_member uuid, p_items jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; bid uuid := gen_random_uuid(); it record; have guild_level; knd text; n integer := 0;
begin
  if not has_capability('mint_skillcard') then
    raise exception 'requires the mint_skillcard capability';
  end if;
  minter := current_member_id();
  if not exists (select 1 from member where id = p_member) then raise exception 'no such member'; end if;

  for it in select * from jsonb_to_recordset(p_items) as x(skill uuid, level guild_level) loop
    if it.skill is null or it.level is null then continue; end if;
    if not exists (select 1 from skill where id = it.skill) then raise exception 'no such skill'; end if;
    if exists (select 1 from skill where parent_id = it.skill) then
      raise exception 'role cards are minted on leaf skills, not domains';
    end if;
    select certified_level into have from member_skill where member_id = p_member and skill_id = it.skill;
    if have is not null and guild_level_rank(have) >= guild_level_rank(it.level) then
      continue;  -- already at/above this level — skip
    end if;
    if exists (select 1 from skillcard_request
               where member_id = p_member and skill_id = it.skill and status = 'submitted') then
      continue;  -- already has an open request — skip
    end if;
    knd := case when have is null then 'mint' else 'update' end;
    insert into skillcard_request (member_id, skill_id, target_level, kind, fee, status, submitted_by, batch_id)
    values (p_member, it.skill, it.level, knd, 0, 'submitted', minter, bid);
    n := n + 1;
  end loop;

  if n = 0 then raise exception 'nothing to submit — picked skills are already certified or pending'; end if;
  return bid;
end $$;
grant execute on function mint_skillcard_batch(uuid, jsonb) to authenticated;

-- ---- 审: approve / reject a whole batch at once --------------------
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
      insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
      values (r.member_id, r.skill_id, 'Expert', r.target_level, now())
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

commit;

notify pgrst, 'reload schema';
