-- ARR 2026 August: stamp author roles for EXISTING members (5 papers, confirmed
-- mapping 727→FinCritic 726→Japanese 721→King 718→Herculean 454→Enterprise).
-- Rule: pos1=first, last=last, middle=normal. Idempotent DATA migration —
-- every block no-ops when the referenced prod rows are absent (CI clones).

-- ── #727 FinCriticalED: A Visual Benchmark for Financial Fact-Level OCR → FinCritic ──
-- Yueru He → first
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '6a8a15eb-8d4d-4f79-a782-2172589bd437';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'first'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'first', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'first');
  end if;
end $$;
-- Xueqing Peng → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'df2642f5-fd4d-4120-83d0-b44fcc786592';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yupeng Cao → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f13ee5e2-e362-4082-9e66-e2ebe1216ebb';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yan Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '422ee34e-c932-46a7-b913-4532a1597147';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Lingfei Qian → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8087dfd3-3408-4353-ba55-750510c42ef2';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Haohang Li → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8e0877f9-b60a-4110-98e0-02b0c3740086';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Ruoyu Xiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '374d5024-d29b-41f5-ab45-e2ae23329e8d';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Zhuohan Xie → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '26d7f950-c26d-47eb-a5f3-417f5068351d';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Mingquan Lin → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a549d2a2-d030-4261-85c5-3c766389b86a';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jimin Huang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f6fd6638-6faa-4acd-acb4-440c718f987f';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Sophia Ananiadou → last
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a0eccdd9-56c1-4938-a80b-eb720c1b26e9';
  if mid is null or not exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
    update work_commitment set authorship = 'last'
     where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'last', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'last');
  end if;
end $$;

-- ── #726 Ebisu: Benchmarking Large Language Models in Japanese Finance → Japanese (Financial benchmark) ──
-- Xueqing Peng → first
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'df2642f5-fd4d-4120-83d0-b44fcc786592';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'first'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'first', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'first');
  end if;
end $$;
-- Ruoyu Xiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '374d5024-d29b-41f5-ab45-e2ae23329e8d';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Mingyang Jiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '3a624648-b263-4cf2-bb88-8c427e45fedc';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yan Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '422ee34e-c932-46a7-b913-4532a1597147';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Lingfei Qian → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8087dfd3-3408-4353-ba55-750510c42ef2';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jimin Huang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f6fd6638-6faa-4acd-acb4-440c718f987f';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Sophia Ananiadou → last
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a0eccdd9-56c1-4938-a80b-eb720c1b26e9';
  if mid is null or not exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
    update work_commitment set authorship = 'last'
     where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'last', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'last');
  end if;
end $$;

-- ── #721 A King of Infinite Space in a Nutshell: Belief-State Policy Optimizati → A King of Infinite Space in a Nutshell: Belief-State Policy Optimization for Financial Language Agents ──
-- Jimin Huang → first
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f6fd6638-6faa-4acd-acb4-440c718f987f';
  if mid is null or not exists (select 1 from project where id = 'bc41384a-9303-4505-9fe4-4e62a705984d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid) then
    update work_commitment set authorship = 'first'
     where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('bc41384a-9303-4505-9fe4-4e62a705984d', 'work_labor', 'first', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'bc41384a-9303-4505-9fe4-4e62a705984d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'first');
  end if;
end $$;
-- Xueqing Peng → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'df2642f5-fd4d-4120-83d0-b44fcc786592';
  if mid is null or not exists (select 1 from project where id = 'bc41384a-9303-4505-9fe4-4e62a705984d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('bc41384a-9303-4505-9fe4-4e62a705984d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'bc41384a-9303-4505-9fe4-4e62a705984d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Sophia Ananiadou → last
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a0eccdd9-56c1-4938-a80b-eb720c1b26e9';
  if mid is null or not exists (select 1 from project where id = 'bc41384a-9303-4505-9fe4-4e62a705984d') then return; end if;
  if exists (select 1 from work_commitment where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid) then
    update work_commitment set authorship = 'last'
     where project_id = 'bc41384a-9303-4505-9fe4-4e62a705984d' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('bc41384a-9303-4505-9fe4-4e62a705984d', 'work_labor', 'last', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, 'bc41384a-9303-4505-9fe4-4e62a705984d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'last');
  end if;
end $$;

-- ── #718 Herculean: An Agentic Benchmark for Financial Intelligence → Herculean ──
-- Xueqing Peng → first
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'df2642f5-fd4d-4120-83d0-b44fcc786592';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'first'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'first', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'first');
  end if;
end $$;
-- Zhuohan Xie → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '26d7f950-c26d-47eb-a5f3-417f5068351d';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yupeng Cao → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f13ee5e2-e362-4082-9e66-e2ebe1216ebb';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Haohang Li → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8e0877f9-b60a-4110-98e0-02b0c3740086';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Lingfei Qian → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8087dfd3-3408-4353-ba55-750510c42ef2';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yan Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '422ee34e-c932-46a7-b913-4532a1597147';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Vincent Jim Zhang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'da4b300e-f0fb-483f-97b6-edd8f545c6a2';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Xuguang Ai → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '922826a1-92d9-49ab-9901-c99c7bf17460';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Linhai Ma → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '435323e6-721e-406f-b978-9e884f08bba4';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Ruoyu Xiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '374d5024-d29b-41f5-ab45-e2ae23329e8d';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yueru He → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '6a8a15eb-8d4d-4f79-a782-2172589bd437';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Mingyang Jiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '3a624648-b263-4cf2-bb88-8c427e45fedc';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Xiaoyu Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'd559331f-209c-4a56-8bca-2d42cf0e41fc';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yankai Chen → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'c5c2f3e4-bd3c-4873-93bd-a757de53a5cc';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Ye Yuan → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'be0e277b-2819-439e-814a-9b3a8c0db5f4';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Haolun Wu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'b76b35b3-678c-4259-b148-55981ed3c0b4';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yuyang Dai → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'c0be68db-f5d6-476a-8c4d-3f11cfb80078';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Ayesha Gull → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '00735785-b698-4238-8944-d8a6261608f2';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Muhammad Usman Safder → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'cff4edc5-faa4-4e3c-8715-e780e490be56';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Nuo Chen → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '63a6e751-725c-4903-bc14-a1e3464a9a56';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yuechen Jiang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '00532638-a13b-4fe8-885a-f2712b30451e';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Zhiwei Liu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'ca2d124c-3359-494d-9835-4b2ac171c489';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yuyan Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'd7e480f8-f0cd-4974-a4cf-be4b5482cd1f';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yixiang Zheng → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '926bda81-7f50-4427-a3fd-a80a9853f8fc';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yangyang Yu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '51c6a2c8-d3a7-4aab-ad24-7d88005e80ce';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Weijin Liu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8c53577d-276d-4876-b043-52e67ca6f523';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Peng Lu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '1f442f3c-9ae4-4d85-be58-e39483472d6e';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Fengran Mo → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'bebc4b0a-c5a0-4793-a93f-944f7279d94c';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Mingquan Lin → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a549d2a2-d030-4261-85c5-3c766389b86a';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jiahuan Pei → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '1513ccae-1c3b-4fd4-97a2-e2562c488dfb';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jimin Huang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f6fd6638-6faa-4acd-acb4-440c718f987f';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yuehua Tang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '6b3b2905-817d-4470-b1bc-bb8ebdee6ad0';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Alejandro Lopez Lira → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '33436c76-0d61-43ff-b5d8-584e260065da';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jianyun Nie → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '5a233e70-ee42-4ae8-9a15-bf0d5fe86453';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Sophia Ananiadou → last
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a0eccdd9-56c1-4938-a80b-eb720c1b26e9';
  if mid is null or not exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then return; end if;
  if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
    update work_commitment set authorship = 'last'
     where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'last', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'last');
  end if;
end $$;

-- ── #454 Can LLM Agents Be CFOs? Benchmarking Long-Horizon Resource Allocation  → Enterprise Finance Operations Benchmark ──
-- Yan Wang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '422ee34e-c932-46a7-b913-4532a1597147';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Lingfei Qian → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8087dfd3-3408-4353-ba55-750510c42ef2';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Haohang Li → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '8e0877f9-b60a-4110-98e0-02b0c3740086';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yupeng Cao → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f13ee5e2-e362-4082-9e66-e2ebe1216ebb';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yueru He → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '6a8a15eb-8d4d-4f79-a782-2172589bd437';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Xueqing Peng → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'df2642f5-fd4d-4120-83d0-b44fcc786592';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yitao Xu → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '3c97dd9a-5d87-4ca8-ac61-db9738e0730a';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Yankai Chen → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'c5c2f3e4-bd3c-4873-93bd-a757de53a5cc';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Dongji Feng → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'b87f93db-174a-4edc-8985-2fbce51b8668';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jimin Huang → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'f6fd6638-6faa-4acd-acb4-440c718f987f';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Jianyun Nie → normal
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = '5a233e70-ee42-4ae8-9a15-bf0d5fe86453';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'normal'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
  end if;
end $$;
-- Sophia Ananiadou → last
do $$
declare sid uuid; mid uuid;
begin
  select id into mid from member where id = 'a0eccdd9-56c1-4938-a80b-eb720c1b26e9';
  if mid is null or not exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then return; end if;
  if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
    update work_commitment set authorship = 'last'
     where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
  else
    insert into project_slot (project_id, slot_kind, authorship, status, headcount)
    values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'last', 'filled', 1) returning id into sid;
    insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
    values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'last');
  end if;
end $$;