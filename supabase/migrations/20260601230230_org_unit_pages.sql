-- ============================================================
-- Org-unit pages: each chapter / working group gets a public page
-- showing its info, officers, members, (WG) projects — plus a
-- join-by-application flow that the unit's officers approve.
--
-- Adds:
--   * org_unit.description          (free-text "about this unit")
--   * org_unit_member               (who belongs / has applied)
--   * is_unit_officer(p_unit)        any serving officer OR manage_members
--   * apply_to_unit(p_unit)          self -> pending application
--   * leave_unit(p_unit)             self -> left
--   * decide_unit_member(...)        officer/admin approve|reject
--   * officer_add_unit_member(...)   officer/admin add someone directly
--   * update_org_unit(...)           officer/admin edit name+description
--
-- Rule: a member has at most ONE active *chapter* membership (their
-- home chapter); approving a chapter membership retires the others and
-- syncs member.home_unit_id. Working-group memberships are unlimited.
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1. unit description ----------
alter table org_unit add column if not exists description text;

-- ---------- 2. membership / applications ----------
create table if not exists org_unit_member (
  org_unit_id uuid not null references org_unit (id) on delete cascade,
  member_id   uuid not null references member (id)   on delete cascade,
  status      text not null default 'pending'
                check (status in ('pending', 'active', 'rejected', 'left')),
  applied_on  timestamptz not null default now(),
  decided_on  timestamptz,
  decided_by  uuid references member (id),
  primary key (org_unit_id, member_id)
);
create index if not exists org_unit_member_unit_idx   on org_unit_member (org_unit_id, status);
create index if not exists org_unit_member_member_idx on org_unit_member (member_id, status);

-- ---------- 3. is the current user an officer of this unit? ----------
-- any serving chair/secretary/leader of THIS unit, or a member-manager.
create or replace function is_unit_officer(p_unit uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select has_capability('manage_members')
      or exists (
        select 1
        from org_unit_officer o
        join member m on m.id = o.member_id
        where o.org_unit_id = p_unit
          and o.ended_on is null
          and m.auth_user_id = auth.uid()
      );
$$;
grant execute on function is_unit_officer(uuid) to authenticated;

-- ---------- 4. apply to join (self) ----------
create or replace function apply_to_unit(p_unit uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid;
begin
  me := current_member_id();
  if me is null then raise exception 'no membership for current user'; end if;
  if not exists (select 1 from org_unit where id = p_unit) then
    raise exception 'no such org unit'; end if;
  insert into org_unit_member (org_unit_id, member_id, status, applied_on)
  values (p_unit, me, 'pending', now())
  on conflict (org_unit_id, member_id) do update
    set status = case when org_unit_member.status in ('active', 'pending')
                      then org_unit_member.status else 'pending' end,
        applied_on = case when org_unit_member.status in ('active', 'pending')
                          then org_unit_member.applied_on else now() end,
        decided_on = null, decided_by = null;
end; $$;
grant execute on function apply_to_unit(uuid) to authenticated;

-- ---------- 5. leave a unit (self) ----------
create or replace function leave_unit(p_unit uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; ukind text;
begin
  me := current_member_id();
  if me is null then raise exception 'no membership for current user'; end if;
  update org_unit_member set status = 'left', decided_on = now(), decided_by = me
   where org_unit_id = p_unit and member_id = me and status in ('pending', 'active');
  select kind into ukind from org_unit where id = p_unit;
  if ukind = 'chapter' then
    update member set home_unit_id = null where id = me and home_unit_id = p_unit;
  end if;
end; $$;
grant execute on function leave_unit(uuid) to authenticated;

-- ---------- 6. approve / reject an application (officer/admin) ----------
create or replace function decide_unit_member(p_unit uuid, p_member uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid; ukind text;
begin
  if not is_unit_officer(p_unit) then
    raise exception 'only an officer of this unit (or member-manager) can decide'; end if;
  me := current_member_id();
  select kind into ukind from org_unit where id = p_unit;
  if ukind is null then raise exception 'no such org unit'; end if;

  if p_approve then
    -- one active chapter at a time: retire other active chapter memberships
    if ukind = 'chapter' then
      update org_unit_member oum set status = 'left', decided_on = now(), decided_by = me
        from org_unit ou
       where oum.org_unit_id = ou.id and ou.kind = 'chapter'
         and oum.member_id = p_member and oum.org_unit_id <> p_unit
         and oum.status = 'active';
      update member set home_unit_id = p_unit where id = p_member;
    end if;
    insert into org_unit_member (org_unit_id, member_id, status, decided_on, decided_by)
    values (p_unit, p_member, 'active', now(), me)
    on conflict (org_unit_id, member_id) do update
      set status = 'active', decided_on = now(), decided_by = me;
  else
    insert into org_unit_member (org_unit_id, member_id, status, decided_on, decided_by)
    values (p_unit, p_member, 'rejected', now(), me)
    on conflict (org_unit_id, member_id) do update
      set status = 'rejected', decided_on = now(), decided_by = me;
  end if;
end; $$;
grant execute on function decide_unit_member(uuid, uuid, boolean) to authenticated;

-- ---------- 7. add a member directly (officer/admin) ----------
create or replace function officer_add_unit_member(p_unit uuid, p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_unit_officer(p_unit) then
    raise exception 'only an officer of this unit (or member-manager) can add members'; end if;
  perform decide_unit_member(p_unit, p_member, true);
end; $$;
grant execute on function officer_add_unit_member(uuid, uuid) to authenticated;

-- ---------- 8. edit unit info (officer/admin) ----------
-- runs as definer so officers can edit despite org_unit's manage_members RLS.
create or replace function update_org_unit(p_unit uuid, p_name text, p_description text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_unit_officer(p_unit) then
    raise exception 'only an officer of this unit (or member-manager) can edit it'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name required'; end if;
  update org_unit set name = trim(p_name), description = nullif(trim(p_description), '')
   where id = p_unit;
end; $$;
grant execute on function update_org_unit(uuid, text, text) to authenticated;

-- ---------- 9. RLS + grants ----------
alter table org_unit_member enable row level security;

drop policy if exists read_org_unit_member on org_unit_member;
create policy read_org_unit_member on org_unit_member for select to authenticated using (true);
-- all writes go through the SECURITY DEFINER RPCs above; no direct policy.

grant select on org_unit_member to anon, authenticated;

notify pgrst, 'reload schema';
