-- Merge duplicate members: "Han Yi" (original card, real email + skills,
-- 2026-06-27) and "Yi Han" (created by 20260824080000 from the ARR import —
-- name-order flip defeated the matcher). Keep the ORIGINAL row, canonicalize
-- its name to the publication form "Yi Han", carry over the OpenReview link
-- and the three paper seats, delete the day-old duplicate. Guarded: no-ops
-- where the rows are absent (CI clones).
do $$
declare keep uuid := '72a6668b-62df-4acf-9378-fb55fa08d195';  -- Han Yi (original)
        dup  uuid := '1260441e-f4e7-4c73-b60d-0b06d1c41478';  -- Yi Han (import)
        w record;
begin
  if not exists (select 1 from member where id = keep)
     or not exists (select 1 from member where id = dup) then return; end if;

  for w in select * from work_commitment where member_id = dup loop
    if exists (select 1 from work_commitment
                where member_id = keep and project_id = w.project_id) then
      -- both on the project: keep the original's rows, transfer the role
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

  delete from project_member where member_id = dup;
  delete from person_skill where member_id = dup;
  delete from member where id = dup;
end $$;
