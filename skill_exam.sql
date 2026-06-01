-- =====================================================================
-- Migration B — skill_exam.sql : the GUILD
-- ---------------------------------------------------------------------
-- Turns self-declared skills into a paid, peer-reviewed credential system.
--   * Guild ladder  Apprentice → Journeyman → Craftsman → Master
--   * First holder of a skill = its author/Master (auto-certified at top),
--     owns the rubric, may branch sub-skills.
--   * request_skill_exam → random 3 qualified reviewers → cast_exam_vote →
--     settle_exam (≥ majority pass ⇒ certified). Fee distributes 80/20
--     to reviewers/treasury REGARDLESS of outcome (pay-to-sit).
--
-- Depends on: stater.sql (accounts/ledger/policy/move helpers),
--             schema.sql (skill, member_skill, member),
--             contributions.sql (exam_fee_treasury_cut policy + policy_num).
--
-- NOTE: self-rating signal (member_skill.self_level, skill_level enum) and
-- lightweight endorsements (stater_skill_credit) are KEPT untouched — the
-- paid exam is a separate, harder credential layered on top.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Guild ladder enum (ordered: master is the highest, so `>=` works)
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'guild_level') then
    create type guild_level as enum ('apprentice', 'journeyman', 'craftsman', 'master');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Fee + panel policy knobs (liquid STR per level; treasury cut reused)
-- ---------------------------------------------------------------------
insert into stater_policy (key, value, description) values
  ('skill_exam_fee_apprentice',   5, 'Exam sitting fee — Apprentice'),
  ('skill_exam_fee_journeyman',  10, 'Exam sitting fee — Journeyman'),
  ('skill_exam_fee_craftsman',   20, 'Exam sitting fee — Craftsman'),
  ('skill_exam_fee_master',      40, 'Exam sitting fee — Master'),
  ('skill_exam_panel_size',       3, 'Reviewers randomly drawn per exam')
on conflict (key) do nothing;

-- numeric reader (stater_policy_num) ships in contributions.sql.

-- ---------------------------------------------------------------------
-- 2. Skill authorship + rubric  (skill.parent_id already exists)
-- ---------------------------------------------------------------------
alter table skill add column if not exists master_member_id uuid references member (id);

create table if not exists skill_exam_rubric (
  skill_id    uuid not null references skill (id) on delete cascade,
  level       guild_level not null,
  requirements text not null,
  updated_by  uuid references member (id),
  updated_at  timestamptz not null default now(),
  primary key (skill_id, level)
);

-- certification lives alongside the self-rating on member_skill
alter table member_skill add column if not exists certified_level guild_level;
alter table member_skill add column if not exists certified_at   timestamptz;

-- ---------------------------------------------------------------------
-- 3. The exam + its reviewer votes
-- ---------------------------------------------------------------------
create table if not exists skill_exam (
  id                 uuid primary key default gen_random_uuid(),
  skill_id           uuid not null references skill (id) on delete cascade,
  applicant_member_id uuid not null references member (id) on delete cascade,
  target_level       guild_level not null,
  fee                integer not null,
  panel_size         integer not null,
  status             text not null default 'in_review',  -- in_review | passed | failed | cancelled
  created_by         uuid references member (id),
  created_at         timestamptz not null default now(),
  settled_at         timestamptz
);
create index if not exists skill_exam_skill_idx on skill_exam (skill_id);
create index if not exists skill_exam_applicant_idx on skill_exam (applicant_member_id);

create table if not exists skill_exam_vote (
  exam_id            uuid not null references skill_exam (id) on delete cascade,
  reviewer_member_id uuid not null references member (id) on delete cascade,
  vote               text,            -- null = not yet cast | 'pass' | 'fail'
  note               text,
  assigned_at        timestamptz not null default now(),
  voted_at           timestamptz,
  primary key (exam_id, reviewer_member_id)
);
create index if not exists skill_exam_vote_reviewer_idx on skill_exam_vote (reviewer_member_id);

-- ---------------------------------------------------------------------
-- 4. Cold-start trigger: first holder of a skill becomes its Master.
--    Auto-certifies that first row at 'master', seeding the reviewer pool.
-- ---------------------------------------------------------------------
create or replace function _skill_first_holder_is_master()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select master_member_id from skill where id = new.skill_id) is null then
    update skill set master_member_id = new.member_id
      where id = new.skill_id and master_member_id is null;
    new.certified_level := 'master';
    new.certified_at := now();
  end if;
  return new;
end $$;

drop trigger if exists skill_first_holder_master on member_skill;
create trigger skill_first_holder_master
  before insert on member_skill
  for each row execute function _skill_first_holder_is_master();

-- ---------------------------------------------------------------------
-- 5. Rubric editor — only the skill's Master may write it
-- ---------------------------------------------------------------------
create or replace function set_exam_rubric(p_skill uuid, p_level guild_level, p_requirements text)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if (select master_member_id from skill where id = p_skill) is distinct from me then
    raise exception 'only the skill master may edit its rubric';
  end if;
  insert into skill_exam_rubric (skill_id, level, requirements, updated_by, updated_at)
  values (p_skill, p_level, p_requirements, me, now())
  on conflict (skill_id, level)
    do update set requirements = excluded.requirements, updated_by = me, updated_at = now();
end $$;
grant execute on function set_exam_rubric(uuid, guild_level, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. request_skill_exam — pay fee, draw a random qualified panel
-- ---------------------------------------------------------------------
create or replace function request_skill_exam(p_skill uuid, p_level guild_level)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid; fee integer; panel int; qcount int; exam_id uuid; r record;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;

  -- exams happen at concrete leaf skills only
  if exists (select 1 from skill where parent_id = p_skill) then
    raise exception 'exams are taken on leaf skills, not domains';
  end if;
  if not exists (select 1 from skill where id = p_skill) then
    raise exception 'no such skill';
  end if;

  fee := stater_policy_int('skill_exam_fee_' || p_level::text,
           case p_level when 'apprentice' then 5 when 'journeyman' then 10
                        when 'craftsman' then 20 else 40 end);

  -- qualified reviewers: certified in THIS skill at >= target level, not the applicant
  select count(*) into qcount
    from member_skill
   where skill_id = p_skill and certified_level >= p_level and member_id <> me;
  if qcount = 0 then
    raise exception 'no qualified reviewers for this skill at this level yet';
  end if;
  panel := least(stater_policy_int('skill_exam_panel_size', 3), qcount);

  if stater_balance_of(stater_member_acc(me)) < fee then
    raise exception 'insufficient STR: exam fee is %, you have %', fee, stater_balance_of(stater_member_acc(me));
  end if;

  insert into skill_exam (skill_id, applicant_member_id, target_level, fee, panel_size, created_by)
  values (p_skill, me, p_level, fee, panel, me)
  returning id into exam_id;

  -- escrow the fee into the treasury; it pays out on settle
  perform stater_move(stater_member_acc(me), stater_treasury(), fee, 'exam_fee',
                      'skill exam sitting fee', null, p_skill, null, me);

  -- draw the panel at random and seat them
  for r in
    select member_id from member_skill
     where skill_id = p_skill and certified_level >= p_level and member_id <> me
     order by random() limit panel
  loop
    insert into skill_exam_vote (exam_id, reviewer_member_id) values (exam_id, r.member_id);
  end loop;

  return exam_id;
end $$;
grant execute on function request_skill_exam(uuid, guild_level) to authenticated;

-- ---------------------------------------------------------------------
-- 7. cast_exam_vote — a seated reviewer grades; auto-settles on last vote
-- ---------------------------------------------------------------------
create or replace function cast_exam_vote(p_exam uuid, p_pass boolean, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; pending int;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if (select status from skill_exam where id = p_exam) <> 'in_review' then
    raise exception 'exam is not open for voting';
  end if;
  if not exists (select 1 from skill_exam_vote where exam_id = p_exam and reviewer_member_id = me) then
    raise exception 'you are not a reviewer on this exam';
  end if;

  update skill_exam_vote
     set vote = case when p_pass then 'pass' else 'fail' end,
         note = nullif(btrim(coalesce(p_note, '')), ''), voted_at = now()
   where exam_id = p_exam and reviewer_member_id = me;

  -- once everyone has voted, settle automatically
  select count(*) into pending from skill_exam_vote where exam_id = p_exam and vote is null;
  if pending = 0 then perform settle_exam(p_exam); end if;
end $$;
grant execute on function cast_exam_vote(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------
-- 8. settle_exam — majority rule; fee splits 80/20 regardless of outcome
-- ---------------------------------------------------------------------
create or replace function settle_exam(p_exam uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  ex record; passes int; majority int; cut int; pool int; per int; r record; passed boolean;
begin
  select * into ex from skill_exam where id = p_exam;
  if ex is null then raise exception 'no such exam'; end if;
  if ex.status <> 'in_review' then raise exception 'exam already settled'; end if;
  if exists (select 1 from skill_exam_vote where exam_id = p_exam and vote is null) then
    raise exception 'votes still pending';
  end if;

  select count(*) into passes from skill_exam_vote where exam_id = p_exam and vote = 'pass';
  majority := (ex.panel_size / 2) + 1;          -- 3→2, 2→2, 1→1
  passed := passes >= majority;

  -- distribute the escrowed fee: 20% stays with treasury, 80% split evenly
  cut  := floor(ex.fee * stater_policy_num('exam_fee_treasury_cut', 0.2));
  pool := ex.fee - cut;
  per  := pool / ex.panel_size;                  -- integer split; remainder stays in treasury
  if per > 0 then
    for r in select reviewer_member_id from skill_exam_vote where exam_id = p_exam loop
      perform stater_move(stater_treasury(), stater_member_acc(r.reviewer_member_id), per,
                          'exam_payout', 'skill exam review fee', null, ex.skill_id, null, ex.applicant_member_id);
    end loop;
  end if;

  if passed then
    -- certify: keep the highest level the applicant has reached
    insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
    values (ex.applicant_member_id, ex.skill_id, 'Expert', ex.target_level, now())
    on conflict (member_id, skill_id) do update
      set certified_level = greatest(member_skill.certified_level, excluded.certified_level),
          certified_at = now();
  end if;

  update skill_exam set status = case when passed then 'passed' else 'failed' end,
                        settled_at = now()
   where id = p_exam;
end $$;
grant execute on function settle_exam(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 9. branch_skill — a Master grows the tree under their node
-- ---------------------------------------------------------------------
create or replace function branch_skill(p_parent uuid, p_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; child uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if btrim(coalesce(p_name, '')) = '' then raise exception 'name required'; end if;

  -- must be the parent's Master (or certified Master of it)
  if (select master_member_id from skill where id = p_parent) is distinct from me
     and not exists (select 1 from member_skill
                      where skill_id = p_parent and member_id = me and certified_level = 'master') then
    raise exception 'only a Master of the parent skill may branch it';
  end if;

  insert into skill (parent_id, name, master_member_id)
  values (p_parent, btrim(p_name), me)
  returning id into child;

  -- author becomes Master of the new leaf (also satisfies the cold-start trigger)
  insert into member_skill (member_id, skill_id, self_level, certified_level, certified_at)
  values (me, child, 'Expert', 'master', now())
  on conflict (member_id, skill_id) do nothing;

  return child;
end $$;
grant execute on function branch_skill(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 10. RLS — public reads (consistent with the rest of the schema)
-- ---------------------------------------------------------------------
alter table skill_exam_rubric enable row level security;
alter table skill_exam        enable row level security;
alter table skill_exam_vote   enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='skill_exam_rubric' and policyname='read_skill_exam_rubric') then
    create policy read_skill_exam_rubric on skill_exam_rubric for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='skill_exam' and policyname='read_skill_exam') then
    create policy read_skill_exam on skill_exam for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='skill_exam_vote' and policyname='read_skill_exam_vote') then
    create policy read_skill_exam_vote on skill_exam_vote for select to authenticated using (true);
  end if;
end $$;

grant select on skill_exam_rubric, skill_exam, skill_exam_vote to authenticated;

commit;
