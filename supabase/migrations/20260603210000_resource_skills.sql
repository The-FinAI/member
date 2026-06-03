-- ============================================================
-- Skills on a resource (the custody channel).
--
-- A labour/time resource can be STEWARDED — its holder card isn't necessarily
-- the person whose expertise the hours represent (e.g. an officer holds an
-- external expert's hours). So a resource declares the skills it can fill,
-- decoupled from the holder's badges. At seating, a work_labor need's skill is
-- satisfied if the member holds the badge OR the committed resource lists the
-- skill — so stewarded expert hours qualify even with no badge on the card.
--
-- resource.skills = jsonb array of skill_id strings. Idempotent.
-- ============================================================

alter table resource add column if not exists skills jsonb not null default '[]'::jsonb;

-- does a committed resource declare every skill a need requires?
create or replace function resource_covers_requirements(p_resource uuid, p_reqs jsonb)
returns boolean language sql stable security definer set search_path = public as $$
  select p_resource is not null and not exists (
    select 1 from jsonb_array_elements(coalesce(p_reqs, '[]'::jsonb)) r
    where not (coalesce((select skills from resource where id = p_resource), '[]'::jsonb) ? (r->>'skill_id'))
  );
$$;
grant execute on function resource_covers_requirements(uuid, jsonb) to authenticated;

-- forge_resource: now carries the resource's skills
create or replace function forge_resource(
  p_type uuid, p_name text, p_holder uuid, p_scope text, p_monthly_quota numeric,
  p_unit text default null, p_usd_per_unit numeric default null, p_str_per_unit numeric default null,
  p_skills jsonb default '[]'::jsonb)
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
  insert into resource (type_id, name, scope, holder_member_id, monthly_quota, unit, usd_per_unit, str_per_unit, skills)
  values (p_type, trim(p_name), p_scope, p_holder, p_monthly_quota, p_unit, p_usd_per_unit, p_str_per_unit,
          coalesce(p_skills, '[]'::jsonb))
  returning id into rid;

  insert into forge_request (target_type, action, target_id, payload, submitted_by, status)
  values ('resource', 'create', rid,
          jsonb_build_object('name', trim(p_name), 'scope', p_scope, 'holder_member_id', p_holder,
                             'monthly_quota', p_monthly_quota, 'skills', coalesce(p_skills,'[]'::jsonb)),
          submitter, 'submitted')
  returning id into req;
  update resource set forge_request_id = req where id = rid;
  return req;
end $$;
grant execute on function forge_resource(uuid, text, uuid, text, numeric, text, numeric, numeric, jsonb) to authenticated;

-- work_seat: the skill gate now accepts the committed resource's skills too
create or replace function work_seat(
  p_slot uuid, p_member uuid, p_resource uuid, p_year_month text,
  p_monthly_amount numeric, p_as uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare s project_slot; nominal int := 0; rate int; cap numeric; tot numeric;
        appr text := 'ok'; role_id uuid; wcid uuid; filled int; lvl guild_level;
begin
  select * into s from project_slot where id = p_slot;
  if s.id is null then raise exception 'no such slot'; end if;
  if p_year_month !~ '^\d{4}-\d{2}$' then raise exception 'year_month must be YYYY-MM'; end if;
  if coalesce(p_monthly_amount,0) < 0 then raise exception 'amount cannot be negative'; end if;

  if not (manages_card(p_member) or has_capability('manage_members')
          or has_capability('edit_any_project')) then
    raise exception 'not authorized to seat this member';
  end if;

  -- skill gate: the member's badges OR the committed resource's declared skills
  if not (member_meets_requirements(p_member, s.requirements)
          or resource_covers_requirements(p_resource, s.requirements)) then
    raise exception 'member does not meet this slot''s skill requirements';
  end if;

  if s.slot_kind = 'work_labor' then
    rate := coalesce((select sr.rate from stater_skill_rate sr where sr.skill_id = s.skill_id),
                     stater_policy_int('paper_writing_rate', 10));
    lvl := (select b.level from badge b where b.member_id = p_member and b.skill_id = s.skill_id);
    nominal := ceil(rate
                    * stater_policy_num('skill_level_mult_' || coalesce(lvl::text, 'apprentice'), 1.0)
                    * coalesce(p_monthly_amount,0));
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

notify pgrst, 'reload schema';
