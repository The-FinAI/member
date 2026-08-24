-- ARR 2026 August: 31 NEW member cards (chapter by verified OpenReview
-- affiliation; AE→Asia-Pacific by proximity) + 40 paper seats. Placeholder
-- emails @pending.thefin.ai (chapter chairs to backfill); links.openreview
-- records the verified profile. Idempotent DATA migration — no-ops on clones.

-- ── Anke Xu · Facebook (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Anke Xu');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Anke Xu', 'anke.xu@pending.thefin.ai', 'Facebook', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Anke_Xu1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Arman Cohan · Yale University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Arman Cohan');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Arman Cohan', 'arman.cohan@pending.thefin.ai', 'Yale University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Arman_Cohan1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Fan Zhang · The University of Tokyo (JP) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Fan Zhang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Fan Zhang', 'fan.zhang@pending.thefin.ai', 'The University of Tokyo', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Fan_Zhang67'))
    returning id into mid;
  end if;
  -- FinCritic → normal
  if exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then
    if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Fengbin Zhu · National University of Singapore (SG) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Fengbin Zhu');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Fengbin Zhu', 'fengbin.zhu@pending.thefin.ai', 'National University of Singapore', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Fengbin_Zhu2'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Fuyuan Lyu · Vatic Labs (AE) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Fuyuan Lyu');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Fuyuan Lyu', 'fuyuan.lyu@pending.thefin.ai', 'Vatic Labs', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Fuyuan_Lyu1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Guojun Xiong · Harvard University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Guojun Xiong');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Guojun Xiong', 'guojun.xiong@pending.thefin.ai', 'Harvard University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~GUOJUN_XIONG1'))
    returning id into mid;
  end if;
  -- FinCritic → normal
  if exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then
    if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Huan He · Yale University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Huan He');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Huan He', 'huan.he@pending.thefin.ai', 'Yale University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Huan_He1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Jerry Huang · MILA, Universite de Montreal (CA) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Jerry Huang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Jerry Huang', 'jerry.huang@pending.thefin.ai', 'MILA, Universite de Montreal', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Jerry_Huang1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Junichi Tsujii · AIST (JP) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Junichi Tsujii');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Junichi Tsujii', 'junichi.tsujii@pending.thefin.ai', 'AIST', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Junichi_Tsujii1'))
    returning id into mid;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Mingzi Song · Yokohama National University (JP) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Mingzi Song');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Mingzi Song', 'mingzi.song@pending.thefin.ai', 'Yokohama National University', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Mingzi_Song1'))
    returning id into mid;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Mohsinul Kabir · University of Manchester (GB) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Mohsinul Kabir');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Mohsinul Kabir', 'mohsinul.kabir@pending.thefin.ai', 'University of Manchester', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Mohsinul_Kabir1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Nanhan Shen · Georgia Institute of Technology (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Nanhan Shen');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Nanhan Shen', 'nanhan.shen@pending.thefin.ai', 'Georgia Institute of Technology', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Nanhan_Shen1'))
    returning id into mid;
  end if;
  -- Enterprise Finance Operations Benchmark → normal
  if exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then
    if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Polydoros Giannouris · University of Manchester (GB) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Polydoros Giannouris');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Polydoros Giannouris', 'polydoros.giannouris@pending.thefin.ai', 'University of Manchester', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Polydoros_Giannouris1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Prayag Tiwari · Halmstad University (SE) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Prayag Tiwari');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Prayag Tiwari', 'prayag.tiwari@pending.thefin.ai', 'Halmstad University', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Prayag_Tiwari1'))
    returning id into mid;
  end if;
  -- FinCritic → normal
  if exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then
    if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Rania Elbadry · MBZUAI (AE) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Rania Elbadry');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Rania Elbadry', 'rania.elbadry@pending.thefin.ai', 'MBZUAI', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Rania_Elbadry1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Shuyao Wang · Harvard University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Shuyao Wang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Shuyao Wang', 'shuyao.wang@pending.thefin.ai', 'Harvard University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Shuyao_Wang3'))
    returning id into mid;
  end if;
  -- FinCritic → normal
  if exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then
    if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Taiki Hara · University of Manchester (GB) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Taiki Hara');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Taiki Hara', 'taiki.hara@pending.thefin.ai', 'University of Manchester', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Taiki_Hara1'))
    returning id into mid;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Tianshi Cai · University of Liverpool (GB) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Tianshi Cai');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Tianshi Cai', 'tianshi.cai@pending.thefin.ai', 'University of Liverpool', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Tianshi_Cai1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Victor Gutierrez Basulto · Cardiff University (GB) → Europe ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '6aece644-9228-4358-ae00-cd0a315c468e') then return; end if;
  select id into mid from member where lower(full_name) = lower('Victor Gutierrez Basulto');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Victor Gutierrez Basulto', 'victor.gutierrez.basulto@pending.thefin.ai', 'Cardiff University', 'card', 'invited', '6aece644-9228-4358-ae00-cd0a315c468e',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Victor_Gutierrez_Basulto1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Wenbo Cao · Lessen LLC (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Wenbo Cao');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Wenbo Cao', 'wenbo.cao@pending.thefin.ai', 'Lessen LLC', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Wenbo_Cao1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Xi Chen · New York University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Xi Chen');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Xi Chen', 'xi.chen@pending.thefin.ai', 'New York University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Xi_Chen6'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Xue Liu · MBZUAI (AE) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Xue Liu');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Xue Liu', 'xue.liu@pending.thefin.ai', 'MBZUAI', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Xue_Liu1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Enterprise Finance Operations Benchmark → normal
  if exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then
    if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Yi Han · Georgia Institute of Technology (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yi Han');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yi Han', 'yi.han@pending.thefin.ai', 'Georgia Institute of Technology', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yi_Han16'))
    returning id into mid;
  end if;
  -- FinCritic → normal
  if exists (select 1 from project where id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d') then
    if exists (select 1 from work_commitment where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'a527178a-dc72-45ed-8710-1451e2ca1c3d' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('a527178a-dc72-45ed-8710-1451e2ca1c3d', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'a527178a-dc72-45ed-8710-1451e2ca1c3d', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Enterprise Finance Operations Benchmark → first
  if exists (select 1 from project where id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb') then
    if exists (select 1 from work_commitment where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid) then
      update work_commitment set authorship = 'first' where project_id = '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', 'work_labor', 'first', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '4a4e9374-bdb6-4836-ace2-7a3bd70ac8cb', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'first');
    end if;
  end if;
end $$;

-- ── Yijia Zhao · University of Massachusetts Boston (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yijia Zhao');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yijia Zhao', 'yijia.zhao@pending.thefin.ai', 'University of Massachusetts Boston', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yijia_Zhao2'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Yilun Zhao · Yale University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yilun Zhao');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yilun Zhao', 'yilun.zhao@pending.thefin.ai', 'Yale University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yilun_Zhao1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Yonghan Yang · MBZUAI (AE) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yonghan Yang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yonghan Yang', 'yonghan.yang@pending.thefin.ai', 'MBZUAI', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yonghan_Yang1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Youzhong Dong · Malvern College Chengdu (CN) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Youzhong Dong');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Youzhong Dong', 'youzhong.dong@pending.thefin.ai', 'Malvern College Chengdu', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Youzhong_Dong1'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Yuqing Guo · Northeastern University (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yuqing Guo');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yuqing Guo', 'yuqing.guo@pending.thefin.ai', 'Northeastern University', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yuqing_Guo5'))
    returning id into mid;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Yushen Yang · Kent School (US) → North America ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '241dc5e1-96df-45f6-adb2-39c86e730df8') then return; end if;
  select id into mid from member where lower(full_name) = lower('Yushen Yang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Yushen Yang', 'yushen.yang@pending.thefin.ai', 'Kent School', 'card', 'invited', '241dc5e1-96df-45f6-adb2-39c86e730df8',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Yushen_Yang2'))
    returning id into mid;
  end if;
  -- Japanese (Financial benchmark) → normal
  if exists (select 1 from project where id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191') then
    if exists (select 1 from work_commitment where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, 'cbf2f405-5b6e-4cc9-aae4-5dfe6555b191', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Zichen Zhao · MBZUAI (AE) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Zichen Zhao');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Zichen Zhao', 'zichen.zhao@pending.thefin.ai', 'MBZUAI', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Zichen_Zhao2'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;

-- ── Zimu Wang · Monash University (AU) → Asia-Pacific ──
do $$
declare mid uuid; sid uuid;
begin
  if not exists (select 1 from org_unit where id = '776aafea-4e81-42ca-bd47-92245f61723d') then return; end if;
  select id into mid from member where lower(full_name) = lower('Zimu Wang');
  if mid is null then
    insert into member (full_name, email, affiliation, kind, status, home_unit_id, links)
    values ('Zimu Wang', 'zimu.wang@pending.thefin.ai', 'Monash University', 'card', 'invited', '776aafea-4e81-42ca-bd47-92245f61723d',
            jsonb_build_object('openreview', 'https://openreview.net/profile?id=~Zimu_Wang3'))
    returning id into mid;
  end if;
  -- Herculean → normal
  if exists (select 1 from project where id = '0f418022-7d58-439d-9a9e-18d0115dfde3') then
    if exists (select 1 from work_commitment where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid) then
      update work_commitment set authorship = 'normal' where project_id = '0f418022-7d58-439d-9a9e-18d0115dfde3' and member_id = mid;
    else
      insert into project_slot (project_id, slot_kind, authorship, status, headcount)
      values ('0f418022-7d58-439d-9a9e-18d0115dfde3', 'work_labor', 'normal', 'filled', 1) returning id into sid;
      insert into work_commitment (slot_id, project_id, member_id, year_month, monthly_amount, nominal_str, approval, authorship)
      values (sid, '0f418022-7d58-439d-9a9e-18d0115dfde3', mid, to_char(now(), 'YYYY-MM'), 0, 0, 'ok', 'normal');
    end if;
  end if;
end $$;