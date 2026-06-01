-- ============================================================
-- First-author writing obligation for project leaders.
--
-- Every project leader carries a standing monthly first-author writing
-- duty (default 20h/month). It is modelled as its OWN commitment row
-- (commitment_type = 'first_author_writing', skill_id = null) with one
-- monthly period per month — same declare = mint mechanic as labor.
--
-- A fresh leader (new project, or claim_leadership) is auto-seeded with
-- the current month's 20h so the duty shows up immediately. Leaders can
-- restate the month's hours via set_first_author_writing.
--
-- writing_laggards() lets an admin list this month's non-compliant
-- leaders so they can be e-mailed a reminder.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- policy: per-hour mint rate for first-author writing ----------
insert into stater_policy (key, value, description) values
  ('first_author_writing_rate', 10,
   'Nominal STR minted per hour of leader first-author writing')
on conflict (key) do nothing;

-- the required monthly hours policy already exists as
-- 'default_first_author_writing_hours' (= 20); keep it if missing.
insert into stater_policy (key, value, description) values
  ('default_first_author_writing_hours', 20,
   'Monthly first-author writing hours required of a project leader')
on conflict (key) do nothing;

-- ---------- declare = mint the leader's monthly writing hours ----------
create or replace function set_first_author_writing(p uuid, ym text, hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; rate integer; equiv integer;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if hours < 0 then raise exception 'hours cannot be negative'; end if;

  -- only a managing leader of THIS project carries the first-author duty
  if not (manages_project(p) or has_capability('edit_any_project')) then
    raise exception 'only the project leader records first-author writing';
  end if;

  -- find or create the standing first-author-writing commitment for this leader
  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me
     and commitment_type = 'first_author_writing'
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, skill_id, status)
    values (p, me, 'first_author_writing', null, 'verified') returning id into cid;
  end if;

  rate  := stater_policy_int('first_author_writing_rate',
                             stater_policy_int('paper_writing_rate', 10));
  equiv := ceil(rate * hours);

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, hours, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';
  return cid;
end; $$;
grant execute on function set_first_author_writing(uuid, text, numeric) to authenticated;

-- ---------- auto-seed a leader's current-month writing duty ----------
-- Used by project creation and claim_leadership. Runs as the seeded leader
-- (me must already hold the managing seat by the time this is called).
create or replace function seed_first_author_writing(p uuid, mid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cid uuid; req integer; rate integer; equiv integer; ym text;
begin
  ym  := to_char(now(), 'YYYY-MM');
  req := stater_policy_int('default_first_author_writing_hours', 20);

  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = mid
     and commitment_type = 'first_author_writing'
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, skill_id, status)
    values (p, mid, 'first_author_writing', null, 'verified') returning id into cid;
  end if;

  rate  := stater_policy_int('first_author_writing_rate',
                             stater_policy_int('paper_writing_rate', 10));
  equiv := ceil(rate * req);

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, req, equiv, 'minted')
  on conflict (commitment_id, year_month) do nothing;
end; $$;

-- ---------- wire the seed into project creation ----------
create or replace function create_project_with_leader_stake(
  p_name text, p_type_id uuid, p_status_id uuid, p_venue text, p_summary text,
  p_stake integer default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; esc uuid; lstake integer; lrole uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  lstake := coalesce(p_stake, (select leader_stake from project_type where id = p_type_id),
                     stater_policy_int('leader_stake_normal', 50));
  vname := coalesce((select name from venue where id = p_venue_id), p_venue);
  insert into project (name, type_id, status_id, target_venue, venue_id, summary)
  values (p_name, p_type_id, p_status_id, vname, p_venue_id, p_summary) returning id into pid;
  esc := stater_project_acc(pid);  -- created by trigger
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader initiation stake', pid, null, null, me);
  select id into lrole from project_role where name = 'Leader' limit 1;
  insert into project_member (project_id, member_id, project_role_id) values (pid, me, lrole) on conflict do nothing;
  insert into stater_project_stake_commitment (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (pid, me, 'leader_initiation', lstake, 'verified', me, now());
  perform seed_first_author_writing(pid, me);
  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;
  return pid;
end; $$;
grant execute on function create_project_with_leader_stake(text, uuid, uuid, text, text, integer, uuid, text) to authenticated;

-- ---------- wire the seed into claim_leadership ----------
create or replace function claim_leadership(p uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; lstake integer; lrole uuid; bal numeric; esc uuid; nm text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;

  if exists (
    select 1 from project_member pm
    join project_role pr on pr.id = pm.project_role_id
    where pm.project_id = p and pr.can_manage
  ) then
    raise exception 'project already has a leader';
  end if;

  lstake := coalesce(
    (select leader_stake from project_type t join project pr on pr.type_id = t.id where pr.id = p),
    stater_policy_int('leader_stake_normal', 50));

  select coalesce(balance, 0) into bal from stater_balance where owner_member_id = me;
  if coalesce(bal, 0) < lstake then
    raise exception 'insufficient STR balance: leading stakes %, you have %', lstake, coalesce(bal, 0);
  end if;

  select id into lrole from project_role where name = 'Leader' limit 1;
  esc := stater_project_acc(p);
  perform stater_move(stater_member_acc(me), esc, lstake, 'stake', 'leader claim stake', p, null, null, me);

  if exists (select 1 from project_member where project_id = p and member_id = me) then
    update project_member set project_role_id = lrole where project_id = p and member_id = me;
  else
    insert into project_member (project_id, member_id, project_role_id) values (p, me, lrole);
  end if;

  insert into stater_project_stake_commitment
    (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (p, me, 'leader_initiation', lstake, 'verified', me, now());

  perform seed_first_author_writing(p, me);

  select full_name into nm from member where id = me;
  insert into project_event (project_id, actor_member_id, event_type, summary)
  values (p, me, 'member_joined', coalesce(nm, 'A member') || ' staked ' || lstake || ' STR to lead this project');
end; $$;
grant execute on function claim_leadership(uuid) to authenticated;

-- ---------- admin: this month's non-compliant leaders ----------
-- One row per leader-seat on a live (non-finished) project whose first-author
-- writing for the current month falls short of the required hours.
create or replace function writing_laggards()
returns table (
  project_id   uuid,
  project_name text,
  leader_id    uuid,
  leader_name  text,
  leader_email text,
  year_month   text,
  hours        numeric,
  required     integer
) language sql stable security definer set search_path = public as $$
  select
    p.id,
    p.name,
    m.id,
    m.full_name,
    m.email,
    to_char(now(), 'YYYY-MM') as year_month,
    coalesce(w.hours, 0) as hours,
    stater_policy_int('default_first_author_writing_hours', 20) as required
  from project p
  join project_status ps on ps.id = p.status_id
  join project_member pm on pm.project_id = p.id
  join project_role pr on pr.id = pm.project_role_id and pr.can_manage
  join member m on m.id = pm.member_id
  left join lateral (
    select coalesce(sum(cp.committed_amount), 0) as hours
    from stater_project_stake_commitment c
    join stater_commitment_period cp on cp.commitment_id = c.id
    where c.project_id = p.id and c.member_id = m.id
      and c.commitment_type = 'first_author_writing'
      and cp.year_month = to_char(now(), 'YYYY-MM')
  ) w on true
  where ps.name <> 'Finished'
    and coalesce(w.hours, 0) < stater_policy_int('default_first_author_writing_hours', 20)
  order by p.name;
$$;
grant execute on function writing_laggards() to authenticated;

notify pgrst, 'reload schema';
