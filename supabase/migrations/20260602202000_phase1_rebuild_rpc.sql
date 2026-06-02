-- =====================================================================
-- Phase 1 REBUILD — RPC layer (concept-named verbs over the new schema)
-- Design doc: docs/phase1-rebuild.md §RPC 表面
-- Depends on: 20260602201500_phase1_rebuild.sql (badge, forge_request,
--   project_slot, work_commitment, resource.monthly_quota) and the existing
--   gating helpers (has_capability, is_chapter_officer, is_unit_officer,
--   manages_project, manages_card, effective_member, current_member_id) +
--   STR helpers (stater_member_acc, stater_skill_rate, resource_value_usd,
--   stater_policy_int/num, guild_level_rank).
--
-- Verbs: Forge (inject) → Work (consume) → Settle (realise).
--   forge_member_card / forge_badge(s) / forge_resource / forge_need /
--   forge_claim / forge_project_done   — create/update + review
--   review_forge                        — ONE approval entry point
--   work_seat / review_capacity         — enter slot + over-capacity queue
--   submit_settlement / approve_settlement (KEEP, unchanged)
-- Idempotent: create or replace.  Apply AFTER the rebuild DDL migration.
-- =====================================================================

begin;

-- =====================================================================
-- FORGE — member card (Agent): create the card + stage badges as a batch
-- =====================================================================
create or replace function forge_member_card(
  p_full_name text, p_email text, p_unit uuid,
  p_affiliation text default null, p_badges jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare minter uuid; new_id uuid; bid uuid := gen_random_uuid(); it record; act text;
begin
  if not (is_chapter_officer(p_unit) or has_capability('manage_members')) then
    raise exception 'only a chapter chair/secretary (or member-manager) can forge cards';
  end if;
  if not exists (select 1 from org_unit where id = p_unit and kind = 'chapter') then
    raise exception 'cards belong to a chapter, not a working group';
  end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'full_name required'; end if;
  if coalesce(trim(p_email), '')     = '' then raise exception 'email required (used to claim the card later)'; end if;

  minter := current_member_id();
  insert into member (full_name, email, affiliation, kind, home_unit_id, status)
  values (trim(p_full_name), lower(trim(p_email)), p_affiliation, 'card', p_unit, 'invited')
  returning id into new_id;

  -- stage picked badges as ONE forge batch awaiting review (leaves only, fee 0)
  for it in select * from jsonb_to_recordset(coalesce(p_badges, '[]'::jsonb)) as x(skill uuid, level guild_level) loop
    if it.skill is null or it.level is null then continue; end if;
    if not exists (select 1 from skill where id = it.skill) then continue; end if;
    if exists (select 1 from skill where parent_id = it.skill) then continue; end if;  -- leaf only
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

-- =====================================================================
-- FORGE — badge (single + batch).  Submits a forge_request for review.
-- =====================================================================
create or replace function forge_badge(p_member uuid, p_skill uuid, p_level guild_level, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; act text; have guild_level; req uuid;
begin
  if not (manages_card(p_member) or has_capability('manage_members') or has_capability('mint_skillcard')) then
    raise exception 'not authorized to forge a badge for this member';
  end if;
  if not exists (select 1 from skill where id = p_skill) then raise exception 'no such skill'; end if;
  if exists (select 1 from skill where parent_id = p_skill) then
    raise exception 'badges are forged on leaf skills, not domains';
  end if;
  select level into have from badge where member_id = p_member and skill_id = p_skill;
  if have is not null and guild_level_rank(have) >= guild_level_rank(p_level) then
    raise exception 'this badge is already at % or higher', have;
  end if;
  act := case when have is null then 'create' else 'update' end;
  submitter := current_member_id();
  insert into forge_request (target_type, action, target_id, payload, fee, submitted_by, submitted_as, status)
  values ('badge', act, p_member,
          jsonb_build_object('member_id', p_member, 'skill_id', p_skill, 'target_level', p_level),
          0, submitter, p_as, 'submitted')
  returning id into req;
  return req;
end $$;
grant execute on function forge_badge(uuid, uuid, guild_level, uuid) to authenticated;

-- batch: stage many badges for one member under a single batch_id
create or replace function forge_badges(p_member uuid, p_items jsonb, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; bid uuid := gen_random_uuid(); it record; act text; n int := 0;
begin
  if not (manages_card(p_member) or has_capability('manage_members') or has_capability('mint_skillcard')) then
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

-- =====================================================================
-- FORGE — resource (monthly-quota custody card).  Creates the resource +
-- a submitted forge_request; approval flips resource.approval_status.
-- =====================================================================
create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; rid uuid; req uuid;
begin
  if not (has_capability('manage_resources') or manages_card(p_holder)
          or (p_holder = current_member_id())) then
    raise exception 'not authorized to forge this resource';
  end if;
  if p_scope not in ('member','community') then raise exception 'scope must be member|community'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'resource name required'; end if;
  if p_holder is null then raise exception 'a resource needs an in-community holder'; end if;
  if p_monthly_quota is null or p_monthly_quota < 0 then raise exception 'monthly_quota must be >= 0'; end if;

  submitter := current_member_id();
  -- the approval-guard trigger forces non-stewards to 'pending'; review flips it.
  insert into resource (type_id, name, scope, holder_member_id, monthly_quota, unit, usd_per_unit, str_per_unit)
  values (p_type, trim(p_name), p_scope, p_holder, p_monthly_quota, p_unit, p_usd_per_unit, p_str_per_unit)
  returning id into rid;

  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('resource', 'create', rid,
          jsonb_build_object('name', trim(p_name), 'scope', p_scope, 'holder_member_id', p_holder,
                             'monthly_quota', p_monthly_quota),
          submitter, 'submitted')
  returning id into req;
  update resource set forge_request_id = req where id = rid;
  return req;
end $$;
grant execute on function forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric) to authenticated;

-- =====================================================================
-- FORGE — need (post a slot).  Submitted for review; approval creates the
-- project_slot.  Authorship derives from slot_kind.
-- =====================================================================
create or replace function forge_need(
  p_project uuid, p_slot_kind text, p_req_access guild_level default null,
  p_skill uuid default null, p_resource_type uuid default null,
  p_quota numeric default null, p_headcount int default 1)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; wg uuid; req uuid;
begin
  if p_slot_kind not in ('work_labor','work_resource') then
    raise exception 'a need is work_labor or work_resource (leader slot is intrinsic)';
  end if;
  select org_unit_id into wg from project where id = p_project;
  if not (manages_project(p_project) or has_capability('edit_any_project')
          or (wg is not null and is_unit_officer(wg))) then
    raise exception 'only the project lead or its working-group officer can post a need';
  end if;
  submitter := current_member_id();
  insert into forge_request (target_type, action, payload, submitted_by, status)
  values ('need', 'create',
          jsonb_build_object('project_id', p_project, 'slot_kind', p_slot_kind,
                             'req_access', p_req_access, 'skill_id', p_skill,
                             'resource_type_id', p_resource_type, 'quota', p_quota,
                             'headcount', coalesce(p_headcount,1)),
          submitter, 'submitted')
  returning id into req;
  return req;
end $$;
grant execute on function forge_need(uuid, text, guild_level, uuid, uuid, numeric, int) to authenticated;

-- =====================================================================
-- FORGE — claim (set project.org_unit_id).  Self-serve, IMMEDIATE approve.
-- =====================================================================
create or replace function forge_claim(p_project uuid, p_wg_unit uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; req uuid;
begin
  if not exists (select 1 from org_unit where id = p_wg_unit and kind = 'working_group') then
    raise exception 'claims attach to a working group';
  end if;
  if not (is_unit_officer(p_wg_unit) or has_capability('edit_any_project')) then
    raise exception 'only a leader of this working group can claim a project';
  end if;
  if not exists (select 1 from project where id = p_project) then raise exception 'no such project'; end if;

  submitter := current_member_id();
  update project set org_unit_id = p_wg_unit where id = p_project;  -- immediate
  insert into forge_request (target_type, action, target_id, payload, submitted_by,
                             status, reviewed_by, review_note, settled_at)
  values ('claim', 'update', p_project,
          jsonb_build_object('project_id', p_project, 'wg_unit', p_wg_unit),
          submitter, 'approved', submitter, 'self-serve immediate claim', now())
  returning id into req;
  return req;
end $$;
grant execute on function forge_claim(uuid, uuid) to authenticated;

-- =====================================================================
-- FORGE — project_done (mint).  Submitted for review; approval marks the
-- project Finished, which gates Settle (submit/approve_settlement).
-- =====================================================================
create or replace function forge_project_done(p_project uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare submitter uuid; wg uuid; req uuid;
begin
  select org_unit_id into wg from project where id = p_project;
  if not (manages_project(p_project) or has_capability('edit_any_project')
          or (wg is not null and is_unit_officer(wg))) then
    raise exception 'only the project lead or its working-group officer can mint completion';
  end if;
  submitter := current_member_id();
  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('project_done', 'update', p_project, jsonb_build_object('project_id', p_project), submitter, 'submitted')
  returning id into req;
  return req;
end $$;
grant execute on function forge_project_done(uuid) to authenticated;

-- =====================================================================
-- REVIEW_FORGE — ONE approval entry point; dispatches by target_type.
-- =====================================================================
create or replace function review_forge(p_request uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r forge_request; reviewer uuid; fin uuid; sid uuid;
begin
  select * into r from forge_request where id = p_request;
  if r.id is null then raise exception 'no such forge request'; end if;
  if r.status <> 'submitted' then raise exception 'request is not open for review'; end if;
  reviewer := current_member_id();

  -- per-type authorization
  if r.target_type = 'badge' then
    if not (has_capability('review_skillcard') or has_capability('manage_members')) then
      raise exception 'requires review_skillcard'; end if;
  elsif r.target_type = 'resource' then
    if not has_capability('manage_resources') then raise exception 'requires manage_resources'; end if;
  elsif r.target_type in ('need','project_done') then
    if not (has_capability('edit_any_project') or has_capability('manage_stater')
            or is_unit_officer((select org_unit_id from project where id = r.target_id))
            or is_unit_officer((r.payload->>'project_id')::uuid)) then
      raise exception 'requires project/working-group authority'; end if;
  elsif r.target_type = 'member_card' then
    if not has_capability('manage_members') then raise exception 'requires manage_members'; end if;
  else
    if not has_capability('manage_members') then raise exception 'not authorized'; end if;
  end if;

  if p_approve then
    if r.target_type = 'badge' then
      insert into badge (member_id, skill_id, level, forge_request_id)
      values ((r.payload->>'member_id')::uuid, (r.payload->>'skill_id')::uuid,
              (r.payload->>'target_level')::guild_level, r.id)
      on conflict (member_id, skill_id) do update
        set level = greatest(badge.level, excluded.level), forge_request_id = excluded.forge_request_id;

    elsif r.target_type = 'resource' then
      update resource set approval_status = 'approved', forge_request_id = r.id where id = r.target_id;

    elsif r.target_type = 'need' then
      insert into project_slot
        (project_id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, authorship, status, created_via)
      values ((r.payload->>'project_id')::uuid, r.payload->>'slot_kind',
              nullif(r.payload->>'req_access','')::guild_level,
              nullif(r.payload->>'skill_id','')::uuid,
              nullif(r.payload->>'resource_type_id','')::uuid,
              nullif(r.payload->>'quota','')::numeric,
              coalesce(nullif(r.payload->>'headcount','')::int, 1),
              case when r.payload->>'slot_kind' = 'work_resource' then 'last_candidate' else 'co' end,
              'open', r.id)
      returning id into r.target_id;

    elsif r.target_type = 'project_done' then
      select id into fin from project_status where name = 'Finished' limit 1;
      if fin is not null then update project set status_id = fin where id = r.target_id; end if;
    end if;
  else
    -- reject: refund any escrowed fee to the card
    if r.fee > 0 and r.target_id is not null then
      perform stater_move(stater_treasury(), stater_member_acc(r.target_id), r.fee, 'forge_refund',
                          'forge request rejected — fee refunded', null, null, null, reviewer);
    end if;
  end if;

  update forge_request
     set status = case when p_approve then 'approved' else 'rejected' end,
         target_id = r.target_id,
         reviewed_by = reviewer,
         review_note = nullif(btrim(coalesce(p_note,'')), ''),
         settled_at = now()
   where id = p_request;
end $$;
grant execute on function review_forge(uuid, boolean, text) to authenticated;

-- =====================================================================
-- WORK — seat a card into a slot + the month's commitment (nominal mint).
-- Over-capacity (vs resource.monthly_quota) flags 'needs_review'.
-- =====================================================================
create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such slot'; end if;
  if p_year_month !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount,0) < 0 then raise exception 'amount cannot be negative'; end if;

  -- chapter officer pushes a card they manage (consent is offline in Phase 1)
  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project')) then
    raise exception 'not authorized to seat this member';
  end if;

  -- badge gate: card must meet the slot's required access level
  if s.req_access is not null and s.skill_id is not null then
    if coalesce((select guild_level_rank(level) from badge where member_id = p_member and skill_id = s.skill_id), 0)
       < guild_level_rank(s.req_access) then
      raise exception 'member lacks the required badge level for this slot';
    end if;
  end if;

  -- nominal STR for the month
  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    nominal := ceil(rate * coalesce(p_monthly_amount,0));
  elsif s.slot_kind = 'work_resource' and p_resource is not null then
    nominal := ceil(resource_value_usd(p_resource, coalesce(p_monthly_amount,0))
                    * stater_policy_num('str_per_usd', 0.2));
  end if;

  -- capacity check against the committing resource's monthly_quota
  if p_resource is not null then
    select monthly_quota into cap from resource where id = p_resource;
    if cap is not null then
      select coalesce(sum(monthly_amount),0) into tot from work_commitment
       where member_id = p_member and resource_id = p_resource and year_month = p_year_month
         and slot_id is distinct from p_slot;  -- exclude this slot's prior row (upsert)
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

  -- keep legacy project_member in sync (settlement + roster read it)
  role_id := (select id from project_role
              where name = case when s.slot_kind = 'leader' then 'Leader' else 'Contributor' end limit 1);
  if role_id is not null then
    insert into project_member (project_id, member_id, project_role_id)
    values (s.project_id, p_member, role_id) on conflict do nothing;
  end if;

  -- mark the slot filled once headcount is met
  select count(distinct member_id) into filled from work_commitment where slot_id = p_slot;
  if filled >= s.headcount then update project_slot set status = 'filled' where id = p_slot and status = 'open'; end if;

  return wcid;
end $$;
grant execute on function work_seat(uuid, uuid, uuid, text, numeric, uuid) to authenticated;

-- =====================================================================
-- REVIEW_CAPACITY — officer decision on an over-capacity commitment.
-- approve = keep the nominal; reject = excluded from the nominal pool.
-- =====================================================================
create or replace function review_capacity(p_commitment uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (has_capability('manage_stater') or has_capability('manage_resources')
          or has_capability('manage_members')) then
    raise exception 'not authorized to review capacity';
  end if;
  update work_commitment
     set approval = case when p_approve then 'approved' else 'rejected' end
   where id = p_commitment;
end $$;
grant execute on function review_capacity(uuid, boolean) to authenticated;

commit;

notify pgrst, 'reload schema';
