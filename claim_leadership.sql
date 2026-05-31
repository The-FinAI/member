-- ============================================================
-- Claim leadership of a leaderless project.
-- If a project has no managing member (no can_manage role seated),
-- any member may stake the leader bond to take the lead seat.
-- Mirrors create_project_with_leader_stake's leader seating.
-- ============================================================
create or replace function claim_leadership(p uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; lstake integer; lrole uuid; bal numeric; esc uuid; nm text;
begin
  me := current_member_id();
  if me is null then raise exception 'no member record'; end if;

  -- refuse if the project already has a managing leader
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

  -- promote an existing member, or seat a new one, as Leader
  if exists (select 1 from project_member where project_id = p and member_id = me) then
    update project_member set project_role_id = lrole where project_id = p and member_id = me;
  else
    insert into project_member (project_id, member_id, project_role_id) values (p, me, lrole);
  end if;

  insert into stater_project_stake_commitment
    (project_id, member_id, commitment_type, token_amount, status, verified_by, verified_at)
  values (p, me, 'leader_initiation', lstake, 'verified', me, now());

  select full_name into nm from member where id = me;
  insert into project_event (project_id, actor_member_id, event_type, summary)
  values (p, me, 'member_joined', coalesce(nm, 'A member') || ' staked ' || lstake || ' STR to lead this project');
end; $$;

grant execute on function claim_leadership(uuid) to authenticated;

notify pgrst, 'reload schema';
