-- ============================================================
-- Site-wide announcements / notice board.
--
-- A small, admin-curated set of notices that surface at the top of every page
-- (when pinned) and on a dedicated board. Replaces the previously hard-coded
-- Phase-1 launch banner with editable rows. Anyone signed in can read; only a
-- holder of manage_members can post / edit / pin / retire one.
-- ============================================================

create table if not exists announcement (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  href        text,                       -- optional call-to-action link
  cta_label   text,                       -- label for that link
  level       text not null default 'info'
                check (level in ('info', 'success', 'warn')),
  pinned      boolean not null default true,   -- show in the top banner
  is_active   boolean not null default true,   -- retired notices stay for history
  created_by  uuid references member(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists announcement_active_idx
  on announcement (is_active, pinned, created_at desc);

create or replace function _announcement_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

drop trigger if exists ev_announcement_touch on announcement;
create trigger ev_announcement_touch before update on announcement
  for each row execute function _announcement_touch();

alter table announcement enable row level security;

drop policy if exists announcement_read on announcement;
create policy announcement_read on announcement
  for select to authenticated using (true);

drop policy if exists announcement_manage on announcement;
create policy announcement_manage on announcement
  for all to authenticated
  using (has_capability('manage_members'))
  with check (has_capability('manage_members'));

notify pgrst, 'reload schema';
