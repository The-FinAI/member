-- ARR is not one venue: every cycle has its own deadline and decision date, and
-- a paper lives in the cycle it was submitted to. One venue row per cycle.
--   'ARR'          → renamed 'ARR 2026-10' (it already carries the October dates)
--   'ARR 2026-08'  → new; everything currently under review was submitted here
--   'ARR 2027-01'  → new; dates TBA (sync-venues fills them from the official table)
-- Guarded data migration: a no-op on clones that carry schema only.
do $$
declare arr uuid := 'cba5a72a-1d9f-418d-bf43-7ac04b5fdbdd'; aug uuid; rev uuid;
begin
  if not exists (select 1 from venue where id = arr and name = 'ARR') then return; end if;

  update venue set name = 'ARR 2026-10', deadline = '2026-10-12', notification = '2026-12-17' where id = arr;
  update project set target_venue = 'ARR 2026-10' where venue_id = arr;

  insert into venue (name, kind, deadline, notification, rank, is_active, source_url)
  values ('ARR 2026-08', 'rolling', '2026-08-03', '2026-10-08', 99, true, 'https://aclrollingreview.org/dates')
  returning id into aug;
  insert into venue (name, kind, deadline, notification, rank, is_active, source_url)
  values ('ARR 2027-01', 'rolling', null, null, 101, true, 'https://aclrollingreview.org/dates');

  select id into rev from project_status where name = 'Under review';
  update project set venue_id = aug, target_venue = 'ARR 2026-08'
   where venue_id = arr and status_id = rev and archived_at is null;
end $$;
