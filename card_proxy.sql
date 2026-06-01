-- ============================================================
-- Phase 1 card proxy: let a chapter officer act on behalf of a card.
--
-- Builds on card_membership.sql (org units, member.kind/home_unit_id,
-- manages_card(), effective_member()).  Every member-scoped action RPC
-- gains an optional p_as card argument and resolves the acting member via
-- effective_member(p_as): yourself, or a card you manage.  Money always
-- moves from / accrues to that resolved member (the card), never the
-- operator — so value stays custodial to the card (claimed later by the
-- person).  Also: an officer "manages" a project a card of theirs leads,
-- so they can post needs / accept applicants for card-led projects.
-- Idempotent: safe to re-run.  Apply AFTER card_membership.sql.
-- ============================================================

-- ---------- 0. an officer manages a project led by a card they manage ----------
create or replace function manages_project(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    -- I personally hold a managing role on this project
    select 1
    from member m
    join project_member pm on pm.member_id = m.id
    join project_role  pr on pr.id = pm.project_role_id
    where m.auth_user_id = auth.uid()
      and pm.project_id = p
      and pr.can_manage
  )
  or exists (
    -- or a card I manage holds a managing role on this project
    select 1
    from project_member pm
    join project_role pr on pr.id = pm.project_role_id
    where pm.project_id = p
      and pr.can_manage
      and manages_card(pm.member_id)
  );
$$;

-- ---------- 1. monthly mint: labor (proxy-aware) ----------
drop function if exists set_labor_commitment(uuid, uuid, text, numeric);
create or replace function set_labor_commitment(p uuid, sk uuid, ym text, hours numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; rate integer; equiv integer;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if sk is null then raise exception 'a labor commitment needs a skill'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if hours < 0 then raise exception 'hours cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing labor';
  end if;

  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'labor' and skill_id = sk
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, skill_id, status)
    values (p, me, 'labor', sk, 'verified') returning id into cid;
  end if;

  rate  := coalesce((select s.rate from stater_skill_rate s where s.skill_id = sk),
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
grant execute on function set_labor_commitment(uuid, uuid, text, numeric, uuid) to authenticated;

-- ---------- 2. monthly mint: resource (proxy-aware) ----------
drop function if exists set_resource_commitment(uuid, uuid, text, numeric);
create or replace function set_resource_commitment(p uuid, res uuid, ym text, qty numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; cid uuid; usd numeric; equiv integer; appr text; holder uuid; scp text;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if res is null then raise exception 'a resource commitment needs a resource'; end if;
  if ym !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if qty < 0 then raise exception 'quantity cannot be negative'; end if;
  if not exists (select 1 from project_member where project_id = p and member_id = me) then
    raise exception 'join the project before committing a resource';
  end if;

  select approval_status, holder_member_id, scope into appr, holder, scp from resource where id = res;
  if appr is null then raise exception 'resource not found'; end if;
  if appr <> 'approved' then raise exception 'resource is not approved yet'; end if;
  if scp = 'member' and holder is not null and holder <> me then
    raise exception 'only the resource holder can commit it';
  end if;

  select id into cid from stater_project_stake_commitment
   where project_id = p and member_id = me and commitment_type = 'resource' and resource_id = res
   limit 1;
  if cid is null then
    insert into stater_project_stake_commitment
      (project_id, member_id, commitment_type, resource_id, status)
    values (p, me, 'resource', res, 'verified') returning id into cid;
  end if;

  usd   := resource_value_usd(res, qty);
  equiv := ceil(usd * stater_policy_num('str_per_usd', 0.2));

  insert into stater_commitment_period (commitment_id, year_month, committed_amount, token_equivalent, status)
  values (cid, ym, qty, equiv, 'minted')
  on conflict (commitment_id, year_month)
  do update set committed_amount = excluded.committed_amount,
                token_equivalent = excluded.token_equivalent,
                status = 'minted';
  return cid;
end; $$;
grant execute on function set_resource_commitment(uuid, uuid, text, numeric, uuid) to authenticated;

-- ---------- 3. claim leadership (proxy-aware; gate checks the card) ----------
drop function if exists claim_leadership(uuid);
create or replace function claim_leadership(p uuid, p_as uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; lstake integer; lrole uuid; bal numeric; esc uuid; nm text;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if not member_meets_leader_reqs(me) then
    raise exception 'leader requirements not met: certify English, Academic Writing and Project Management to the required guild level before leading a project';
  end if;

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
grant execute on function claim_leadership(uuid, uuid) to authenticated;

-- ---------- 4. create project with leader stake (proxy-aware) ----------
drop function if exists create_project_with_leader_stake(text, uuid, uuid, text, text, integer, uuid, text);
create or replace function create_project_with_leader_stake(
  p_name text, p_type_id uuid, p_status_id uuid, p_venue text, p_summary text,
  p_stake integer default null, p_venue_id uuid default null, p_proposal_url text default null,
  p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; esc uuid; lstake integer; lrole uuid; vname text;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if not member_meets_leader_reqs(me) then
    raise exception 'leader requirements not met: certify English, Academic Writing and Project Management to the required guild level before leading a project';
  end if;
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
grant execute on function create_project_with_leader_stake(text, uuid, uuid, text, text, integer, uuid, text, uuid) to authenticated;

-- ---------- 5. apply to a need (proxy-aware) ----------
-- Operators self-apply; officers may apply on behalf of a card they manage.
create or replace function apply_to_need(p_need uuid, p_message text default null, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; app_id uuid;
begin
  me := effective_member(p_as);
  if me is null then raise exception 'no member record'; end if;
  if not exists (select 1 from open_need where id = p_need and status = 'open') then
    raise exception 'need is not open';
  end if;
  insert into need_application (open_need_id, member_id, message)
  values (p_need, me, nullif(trim(coalesce(p_message, '')), ''))
  on conflict (open_need_id, member_id) do update set message = excluded.message
  returning id into app_id;
  return app_id;
end; $$;
grant execute on function apply_to_need(uuid, text, uuid) to authenticated;

-- ---------- 6. confirm join (proxy-aware) ----------
drop function if exists confirm_join(uuid);
create or replace function confirm_join(app_id uuid, p_as uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid; rid uuid; nid uuid; hc integer; js integer; bal numeric; joined_cnt integer;
begin
  select n.project_id, na.member_id, n.project_role_id, n.id, n.headcount
    into pid, mid, rid, nid, hc
  from need_application na join open_need n on n.id = na.open_need_id
  where na.id = app_id and na.status = 'accepted';
  if mid is null then raise exception 'no accepted application to confirm'; end if;
  if mid <> effective_member(p_as) then raise exception 'not your application'; end if;

  js := coalesce(
    (select join_stake from project_type t join project pr on pr.type_id = t.id where pr.id = pid),
    stater_policy_int('join_stake_normal', 20));
  select coalesce(balance, 0) into bal from stater_balance where owner_member_id = mid;
  if coalesce(bal, 0) < js then
    raise exception 'insufficient STR balance: joining stakes %, you have %', js, coalesce(bal, 0);
  end if;

  update need_application set status = 'joined' where id = app_id;
  perform _stater_seat(pid, mid, rid, 'join_token', js, 0, null, null, null);

  select count(*) into joined_cnt from need_application where open_need_id = nid and status = 'joined';
  if joined_cnt >= hc then
    update open_need set status = 'filled' where id = nid;
  end if;
end; $$;
grant execute on function confirm_join(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
