-- Merge duplicate members: "Han Yi" (original card, real email + skills,
-- 2026-06-27) and "Yi Han" (created by 20260824080000 — name-order flip
-- defeated the matcher). Keep the ORIGINAL row, canonicalize the name to
-- "Yi Han", carry seats + OpenReview link over, then repoint EVERY foreign
-- key that references the duplicate (project_event actor rows etc.) before
-- deleting it. Guarded: no-ops where the rows are absent (CI clones).
do $$
declare keep uuid := '72a6668b-62df-4acf-9378-fb55fa08d195';  -- Han Yi (original)
        dup  uuid := '1260441e-f4e7-4c73-b60d-0b06d1c41478';  -- Yi Han (import)
        w record; fk record;
begin
  if not exists (select 1 from member where id = keep)
     or not exists (select 1 from member where id = dup) then return; end if;

  -- seats: move, or transfer the role where the original is already on the project
  for w in select * from work_commitment where member_id = dup loop
    if exists (select 1 from work_commitment
                where member_id = keep and project_id = w.project_id) then
      update work_commitment set authorship = w.authorship
       where member_id = keep and project_id = w.project_id and w.authorship is not null;
      delete from work_commitment where id = w.id;
    else
      update work_commitment set member_id = keep where id = w.id;
    end if;
  end loop;

  update member set
    full_name = 'Yi Han',
    links = coalesce((select links from member where id = keep), '{}'::jsonb)
            || coalesce((select links from member where id = dup), '{}'::jsonb)
   where id = keep;

  -- repoint every remaining FK reference dup → keep; rows that would collide
  -- with a unique constraint (already present for keep) are dropped instead
  for fk in
    select c.conrelid::regclass as tbl, a.attname as col
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
     where c.confrelid = 'member'::regclass and c.contype = 'f'
  loop
    begin
      execute format('update %s set %I = $1 where %I = $2', fk.tbl, fk.col, fk.col)
        using keep, dup;
    exception when unique_violation then
      execute format('delete from %s where %I = $1', fk.tbl, fk.col) using dup;
    end;
  end loop;

  delete from member where id = dup;
end $$;
