-- =====================================================================
-- The Fin AI Community — Resources (run after schema/policies/functions)
-- A resource can be personal (a member brings it) or community-owned
-- (created by a manage_resources holder, stewarded by a position-holder).
-- Projects post resource_requests; holders respond with resource_offers.
-- Accepting an offer adds the contributor to the project — enforcing the
-- governance rule: contribute a resource OR participate => listed as author.
-- =====================================================================

-- ---------- new capability ----------
insert into capability (key, description) values
  ('manage_resources', 'Create and steward community resources and resource types')
on conflict (key) do nothing;

-- grant it to President (and anyone already holding manage_taxonomy keeps theirs separate)
insert into position_capability (position_id, capability_key)
select p.id, 'manage_resources' from position p where p.name = 'President'
on conflict do nothing;

-- ---------- tables ----------
create table if not exists resource_type (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  rank        integer not null default 0,
  description text
);

create table if not exists resource (
  id               uuid primary key default gen_random_uuid(),
  type_id          uuid references resource_type (id) on delete set null,
  name             text not null,
  description      text,
  scope            text not null default 'member' check (scope in ('member', 'community')),
  holder_member_id uuid references member (id) on delete set null,
  capacity         text,
  availability     text not null default 'available' check (availability in ('available', 'limited', 'committed')),
  created_at       timestamptz not null default now()
);

create table if not exists resource_request (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references project (id) on delete cascade,
  type_id     uuid references resource_type (id) on delete set null,
  description text,
  quantity    text,
  status      text not null default 'open' check (status in ('open', 'fulfilled', 'closed')),
  created_at  timestamptz not null default now()
);

create table if not exists resource_offer (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references resource_request (id) on delete cascade,
  resource_id uuid references resource (id) on delete set null,
  offered_by  uuid not null references member (id) on delete cascade,
  message     text,
  status      text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at  timestamptz not null default now()
);

-- ---------- RLS ----------
alter table resource_type    enable row level security;
alter table resource         enable row level security;
alter table resource_request enable row level security;
alter table resource_offer   enable row level security;

-- resource_type: everyone reads; manage_resources writes
drop policy if exists read_resource_type on resource_type;
create policy read_resource_type on resource_type for select to authenticated using (true);
drop policy if exists manage_resource_type on resource_type;
create policy manage_resource_type on resource_type for all to authenticated
  using (has_capability('manage_resources')) with check (has_capability('manage_resources'));

-- resource: everyone reads; own personal resource OR manage_resources writes
drop policy if exists read_resource on resource;
create policy read_resource on resource for select to authenticated using (true);
drop policy if exists manage_resource on resource;
create policy manage_resource on resource for all to authenticated
  using ((scope = 'member' and holder_member_id = current_member_id()) or has_capability('manage_resources'))
  with check ((scope = 'member' and holder_member_id = current_member_id()) or has_capability('manage_resources'));

-- resource_request: everyone reads; project managers write
drop policy if exists read_resource_request on resource_request;
create policy read_resource_request on resource_request for select to authenticated using (true);
drop policy if exists manage_resource_request on resource_request;
create policy manage_resource_request on resource_request for all to authenticated
  using (manages_project(project_id) or has_capability('edit_any_project'))
  with check (manages_project(project_id) or has_capability('edit_any_project'));

-- resource_offer: everyone reads; offerer creates; offerer or project manager updates
drop policy if exists read_resource_offer on resource_offer;
create policy read_resource_offer on resource_offer for select to authenticated using (true);
drop policy if exists insert_resource_offer on resource_offer;
create policy insert_resource_offer on resource_offer for insert to authenticated
  with check (offered_by = current_member_id());
drop policy if exists update_resource_offer on resource_offer;
create policy update_resource_offer on resource_offer for update to authenticated
  using (
    offered_by = current_member_id()
    or exists (select 1 from resource_request r where r.id = request_id and manages_project(r.project_id))
    or has_capability('edit_any_project')
  );
drop policy if exists delete_resource_offer on resource_offer;
create policy delete_resource_offer on resource_offer for delete to authenticated
  using (offered_by = current_member_id() or has_capability('edit_any_project'));

-- ---------- accept a resource offer (adds contributor as author) ----------
create or replace function accept_resource_offer(offer_id uuid, role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare pid uuid; mid uuid;
begin
  select r.project_id, o.offered_by
    into pid, mid
  from resource_offer o
  join resource_request r on r.id = o.request_id
  where o.id = offer_id;

  if pid is null then
    raise exception 'offer not found';
  end if;
  if not manages_project(pid) and not has_capability('edit_any_project') then
    raise exception 'not authorized to accept for this project';
  end if;

  update resource_offer set status = 'accepted' where id = offer_id;
  -- governance rule: contributing a resource makes you a project author
  insert into project_member (project_id, member_id, project_role_id)
  values (pid, mid, role_id)
  on conflict do nothing;
end;
$$;
grant execute on function accept_resource_offer(uuid, uuid) to authenticated;

-- ---------- seed resource types ----------
insert into resource_type (name, rank) values
  ('Compute / GPU', 1),
  ('Funding / Budget', 2),
  ('API Credits', 3),
  ('Dataset / Data Access', 4),
  ('Annotation Labor', 5),
  ('Software / License', 6),
  ('Expert Time', 7),
  ('Other', 99)
on conflict (name) do nothing;
