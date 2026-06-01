-- ============================================================
-- Phase 1 identity model: operators vs member-cards, scoped to chapters.
--
-- Story: only chapter officers (Chair / Secretary) and working-group
-- Leaders log in.  Ordinary members exist as *cards* — real member rows
-- with no auth — owned by a chapter.  Their chapter's Chair/Secretary act
-- on their behalf (proxy) and mint their monthly contribution; value
-- accrues to the card's own STR balance and is custodial until the person
-- later signs up (the existing email-matched claim binds auth to the card
-- row, so the balance/skills/history transfer with zero migration).
--
-- This migration is the FOUNDATION ONLY:
--   * org_unit (3 chapters + 3 working groups)
--   * org_unit_officer (admin assigns chair/secretary/leader later)
--   * member.kind ('operator' | 'card') + member.home_unit_id (a chapter)
--   * manages_card() / effective_member() proxy-auth helpers
--   * create_card() and assign/remove officer RPCs
-- The proxy retrofit of the action RPCs (claim_leadership,
-- create_project_with_leader_stake, set_labor_commitment,
-- set_resource_commitment, need apply/accept/join) — adding an optional
-- p_as card argument — lands in a SEPARATE migration so each is reviewable.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1. organisational units ----------
create table if not exists org_unit (
  id   uuid primary key default gen_random_uuid(),
  code text unique not null,                 -- NA, EU, ASPC, MLMM, MISINFO, AGENT
  name text not null,
  kind text not null check (kind in ('chapter', 'working_group')),
  rank int not null default 100
);

insert into org_unit (code, name, kind, rank) values
  ('NA',      'North America',             'chapter',       10),
  ('EU',      'Europe',                    'chapter',       20),
  ('ASPC',    'Asia-Pacific',              'chapter',       30),
  ('MLMM',    'Multilingual & Multimodal', 'working_group', 40),
  ('MISINFO', 'Misinformation',            'working_group', 50),
  ('AGENT',   'Agent',                     'working_group', 60)
on conflict (code) do nothing;

-- ---------- 2. officers (admin assigns the people later) ----------
-- Chapters carry 'chair' and 'secretary'; working groups carry 'leader'.
create table if not exists org_unit_officer (
  org_unit_id uuid not null references org_unit (id) on delete cascade,
  member_id   uuid not null references member (id)   on delete cascade,
  role        text not null check (role in ('chair', 'secretary', 'leader')),
  started_on  date not null default current_date,
  ended_on    date,
  primary key (org_unit_id, member_id, role)
);
create index if not exists org_unit_officer_member_idx on org_unit_officer (member_id) where ended_on is null;

-- ---------- 3. member kind + chapter home ----------
-- existing rows default to 'operator' so current logins are unchanged.
alter table member add column if not exists kind text not null default 'operator'
  check (kind in ('operator', 'card'));
-- a card's home chapter (must be a chapter, enforced in create_card)
alter table member add column if not exists home_unit_id uuid references org_unit (id);

-- ---------- 4. proxy-auth helpers ----------
-- is the current user a serving chair/secretary of this chapter?
create or replace function is_chapter_officer(p_unit uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from org_unit_officer o
    join member m on m.id = o.member_id
    where o.org_unit_id = p_unit
      and o.role in ('chair', 'secretary')
      and o.ended_on is null
      and m.auth_user_id = auth.uid()
  );
$$;
grant execute on function is_chapter_officer(uuid) to authenticated;

-- may the current user manage / act for this card?
-- true for a serving chair/secretary of the card's home chapter, or any
-- member-manager admin (manage_members).
create or replace function manages_card(p_card uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select has_capability('manage_members')
      or exists (
        select 1
        from member c
        join org_unit_officer o on o.org_unit_id = c.home_unit_id
        join member m on m.id = o.member_id
        where c.id = p_card
          and c.kind = 'card'
          and o.role in ('chair', 'secretary')
          and o.ended_on is null
          and m.auth_user_id = auth.uid()
      );
$$;
grant execute on function manages_card(uuid) to authenticated;

-- resolve the member an action is attributed to: yourself, or a card you
-- manage (p_as).  Raises rather than silently falling back, so a bad p_as
-- can never mis-attribute a mint/stake.
create or replace function effective_member(p_as uuid)
returns uuid language plpgsql stable security definer set search_path = public as $$
declare me uuid;
begin
  me := current_member_id();
  if p_as is null then return me; end if;
  if not manages_card(p_as) then
    raise exception 'not authorized to act on behalf of this member';
  end if;
  return p_as;
end; $$;
grant execute on function effective_member(uuid) to authenticated;

-- ---------- 5. create a card (chapter officer or admin) ----------
create or replace function create_card(p_full_name text, p_email text, p_unit uuid, p_affiliation text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if not (is_chapter_officer(p_unit) or has_capability('manage_members')) then
    raise exception 'only a chapter chair/secretary (or member-manager) can add cards';
  end if;
  if not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'cards belong to a chapter, not a working group';
  end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'full_name required'; end if;
  if coalesce(trim(p_email), '') = '' then raise exception 'email required (used to claim the card later)'; end if;
  insert into member (full_name, email, affiliation, kind, home_unit_id, status)
  values (trim(p_full_name), lower(trim(p_email)), p_affiliation, 'card', p_unit, 'invited')
  returning id into new_id;
  return new_id;
end; $$;
grant execute on function create_card(text, text, uuid, text) to authenticated;

-- ---------- 6. assign / remove officers (admin only) ----------
create or replace function assign_org_officer(p_unit uuid, p_member uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare ukind text;
begin
  if not has_capability('manage_members') then raise exception 'requires manage_members capability'; end if;
  select kind into ukind from org_unit where id = p_unit;
  if ukind is null then raise exception 'no such org unit'; end if;
  if ukind = 'chapter'        and p_role not in ('chair', 'secretary') then
    raise exception 'chapters take chair or secretary'; end if;
  if ukind = 'working_group'  and p_role <> 'leader' then
    raise exception 'working groups take a leader'; end if;
  insert into org_unit_officer (org_unit_id, member_id, role)
  values (p_unit, p_member, p_role)
  on conflict (org_unit_id, member_id, role) do update set ended_on = null, started_on = current_date;
end; $$;
grant execute on function assign_org_officer(uuid, uuid, text) to authenticated;

create or replace function remove_org_officer(p_unit uuid, p_member uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not has_capability('manage_members') then raise exception 'requires manage_members capability'; end if;
  update org_unit_officer set ended_on = current_date
   where org_unit_id = p_unit and member_id = p_member and role = p_role and ended_on is null;
end; $$;
grant execute on function remove_org_officer(uuid, uuid, text) to authenticated;

-- ---------- 7. RLS + grants ----------
alter table org_unit         enable row level security;
alter table org_unit_officer enable row level security;

drop policy if exists read_org_unit on org_unit;
create policy read_org_unit on org_unit for select to authenticated using (true);
drop policy if exists manage_org_unit on org_unit;
create policy manage_org_unit on org_unit for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));

drop policy if exists read_org_officer on org_unit_officer;
create policy read_org_officer on org_unit_officer for select to authenticated using (true);
drop policy if exists manage_org_officer on org_unit_officer;
create policy manage_org_officer on org_unit_officer for all to authenticated
  using (has_capability('manage_members')) with check (has_capability('manage_members'));

grant select on org_unit, org_unit_officer to anon, authenticated;
grant insert, update, delete on org_unit, org_unit_officer to authenticated;

notify pgrst, 'reload schema';
