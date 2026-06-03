-- =====================================================================
-- Data hygiene — normalise project_status names
-- ---------------------------------------------------------------------
-- A delivered project was leaking into the "active" grid. Root suspect:
-- a project_status row whose name carried stray whitespace / casing
-- (e.g. 'Finished ' or 'finished'), so exact-match logic (status =
-- 'Finished') failed. This migration:
--   1. merges status rows that differ only by surrounding whitespace/case
--      — repointing project.project_status_id (+ held_from_status_id) to
--      one canonical row, then deleting the duplicates;
--   2. trims the surviving names.
-- Idempotent and safe to re-run. Apply to the live DB.
-- =====================================================================

begin;

do $$
declare r record; has_held boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'project' and column_name = 'held_from_status_id'
  ) into has_held;

  -- one canonical row per (case-insensitive, trimmed) name; prefer a name
  -- that is already proper-cased & clean, then the lowest id.
  for r in
    select lower(btrim(name)) as key,
           (array_agg(id order by
              (name = initcap(btrim(name))) desc,  -- prefer 'Finished'
              (name = btrim(name)) desc,           -- then any clean (no stray ws)
              id))[1] as keep_id,
           array_agg(id) as all_ids
    from project_status
    group by lower(btrim(name))
    having count(*) > 1
  loop
    update project set project_status_id = r.keep_id
      where project_status_id = any(r.all_ids) and project_status_id <> r.keep_id;
    if has_held then
      execute 'update project set held_from_status_id = $1
                 where held_from_status_id = any($2) and held_from_status_id <> $1'
        using r.keep_id, r.all_ids;
    end if;
    delete from project_status
      where id = any(r.all_ids) and id <> r.keep_id;
  end loop;
end $$;

-- trim stray whitespace on the survivors (no collisions left after the merge)
update project_status set name = btrim(name) where name <> btrim(name);

commit;
