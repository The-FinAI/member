-- Market Phase 1 ②: governance v0.3 — permissions suspended for the officer
-- market. Any signed-in member may act; safety = openness + history +
-- reversibility. Settlement/minting REMAIN President-gated. CHANGELOG v1.3.0.
--
-- Method: composite predicates opened at the source; work_seat/assign bodies
-- are VERBATIM copies of their latest definitions with ONLY the auth block
-- swapped (STR pricing, requirement checks, capacity review all preserved).

create or replace function can_edit_member(p_member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select current_member_id() is not null;
$$;
create or replace function can_edit_project(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select current_member_id() is not null;
$$;

-- ── work_seat: verbatim from 20260614010000, gate → signed-in ──
create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int; lvl guild_level;
        need text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such slot'; end if;
  if p_year_month !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount,0) < 0 then raise exception 'amount cannot be negative'; end if;

  if current_member_id() is null then raise exception 'sign in first'; end if;

  if s.slot_kind = 'work_resource' then
    if not resource_covers_requirements(p_resource, s.requirements) then
      raise exception 'this resource does not meet the need''s requirements';
    end if;
  else
    if not member_fits_labour_slot(p_member, p_slot) then
      need := slot_skill_need_text(p_slot);
      raise exception 'member does not meet this need: requires %', coalesce(need, 'a higher skill level');
    end if;
  end if;

  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    lvl := coalesce(
      (select (rs->>'level')::guild_level
         from jsonb_array_elements(coalesce((select skills from resource where id = p_resource), '[]'::jsonb)) rs
        where rs->>'skill_id' = s.skill_id::text limit 1),
      (select b.level from badge b where b.member_id = p_member and b.skill_id = s.skill_id));
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'leader' then
    rate := coalesce(stater_policy_int('first_author_writing_rate',
                     stater_policy_int('paper_writing_rate', 10)), 10);
    nominal := ceil(rate * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'work_resource' and p_resource is not null then
    nominal := ceil(resource_value_usd(p_resource, coalesce(p_monthly_amount,0))
                    * stater_policy_num('str_per_usd', 0.2));
  end if;

  if p_resource is not null then
    select monthly_quota into cap from resource where id = p_resource;
    if cap is not null then
      select coalesce(sum(monthly_amount),0) into tot from work_commitment
       where member_id = p_member and resource_id = p_resource and year_month = p_year_month
         and slot_id is distinct from p_slot;
      if tot + coalesce(p_monthly_amount,0) > cap then appr := 'needs_review'; end if;
    end if;
  end if;

  insert into work_commitment
    (slot_id, project_id, member_id, resource_id, year_month, monthly_amount, nominal_str, approval)
  values (p_slot, s.project_id, p_member, p_resource, p_year_month,
          coalesce(p_monthly_amount,0), nominal, appr)
  on conflict (slot_id, member_id, year_month) do update
    set resource_id = excluded.resource_id,
        monthly_amount = excluded.monthly_amount,
        nominal_str = excluded.nominal_str,
        approval = case when work_commitment.approval in ('approved','rejected')
                        then work_commitment.approval else excluded.approval end
  returning id into wcid;

  role_id := (select id from project_role
              where name = case when s.slot_kind = 'leader' then 'Leader' else 'Contributor' end limit 1);
  if role_id is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (s.project_id, p_member, role_id) on conflict do nothing;
  end if;

  select count(distinct member_id) into filled from work_commitment where slot_id = p_slot;
  if filled >= s.headcount then update project_slot set status = 'filled' where id = p_slot and status = 'open'; end if;

  return wcid;
end $$;
grant execute on function work_seat(uuid, uuid, uuid, text, numeric, uuid) to authenticated;

-- ── assign: verbatim from 20260726020000, gate → signed-in ──
create or replace function assign(p_member uuid, p_slot uuid, p_hours numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; res uuid; ym text := to_char(now(), 'YYYY-MM'); freeh numeric;
        wcid uuid; pname text; what text;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such need'; end if;
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if coalesce(p_hours, 0) <= 0 then raise exception 'amount must be greater than 0'; end if;

  if s.slot_kind = 'work_resource' then
    select r.id into res from resource r
      where r.holder_member_id = p_member and r.type_id = s.resource_type_id and r.scope = 'member' limit 1;
    if res is null then raise exception 'this person holds no resource of that type'; end if;
    freeh := resource_free(res, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over quota: only % left this month', freeh; end if;
    what := coalesce((select name from resource_type where id = s.resource_type_id), 'a resource');
  else
    select r.id into res from resource r join resource_type rt on rt.id = r.type_id
      where r.holder_member_id = p_member and rt.name = 'Labor' limit 1;
    freeh := member_free_hours(p_member, ym);
    if freeh is not null and freeh < p_hours then raise exception 'over capacity: only % h free this month', freeh; end if;
    what := coalesce((select name from skill where id = s.skill_id), 'work');
  end if;

  wcid := work_seat(p_slot, p_member, res, ym, p_hours, p_member);
  select name into pname from project where id = s.project_id;
  perform notify(p_member, 'assigned',
    'You were assigned to a project', pname || ' · ' || what || ' · ' || p_hours,
    '/projects/' || s.project_id);
  return wcid;
end $$;
grant execute on function assign(uuid, uuid, numeric) to authenticated;

-- ── project ↔ WG move, archive, units, member moves — signed-in ──
create or replace function forge_claim(p_project uuid, p_wg_unit uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; req uuid;
begin
  if not exists (select 1 from org_unit where id = p_wg_unit and kind = 'working_group') then
    raise exception 'claims attach to a working group'; end if;
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if not exists (select 1 from project where id = p_project) then raise exception 'no such project'; end if;
  submitter := current_member_id();
  update project set org_unit_id = p_wg_unit where id = p_project;
  insert into forge_request (target_type, action, target_id, payload, submitted_by,
                             status, reviewed_by, review_note, settled_at)
  values ('claim', 'update', p_project,
          jsonb_build_object('project_id', p_project, 'wg_unit', p_wg_unit),
          submitter, 'approved', submitter, 'phase1 open market', now())
  returning id into req;
  return req;
end $$;
grant execute on function forge_claim(uuid, uuid) to authenticated;

create or replace function member_archive(p_member uuid, p_archived boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  update member set archived_at = case when p_archived then now() else null end
   where id = p_member;
end $$;
grant execute on function member_archive(uuid, boolean) to authenticated;

create or replace function unit_create(p_name text, p_kind text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_kind not in ('chapter','working_group') then raise exception 'kind must be chapter or working_group'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'name required'; end if;
  insert into org_unit (name, code, kind, rank)
  values (trim(p_name), upper(left(regexp_replace(trim(p_name), '[^a-zA-Z0-9]', '', 'g'), 6)), p_kind,
          coalesce((select max(rank) + 1 from org_unit), 1))
  returning id into uid;
  return uid;
end $$;
grant execute on function unit_create(text, text) to authenticated;

create or replace function member_set_home_unit(p_member uuid, p_unit uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_unit is not null and not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'home unit must be a chapter'; end if;
  update member set home_unit_id = p_unit where id = p_member;
end $$;
grant execute on function member_set_home_unit(uuid, uuid) to authenticated;

-- ── create_project_phase1: verbatim from 20260603440000, WG-officer check removed ──
create or replace function create_project_phase1(
  p_name text, p_type_id uuid, p_status_id uuid, p_wg_unit uuid default null,
  p_summary text default null, p_venue_id uuid default null, p_proposal_url text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid; pid uuid; vname text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'project name required'; end if;

  vname := (select name from venue where id = p_venue_id);
  insert into project (name, type_id, status_id, org_unit_id, target_venue, venue_id, summary, created_by)
  values (trim(p_name), p_type_id, p_status_id, p_wg_unit, vname, p_venue_id, p_summary, me)
  returning id into pid;
  perform stater_project_acc(pid);

  insert into project_slot (project_id, slot_kind, authorship, status, headcount)
  values (pid, 'leader', 'first', 'open', 1);

  if p_proposal_url is not null and length(trim(p_proposal_url)) > 0 then
    insert into project_link (project_id, kind, title, url, added_by)
    values (pid, 'proposal', 'Proposal', trim(p_proposal_url), me);
  end if;
  return pid;
end $$;
grant execute on function create_project_phase1(text, uuid, uuid, uuid, text, uuid, text) to authenticated;

-- ── forge_member_card: verbatim from 20260602202000; gate → signed-in, and a
--    card may be forged without a chapter (home_unit_id null → “未加入分会”) ──
create or replace function forge_member_card(
  p_full_name text, p_email text, p_unit uuid,
  p_affiliation text default null, p_badges jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; new_id uuid; bid uuid := gen_random_uuid(); it record; act text;
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if p_unit is not null and not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'cards belong to a chapter, not a working group';
  end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'full_name required'; end if;
  if coalesce(trim(p_email), '')     = '' then raise exception 'email required (used to claim the card later)'; end if;

  minter := current_member_id();
  insert into member (full_name, email, affiliation, kind, home_unit_id, status)
  values (trim(p_full_name), lower(trim(p_email)), p_affiliation, 'card', p_unit, 'invited')
  returning id into new_id;

  for it in select * from jsonb_to_recordset(coalesce(p_badges, '[]'::jsonb)) as x(skill uuid, level guild_level) loop
    if it.skill is null or it.level is null then continue; end if;
    if not exists (select 1 from skill where id = it.skill) then continue; end if;
    if exists (select 1 from skill where parent_id = it.skill) then continue; end if;
    act := case when exists (select 1 from badge b where b.member_id = new_id and b.skill_id = it.skill)
                then 'update' else 'create' end;
    insert into forge_request (target_type, action, target_id, payload, batch_id, fee, submitted_by, status)
    values ('badge', act, new_id,
            jsonb_build_object('member_id', new_id, 'skill_id', it.skill, 'target_level', it.level),
            bid, 0, minter, 'submitted');
  end loop;

  return new_id;
end $$;
grant execute on function forge_member_card(text, text, uuid, text, jsonb) to authenticated;

-- ── account linking: surface auth accounts with no member, and link them ──
create or replace function orphan_accounts()
returns table(account_id uuid, email text)
language sql stable security definer set search_path = public as $$
  select u.id, u.email::text from auth.users u
  where current_member_id() is not null
    and not exists (select 1 from member m where m.auth_user_id = u.id);
$$;
grant execute on function orphan_accounts() to authenticated;

create or replace function member_link_account(p_member uuid, p_account uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if current_member_id() is null then raise exception 'sign in first'; end if;
  if exists (select 1 from member where auth_user_id = p_account) then
    raise exception 'that account is already linked to a member'; end if;
  if (select auth_user_id from member where id = p_member) is not null then
    raise exception 'that member is already linked to an account'; end if;
  update member set auth_user_id = p_account,
         status = case when status = 'invited' then 'active' else status end,
         kind = case when kind = 'card' then 'operator' else kind end
   where id = p_member;
end $$;
grant execute on function member_link_account(uuid, uuid) to authenticated;
