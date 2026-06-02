-- =====================================================================
-- Let unit officers review their own members' over-capacity commitments.
--
-- The consolidated approval portal already routes most queues to a
-- capability (manage_resources, review_skillcard, …). Over-capacity
-- monthly commitments, though, belong to the officer who runs the
-- member's chapter / working group — that was the original "officer
-- approval list" intent. This opens commitment review to an officer of
-- the member's unit, in addition to the manage_* capability holders.
--
-- Other queues (milestones, resources, role cards) stay capability-gated.
-- Builds on commitment_capacity_approval.sql. Idempotent.
-- =====================================================================

-- ---------- 1. is the current user an officer of a member's unit? ----------
-- True when the caller holds an active officer seat on any unit the member
-- belongs to — their chapter home, or any working group they actively join.
create or replace function is_unit_officer_of(p_member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from org_unit_officer o
    where o.member_id = current_member_id()
      and o.ended_on is null
      and (
        o.org_unit_id = (select home_unit_id from member where id = p_member)
        or o.org_unit_id in (
          select org_unit_id from org_unit_member
          where member_id = p_member and status = 'active')
      )
  );
$$;
grant execute on function is_unit_officer_of(uuid) to authenticated;

-- ---------- 2. review RPC: capability holder OR the member's unit officer --
create or replace function review_commitment_period(p_period uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare owner_member uuid;
begin
  select c.member_id into owner_member
  from stater_commitment_period cp
  join stater_project_stake_commitment c on c.id = cp.commitment_id
  where cp.id = p_period;
  if owner_member is null then raise exception 'commitment period not found'; end if;

  if not (
       has_capability('manage_stater')
    or has_capability('manage_resources')
    or has_capability('manage_members')
    or is_unit_officer_of(owner_member)
  ) then
    raise exception 'not authorized to review commitments';
  end if;

  if p_approve then
    update stater_commitment_period
       set approval = 'approved', status = 'minted'
     where id = p_period;
  else
    -- discounted leaves the nominal pool (pool sums status = 'minted' only)
    update stater_commitment_period
       set approval = 'rejected', status = 'discounted'
     where id = p_period;
  end if;
end; $$;
grant execute on function review_commitment_period(uuid, boolean) to authenticated;

-- ---------- 3. queue view filters rows to what the caller may act on -------
-- Admins / capability holders see every needs_review row; an officer sees
-- only their own unit members'. (The view runs the auth checks per row, so
-- the frontend can select it directly without leaking other units' data.)
create or replace view commitment_review_queue as
select cp.id              as period_id,
       cp.year_month,
       cp.committed_amount,
       cp.token_equivalent,
       cp.approval,
       cp.status,
       c.commitment_type,
       c.project_id,
       pr.name            as project_name,
       c.member_id,
       m.full_name        as member_name,
       c.skill_id,
       sk.name            as skill_name,
       c.resource_id,
       rs.name            as resource_name,
       case c.commitment_type
         when 'labor'    then member_labor_cap(c.member_id)
         when 'resource' then resource_capacity_num(c.resource_id)
       end                as capacity,
       case c.commitment_type
         when 'labor' then (
           select coalesce(sum(cp2.committed_amount), 0)
           from stater_commitment_period cp2
           join stater_project_stake_commitment c2 on c2.id = cp2.commitment_id
           where c2.member_id = c.member_id and c2.commitment_type = 'labor'
             and cp2.year_month = cp.year_month)
         when 'resource' then (
           select coalesce(sum(cp2.committed_amount), 0)
           from stater_commitment_period cp2
           join stater_project_stake_commitment c2 on c2.id = cp2.commitment_id
           where c2.member_id = c.member_id and c2.commitment_type = 'resource'
             and c2.resource_id = c.resource_id and cp2.year_month = cp.year_month)
       end                as month_total
from stater_commitment_period cp
join stater_project_stake_commitment c on c.id = cp.commitment_id
join project pr on pr.id = c.project_id
join member  m  on m.id  = c.member_id
left join skill    sk on sk.id = c.skill_id
left join resource rs on rs.id = c.resource_id
where cp.approval = 'needs_review'
  and (
       has_capability('manage_stater')
    or has_capability('manage_resources')
    or has_capability('manage_members')
    or is_unit_officer_of(c.member_id)
  );

grant select on commitment_review_queue to authenticated;

notify pgrst, 'reload schema';
