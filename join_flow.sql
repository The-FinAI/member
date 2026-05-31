-- ============================================================
-- Join flow (user-story aligned):
--   1. Member applies to an open need (free, optional pitch).
--   2. Leader accepts  -> extends a SEAT OFFER (no charge yet).
--   3. Member confirms -> stakes the join bond and is seated.
-- Plus: a need auto-fills (closes) once its headcount is reached.
-- ============================================================

-- Acceptance no longer seats/charges; it just extends the offer.
create or replace function accept_application(app_id uuid, role_id uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select n.project_id into pid
  from need_application na join open_need n on n.id = na.open_need_id
  where na.id = app_id;
  if pid is null then raise exception 'application not found'; end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then
    raise exception 'not authorized';
  end if;
  update need_application set status = 'accepted' where id = app_id and status = 'pending';
end; $$;

-- Member confirms an accepted offer: stake the join bond, take the seat.
create or replace function confirm_join(app_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid; rid uuid; nid uuid; hc integer; js integer; bal numeric; joined_cnt integer;
begin
  select n.project_id, na.member_id, n.project_role_id, n.id, n.headcount
    into pid, mid, rid, nid, hc
  from need_application na join open_need n on n.id = na.open_need_id
  where na.id = app_id and na.status = 'accepted';
  if mid is null then raise exception 'no accepted application to confirm'; end if;
  if mid <> current_member_id() then raise exception 'not your application'; end if;

  js := coalesce(
    (select join_stake from project_type t join project pr on pr.type_id = t.id where pr.id = pid),
    stater_policy_int('join_stake_normal', 20));
  select coalesce(balance, 0) into bal from stater_balance where owner_member_id = mid;
  if coalesce(bal, 0) < js then
    raise exception 'insufficient STR balance: joining stakes %, you have %', js, coalesce(bal, 0);
  end if;

  update need_application set status = 'joined' where id = app_id;
  perform _stater_seat(pid, mid, rid, 'join_token', js, 0, null, null, null);

  -- auto-fill the need once enough members have joined
  select count(*) into joined_cnt from need_application where open_need_id = nid and status = 'joined';
  if joined_cnt >= hc then
    update open_need set status = 'filled' where id = nid;
  end if;
end; $$;

grant execute on function accept_application(uuid, uuid) to authenticated;
grant execute on function confirm_join(uuid) to authenticated;

notify pgrst, 'reload schema';
