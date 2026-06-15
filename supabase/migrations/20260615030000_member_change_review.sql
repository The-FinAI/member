-- =====================================================================
-- Issue #40 B (model A): a member editing THEIR OWN card submits the change for
-- their chapter officer to review; an OFFICER editing a card they manage is
-- authoritative and applies directly. (Resources already had their own review.)
--
--   member_change_submit(member, kind, payload)
--     · officer/admin caller → applies now, returns {applied:true}
--     · the member themselves → queues a pending request, {applied:false}
--   member_change_decide(request, approve) → officer applies or rejects it
--
-- kind ∈ {skill, hours}; payload: {skill_id, level} or {hours}. Idempotent.
-- =====================================================================

begin;

create table if not exists member_change_request (
  id           uuid primary key default gen_random_uuid(),
  member_id    uuid not null references member (id) on delete cascade,
  kind         text not null check (kind in ('skill', 'hours')),
  payload      jsonb not null,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_by uuid references member (id),
  decided_by   uuid references member (id),
  decided_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists mcr_member_idx on member_change_request (member_id, status);

alter table member_change_request enable row level security;
-- the member themselves, or anyone who manages the card, can see the requests
drop policy if exists mcr_read on member_change_request;
create policy mcr_read on member_change_request for select using (
  member_id in (select id from member where auth_user_id = auth.uid())
  or manages_card(member_id)
  or has_capability('manage_members')
);

create or replace function member_change_submit(p_member uuid, p_kind text, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare is_officer boolean;
begin
  if p_kind not in ('skill', 'hours') then raise exception 'bad kind'; end if;
  is_officer := manages_card(p_member) or has_capability('manage_members');

  if is_officer then
    -- officer edit is authoritative — apply immediately
    if p_kind = 'skill' then
      perform person_skill_set((p_payload->>'skill_id')::uuid, nullif(p_payload->>'level', ''), p_member);
    else
      perform person_set_capacity((p_payload->>'hours')::int, p_member);
    end if;
    return jsonb_build_object('applied', true);
  end if;

  -- otherwise only the member may submit, and it queues for review
  if not exists (select 1 from member where id = p_member and auth_user_id = auth.uid()) then
    raise exception 'not allowed to edit this card';
  end if;
  -- collapse a prior pending request for the same field
  if p_kind = 'skill' then
    delete from member_change_request
      where member_id = p_member and kind = 'skill' and status = 'pending'
        and payload->>'skill_id' = p_payload->>'skill_id';
  else
    delete from member_change_request where member_id = p_member and kind = 'hours' and status = 'pending';
  end if;
  insert into member_change_request (member_id, kind, payload, requested_by)
  values (p_member, p_kind, p_payload, p_member);
  return jsonb_build_object('applied', false, 'pending', true);
end $$;
grant execute on function member_change_submit(uuid, text, jsonb) to authenticated;

create or replace function member_change_decide(p_request uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare r member_change_request;
begin
  select * into r from member_change_request where id = p_request;
  if r.id is null then raise exception 'no such request'; end if;
  if not (manages_card(r.member_id) or has_capability('manage_members')) then
    raise exception 'not allowed to review this change';
  end if;
  if r.status <> 'pending' then return; end if;

  if p_approve then
    if r.kind = 'skill' then
      perform person_skill_set((r.payload->>'skill_id')::uuid, nullif(r.payload->>'level', ''), r.member_id);
    else
      perform person_set_capacity((r.payload->>'hours')::int, r.member_id);
    end if;
  end if;
  update member_change_request
     set status = case when p_approve then 'approved' else 'rejected' end, decided_at = now()
   where id = r.id;
end $$;
grant execute on function member_change_decide(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

commit;
