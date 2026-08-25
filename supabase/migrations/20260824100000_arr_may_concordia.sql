-- ARR 2026 May: Concordia (#2962) → Federated Learning.
-- (Ebisu May == Ebisu August author-for-author; already imported — no action.)
-- Adds the paper's authors NOT yet seated on the project; existing seats
-- (Jimin first / Xueqing corresponding) are curated and left untouched.
-- New member: Duanyu Feng (Sichuan University → Asia-Pacific); Zhiqiang Zhang
-- deliberately excluded per President review. Guarded: no-ops on clones.
do $$
declare pid uuid; mid uuid; sid uuid; nm text; role text;
begin
  select id into pid from project where name = 'Federated Learning';
  if pid is null then return; end if;

  -- Duanyu Feng: card + seat (author position 2 → normal)
  if exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then
    select id into mid from member where lower(full_name) = 'duanyu feng';
    if mid is null then
      insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
      values ('Duanyu Feng', 'duanyu.feng@pending.thefin.ai', 'Sichuan University', 'card', 'invited',
              '776aafea-4e81-42ca-bd47-92245f61723d',
              jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Duanyu_Feng1'))
      returning id into mid;
    end if;
    if not exists (select 1 from work_commitment where project_id = pid and member_id = mid) then
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values (pid, 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, pid, mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;

  -- existing members missing from the project (middle authors normal, Sophia last)
  for nm, role in
    select * from (values
      ('Nuo Chen', 'normal'), ('Xiaoyu Wang', 'normal'), ('Mingquan Lin', 'normal'),
      ('Prayag Tiwari', 'normal'), ('Guojun Xiong', 'normal'),
      ('Alejandro Lopez Lira', 'normal'), ('Sophia Ananiadou', 'last')) as v(n, r)
  loop
    select id into mid from member where lower(full_name) = lower(nm) and archived_at is null;
    if mid is null then continue; end if;
    if not exists (select 1 from work_commitment where project_id = pid and member_id = mid) then
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values (pid, 'work_labor', role, 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, pid, mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', role);
    end if;
  end loop;
end $$;
