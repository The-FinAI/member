-- =====================================================================
-- skillcard.sql — role-card (角色卡牌) mint / review credential flow
-- ---------------------------------------------------------------------
-- Restructures the guild credential economy.  A member's certified skill
-- is a "role card" (角色卡牌); acquiring or levelling one is now an
-- admin-mediated MINT/REVIEW action instead of a paid peer exam.
--
--   * 铸 (mint)   — capability mint_skillcard: a holder mints a card
--                   DIRECTLY onto any member (genesis / first card / waiver),
--                   no fee, no review.  "admin 有权利".
--   * 提交 (submit)— a member (or a chapter officer on behalf of a card,
--                   via p_as) SUBMITS a request to mint a new card or
--                   update an existing one to a higher level.  The mint /
--                   update FEE is escrowed from the card's own balance.
--   * 审 (review) — capability review_skillcard: a holder approves or
--                   rejects a submitted request.  Approve ⇒ the card is
--                   certified and the fee is kept by the treasury.  Reject
--                   (or the submitter cancels) ⇒ the fee is REFUNDED.
--
-- The old paid peer exam (skill_exam.sql) is LEFT IN PLACE as an
-- alternative path; this migration only adds the mint/review economy and
-- its two new capabilities.  The exam sitting fee is unchanged here.
--
-- Proxy-aware: submit/cancel resolve the acting member via
-- effective_member(p_as) so officers can manage their cards' role cards;
-- value (fee debit / refund) always moves on the CARD's account.
--
-- Depends on: stater.sql, schema.sql, skill_exam.sql (guild_level enum,
--   member_skill.certified_level), leader_requirements.sql
--   (guild_level_rank), card_membership.sql (effective_member),
--   policies.sql (has_capability).  Idempotent: safe to re-run.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Two new capabilities: mint (铸) and review (审) role cards.
--    Granted by default to whoever already oversees the guild.
-- ---------------------------------------------------------------------
insert into capability (key, description) values
  ('mint_skillcard',   'Mint a role card (skill credential) directly onto a member — genesis / waiver, no review'),
  ('review_skillcard', 'Review and approve/reject submitted role-card mint/update requests')
on conflict (key) do nothing;

insert into position_capability (position_id, capability_key)
select pc.position_id, c.key
from position_capability pc
cross join (values ('mint_skillcard'), ('review_skillcard')) as c(key)
where pc.capability_key = 'manage_guild'
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 2. Fee knobs (liquid STR).  Replaces the per-sitting exam fee with a
--    flat mint fee (a brand-new card) and a cheaper update fee (level-up).
-- ---------------------------------------------------------------------
insert into stater_policy (key, value, description) values
  ('skillcard_mint_fee',   10, 'Fee to mint a brand-new role card (skill credential)'),
  ('skillcard_update_fee',  5, 'Fee to update an existing role card to a higher level')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 3. The submission queue.  A request escrows its fee on submit; review
--    settles it (keep on approve, refund on reject), cancel refunds.
-- ---------------------------------------------------------------------
create table if not exists skillcard_request (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references member (id) on delete cascade,  -- the card/person credentialed
  skill_id      uuid not null references skill (id)  on delete cascade,
  target_level  guild_level not null,
  kind          text not null check (kind in ('mint', 'update')),
  fee           integer not null default 0,
  status        text not null default 'submitted'
                  check (status in ('submitted', 'approved', 'rejected', 'cancelled')),
  submitted_by  uuid references member (id),     -- the acting member (officer, if proxy)
  reviewed_by   uuid references member (id),
  review_note   text,
  created_at    timestamptz not null default now(),
  settled_at    timestamptz
);
create index if not exists skillcard_request_member_idx on skillcard_request (member_id);
create index if not exists skillcard_request_skill_idx  on skillcard_request (skill_id);
create index if not exists skillcard_request_open_idx   on skillcard_request (status) where status = 'submitted';
-- at most one open request per (member, skill)
create unique index if not exists skillcard_request_one_open
  on skillcard_request (member_id, skill_id) where status = 'submitted';

-- ---------------------------------------------------------------------
-- 4. submit_skillcard_request — escrow the fee, queue for review.
--    Proxy-aware: p_as lets an officer submit for a card they manage.
-- ---------------------------------------------------------------------
create or replace function submit_skillcard_request(p_skill uuid, p_level guild_level, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; have guild_level; knd text; fee integer; req_id uuid;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;

  if not exists (select 1 from skill where id = p_skill) then
    raise exception 'no such skill';
  end if;
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

  insert into skillcard_request (member_id, skill_id, target_level, kind, fee, status, submitted_by)
  values (me, p_skill, p_level, knd, fee, 'submitted', current_member_id())
  returning id into req_id;

  -- escrow the fee into the treasury; refunded on reject/cancel, kept on approve
  if fee > 0 then
    perform stater_move(stater_member_acc(me), stater_treasury(), fee, 'skillcard_fee',
                        'role card ' || knd || ' fee', null, p_skill, null, current_member_id());
  end if;

  return req_id;
end $$;
grant execute on function submit_skillcard_request(uuid, guild_level, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5. review_skillcard_request — a 审 holder approves (certify + keep fee)
--    or rejects (refund the fee).
-- ---------------------------------------------------------------------
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
    insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
    values (r.member_id, r.skill_id, 'Expert', r.target_level, now())
    on conflict (member_id, skill_id) do update
      set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
          certified_at = now();
    -- fee stays in the treasury
  else
    -- refund the escrowed fee to the card
    if r.fee > 0 then
      perform stater_move(stater_treasury(), stater_member_acc(r.member_id), r.fee, 'skillcard_refund',
                          'role card request rejected — fee refunded', null, r.skill_id, null, reviewer);
    end if;
  end if;

  update skillcard_request
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = reviewer,
         review_note = nullif(btrim(coalesce(p_note, '')), ''),
         settled_at = now()
   where id = p_request;
end $$;
grant execute on function review_skillcard_request(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. cancel_skillcard_request — the submitter withdraws a pending request
--    and gets the fee back.  Proxy-aware.
-- ---------------------------------------------------------------------
create or replace function cancel_skillcard_request(p_request uuid, p_as uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; r record;
begin
  me := effective_member(p_as);
  select * into r from skillcard_request where id = p_request;
  if r is null then raise exception 'no such request'; end if;
  if r.member_id <> me then raise exception 'not your request'; end if;
  if r.status <> 'submitted' then raise exception 'request is not open'; end if;

  if r.fee > 0 then
    perform stater_move(stater_treasury(), stater_member_acc(r.member_id), r.fee, 'skillcard_refund',
                        'role card request cancelled — fee refunded', null, r.skill_id, null, me);
  end if;
  update skillcard_request set status = 'cancelled', settled_at = now() where id = p_request;
end $$;
grant execute on function cancel_skillcard_request(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 7. mint_skillcard — 铸: a holder mints a card directly, no fee/review.
--    Genesis seeding, first cards, and admin waivers. "admin 有权利".
-- ---------------------------------------------------------------------
create or replace function mint_skillcard(p_member uuid, p_skill uuid, p_level guild_level)
returns void language plpgsql security definer set search_path = public as $$
declare minter uuid;
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

  insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
  values (p_member, p_skill, 'Expert', p_level, now())
  on conflict (member_id, skill_id) do update
    set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
        certified_at = now();

  -- audit trail: a pre-approved, zero-fee mint record
  insert into skillcard_request
    (member_id, skill_id, target_level, kind, fee, status, submitted_by, reviewed_by, review_note, settled_at)
  values (p_member, p_skill, p_level, 'mint', 0, 'approved', minter, minter, 'direct mint', now());
end $$;
grant execute on function mint_skillcard(uuid, uuid, guild_level) to authenticated;

-- ---------------------------------------------------------------------
-- 8. RLS — public reads, consistent with the rest of the schema.
-- ---------------------------------------------------------------------
alter table skillcard_request enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='skillcard_request' and policyname='read_skillcard_request') then
    create policy read_skillcard_request on skillcard_request for select to authenticated using (true);
  end if;
end $$;
grant select on skillcard_request to authenticated;

commit;

notify pgrst, 'reload schema';
