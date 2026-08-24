<script lang="ts">
  // 市场 Market —— 概念稿 v49 的落地(规格:scratchpad/gen.py)。
  // 本体:缺口(项目要的贡献)↔ 人池(每个人能给的贡献)。
  // 动词三个:派(补位)· 招(挂缺口)· 维护(人)。Notion 式折叠行,详情页退役。
  // Phase 1 无权限(governance v0.3):登录即可操作;结算/铸币仍归 President。
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import { toast } from '$lib/toast';
  import PersonPick from '$lib/PersonPick.svelte';

  type Slot = { id: string; project_id: string; slot_kind: string; authorship: string | null;
    skill: { name: string } | null; resource_type: { name: string } | null;
    desired_level: string | null; quota: number | null; status: string };
  type Seat = { memberId: string; name: string; amount: number; nominal: number; slotId: string; authorship: string };
  type Proj = { id: string; name: string; status: string; venue: string | null; venueId: string | null;
    venueYr: string; decision: string | null; venueNotif: string | null; outcome: string | null;
    unitId: string | null; unit: string | null; team: Seat[]; slots: Slot[];
    pool: number; ddlDays: number | null; ddlLabel: string };
  type Mem = { id: string; name: string; email: string; unitId: string | null; unit: string | null;
    hours: number | null; used: number; linked: boolean;
    skills: { id: string; name: string; level: string }[];
    resources: { id: string; name: string; typeName: string; quota: number }[] };
  type Unit = { id: string; name: string; kind: string };

  const STEPS = ['Start', 'Active', 'In review', 'Accepted'];
  const SG: Record<string, number> = { Proposal: 0, 'Data Collecting': 1, 'Work in progress': 1, Active: 1, 'Under review': 2, Finished: 3 };
  const SG_CLS = ['st-seed', 'st-grow', 'st-rev', 'st-ripe'];
  const LV: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Can mentor' };
  const ROLE_LABEL: Record<string, string> = {
    first: 'First author', normal: 'Author', co: 'Author',
    corresponding: '✉ Co-corresponding', last: 'Last author', last_candidate: 'Last author'
  };
  const ROLE_CLS: Record<string, string> = { first: 'r1c', corresponding: 'rcor', last: 'rlast', last_candidate: 'rlast' };
  const CIRC = '①②③④⑤⑥⑦⑧⑨⑩⑪⑫';
  const PAL = ['#31735f', '#4c7a9b', '#8a6d3b', '#a35d48', '#5b5f97', '#6c8363', '#96694f', '#527a7a', '#7b5e7b', '#6e7f52'];

  let projs = $state<Proj[]>([]);
  let archived = $state<Proj[]>([]);
  let mems = $state<Mem[]>([]);
  let removedMems = $state<{ id: string; name: string }[]>([]);
  let wgs = $state<Unit[]>([]);
  let chapterUnits = $state<Unit[]>([]);
  let venues = $state<{ id: string; name: string; kind: string; deadline: string | null }[]>([]);
  let skills = $state<{ id: string; name: string }[]>([]);
  let resourceTypes = $state<{ id: string; name: string }[]>([]);
  let statuses = $state<{ id: string; name: string }[]>([]);
  let types = $state<{ id: string; name: string }[]>([]);
  let gpuModels = $state<{ id: string; name: string }[]>([]);
  let orphans = $state<{ account_id: string; email: string }[]>([]);
  let settledBy = $state<Record<string, number>>({});
  let loading = $state(true);
  let busy = $state('');
  // details open-state survives load() re-renders (Notion-like: a row you
  // opened stays open while you act inside it)
  let openRows = $state<Record<string, boolean>>({});
  const toggleRow = (id: string) => (e: Event) => { openRows[id] = (e.target as HTMLDetailsElement).open; };

  const initials = (n: string) => { const p = n.split(' '); return (p[0]?.[0] ?? '' ) + (p[1]?.[0] ?? ''); };
  const avColor = (n: string) => PAL[[...n].reduce((a, c) => a + c.charCodeAt(0), 0) % PAL.length];

  // 目标会议的下一轮截止(过期按年顺延;期刊=随时可投)
  function nextDdl(name: string | null, kind: string | null, deadline: string | null): { label: string; days: number | null; year: number | null } {
    if (!name) return { label: '', days: null, year: null };
    if (kind === 'journal') return { label: 'rolling', days: 999, year: null };
    if (!deadline) return { label: '', days: null, year: null };
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const d = new Date(deadline + 'T00:00:00');
    while (d < today) d.setFullYear(d.getFullYear() + 1);
    const days = Math.round((d.getTime() - today.getTime()) / 86400000);
    return { label: `${days}d`, days, year: d.getFullYear() };
  }
  // 评审中:倒数到 decision 日;为负=结果应已出
  const venLabel = (v: { name: string; kind: string; deadline: string | null }) => {
    const y = nextDdl(v.name, v.kind, v.deadline).year;
    return y ? `${v.name} ${y}` : v.name;
  };
  function decDays(decision: string | null): number | null {
    if (!decision) return null;
    const today = new Date(); today.setHours(0, 0, 0, 0);
    return Math.round((new Date(decision + 'T00:00:00').getTime() - today.getTime()) / 86400000);
  }

  let booted = false; // plain var on purpose: reading $state (projs/mems)
                      // inside the load()-effect would make it self-tracking
                      // and loop forever (the bug behind the frozen page)
  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    // silent refresh: only the very first load shows the loading state —
    // later run()->load() swaps data in place (no full-page flash)
    if (!booted) { loading = true; booted = true; }
    const [{ data: pr }, { data: ou }, { data: vn }, { data: slr }, { data: wc }, { data: mm },
      { data: ps }, { data: sk }, { data: rt }, { data: st }, { data: ty }, { data: rs },
      { data: gm }, { data: sb }, { data: orp }] = await Promise.all([
      supabase.from('project').select('id, name, org_unit_id, target_venue, venue_id, deadline, tag, archived_at, project_status!project_status_id_fkey(name)'),
      supabase.from('org_unit').select('id, name, kind'),
      supabase.from('venue').select('id, name, kind, deadline, notification'),
      supabase.from('project_slot').select('id, project_id, slot_kind, authorship, desired_level, quota, status, skill:skill_id(name), resource_type:resource_type_id(name)'),
      supabase.from('work_commitment').select('project_id, slot_id, member_id, monthly_amount, nominal_str, member:member_id(full_name)'),
      supabase.from('member').select('id, full_name, email, home_unit_id, monthly_hours, auth_user_id, archived_at'),
      supabase.from('person_skill').select('member_id, level, skill_id, skill:skill_id(name)'),
      supabase.from('skill').select('id, name, parent_id'),
      supabase.from('resource_type').select('id, name'),
      supabase.from('project_status').select('id, name'),
      supabase.from('project_type').select('id, name'),
      supabase.from('resource').select('id, name, holder_member_id, monthly_quota, resource_type:type_id(name)'),
      supabase.from('gpu_model').select('id, name').order('rank'),
      supabase.from('stater_balance').select('owner_member_id, balance'),
      supabase.rpc('orphan_accounts')
    ]);

    const unitName: Record<string, string> = {};
    for (const u of (ou as any[]) ?? []) unitName[u.id] = u.name;
    wgs = ((ou as any[]) ?? []).filter((u) => u.kind === 'working_group');
    chapterUnits = ((ou as any[]) ?? []).filter((u) => u.kind === 'chapter');
    venues = (vn as any[]) ?? [];
    skills = ((sk as any[]) ?? []).filter((s) => s.parent_id != null);
    if (!skills.length) skills = (sk as any[]) ?? [];
    resourceTypes = (rt as any[]) ?? [];
    statuses = (st as any[]) ?? [];
    types = (ty as any[]) ?? [];
    gpuModels = (gm as any[]) ?? [];
    orphans = (orp as any[]) ?? [];
    const venByName: Record<string, any> = {};
    const venById: Record<string, any> = {};
    for (const v of venues) { venByName[v.name] = v; venById[v.id] = v; }

    const slotsBy: Record<string, Slot[]> = {};
    const slotById: Record<string, Slot> = {};
    for (const s of (slr as any[]) ?? []) { (slotsBy[s.project_id] ??= []).push(s as Slot); slotById[s.id] = s as Slot; }

    const teamBy: Record<string, Seat[]> = {};
    const usedBy: Record<string, number> = {};
    const nominalBy: Record<string, number> = {};
    for (const w of (wc as any[]) ?? []) {
      const list = (teamBy[w.project_id] ??= []);
      const nom = Number(w.nominal_str) || 0;
      const prev = list.find((x) => x.memberId === w.member_id);
      if (prev) { prev.amount += Number(w.monthly_amount) || 0; prev.nominal += nom; }
      else list.push({ memberId: w.member_id, name: w.member?.full_name ?? '—',
        amount: Number(w.monthly_amount) || 0, nominal: nom, slotId: w.slot_id,
        authorship: slotById[w.slot_id]?.authorship ?? (slotById[w.slot_id]?.slot_kind === 'leader' ? 'first' : 'normal') });
      usedBy[w.member_id] = (usedBy[w.member_id] ?? 0) + (Number(w.monthly_amount) || 0);
      nominalBy[w.member_id] = (nominalBy[w.member_id] ?? 0) + nom;
    }

    const rowsAll = ((pr as any[]) ?? []);
    const toProj = (p: any) => {
      const v = p.venue_id ? venById[p.venue_id] : venByName[p.target_venue ?? ''];
      const vname = v?.name ?? p.target_venue ?? null;
      const dd = nextDdl(vname, v?.kind ?? null, v?.deadline ?? null);
      const team = (teamBy[p.id] ?? []).sort((a, b) => (a.authorship === 'first' ? -1 : 0) - (b.authorship === 'first' ? -1 : 0) || b.nominal - a.nominal);
      return { id: p.id, name: p.name, status: p.project_status?.name ?? 'Proposal',
        venue: vname, venueId: p.venue_id ?? null,
        venueYr: vname ? (dd.year ? `${vname} ${dd.year}` : vname) : '',
        decision: p.deadline ?? null, venueNotif: v?.notification ?? null,
        outcome: p.tag || null, unitId: p.org_unit_id ?? null,
        unit: p.org_unit_id ? (unitName[p.org_unit_id] ?? null) : null,
        team, slots: (slotsBy[p.id] ?? []).filter((s) => s.status === 'open'),
        pool: team.reduce((a, x) => a + x.nominal, 0), ddlDays: dd.days, ddlLabel: dd.label };
    };
    projs = rowsAll.filter((p) => !p.archived_at).map(toProj);
    archived = rowsAll.filter((p) => p.archived_at).map(toProj);

    const skillBy: Record<string, { id: string; name: string; level: string }[]> = {};
    for (const r of (ps as any[]) ?? []) if (r.skill?.name) (skillBy[r.member_id] ??= []).push({ id: r.skill_id, name: r.skill.name, level: r.level });
    const resBy: Record<string, { id: string; name: string; typeName: string; quota: number }[]> = {};
    for (const r of (rs as any[]) ?? []) {
      const nm = r.resource_type?.name;
      if (!nm || nm === 'Labor') continue;
      (resBy[r.holder_member_id] ??= []).push({ id: r.id, name: r.name ?? nm, typeName: nm, quota: Number(r.monthly_quota) || 0 });
    }
    settledBy = {};
    for (const b of (sb as any[]) ?? []) if (b.owner_member_id) settledBy[b.owner_member_id] = (settledBy[b.owner_member_id] ?? 0) + (Number(b.balance) || 0);

    removedMems = ((mm as any[]) ?? []).filter((m) => m.archived_at).map((m) => ({ id: m.id, name: m.full_name }));
    mems = ((mm as any[]) ?? []).filter((m) => !m.archived_at).map((m) => ({
      id: m.id, name: m.full_name, email: m.email ?? '', unitId: m.home_unit_id ?? null,
      unit: m.home_unit_id ? (unitName[m.home_unit_id] ?? null) : null,
      hours: m.monthly_hours, used: usedBy[m.id] ?? 0, linked: !!m.auth_user_id,
      skills: skillBy[m.id] ?? [], resources: resBy[m.id] ?? []
    }));
    loading = false;
  }
  $effect(() => { load(); });

  // 多人实时同步:别人改了,你的屏幕 ~1s 内静默刷新(Notion 感)。
  // 自己的操作本来就会 run()→load(),这里去抖合并,mock 客户端无 channel 则跳过。
  $effect(() => {
    if (typeof (supabase as any).channel !== 'function') return;
    let timer: ReturnType<typeof setTimeout> | null = null;
    const ch = (supabase as any)
      .channel('market-live')
      .on('postgres_changes', { event: '*', schema: 'public' }, () => {
        if (timer) clearTimeout(timer);
        timer = setTimeout(() => { if (!busy) load(); }, 600);
      })
      .subscribe();
    return () => { if (timer) clearTimeout(timer); (supabase as any).removeChannel(ch); };
  });

  const stage = (p: Proj) => (p.status === 'Hold' ? -1 : (SG[p.status] ?? 0));
  const leadOpen = (p: Proj) => p.slots.some((s) => s.slot_kind === 'leader');
  const freeOf = (m: Mem) => (m.hours != null ? m.hours - m.used : null);
  const freeMems = $derived(mems.filter((m) => (freeOf(m) ?? 0) > 0).sort((a, b) => (freeOf(b) ?? 0) - (freeOf(a) ?? 0)));
  const unsetCount = $derived(mems.filter((m) => m.hours == null).length);

  // Notion 式视图控制:分组 × 排序,记住上次选择
  let groupBy = $state<'needs' | 'stage' | 'wg' | 'venue' | 'none'>(
    (typeof localStorage !== 'undefined' && (localStorage.getItem('mkGroup') as any)) || 'needs');
  let sortBy = $state<'ddl' | 'name' | 'pool'>(
    (typeof localStorage !== 'undefined' && (localStorage.getItem('mkSort') as any)) || 'ddl');
  $effect(() => { try { localStorage.setItem('mkGroup', groupBy); localStorage.setItem('mkSort', sortBy); } catch { /* ignore */ } });

  const cmp = (a: Proj, b: Proj) =>
    sortBy === 'name' ? a.name.localeCompare(b.name) :
    sortBy === 'pool' ? b.pool - a.pool :
    (a.ddlDays ?? 998) - (b.ddlDays ?? 998);
  const working = $derived(projs.filter((p) => stage(p) !== 3));
  const finished = $derived(projs.filter((p) => stage(p) === 3));
  const sections = $derived.by(() => {
    const S = (label: string, ps: Proj[]) => ({ label, ps: [...ps].sort(cmp) });
    if (groupBy === 'stage')
      return [0, 1, 2, -1].map((k) =>
        S($t(k >= 0 ? STEPS[k] : 'On hold'), working.filter((p) => stage(p) === k)));
    if (groupBy === 'wg') {
      const m = new Map<string, Proj[]>();
      for (const p of working) { const k = p.unit ?? $t('Proposal'); m.set(k, [...(m.get(k) ?? []), p]); }
      return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([k, ps]) => S(k, ps));
    }
    if (groupBy === 'venue') {
      const m = new Map<string, Proj[]>();
      for (const p of working) { const k = p.venueYr || $t('TBD'); m.set(k, [...(m.get(k) ?? []), p]); }
      // 分节按该会最近截止日排,未定沉底
      const ddlOf = (ps: Proj[]) => Math.min(...ps.map((p) => p.ddlDays ?? 998));
      return [...m.entries()]
        .sort((a, b) => (a[0] === $t('TBD') ? 1 : 0) - (b[0] === $t('TBD') ? 1 : 0) || ddlOf(a[1]) - ddlOf(b[1]))
        .map(([k, ps]) => S(k, ps));
    }
    if (groupBy === 'none') return [S($t('Projects'), working)];
    const hot = working.filter((p) => p.slots.length && [0, 1].includes(stage(p)));
    return [S($t('Projects needing people'), hot),
      { label: $t('Other projects'),
        ps: working.filter((p) => !hot.includes(p))
          .sort((a, b) => (stage(a) < 0 ? 1 : 0) - (stage(b) < 0 ? 1 : 0) || cmp(a, b)) }];
  });

  // ── STR 双轨:名义(在池)/实际(已结算)+ 三榜 ──
  const nominalPerMember = $derived.by(() => {
    const m: Record<string, number> = {};
    for (const p of projs) for (const s of p.team) m[s.name] = (m[s.name] ?? 0) + s.nominal;
    return m;
  });
  const settledPerName = $derived.by(() => {
    const m: Record<string, number> = {};
    for (const me of mems) if (settledBy[me.id]) m[me.name] = settledBy[me.id];
    return m;
  });
  const nomTotal = $derived(Object.values(nominalPerMember).reduce((a, b) => a + b, 0));
  const setTotal = $derived(Object.values(settledPerName).reduce((a, b) => a + b, 0));
  function board(nom: Record<string, number>, set: Record<string, number>, n: number) {
    return Object.entries(nom).sort((a, b) => (b[1] + (set[b[0]] ?? 0)) - (a[1] + (set[a[0]] ?? 0))).slice(0, n);
  }
  const wgBoard = $derived.by(() => {
    const nom: Record<string, number> = {};
    for (const p of projs) if (p.unit) nom[p.unit] = (nom[p.unit] ?? 0) + p.pool;
    return board(nom, {}, 4);
  });
  const chBoard = $derived.by(() => {
    const nom: Record<string, number> = {}; const set: Record<string, number> = {};
    const unitOf: Record<string, string | null> = {};
    for (const me of mems) unitOf[me.name] = me.unit;
    for (const [nm, v] of Object.entries(nominalPerMember)) { const u = unitOf[nm]; if (u) nom[u] = (nom[u] ?? 0) + v; }
    for (const [nm, v] of Object.entries(settledPerName)) { const u = unitOf[nm]; if (u) set[u] = (set[u] ?? 0) + v; }
    return { rows: board(nom, set, 3), set };
  });
  const memBoard = $derived(board(nominalPerMember, settledPerName, 5));

  const chapterGroups = $derived.by(() => {
    const m = new Map<string, Mem[]>();
    for (const me of mems) { const k = me.unit ?? ''; m.set(k, [...(m.get(k) ?? []), me]); }
    const key = (x: Mem) => { const fh = freeOf(x); return [fh != null && fh > 0 ? 0 : x.hours != null ? 1 : 2, -(fh ?? 0)] as const; };
    for (const [, list] of m) list.sort((a, b) => { const ka = key(a), kb = key(b); return ka[0] - kb[0] || ka[1] - kb[1]; });
    return [...m.entries()].sort((a, b) => (a[0] === '' ? 1 : 0) - (b[0] === '' ? 1 : 0));
  });
  const linkedCount = $derived(mems.filter((m) => m.linked).length);

  // ── 动作(全部真实 RPC;错误上 toast)──
  async function run(key: string, fn: () => PromiseLike<{ error: any }>) {
    busy = key;
    const { error } = await fn();
    busy = '';
    if (error) { toast.error(error.message); await load(); return false; } // reload reverts optimistic state
    await load();
    return true;
  }

  // form drafts are plain objects on purpose: typing/picking must not re-render
  // the page (a re-render would collapse the open <details> rows)
  const assignPick: Record<string, string> = {};
  const assignHours: Record<string, string> = {};
  async function assignSeat(p: Proj, s: Slot) {
    const memberId = assignPick[s.id];
    if (!memberId) return;
    const hours = Number(assignHours[s.id]) || Number(s.quota) || 5;
    await run(s.id, () => supabase.rpc('assign', { p_member: memberId, p_slot: s.id, p_hours: hours }));
  }
  async function removeSeat(p: Proj, seat: Seat) {
    await run(seat.slotId + seat.memberId,
      () => supabase.rpc('unassign', { p_slot: seat.slotId, p_member: seat.memberId }));
  }

  const openRole: Record<string, string> = {};
  const openNeed: Record<string, string> = {};
  const openHours: Record<string, string> = {};
  async function addOpening(p: Proj) {
    const need = openNeed[p.id] ?? '';
    const isRes = need.startsWith('rt:');
    const hours = Number(openHours[p.id]) || 8;
    await run('open' + p.id, () => supabase.rpc('forge_need', {
      p_project: p.id, p_kind: isRes ? 'work_resource' : 'work_labor',
      p_skill: !isRes && need ? need : null, p_resource_type: isRes ? need.slice(3) : null,
      p_level: null, p_capacity: hours, p_headcount: 1,
      p_authorship: openRole[p.id] || 'normal'
    }));
  }

  async function setRole(slotId: string, v: string) {
    await run('rl' + slotId, () => supabase.rpc('slot_set_role', { p_slot: slotId, p_authorship: v }));
  }

  // 直加作者(补录既有作者):forge_need 建槽 → assign 入席,一步完成
  const authorPick: Record<string, string> = {};
  const authorRole: Record<string, string> = {};
  const authorHours: Record<string, string> = {};
  async function addAuthor(p: Proj) {
    const memberId = authorPick[p.id];
    if (!memberId) return;
    const hours = Number(authorHours[p.id]) || 5;
    busy = 'au' + p.id;
    const { data: sid, error } = await supabase.rpc('forge_need', {
      p_project: p.id, p_kind: 'work_labor', p_skill: null, p_resource_type: null,
      p_level: null, p_capacity: hours, p_headcount: 1,
      p_authorship: authorRole[p.id] || 'normal'
    });
    if (error || !sid) { busy = ''; toast.error(error?.message ?? 'failed'); await load(); return; }
    const { error: e2 } = await supabase.rpc('assign', { p_member: memberId, p_slot: sid, p_hours: hours });
    busy = '';
    if (e2) toast.error(e2.message);
    await load();
  }

  const statusId = (name: string) => statuses.find((s) => s.name === name)?.id ?? null;
  // 阶段=下拉:可进可退可停滞(project_set_status 本就无方向限制)
  const STATUS_ORDER = ['Proposal', 'Data Collecting', 'Work in progress', 'Active', 'Under review', 'Finished', 'Hold'];
  const orderedStatuses = $derived([...statuses].sort((a, b) => {
    const ia = STATUS_ORDER.indexOf(a.name), ib = STATUS_ORDER.indexOf(b.name);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
  }));
  async function setStatus(p: Proj, sid: string) {
    if (!sid || sid === statuses.find((s) => s.name === p.status)?.id) return;
    await run('st' + p.id, () => supabase.rpc('project_set_status', { p_project: p.id, p_status: sid }));
  }

  const editName: Record<string, string> = {};
  const editVenue: Record<string, string> = {};
  const editUnit: Record<string, string> = {};
  async function saveProject(p: Proj) {
    const nm = (editName[p.id] ?? p.name).trim();
    if (nm && nm !== p.name) { if (!await run('e' + p.id, () => supabase.rpc('project_rename', { p_project: p.id, p_name: nm }))) return; }
    const v = editVenue[p.id];
    if (v !== undefined && v !== (p.venueId ?? '')) { if (!await run('e' + p.id, () => supabase.rpc('project_set_venue', { p_project: p.id, p_venue: v || null }))) return; }
    const u = editUnit[p.id];
    if (u !== undefined && u !== (p.unitId ?? '')) { if (!await run('e' + p.id, () => supabase.rpc('project_set_org_unit', { p_project: p.id, p_unit: u || null }))) return; }
  }
  async function archiveProject(p: Proj) {
    await run('a' + p.id, () => supabase.rpc('project_archive', { p_project: p.id, p_archived: true }));
  }

  // ── 新建:项目 / 小组 / 分会 ──
  let newProj = $state(''); let newProjUnit = $state(''); let newWg = $state(''); let newCh = $state('');
  let newVen = $state(''); let newVenKind = $state('conference'); let newVenDdl = $state('');
  async function createVenue() {
    if (!newVen.trim()) return;
    if (await run('newv', () => supabase.rpc('venue_create', {
      p_name: newVen.trim(), p_kind: newVenKind, p_deadline: newVenDdl || null
    }))) { newVen = ''; newVenDdl = ''; }
  }
  async function createProject() {
    if (!newProj.trim()) return;
    const sid = statusId('Proposal') ?? statuses[0]?.id;
    const tid = types.find((x) => /paper|research/i.test(x.name))?.id ?? types[0]?.id;
    if (await run('newp', () => supabase.rpc('create_project_phase1', {
      p_name: newProj.trim(), p_type_id: tid, p_status_id: sid, p_wg_unit: newProjUnit || null
    }))) { newProj = ''; newProjUnit = ''; }
  }
  async function createUnit(kind: 'working_group' | 'chapter') {
    const nm = (kind === 'working_group' ? newWg : newCh).trim();
    if (!nm) return;
    if (await run('newu', () => supabase.rpc('unit_create', { p_name: nm, p_kind: kind })))
      { newWg = ''; newCh = ''; }
  }

  // ── 成员维护 ──
  let addName = $state(''); let addEmail = $state(''); let addUnit = $state('');
  async function addMember() {
    if (!addName.trim() || !addEmail.trim()) { toast.error($t('Name and email are required.')); return; }
    if (await run('add', () => supabase.rpc('forge_member_card', {
      p_full_name: addName.trim(), p_email: addEmail.trim(), p_unit: addUnit || null, p_affiliation: null
    }))) { addName = ''; addEmail = ''; }
  }
  const skillDraft: Record<string, string> = {};
  const levelDraft: Record<string, string> = {};
  async function moveMember(m: Mem, unitId: string) {
    if ((unitId || null) === m.unitId) return;
    await run(m.id, () => supabase.rpc('member_set_home_unit', { p_member: m.id, p_unit: unitId || null }));
  }
  async function archiveMember(m: Mem) {
    await run(m.id, () => supabase.rpc('member_archive', { p_member: m.id, p_archived: true }));
  }
  async function removeSkill(m: Mem, skillId: string) {
    await run(m.id, () => supabase.rpc('person_skill_set', { p_skill: skillId, p_level: null, p_member: m.id }));
  }
  async function setQuota(rid: string, q: number) {
    if (!(q >= 0)) return;
    await run(rid, () => supabase.rpc('resource_set_quota', { p_resource: rid, p_quota: q }));
  }
  const resDraft: Record<string, string> = {};
  const resQty: Record<string, string> = {};
  const resModel: Record<string, string> = {};
  async function addResource(m: Mem) {
    const typeId = resDraft[m.id];
    const qty = Number(resQty[m.id]);
    if (!typeId || !(qty > 0)) return;
    const ty = resourceTypes.find((x) => x.id === typeId);
    const isGpu = /gpu|compute/i.test(ty?.name ?? '');
    await run('res' + m.id, () => supabase.rpc('forge_resource', {
      p_type: typeId, p_name: ty?.name ?? 'Resource', p_holder: m.id, p_scope: 'member',
      p_monthly_quota: qty, p_gpu_model: isGpu ? (resModel[m.id] || gpuModels[0]?.id || null) : null
    }));
  }
  const inviteHref = (m: Mem) =>
    `mailto:${m.email}?subject=${encodeURIComponent('Join The Fin AI research community')}&body=${encodeURIComponent(
      `Hi ${m.name},\n\nSign up with this email at ${location.origin}/login and your member record links automatically.\n`)}`;
  const linkPick: Record<string, string> = {};
  async function linkOrphan(o: { account_id: string; email: string }) {
    const mid = linkPick[o.account_id];
    if (!mid) return;
    await run('lnk', () => supabase.rpc('member_link_account', { p_member: mid, p_account: o.account_id }));
  }

  const slotAsk = (s: Slot) =>
    s.slot_kind === 'leader' ? $t('Lead · hours') :
    s.slot_kind === 'work_resource' ? (s.resource_type?.name ?? $t('Resource')) :
    `${s.skill?.name ?? $t('Hours')}${s.desired_level ? ' (' + $t(LV[s.desired_level] ?? s.desired_level) + ')' : ''}${s.quota ? ` ${s.quota}h/${$t('mo')}` : ''}`;
  const seatPrice = (s: Slot) =>
    s.slot_kind === 'work_resource' ? $t('by type') : s.quota ? `≈ ${Number(s.quota) * 10} STR/${$t('mo')}` : '';
  const roleOf = (s: Slot) => s.authorship ?? (s.slot_kind === 'leader' ? 'first' : 'normal');
</script>

<svelte:head><title>{$t('Market')} · The Fin AI</title></svelte:head>

<div class="mk">
  <div class="mtop">
    <h1>🌿 {$t('Market')}</h1>
    <details class="acct newmenu">
      <summary class="np">+ {$t('New')} ▾</summary>
      <div class="km">
        <details class="sub2"><summary class="mi">{$t('Project')}</summary>
          <div class="hf"><input placeholder={$t('Project name')} bind:value={newProj} style="width:9rem" />
            <select bind:value={newProjUnit}><option value="">{$t('Proposal (no group)')}</option>
              {#each wgs as u}<option value={u.id}>{u.name}</option>{/each}</select>
            <button class="bt sm" disabled={busy === 'newp'} onclick={createProject}>{$t('Create')}</button></div>
        </details>
        <details class="sub2"><summary class="mi">{$t('Working group (projects)')}</summary>
          <div class="hf"><input placeholder={$t('Group name')} bind:value={newWg} style="width:9rem" />
            <button class="bt sm" disabled={busy === 'newu'} onclick={() => createUnit('working_group')}>{$t('Create')}</button></div>
        </details>
        <details class="sub2"><summary class="mi">{$t('Chapter (people)')}</summary>
          <div class="hf"><input placeholder={$t('Chapter name')} bind:value={newCh} style="width:9rem" />
            <button class="bt sm" disabled={busy === 'newu'} onclick={() => createUnit('chapter')}>{$t('Create')}</button></div>
        </details>
        <details class="sub2"><summary class="mi">{$t('New venue')}</summary>
          <div class="hf"><input placeholder={$t('Venue name')} bind:value={newVen} style="width:7rem" />
            <select bind:value={newVenKind}>
              <option value="conference">{$t('Conference')}</option>
              <option value="journal">{$t('Journal')}</option>
              <option value="rolling">{$t('Rolling')}</option></select>
            <input type="date" bind:value={newVenDdl} title={$t('Deadline')} />
            <button class="bt sm" disabled={busy === 'newv'} onclick={createVenue}>{$t('Create')}</button></div>
        </details>
      </div>
    </details>
  </div>

  {#if loading}
    <p class="mut">{$t('Loading…')}</p>
  {:else}
    <div class="strbar">
      <div class="strt">STR
        <span class="lbp">{$t('Nominal (in pool)')} {nomTotal.toLocaleString()}</span> ·
        <span class="lbs">{$t('Settled')} {setTotal.toLocaleString()}</span>
        <span class="mut"> · {$t('Nominal converts to settled by share at settlement')} · 1 {$t('hour')} = 10 STR</span>
      </div>
      <div class="lbrow"><span class="lbl">{$t('Members')}</span>
        {#each memBoard as [nm, v], i}<span class="lbi"><span class="lbn">{i + 1}</span>
          <span class="av" style="background:{avColor(nm)}22;color:{avColor(nm)}">{initials(nm)}</span>
          <span class="lbm">{nm}</span><span class="lbp">{v.toLocaleString()}</span>
          {#if settledPerName[nm]}<span class="lbs">{settledPerName[nm].toLocaleString()}</span>{/if}</span>{/each}
      </div>
      <div class="lbrow"><span class="lbl">{$t('Groups')}</span>
        {#each wgBoard as [nm, v], i}<span class="lbi"><span class="lbn">{i + 1}</span>
          <span class="lbm">{nm}</span><span class="lbp">{v.toLocaleString()}</span></span>{/each}
      </div>
      <div class="lbrow"><span class="lbl">{$t('Chapters')}</span>
        {#each chBoard.rows as [nm, v], i}<span class="lbi"><span class="lbn">{i + 1}</span>
          <span class="lbm">{nm}</span><span class="lbp">{v.toLocaleString()}</span>
          {#if chBoard.set[nm]}<span class="lbs">{chBoard.set[nm].toLocaleString()}</span>{/if}</span>{/each}
      </div>
    </div>

    <div class="cols">
      <div>
        {#snippet cands(p: Proj, s: Slot)}
          <div class="cands">
            {#each freeMems.slice(0, 5) as fm}
              <label class="cd">
                <input type="radio" name="pick-{s.id}" value={fm.id} bind:group={assignPick[s.id]} />
                <span class="av" style="background:{avColor(fm.name)}22;color:{avColor(fm.name)}">{initials(fm.name)}</span>
                <span class="cdn">{fm.name}</span>
                <span class="cdi">{fm.skills[0]?.name ?? ''} · {$t('free')} {freeOf(fm)}h</span>
              </label>
            {/each}
            <div class="cd">
              <PersonPick placeholder={$t('Search member…')}
                people={mems.map((om) => ({ id: om.id, name: om.name, hint: `${om.skills[0]?.name ?? ''}${freeOf(om) != null ? ` · ${$t('free')} ${freeOf(om)}h` : ''}` }))}
                onpick={(id) => (assignPick[s.id] = id)} />
              <input type="number" min="1" placeholder="h" bind:value={assignHours[s.id]} style="width:3.6rem" />
              <button class="bt sm" disabled={busy === s.id} onclick={() => assignSeat(p, s)}>{$t('Assign')}</button>
            </div>
            {#if unsetCount}<div class="mut">{$t('plus {n} members without hours are hidden', { n: unsetCount })}</div>{/if}
          </div>
        {/snippet}

        {#snippet prow(p: Proj)}
          {@const sg = stage(p)}
          {@const openS = p.slots}
          <details class="prow {sg >= 0 ? SG_CLS[Math.min(sg, 3)] : 'st-dorm'}" open={!!openRows['p' + p.id]} ontoggle={toggleRow('p' + p.id)}>
            <summary>
              <span class="sn">{p.name}</span>
              <span class="stc">{$t(sg >= 0 ? STEPS[Math.min(sg, 3)] : 'On hold')}</span>
              {#if openS.length && (sg === 0 || sg === 1)}<span class="vacb">{$t('needs {n}', { n: openS.length })}</span>{/if}
              <span class="unitc2">{p.unit ?? (p.unitId ? '' : $t('Proposal'))}</span>
              <span class="sp"></span>
              {#if p.team.length}<span class="fp">{#each p.team.slice(0, 3) as seat}<span class="av" style="background:{avColor(seat.name)}22;color:{avColor(seat.name)}">{initials(seat.name)}</span>{/each}{#if p.team.length > 3}<span class="fpn">+{p.team.length - 3}</span>{/if}</span>{/if}
              {#if sg === 3 && p.venue}
                <span class="ddl acc">{p.venueYr}{p.outcome ? ` · ${p.outcome}` : ''}</span>
              {:else if sg === 2 && p.venue}
                {@const dn = decDays(p.decision ?? p.venueNotif)}
                <span class="ddl dec" class:red={dn != null && dn < 0}>{p.venueYr}{dn == null ? '' : dn < 0 ? ` · ${$t('result overdue')}` : ` · ${$t('result in')} ${dn}d`}</span>
              {:else if p.venue}
                <span class="ddl" class:red={p.ddlDays != null && p.ddlDays <= 35 && p.ddlDays !== 999}
                class:amb={p.ddlDays != null && p.ddlDays > 35 && p.ddlDays <= 70}>{p.venueYr}{p.ddlLabel ? ` · ${p.ddlLabel === 'rolling' ? $t('rolling') : $t('due in') + ' ' + p.ddlLabel}` : ''}</span>{/if}
            </summary>
            <div class="pbody">
              <div class="stp"><span class="stt">{$t(sg >= 0 ? STEPS[Math.min(sg, 3)] : 'On hold')}{sg === 0 ? ' · ' + $t('awaiting first author') : ''}</span>
                <span class="stb">{#each [0, 1, 2, 3] as k}<i class:on={sg >= 0 && k <= sg}></i>{/each}</span></div>
              {#if p.pool}
                <div class="poolln">{$t('Project pool')} {p.pool.toLocaleString()} STR · {$t('author order set by STR at settlement')}</div>
              {/if}

              {#each p.slots.filter((s) => s.slot_kind === 'leader') as s}
                {#if sg === 0 || sg === 1}
                  <details class="seat vac">
                    <summary><span class="no">①</span><span class="rolec r1c">{$t('First author')}</span>
                      <span class="ask">{$t('Lead · open')}</span><span class="hint">{$t('Choose member')} ▾</span></summary>
                    {@render cands(p, s)}
                  </details>
                {:else}
                  <div class="seat dim"><span class="no">①</span><span class="rolec r1c">{$t('First author')}</span>
                    <span class="ask mut">{$t('Lead · open')}</span></div>
                {/if}
              {/each}
              {#each p.team as seat, i}
                {@const pos = i + (leadOpen(p) ? 1 : 0)}
                <div class="seat">
                  <span class="no">{CIRC[Math.min(pos, 11)]}</span>
                  <span class="av" style="background:{avColor(seat.name)}22;color:{avColor(seat.name)}">{initials(seat.name)}</span>
                  <span class="an">{seat.name}</span>
                  {#if sg <= 2 && seat.authorship !== 'first'}
                    <select class="rolec rolesel {ROLE_CLS[seat.authorship] ?? ''}" value={seat.authorship}
                      onchange={(e) => { const v = (e.target as HTMLSelectElement).value; seat.authorship = v; setRole(seat.slotId, v); }}>
                      <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                      <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
                    </select>
                  {:else}
                    <span class="rolec {ROLE_CLS[seat.authorship] ?? ''}">{$t(ROLE_LABEL[seat.authorship] ?? 'Author')}</span>
                  {/if}
                  {#if sg <= 1}
                    <span class="give"><input class="ghours" type="number" min="1" value={seat.amount}
                      onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h > 0 && h !== seat.amount) {
                        seat.amount = h; // optimistic; reload reconciles nominal
                        run(seat.slotId + seat.memberId, () => supabase.rpc('assign', { p_member: seat.memberId, p_slot: seat.slotId, p_hours: h })); } }} />h/{$t('mo')}</span>
                  {:else}
                    <span class="give">{seat.amount}h/{$t('mo')}</span>
                  {/if}
                  {#if seat.nominal}<span class="pts">{seat.nominal.toLocaleString()} STR</span>{/if}
                  {#if sg <= 1}<button class="rel" title={$t('Remove')} onclick={() => removeSeat(p, seat)}>×</button>{/if}
                </div>
              {/each}
              {#each p.slots.filter((s) => s.slot_kind !== 'leader') as s, j}
                {@const pos = p.team.length + (leadOpen(p) ? 1 : 0) + j}
                {#if sg === 1 || sg === 2}
                  <details class="seat vac">
                    <summary><span class="no">{CIRC[Math.min(pos, 11)]}</span>
                      <select class="rolec rolesel {ROLE_CLS[roleOf(s)] ?? ''}" value={roleOf(s)}
                        onclick={(e) => e.preventDefault()}
                        onchange={(e) => { const v = (e.target as HTMLSelectElement).value; s.authorship = v; setRole(s.id, v); }}>
                        <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                        <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
                      </select>
                      <span class="ask">{slotAsk(s)} · {$t('open')}</span>
                      {#if seatPrice(s)}<span class="pts">{seatPrice(s)}</span>{/if}
                      <span class="hint">{$t('Choose member')} ▾</span>
                      <button class="rel" title={$t('Remove')} onclick={(e) => { e.preventDefault(); run(s.id, () => supabase.rpc('slot_close', { p_slot: s.id })); }}>×</button></summary>
                    {@render cands(p, s)}
                  </details>
                {:else}
                  <div class="seat dim"><span class="no">{CIRC[Math.min(pos, 11)]}</span>
                    <span class="rolec {ROLE_CLS[roleOf(s)] ?? ''}">{$t(ROLE_LABEL[roleOf(s)] ?? 'Author')}</span>
                    <span class="ask mut">{slotAsk(s)} · {$t('open')}{sg === 0 ? ' · ' + $t('awaiting first author') : ''}</span></div>
                {/if}
              {/each}
              {#if !p.team.length && !p.slots.length}<div class="seat"><span class="mut">{$t('no members yet')}</span></div>{/if}

              {#if sg <= 2}
                <details class="hire"><summary>+ {$t('Add author')}</summary>
                  <div class="hf">
                    <PersonPick placeholder={$t('Search member…')}
                      people={mems.map((om) => ({ id: om.id, name: om.name, hint: `${om.skills[0]?.name ?? ''}${freeOf(om) != null ? ` · ${$t('free')} ${freeOf(om)}h` : ''}` }))}
                      onpick={(id) => (authorPick[p.id] = id)} />
                    <select bind:value={authorRole[p.id]}>
                      <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                      <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
                    </select>
                    <input type="number" min="1" bind:value={authorHours[p.id]} placeholder="5" style="width:3.4rem" />h/{$t('mo')}
                    <button class="bt sm" disabled={busy === 'au' + p.id} onclick={() => addAuthor(p)}>{$t('Add')}</button>
                  </div>
                </details>
              {/if}
              {#if sg === 1 || sg === 2}
                <details class="hire"><summary>+ {$t('Add opening')}</summary>
                  <div class="hf">
                    <label>{$t('Role')} <select bind:value={openRole[p.id]}>
                      <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                      <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
                    </select></label>
                    <label>{$t('Needs')} <select bind:value={openNeed[p.id]}>
                      {#each skills as skl}<option value={skl.id}>{skl.name}</option>{/each}
                      {#each resourceTypes.filter((r) => r.name !== 'Labor') as r}<option value={'rt:' + r.id}>{r.name} ({$t('resource')})</option>{/each}
                    </select></label>
                    <input type="number" min="1" bind:value={openHours[p.id]} placeholder="8" style="width:3.4rem" />h/{$t('mo')}
                    <span class="pts">≈ 80 STR/{$t('mo')}</span>
                    <button class="bt sm" disabled={busy === 'open' + p.id} onclick={() => addOpening(p)}>{$t('Add')}</button>
                  </div>
                </details>
              {/if}

              <div class="tail">
                <label class="stsel">{$t('Stage')}
                  <select disabled={busy === 'st' + p.id}
                    value={statuses.find((s) => s.name === p.status)?.id ?? ''}
                    onchange={(e) => setStatus(p, (e.target as HTMLSelectElement).value)}>
                    {#each orderedStatuses as s}<option value={s.id}>{$t(s.name)}</option>{/each}
                  </select></label>
                {#if sg === 2}
                  <label class="stsel">{$t('Result date')}
                    <input type="date" value={p.decision ?? p.venueNotif ?? ''}
                      onchange={(e) => run('dd' + p.id, () => supabase.rpc('project_set_deadline', { p_project: p.id, p_deadline: (e.target as HTMLInputElement).value || null }))} /></label>
                {/if}
                {#if sg === 3 && !p.outcome}
                  <span class="stsel">{$t('Outcome')}
                    <input placeholder="main / findings" style="width:7rem"
                      onchange={(e) => { const v = (e.target as HTMLInputElement).value.trim(); if (v) run('tg' + p.id, () => supabase.rpc('project_set_meta', { p_project: p.id, p_tag: v })); }} /></span>
                {/if}
                {#if sg === 3}<a class="bt sm ghosted" href="/admin">{$t('Settle (President)')}</a>
                  <button class="bt sm ghosted" disabled={busy === 'ar' + p.id}
                    onclick={() => run('ar' + p.id, () => supabase.rpc('project_archive', { p_project: p.id, p_archived: true }))}>{$t('Archive')}</button>{/if}
                {#if sg !== 3}<details class="sub2"><summary>{$t('Edit')} ▾</summary>
                  <div class="hf">
                    <label>{$t('Name')} <input value={p.name} oninput={(e) => (editName[p.id] = (e.target as HTMLInputElement).value)} style="width:10rem" /></label>
                    <label>{$t('Venue')} <select value={p.venueId ?? ''} onchange={(e) => (editVenue[p.id] = (e.target as HTMLSelectElement).value)}>
                      <option value="">{$t('TBD')}</option>
                      {#each venues as v}<option value={v.id}>{venLabel(v)}</option>{/each}</select></label>
                    <label>{$t('Group')} <select value={p.unitId ?? ''} onchange={(e) => (editUnit[p.id] = (e.target as HTMLSelectElement).value)}>
                      <option value="">{$t('Proposal (no group)')}</option>
                      {#each wgs as u}<option value={u.id}>{u.name}</option>{/each}</select></label>
                    <button class="bt sm" disabled={busy === 'e' + p.id} onclick={() => saveProject(p)}>{$t('Save')}</button>
                    <details class="dz"><summary>{$t('Archive (recoverable)…')}</summary>
                      <span class="mut">{$t('Sure?')} </span>
                      <button class="bt sm danger" disabled={busy === 'a' + p.id} onclick={() => archiveProject(p)}>{$t('Confirm')}</button></details>
                  </div>
                </details>{/if}
                <details class="sub2"><summary>{$t('Activity')} ▾</summary>
                  <div class="evs">
                    {#each p.team.slice(0, 6) as seat}
                      <div class="evrow"><span class="av sm" style="background:{avColor(seat.name)}22;color:{avColor(seat.name)}">{initials(seat.name)}</span>
                        {seat.name} {$t('joined')} · {seat.amount}h/{$t('mo')}</div>
                    {:else}<div class="mut">{$t('No activity yet')}</div>{/each}
                  </div>
                </details>
              </div>
            </div>
          </details>
        {/snippet}

        <div class="vtool">
          <label>{$t('Group by')}
            <select bind:value={groupBy}>
              <option value="needs">{$t('Needs people')}</option>
              <option value="stage">{$t('By stage')}</option>
              <option value="wg">{$t('By working group')}</option>
              <option value="venue">{$t('By venue')}</option>
              <option value="none">{$t('Flat')}</option>
            </select></label>
          <label>{$t('Sort')}
            <select bind:value={sortBy}>
              <option value="ddl">{$t('By deadline')}</option>
              <option value="name">{$t('By name')}</option>
              <option value="pool">{$t('By pool STR')}</option>
            </select></label>
        </div>
        {#each sections as sec (sec.label)}
          {#if sec.ps.length}
            <h2>{sec.label} <span class="n">{sec.ps.length}</span></h2>
            {#each sec.ps as p (p.id)}{@render prow(p)}{/each}
          {/if}
        {/each}
        {#if archived.length || finished.length}
          <details class="arcpool" open={!!openRows['arc']} ontoggle={toggleRow('arc')}>
            <summary><h2 style="display:inline">{$t('Accepted')} <span class="n">{finished.length + archived.length}</span></h2></summary>
            {#each finished as p (p.id)}{@render prow(p)}{/each}
            {#each archived as p (p.id)}
              <div class="arow">
                <span class="sn">{p.name}</span>
                {#if p.venue}<span class="ddl acc">{p.venueYr}{p.outcome ? ` · ${p.outcome}` : ''}</span>{/if}
                <span class="sp"></span>
                <button class="bt sm ghosted" disabled={busy === 'ar' + p.id}
                  onclick={() => run('ar' + p.id, () => supabase.rpc('project_archive', { p_project: p.id, p_archived: false }))}>{$t('Restore')}</button>
              </div>
            {/each}
          </details>
        {/if}
      </div>

      <div>
        <h2>{$t('Members')} <span class="n">{mems.length} · {$t('linked')} {linkedCount} · {$t('unlinked')} {mems.length - linkedCount}</span></h2>

        {#each orphans as o (o.account_id)}
          <details class="p m-over orphan" open={!!openRows['o' + o.account_id]} ontoggle={toggleRow('o' + o.account_id)}>
            <summary><span class="regd on"></span><span class="pname">{o.email}</span>
              <span class="chip mutc">{$t('registered, linked to no member')}</span></summary>
            <div class="pf">
              <label>{$t('Link to member')}
                <PersonPick placeholder={$t('Search member…')}
                  people={mems.filter((m) => !m.linked).map((m) => ({ id: m.id, name: m.name, hint: m.email }))}
                  onpick={(id) => (linkPick[o.account_id] = id)} /></label>
              <button class="bt sm" disabled={busy === 'lnk'} onclick={() => linkOrphan(o)}>{$t('Link')}</button>
              <span class="mut wfull">{$t('Or: if the account email matches a member email, linking is automatic on login')}</span>
            </div>
          </details>
        {/each}

        <details class="newbox">
          <summary class="bt sm">+ {$t('Member')}</summary>
          <div class="pf">
            <input placeholder={$t('Name')} bind:value={addName} style="width:7rem" />
            <input placeholder={$t('Email')} bind:value={addEmail} style="width:10rem" />
            <select bind:value={addUnit}><option value="">{$t('No chapter')}</option>
              {#each chapterUnits as u}<option value={u.id}>{u.name}</option>{/each}</select>
            <button class="bt sm" disabled={busy === 'add'} onclick={addMember}>{$t('Add')}</button>
            <span class="mut wfull">{$t('Adding creates a member card — no email is sent; if they later sign up with this email it links automatically')}</span>
          </div>
        </details>

        {#each chapterGroups as [cn, list] (cn)}
          <h3 class="sh">{cn || $t('No chapter')}<span class="n">{list.length}</span></h3>
          {#each list as m (m.id)}
            {@const fh = freeOf(m)}
            <details class="p {fh != null && fh > 0 ? 'm-free' : fh != null && fh < 0 ? 'm-over' : m.hours == null ? 'm-unset' : 'm-full'}" open={!!openRows['m' + m.id]} ontoggle={toggleRow('m' + m.id)}>
              <summary>
                <span class="av md" style="background:{avColor(m.name)}22;color:{avColor(m.name)}">{initials(m.name)}</span>
                <span class="pname">{m.name}</span>
                <span class="regd" class:on={m.linked} title={m.linked ? $t('linked account') : $t('not registered · linked on sign-up')}></span>
                <span class="sp"></span>
                {#if m.hours == null}<span class="warn">{$t('no hours set')}</span>
                {:else if fh != null && fh < 0}<span class="warn">{$t('over by')} {-fh}h</span>
                {:else if fh === 0}<span class="mut mr">{$t('fully booked')}</span>
                {:else}<span class="okn">{$t('free')} {fh}h</span>{/if}
              </summary>
              <div class="pf">
                <div class="wfull">
                  {#each m.skills as skl (skl.id)}<span class="chip"><span class="cn" title={skl.name}>{skl.name}</span>
                    <select class="lvlsel" value={skl.level} title={$t(LV[skl.level] ?? skl.level)}
                      onchange={(e) => { const lv = (e.target as HTMLSelectElement).value; skl.level = lv;
                        run(m.id, () => supabase.rpc('person_skill_set', { p_skill: skl.id, p_level: lv, p_member: m.id })); }}>
                      <option value="learning">{$t('Lrn')}</option>
                      <option value="independent">{$t('Ind')}</option>
                      <option value="lead">{$t('Lead')}</option>
                    </select>
                    <button class="chipx" title={$t('Remove')} onclick={() => removeSkill(m, skl.id)}>×</button></span>{/each}
                  {#each m.resources as r (r.id)}<span class="chip rs">{r.typeName}
                    <input class="ghours" type="number" min="0" value={r.quota}
                      onchange={(e) => { const q = Number((e.target as HTMLInputElement).value); if (q >= 0) { r.quota = q; setQuota(r.id, q); } }} /></span>{/each}
                  {#if !m.skills.length && !m.resources.length}<span class="chip mutc">{$t('no skills set')}</span>{/if}
                </div>
                <label>{$t('Monthly')} (h)<input type="number" min="0" value={m.hours ?? ''}
                  onchange={(e) => { const h = Math.max(0, Math.floor(Number((e.target as HTMLInputElement).value) || 0));
                    m.hours = h; run(m.id, () => supabase.rpc('person_set_capacity', { p_hours: h, p_member: m.id })); }} /></label>
                <label>{$t('Chapter')} <select value={m.unitId ?? ''} onchange={(e) => moveMember(m, (e.target as HTMLSelectElement).value)}>
                  <option value="">{$t('No chapter')}</option>
                  {#each chapterUnits as u}<option value={u.id}>{u.name}</option>{/each}</select></label>
                <details class="sub2 wfull"><summary>+ {$t('Add skill / resource')}</summary>
                  <div class="addbox">
                    <div class="addrow">
                      <select bind:value={skillDraft[m.id]}>
                        <option value="">{$t('Skill')}…</option>
                        {#each skills as skl}<option value={skl.id}>{skl.name}</option>{/each}</select>
                      <select bind:value={levelDraft[m.id]}>
                        <option value="independent">{$t('Independent')}</option>
                        <option value="learning">{$t('Learning')}</option>
                        <option value="lead">{$t('Can mentor')}</option></select>
                      <button class="bt sm ghosted" disabled={busy === m.id}
                        onclick={() => { const skid = skillDraft[m.id]; if (skid) run(m.id, () => supabase.rpc('person_skill_set', { p_skill: skid, p_level: levelDraft[m.id] || 'independent', p_member: m.id })); }}>{$t('Add')}</button>
                    </div>
                    <div class="addrow">
                      <select bind:value={resDraft[m.id]}>
                        <option value="">{$t('Resource')}…</option>
                        {#each resourceTypes.filter((x) => x.name !== 'Labor') as ty}<option value={ty.id}>{ty.name}</option>{/each}</select>
                      <input type="number" min="1" placeholder={$t('qty') + '/' + $t('mo')} bind:value={resQty[m.id]} style="width:4.6rem" />
                      <select bind:value={resModel[m.id]} style="max-width:7.5rem" title="GPU model">
                        {#each gpuModels as g}<option value={g.id}>{g.name}</option>{/each}</select>
                      <button class="bt sm ghosted" disabled={busy === 'res' + m.id} onclick={() => addResource(m)}>{$t('Add')}</button>
                    </div>
                  </div>
                </details>
                {#if !m.linked && m.email}<a class="bt sm ghosted" href={inviteHref(m)}>{$t('Send invite')}</a>{/if}
                <details class="dz"><summary>{$t('Remove (recoverable)…')}</summary>
                  <span class="mut">{$t('Sure?')} </span>
                  <button class="bt sm danger" disabled={busy === m.id} onclick={() => archiveMember(m)}>{$t('Confirm')}</button></details>
              </div>
            </details>
          {/each}
        {/each}
        {#if removedMems.length}
          <details class="arcpool" open={!!openRows['rm']} ontoggle={toggleRow('rm')}>
            <summary><h2 style="display:inline">{$t('Removed')} <span class="n">{removedMems.length}</span></h2></summary>
            {#each removedMems as rm2 (rm2.id)}
              <div class="arow">
                <span class="av" style="background:{avColor(rm2.name)}22;color:{avColor(rm2.name)}">{initials(rm2.name)}</span>
                <span class="sn">{rm2.name}</span>
                <span class="sp"></span>
                <button class="bt sm ghosted" disabled={busy === 'rm' + rm2.id}
                  onclick={() => run('rm' + rm2.id, () => supabase.rpc('member_archive', { p_member: rm2.id, p_archived: false }))}>{$t('Restore')}</button>
              </div>
            {/each}
          </details>
        {/if}
      </div>
    </div>
    <div class="foot">The Fin AI Research Community · 1 {$t('hour')} = 10 STR · {$t('compute / datasets / funding convert by type')}</div>
  {/if}
</div>

<style>
  /* Notion-modern: white sheet, sans type, hover-wash rows; state lives in
     small colored tags, not row backgrounds. (概念稿 v49 + notion 语言) */
  .mk { --ink2: #37352f; --dim2: #6b6a66; --faint2: #9b9a97; --line2: #e9e9e7;
    --wash: #f7f7f5; --green: #0b5e52;
    --tag-or-bg: #fadec9; --tag-or-tx: #9a5b13;   /* Start / openings */
    --tag-gn-bg: #dbeddb; --tag-gn-tx: #1c513f;   /* Active / settled */
    --tag-bl-bg: #d3e5ef; --tag-bl-tx: #2b5a75;   /* In review / corresponding */
    --tag-yl-bg: #fdecc8; --tag-yl-tx: #6f5615;   /* Accepted / nominal STR */
    --tag-gy-bg: #f1f0ef; --tag-gy-tx: #57564f;   /* On hold / neutral */
    --tag-rd-bg: #ffe2dd; --tag-rd-tx: #93382a;   /* first author / danger */
    --tag-pu-bg: #e8deee; --tag-pu-tx: #5a4a72;   /* resources */
    margin: 0 auto; color: var(--ink2); font-size: 14px; }
  .mtop { display: flex; align-items: baseline; gap: 16px; }
  h1 { font-size: 28px; font-weight: 700; letter-spacing: -.01em; padding: 14px 0 14px; }
  h2 { font-size: 13px; font-weight: 600; color: var(--dim2); padding: 14px 0 6px; }
  h2 .n, .sh .n { color: var(--faint2); font-weight: 400; font-size: 12px; margin-left: 5px; }
  .sh { font-size: 12px; font-weight: 600; color: var(--faint2); padding: 16px 2px 6px; }
  .vtool { display: flex; gap: 14px; align-items: center; padding: 2px 0 4px; }
  .vtool label { display: inline-flex; gap: 4px; align-items: center; font-size: 12px; color: var(--faint2); }
  .vtool :global(select) { border: 0 !important; background: none !important; color: var(--dim2);
    font-weight: 500; padding: 2px 4px; cursor: pointer; }
  .vtool :global(select:hover) { background: var(--wash) !important; border-radius: 4px; }
  .cols { display: grid; grid-template-columns: 3fr 1fr; gap: 32px; align-items: start; }
  .cols > div { min-width: 0; }
  @media (max-width: 940px) { .cols { grid-template-columns: 1fr; } }
  .mut { color: var(--faint2); font-size: 12px; }
  .mut.mr { white-space: nowrap; }
  .wfull { width: 100%; }

  .av { display: inline-flex; align-items: center; justify-content: center; border-radius: 50%;
    width: 20px; height: 20px; font-size: 8.5px; font-weight: 700; flex: none; }
  .av.md { width: 26px; height: 26px; font-size: 10.5px; }
  .av.sm { width: 14px; height: 14px; font-size: 6.5px; }

  .strbar { display: flex; flex-direction: column; gap: 5px; border: 1px solid var(--line2);
    border-radius: 8px; padding: 12px 16px; margin: 2px 0 10px; }
  .strt { font-size: 13px; color: var(--dim2); }
  .lbrow { display: flex; gap: 14px; align-items: center; flex-wrap: wrap; }
  .lbl { font-size: 11px; font-weight: 600; color: var(--faint2); width: 52px; flex: none; }
  .lbi { display: inline-flex; align-items: center; gap: 5px; font-size: 12.5px; }
  .lbn { font-size: 10.5px; color: var(--faint2); font-weight: 600; }
  .lbm { font-weight: 500; }
  .lbp { color: #b47d17; font-weight: 600; font-size: 12px; font-variant-numeric: tabular-nums; }
  .lbs { color: var(--green); font-weight: 600; font-size: 12px; font-variant-numeric: tabular-nums; }

  .prow { border-radius: 6px; margin: 0 -8px 1px; }
  .prow > summary { display: flex; align-items: center; gap: 8px; padding: 7px 8px; cursor: pointer;
    list-style: none; border-radius: 6px; }
  .prow > summary:hover { background: var(--wash); }
  .prow > summary::-webkit-details-marker { display: none; }
  .prow[open] { background: #fbfbfa; border: 1px solid var(--line2); margin-bottom: 8px; }
  .prow[open] > summary { border-bottom: 1px solid #f1f1ef; border-radius: 6px 6px 0 0; }
  .prow.st-dorm { opacity: .55; }
  .arcpool { margin-top: 16px; }
  .arcpool > summary { list-style: none; cursor: pointer; }
  .arcpool > summary::-webkit-details-marker { display: none; }
  .arow { display: flex; align-items: center; gap: 8px; padding: 5px 8px; margin: 0 -8px;
    border-radius: 6px; opacity: .65; font-size: 13px; }
  .arow:hover { background: var(--wash); opacity: 1; }
  .sn { font-size: 14px; font-weight: 500; color: var(--ink2); min-width: 0; max-width: 46%;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sp { flex: 1; }
  .fp { display: inline-flex; align-items: center; }
  .fp .av { margin-left: -5px; box-shadow: 0 0 0 1.5px #fff; }
  .fp .av:first-child { margin-left: 0; }
  .fpn { font-size: 10.5px; color: var(--faint2); margin-left: 3px; }
  .stc { font-size: 11.5px; border-radius: 4px; padding: 1px 7px; white-space: nowrap;
    background: var(--tag-gy-bg); color: var(--tag-gy-tx); }
  .prow.st-seed .stc { background: var(--tag-or-bg); color: var(--tag-or-tx); }
  .prow.st-grow .stc { background: var(--tag-gn-bg); color: var(--tag-gn-tx); }
  .prow.st-rev .stc { background: var(--tag-bl-bg); color: var(--tag-bl-tx); }
  .prow.st-ripe .stc { background: var(--tag-yl-bg); color: var(--tag-yl-tx); }
  .unitc2 { font-size: 11.5px; color: var(--faint2); white-space: nowrap; }
  .vacb { font-size: 11.5px; font-weight: 600; color: var(--tag-or-tx); background: var(--tag-or-bg);
    border-radius: 4px; padding: 1px 7px; white-space: nowrap; }
  .ddl { font-size: 11.5px; color: var(--faint2); white-space: nowrap; }
  .ddl.amb { color: var(--tag-or-tx); }
  .ddl.red { color: var(--tag-rd-tx); font-weight: 600; }
  .ddl.dec { color: var(--tag-bl-tx); }
  .ddl.acc { color: var(--tag-gn-tx); background: var(--tag-gn-bg); border-radius: 4px; padding: 1px 7px; font-weight: 600; }
  .pbody { padding: 8px 8px 12px; }
  .stp { display: flex; align-items: center; gap: 8px; }
  .stt { font-size: 12px; color: var(--dim2); white-space: nowrap; }
  .stb { display: flex; gap: 3px; flex: 1; }
  .stb i { flex: 1; height: 3px; border-radius: 2px; background: #37352f14; }
  .stb i.on { background: var(--green); }
  .poolln { font-size: 12px; color: var(--dim2); padding: 6px 0 2px; }

  .seat { padding: 6px 0; border-top: 1px solid #37352f0a; font-size: 13px; display: flex; align-items: center; gap: 8px; }
  details.seat { display: block; }
  details.seat > summary { display: flex; align-items: center; gap: 8px; cursor: pointer; list-style: none;
    margin: 0 -8px; padding: 2px 8px; border-radius: 4px; }
  details.seat > summary:hover { background: var(--wash); }
  details.seat > summary::-webkit-details-marker { display: none; }
  .seat .no { font-size: 11.5px; color: var(--faint2); }
  .seat .an { font-weight: 500; }
  .seat .give { margin-left: auto; font-size: 11.5px; color: var(--faint2); display: inline-flex; align-items: center; gap: 2px; }
  .ghours { width: 3.2rem; text-align: right; border: 1px solid transparent !important; background: none !important; padding: 1px 4px !important; }
  .ghours:hover, .ghours:focus { border-color: var(--line2) !important; background: #fff !important; }
  .seat .ask { color: var(--tag-or-tx); font-weight: 500; }
  .seat .ask.mut { color: var(--faint2); font-weight: 400; }
  .seat .hint { margin-left: auto; font-size: 12px; font-weight: 500; color: var(--green); }
  .seat.dim { opacity: .55; }
  .rel { color: var(--faint2); cursor: pointer; font-weight: 600; padding: 0 4px; opacity: 0; border: 0;
    background: none; font-size: 13px; border-radius: 4px; }
  .seat:hover .rel, details.seat > summary:hover .rel { opacity: 1; color: var(--tag-rd-tx); }
  .rolec { font-size: 11px; font-weight: 500; border-radius: 4px; padding: 0 6px; white-space: nowrap;
    background: var(--tag-gy-bg); color: var(--tag-gy-tx); }
  .rolec.r1c { background: var(--tag-rd-bg); color: var(--tag-rd-tx); }
  .rolec.rcor { background: var(--tag-bl-bg); color: var(--tag-bl-tx); }
  .rolec.rlast { background: var(--tag-gn-bg); color: var(--tag-gn-tx); }
  select.rolesel { border: 0 !important; padding: 0 4px !important; cursor: pointer;
    -webkit-appearance: none; appearance: none; font-size: 11px !important; font-weight: 500; }
  .pts { font-size: 11px; font-weight: 600; color: var(--tag-yl-tx); background: var(--tag-yl-bg);
    border-radius: 4px; padding: 0 6px; white-space: nowrap; }
  .cands { margin: 6px 0 4px 20px; max-width: 380px; background: var(--wash);
    border-radius: 6px; padding: 8px 10px; }
  .cd { display: flex; align-items: center; gap: 7px; padding: 3px 0; font-size: 12.5px; cursor: pointer; }
  .cd input[type="radio"] { margin: 0; accent-color: var(--green); }
  .cdn { font-weight: 500; white-space: nowrap; }
  .cdi { color: var(--faint2); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  .hire { margin-top: 8px; }
  .hire > summary { list-style: none; cursor: pointer; display: inline-block; font-size: 12.5px;
    color: var(--dim2); font-weight: 500; border-radius: 6px; padding: 3px 8px; }
  .hire > summary:hover { background: var(--wash); color: var(--ink2); }
  .hire > summary::-webkit-details-marker { display: none; }
  .hf { display: flex; gap: 6px; align-items: center; padding: 8px 0 2px; font-size: 12.5px;
    color: var(--dim2); flex-wrap: wrap; }
  .hf label { display: inline-flex; gap: 3px; align-items: center; }

  .tail { display: flex; gap: 14px; align-items: center; padding-top: 10px; flex-wrap: wrap; }
  .stsel { display: inline-flex; gap: 5px; align-items: center; font-size: 12px; color: var(--faint2); }
  .sub2 > summary { list-style: none; cursor: pointer; font-size: 12px; color: var(--dim2);
    font-weight: 500; border-radius: 4px; padding: 2px 6px; margin-left: -6px; }
  .sub2 > summary:hover { background: var(--wash); color: var(--ink2); }
  .sub2 > summary::-webkit-details-marker { display: none; }
  .evs { padding: 6px 0 0; }
  .evrow { font-size: 12px; color: var(--dim2); padding: 2px 0; display: flex; align-items: center; gap: 5px; }

  .p { border-radius: 6px; margin: 0 -8px 1px; }
  .p > summary { display: flex; align-items: center; gap: 7px; cursor: pointer; list-style: none;
    padding: 6px 8px; border-radius: 6px; }
  .p > summary:hover { background: var(--wash); }
  .p > summary::-webkit-details-marker { display: none; }
  .p[open] { background: #fbfbfa; border: 1px solid var(--line2); margin-bottom: 8px; }
  .p[open] > summary { border-bottom: 1px solid #f1f1ef; border-radius: 6px 6px 0 0; }
  .p[open] .pf { padding: 8px 10px; }
  .p.orphan { border: 1px solid var(--tag-rd-bg); background: #fff7f6; margin-bottom: 10px; }
  .p[open] > summary { flex-wrap: wrap; }
  .pname { font-weight: 500; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .chip { background: var(--tag-gy-bg); border-radius: 4px; font-size: 10.5px; padding: 1px 5px; color: var(--tag-gy-tx); white-space: nowrap; }
  .chip.rs { background: var(--tag-pu-bg); color: var(--tag-pu-tx); font-weight: 500; }
  .chip.mutc { color: var(--faint2); background: transparent; border: 1px dashed var(--line2); }
  .chipx { border: 0; background: none; cursor: pointer; color: inherit; opacity: .5; padding: 0 1px; font-size: 11px; }
  .chipx:hover { opacity: 1; color: var(--tag-rd-tx); }
  .chip .ghours { width: 3.4rem; font-size: 10.5px !important; }
  .lvlsel { border: 0 !important; background: none !important; font-size: 10.5px !important;
    color: inherit; padding: 0 !important; cursor: pointer; max-width: 3.2rem; }
  .chip { display: inline-flex; align-items: center; gap: 3px; max-width: 100%; }
  .chip .cn { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 8rem; }
  .addbox { display: flex; flex-direction: column; gap: 5px; padding: 6px 0 2px; }
  .addrow { display: flex; gap: 5px; align-items: center; flex-wrap: wrap; }
  .addrow :global(select) { max-width: 8.5rem; }
  .okn { color: var(--green); font-weight: 600; font-size: 12px; white-space: nowrap; }
  .warn { color: var(--tag-rd-tx); font-weight: 600; font-size: 11.5px; white-space: nowrap; }
  .pf { display: flex; gap: 6px 8px; align-items: center; flex-wrap: wrap; padding: 8px 0 2px;
    font-size: 12px; color: var(--dim2); }
  .pf label { display: flex; flex-direction: column; align-items: stretch; gap: 2px;
    flex: 1 1 44%; min-width: 0; font-size: 11px; color: var(--faint2); }
  .pf label :global(input), .pf label :global(select) { width: 100%; }
  .pf > :global(.bt) { flex: 0 0 auto; }
  .regd { width: 7px; height: 7px; border-radius: 50%; border: 1.5px solid var(--faint2); flex: none; }
  .regd.on { background: var(--green); border-color: var(--green); }

  .dz { width: 100%; }
  .dz > summary { list-style: none; cursor: pointer; font-size: 11.5px; color: var(--tag-rd-tx); }
  .dz > summary::-webkit-details-marker { display: none; }
  .newbox { margin-bottom: 10px; }
  .newbox > summary { list-style: none; cursor: pointer; display: inline-block; }
  .newbox > summary::-webkit-details-marker { display: none; }

  .acct { position: relative; margin-left: auto; }
  .acct > summary { list-style: none; cursor: pointer; display: inline-flex; border-radius: 6px; padding: 3px 8px; }
  .acct > summary:hover { background: var(--wash); }
  .acct > summary::-webkit-details-marker { display: none; }
  .np { color: var(--dim2); font-weight: 500; font-size: 13px; }
  .acct[open] > .km { display: flex; position: absolute; right: 0; top: 30px; z-index: 9; background: #fff;
    border: 1px solid var(--line2); border-radius: 8px; box-shadow: 0 8px 28px rgba(55, 53, 47, .12);
    padding: 6px; min-width: 250px; flex-direction: column; gap: 2px; }
  .mi { font-size: 12.5px; text-align: left; padding: 6px 10px; border: 0; background: none;
    border-radius: 6px; cursor: pointer; color: var(--ink2); list-style: none; }
  .mi::-webkit-details-marker { display: none; }
  .mi:hover { background: var(--wash); }

  .mk :global(input), .mk :global(select) { font: inherit; font-size: 12px; padding: 4px 8px;
    border: 1px solid var(--line2); border-radius: 6px; background: #fff; color: var(--ink2); }
  .mk :global(input:focus), .mk :global(select:focus) { outline: 2px solid #0b5e5233; border-color: var(--green); }
  .bt { font: inherit; font-size: 12px; font-weight: 500; padding: 4px 12px; border: 0; border-radius: 6px;
    background: var(--green); color: #fff; cursor: pointer; text-decoration: none; display: inline-block; }
  .bt:hover { background: #0a5449; }
  .bt:disabled { opacity: .5; }
  .bt.danger { background: var(--tag-rd-tx); }
  .bt.sm { padding: 3px 10px; font-size: 11.5px; }
  .bt.ghosted { background: #fff; color: var(--dim2); border: 1px solid var(--line2); }
  .bt.ghosted:hover { background: var(--wash); }
  .foot { margin-top: 48px; font-size: 12px; color: var(--faint2); }
</style>
