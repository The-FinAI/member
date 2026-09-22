<script lang="ts">
  // 会议模式:看板(按组一览)→ 议程(按截止排队)→ 聚焦(逐项过)。
  // →/← 沿这条线走,Esc 退回上一层;加项目/加人两张大表单任何一层都能开。
  import { t } from '$lib/i18n';
  import PersonPick from '$lib/PersonPick.svelte';
  import PersonFocus from '$lib/PersonFocus.svelte';

  type Give = { slotId: string; rtype: string; unit: string; amount: number };
  type Seat = { memberId: string; name: string; amount: number; nominal: number; slotId: string; authorship: string; gives: Give[] };
  type Slot = { id: string; slot_kind: string; authorship: string | null; skill: { name: string } | null; resource_type: { name: string } | null; quota: number | null };
  // everything the market row can do to a project, so the meeting screen can too
  type Acts = {
    setStatus: (p: Proj, statusId: string) => void; setDeadline: (p: Proj, date: string) => void;
    setVenue: (p: Proj, venueId: string) => void; setUnit: (p: Proj, unitId: string) => void; rename: (p: Proj, name: string) => void;
    setSeatRole: (p: Proj, memberId: string, role: string) => void; removeSeat: (p: Proj, s: Seat) => void;
    setSlotRole: (slotId: string, role: string) => void; closeSlot: (slotId: string) => void;
    assign: (slotId: string, memberId: string, qty: number) => void;
    addOpening: (p: Proj, role: string, need: string, qty: number) => void;
    addAuthor: (projectId: string, memberId: string, role: string, give: string, qty: number) => void;
  };
  type Proj = { id: string; name: string; status: string; venueYr: string; venueId: string | null; decision: string | null;
    venueNotif: string | null; unitId: string | null; unit: string | null; team: Seat[]; slots: Slot[];
    pool: number; ddlDays: number | null; ddlLabel: string };
  type Mem = { id: string; name: string; email: string; unitId: string | null; unit: string | null;
    hours: number | null; used: number; linked: boolean; skills: { id: string; name: string; level: string }[];
    resources: { id: string; name: string; typeName: string; quota: number }[] };
  type Commit = { projectId: string; projectName: string; authorship: string; amount: number; nominal: number; slotId: string; gives: Give[] };
  type Offer = { slotId: string; projectId: string; projectName: string; ask: string; ddl: string; urgent: boolean; match: boolean };
  type Unit = { id: string; name: string };
  type Venue = { id: string; name: string; kind: string; deadline: string | null };

  let { projs, mems, wgs, chapters, venues, settled, skills, resourceTypes, gpuModels, stage, decDays, venLabel, busy,
        onclose, onsethours, oncreateproject, onaddmember, onseat, onsetcapacity,
        onsetskill, onaddresource, onsetquota, onsetgive, acts, statuses }: {
    projs: Proj[]; mems: Mem[]; wgs: Unit[]; chapters: Unit[]; venues: Venue[]; settled: Record<string, number>;
    skills: { id: string; name: string }[]; resourceTypes: { id: string; name: string; unit?: string }[]; gpuModels: { id: string; name: string }[];
    stage: (p: Proj) => number; decDays: (d: string | null) => number | null; venLabel: (v: Venue) => string;
    busy: string;
    onclose: () => void;
    onsethours: (p: Proj, s: Seat, h: number) => void;
    oncreateproject: (d: { name: string; unitId: string; venueId: string; firstId: string; hours: number }) => Promise<boolean>;
    onaddmember: (d: { name: string; affiliation: string; email: string; unitId: string; projectId: string; role: string; give: string; hours: number }) => Promise<boolean>;
    onsetgive: (memberId: string, slotId: string, qty: number) => void;
    onseat: (slotId: string, memberId: string, hours: number) => void;
    onsetcapacity: (m: Mem, hours: number) => void;
    onsetskill: (memberId: string, skillId: string, level: string | null) => void;
    onaddresource: (memberId: string, typeId: string, qty: number, gpuModelId: string | null) => void;
    onsetquota: (resourceId: string, qty: number) => void;
    acts: Acts; statuses: { id: string; name: string }[];
  } = $props();
  // drafts for the project screen's add boxes — plain objects (see np/nm)
  const pd = { authorId: '', authorRole: 'normal', authorGive: '', authorQty: '', openRole: 'normal', openNeed: '', openQty: '', pick: {} as Record<string, string>, qty: {} as Record<string, string> };
  const roleCls = (r: string) => (r === 'first' ? 'rd' : r === 'corresponding' ? 'bl' : /last/.test(r) ? 'gn' : '');

  const STEPS = ['Start', 'Active', 'In review', 'Accepted'];
  const STC = ['or', 'gn', 'bl', 'yl'];
  const ROLE: Record<string, string> = { first: 'First author', corresponding: 'Co-corresponding', last: 'Last author', last_candidate: 'Last author' };
  const PAL = ['#31735f', '#4c7a9b', '#8a6d3b', '#a35d48', '#5b5f97', '#6c8363', '#96694f', '#527a7a', '#7b5e7b', '#6e7f52'];
  const initials = (n: string) => { const p = n.split(' '); return (p[0]?.[0] ?? '') + (p[1]?.[0] ?? ''); };
  const avColor = (n: string) => PAL[[...n].reduce((a, c) => a + c.charCodeAt(0), 0) % PAL.length];
  const freeOf = (m: Mem) => (m.hours != null ? m.hours - m.used : null);

  let view = $state<'board' | 'agenda' | 'focus'>('board');
  // 聚焦记的是「哪一个」,不是「第几个」:改完容量/阶段后名单会重排,
  // 按下标记会当场跳到另一个人/另一个项目
  let curId = $state('');
  let sheet = $state<'' | 'project' | 'member'>('');

  // 一条脊柱两条线:组(工作组=项目 / 分会=人)→ 项 → 聚焦。导航只写一次。
  let lane = $state<'wg' | 'chapter'>('wg');
  let gi = $state(0);
  const all = $derived([...projs].sort((a, b) => {
    const sa = stage(a), sb = stage(b);
    const bucket = (s: number) => (s === -1 ? 3 : s === 2 ? 2 : 1);
    if (bucket(sa) !== bucket(sb)) return bucket(sa) - bucket(sb);
    return (a.ddlDays ?? 998) - (b.ddlDays ?? 998);
  }));
  const wgGroups = $derived.by(() => {
    const m = new Map<string, { unitId: string; items: Proj[] }>();
    for (const p of all) { const k = p.unit ?? $t('Proposal'); const g = m.get(k) ?? { unitId: p.unitId ?? '', items: [] }; g.items.push(p); m.set(k, g); }
    return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([name, g]) => ({ name, ...g }));
  });
  // contributing a resource is contributing: only someone giving neither hours nor
  // resources is still to be filled in
  const isZero = (s: Seat) => !s.amount && !s.gives.length;
  const needsCap = (x: Mem) => x.hours == null && !x.resources.length;
  const isOver = (x: Mem) => x.hours != null && x.used > x.hours;
  // 分会议程把「要补的」排前面:没填容量 → 超载 → 有余量 → 已排满
  const weight = (x: Mem) => (needsCap(x) ? 0 : isOver(x) ? 1 : (freeOf(x) ?? 0) > 0 ? 2 : 3);
  const chGroups = $derived.by(() => {
    const m = new Map<string, { unitId: string; items: Mem[] }>();
    for (const x of mems) { const k = x.unit ?? $t('No chapter'); const g = m.get(k) ?? { unitId: x.unitId ?? '', items: [] }; g.items.push(x); m.set(k, g); }
    return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([name, g]) => ({ name, unitId: g.unitId,
      items: [...g.items].sort((a, b) => weight(a) - weight(b) || (freeOf(b) ?? 0) - (freeOf(a) ?? 0) || a.name.localeCompare(b.name)) }));
  });
  const groups = $derived<{ name: string; unitId: string; items: unknown[] }[]>(lane === 'wg' ? wgGroups : chGroups);
  const group = $derived(groups[Math.min(gi, Math.max(0, groups.length - 1))] ?? null);
  const agenda = $derived(group?.items ?? []);
  const projItems = $derived(lane === 'wg' ? (agenda as Proj[]) : []);
  const memItems = $derived(lane === 'chapter' ? (agenda as Mem[]) : []);
  const cur = $derived(Math.max(0, (agenda as { id: string }[]).findIndex((it) => it.id === curId)));
  const focusP = $derived(lane === 'wg' ? ((agenda as Proj[])[cur] ?? null) : null);
  const focusM = $derived(lane === 'chapter' ? ((agenda as Mem[])[cur] ?? null) : null);
  const notRegistered = $derived(mems.filter((x) => !x.linked).length);
  const noHours = $derived(mems.filter(needsCap).length);
  const freePool = $derived(mems.reduce((a, x) => a + Math.max((x.hours ?? 0) - x.used, 0), 0));
  const dueSoon = $derived(all.filter((p) => stage(p) >= 0 && stage(p) < 2 && p.ddlDays != null && p.ddlDays <= 14));
  const openSeats = $derived(all.reduce((a, p) => a + (stage(p) >= 0 && stage(p) < 2 ? p.slots.filter((s) => s.slot_kind !== 'leader').length : 0), 0));
  const zeroHours = $derived(all.reduce((a, p) => a + p.team.filter(isZero).length, 0));
  const hoursOf = (p: Proj) => p.team.reduce((a, s) => a + s.amount, 0);
  const resultDays = (p: Proj) => decDays(p.decision ?? p.venueNotif);
  const needOf = (p: Proj) => {
    const s = p.slots.filter((x) => x.slot_kind !== 'leader');
    if (!s.length) return '';
    const first = s[0];
    return `${$t('needs {n}', { n: s.length })} · ${first.resource_type?.name ?? first.skill?.name ?? $t('Hours')}`;
  };

  const askOf = (s: Slot) => s.slot_kind === 'leader' ? $t('First author')
    : (s.resource_type?.name ?? s.skill?.name ?? $t('Hours'));
  const commitsOf = (x: Mem): Commit[] => all.flatMap((p) => p.team.filter((s) => s.memberId === x.id)
    .map((s) => ({ projectId: p.id, projectName: p.name, authorship: s.authorship, amount: s.amount, nominal: s.nominal, slotId: s.slotId, gives: s.gives })));
  const offersOf = (x: Mem): Offer[] => {
    const taken = new Set(commitsOf(x).map((c) => c.projectId));
    return all.flatMap((p) => p.slots.map((s) => ({
        slotId: s.id, projectId: p.id, projectName: p.name, ask: askOf(s),
        ddl: p.ddlLabel && p.ddlLabel !== 'rolling' ? p.ddlLabel : '',
        urgent: p.ddlDays != null && p.ddlDays <= 14,
        match: !!s.skill && x.skills.some((k) => k.name === s.skill?.name),
        ok: s.slot_kind !== 'work_resource' || x.resources.some((r) => r.typeName === s.resource_type?.name) })))
      // never offer a resource seat to someone who holds no such resource:
      // assign() rejects it in postgres (the mock does not — it would pass here
      // and fail in the real-DB lane)
      .filter((o) => !taken.has(o.projectId) && o.ok)
      .sort((a, b) => Number(b.match) - Number(a.match) || Number(b.urgent) - Number(a.urgent))
      .slice(0, 10);
  };
  const nominalOf = (x: Mem) => all.reduce((a, p) => a + p.team.filter((s) => s.memberId === x.id).reduce((b, s) => b + s.nominal, 0), 0);

  const setCur = (i: number) => { curId = (agenda as { id: string }[])[i]?.id ?? ''; };
  function goGroup(i: number) { gi = Math.max(0, Math.min(groups.length - 1, i)); setCur(0); view = 'agenda'; }
  function goLane(l: 'wg' | 'chapter', i: number) { lane = l; goGroup(i); }
  function go(p: Proj) { lane = 'wg'; const j = wgGroups.findIndex((g) => g.items.includes(p)); if (j >= 0) gi = j;
    curId = p.id; view = 'focus'; }
  function goM(x: Mem) { lane = 'chapter'; const j = chGroups.findIndex((g) => g.items.includes(x)); if (j >= 0) gi = j;
    curId = x.id; view = 'focus'; }
  // 两个镜头互相跳:项目里的作者 → 那个人;人身上的项目 → 那个项目
  function goPerson(memberId: string) { const x = mems.find((y) => y.id === memberId); if (x) goM(x); }
  function goProject(projectId: string) { const p = all.find((y) => y.id === projectId); if (p) go(p); }
  function seatCommit(c: Commit, h: number) {
    const p = all.find((y) => y.id === c.projectId); const s = p?.team.find((y) => y.slotId === c.slotId);
    if (p && s) onsethours(p, s, h);
  }
  // 聚焦走到组尾 → 下一组的议程;走到组头往回 → 本组议程
  function next() { if (cur < agenda.length - 1) setCur(cur + 1); else if (gi < groups.length - 1) goGroup(gi + 1); }
  function prev() { if (cur > 0) setCur(cur - 1); else view = 'agenda'; }
  function onkey(e: KeyboardEvent) {
    if (sheet) { if (e.key === 'Escape') sheet = ''; return; }
    const tag = (e.target as HTMLElement)?.tagName;
    if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return;
    if (e.key === 'ArrowRight') { e.preventDefault();
      if (view === 'board') goGroup(0); else if (view === 'agenda') { setCur(0); view = 'focus'; } else next(); }
    else if (e.key === 'ArrowLeft') { e.preventDefault();
      if (view === 'focus') prev(); else if (view === 'agenda') view = 'board'; }
    else if (e.key === 'Escape') { if (view === 'focus') view = 'agenda'; else if (view === 'agenda') view = 'board'; else onclose(); }
  }

  // ── 表单草稿(普通对象:响应式草稿会让打开的表单重渲染) ──
  let np = $state({ name: '', unitId: '', venueId: '', firstId: '', hours: '' });
  let nm = $state({ name: '', affiliation: '', email: '', unitId: '', projectId: '', role: 'normal', give: '', hours: '' });
  function openProject(unitId = '') { np = { name: '', unitId, venueId: '', firstId: '', hours: '' }; sheet = 'project'; }
  function openMember(unitId = '', chapterId = '') {
    const first = all.find((p) => !unitId || p.unitId === unitId);
    nm = { name: '', affiliation: '', email: '', unitId: chapterId || chapters[0]?.id || '', projectId: first?.id ?? '', role: 'normal', give: '', hours: '' };
    memberWg = unitId; sheet = 'member';
  }
  let memberWg = $state('');
  async function submitProject() {
    if (!np.name.trim()) return;
    if (await oncreateproject({ name: np.name.trim(), unitId: np.unitId, venueId: np.venueId, firstId: np.firstId, hours: Number(np.hours) || 5 })) sheet = '';
  }
  async function submitMember() {
    if (!nm.name.trim()) return;
    if (await onaddmember({ name: nm.name.trim(), affiliation: nm.affiliation.trim(), email: nm.email.trim(), unitId: nm.unitId,
      projectId: nm.projectId, role: nm.role, give: nm.give, hours: Number(nm.hours) || 5 })) sheet = '';
  }
  const people = $derived(mems.map((m) => ({ id: m.id, name: m.name,
    hint: `${m.skills[0]?.name ?? ''}${freeOf(m) != null ? ` · ${$t('free')} ${freeOf(m)}h` : ''}` })));
</script>

<svelte:window onkeydown={onkey} />

<div class="mt" data-view={view}>
  <div class="hd">
    <div class="crumbs">
      <button class:on={view === 'board'} onclick={() => (view = 'board')}>{$t('Board')}</button>
      <span class="sep">→</span>
      <button class:on={view === 'agenda'} onclick={() => (view = 'agenda')}>{group?.name ?? $t('Agenda')}</button>
      <span class="sep">→</span>
      <button class:on={view === 'focus'} onclick={() => { view = 'focus'; }}>{$t('Focus')}{#if view === 'focus'} <span class="num">{cur + 1} / {agenda.length}</span>{/if}</button>
    </div>
    <div class="hr">
      <span class="hint">← → · Esc</span>
      <button class="gh" onclick={() => openProject('')}>+ {$t('Project')}</button>
      <button class="gh" onclick={() => openMember('')}>+ {$t('Member')}</button>
      <button class="gh" onclick={onclose}>{$t('Exit meeting view')}</button>
    </div>
  </div>

  {#if view === 'board'}
    <div class="tiles">
      <div class="tile"><div class="tl rd">{$t('Due within 14 days')}</div>
        <div class="tv"><span class="num big">{dueSoon.length}</span><span class="tx">{dueSoon.map((p) => `${p.name} · ${p.ddlDays}d`).join('  ·  ') || '—'}</span></div></div>
      <div class="tile"><div class="tl or">{$t('Open seats')}</div>
        <div class="tv"><span class="num big">{openSeats}</span><span class="tx">{$t('across {n} projects', { n: all.filter((p) => p.slots.some((s) => s.slot_kind !== 'leader')).length })}</span></div></div>
      <div class="tile"><div class="tl bl">{$t('Hours unset')}</div>
        <div class="tv"><span class="num big">{zeroHours}</span><span class="tx">{$t('authors at 0 h/mo')}</span></div></div>
    </div>
    <div class="tiles">
      <div class="tile"><div class="tl bl">{$t('Not registered')}</div>
        <div class="tv"><span class="num big">{notRegistered}</span><span class="tx">{$t('of {n} people', { n: mems.length })}</span></div></div>
      <div class="tile"><div class="tl rd">{$t('Capacity unset')}</div>
        <div class="tv"><span class="num big">{noHours}</span><span class="tx">{$t('cannot be matched to open seats')}</span></div></div>
      <div class="tile"><div class="tl gn">{$t('Free capacity')}</div>
        <div class="tv"><span class="num big">{freePool}h</span><span class="tx">{$t('per month, across known capacity')}</span></div></div>
    </div>

    <div class="bh">{$t('Working groups')}</div>
    {#each wgGroups as g (g.name)}
      <div class="grp">
        <div class="gh2"><button class="gname" onclick={() => goLane('wg', wgGroups.indexOf(g))}>{g.name}</button><span class="gc">{$t('{n} projects', { n: g.items.length })}</span>
          <button class="gh sm" onclick={() => goLane('wg', wgGroups.indexOf(g))}>{$t('Agenda')} →</button>
          <button class="gh sm" onclick={() => openProject(g.unitId)}>+ {$t('Project')}</button>
          <button class="gh sm" onclick={() => openMember(g.unitId)}>+ {$t('Member')}</button></div>
        <div class="cards">
          {#each g.items as p (p.id)}
            {@const sg = stage(p)}
            <button class="card" onclick={() => go(p)}>
              <div class="ch"><span class="cn">{p.name}</span><span class="stc {sg >= 0 ? STC[Math.min(sg, 3)] : 'gy'}">{$t(sg >= 0 ? STEPS[Math.min(sg, 3)] : 'On hold')}</span></div>
              <div class="cv">
                <span class="mut">{p.venueYr || $t('TBD')}</span>
                {#if sg === 2}<span class="num bl">{resultDays(p) != null ? $t('result in') + ' ' + resultDays(p) + 'd' : ''}</span>
                {:else if p.ddlLabel}<span class="num" class:rd={p.ddlDays != null && p.ddlDays <= 14} class:or={p.ddlDays != null && p.ddlDays > 14 && p.ddlDays <= 70}>{p.ddlLabel === 'rolling' ? $t('rolling') : $t('due in') + ' ' + p.ddlLabel}</span>{/if}
              </div>
              <div class="ct">
                {#each p.team.slice(0, 4) as s (s.memberId)}<span class="av" style="background:{avColor(s.name)}22;color:{avColor(s.name)}">{initials(s.name)}</span>{/each}
                <span class="mut">{$t('{n} authors', { n: p.team.length })} · <span class="num">{hoursOf(p)}h</span>/{$t('mo')}</span>
              </div>
              <div class="cf">
                {#if needOf(p)}<span class="chip or">{needOf(p)}</span>{/if}
                {#if p.team.filter(isZero).length}<span class="chip rd">{$t('{n} authors at 0h', { n: p.team.filter(isZero).length })}</span>{/if}
              </div>
            </button>
          {/each}
        </div>
      </div>
    {/each}

    <div class="bh">{$t('Chapters')}</div>
    <div class="cards">
      {#each chGroups as c (c.name)}
        {@const unset = c.items.filter(needsCap).length}
        {@const over = c.items.filter(isOver).length}
        {@const free = c.items.reduce((a, x) => a + Math.max((x.hours ?? 0) - x.used, 0), 0)}
        <button class="card" onclick={() => goLane('chapter', chGroups.indexOf(c))}>
          <div class="ch"><span class="cn">{c.name}</span><span class="stc gy">{$t('{n} people', { n: c.items.length })}</span></div>
          <div class="cv"><span class="mut">{$t('{n} registered', { n: c.items.filter((x) => x.linked).length })}</span>
            <span class="num gn">{$t('free')} {free}h/{$t('mo')}</span></div>
          <div class="ct">
            {#each c.items.slice(0, 4) as x (x.id)}<span class="av" style="background:{avColor(x.name)}22;color:{avColor(x.name)}">{initials(x.name)}</span>{/each}
            <span class="mut">{$t('committed')} <span class="num">{c.items.reduce((a, x) => a + x.used, 0)}h</span>/{$t('mo')}</span>
          </div>
          <div class="cf">
            {#if unset}<span class="chip rd">{$t('{n} without hours', { n: unset })}</span>{/if}
            {#if over}<span class="chip or">{$t('{n} over capacity', { n: over })}</span>{/if}
          </div>
        </button>
      {/each}
    </div>

  {:else if view === 'agenda'}
    <div class="gnav">
      <button class="gh" disabled={gi === 0} onclick={() => goGroup(gi - 1)}>←</button>
      <span class="gtitle">{group?.name}</span><span class="num mut">{gi + 1} / {groups.length}</span>
      <button class="gh" disabled={gi >= groups.length - 1} onclick={() => goGroup(gi + 1)}>→</button>
      {#if lane === 'wg'}
        <button class="gh sm" onclick={() => openProject(group?.unitId ?? '')}>+ {$t('Project')}</button>
        <button class="gh sm" onclick={() => openMember(group?.unitId ?? '')}>+ {$t('Member')}</button>
      {:else}
        <button class="gh sm" onclick={() => openMember('', group?.unitId ?? '')}>+ {$t('Member')}</button>
      {/if}
    </div>
    <div class="rows">
      {#each memItems as x, i (x.id)}
        <button class="row" onclick={() => goM(x)}>
          <span class="num idx">{String(i + 1).padStart(2, '0')}</span>
          <span class="rn">{x.name}</span>
          <span class="stc {x.linked ? 'gn' : 'gy'}">{x.linked ? $t('Registered') : $t('Card')}</span>
          <span class="rv">{#if x.hours == null && x.resources.length}<span class="pu">{x.resources.map((r) => `${r.typeName} ${r.quota}`).join(' · ')}</span>
            {:else if x.hours == null}<span class="rd">{$t('no hours set')}</span>
            {:else}<span class="num" class:rd={isOver(x)}>{x.used}h</span><span class="mut"> / {x.hours}h</span>{/if}</span>
          <span class="ri mut">{x.skills.map((k) => k.name).join(' · ') || $t('no skills set')}</span>
          <span class="rt">{#if isOver(x)}<span class="chip rd">{$t('over by')} {x.used - (x.hours ?? 0)}h</span>
            {:else if (freeOf(x) ?? 0) > 0}<span class="chip gn">{$t('free')} {freeOf(x)}h</span>
            {:else}<span class="mut">—</span>{/if}</span>
        </button>
      {/each}
      {#each projItems as p, i (p.id)}
        {@const sg = stage(p)}
        <button class="row" class:onhold={sg < 0} onclick={() => go(p)}>
          <span class="num idx">{String(i + 1).padStart(2, '0')}</span>
          <span class="rn">{p.name}</span>
          <span class="stc {sg >= 0 ? STC[Math.min(sg, 3)] : 'gy'}">{$t(sg >= 0 ? STEPS[Math.min(sg, 3)] : 'On hold')}</span>
          <span class="rv"><span class="mut">{p.venueYr || $t('TBD')}</span>
            {#if sg === 2}<span class="num bl"> · {resultDays(p) != null ? $t('result') + ' ' + resultDays(p) + 'd' : ''}</span>
            {:else if p.ddlLabel}<span class="num" class:rd={p.ddlDays != null && p.ddlDays <= 14} class:or={p.ddlDays != null && p.ddlDays > 14 && p.ddlDays <= 70}> · {p.ddlLabel === 'rolling' ? $t('rolling') : p.ddlLabel}</span>{/if}</span>
          <span class="ri mut">{$t('{n} authors', { n: p.team.length })} · <span class="num">{hoursOf(p)}h</span>/{$t('mo')}</span>
          <span class="rt">{#if needOf(p)}<span class="chip or">{needOf(p)}</span>{:else if p.team.filter(isZero).length}<span class="chip rd">{$t('{n} authors at 0h', { n: p.team.filter(isZero).length })}</span>{:else}<span class="mut">—</span>{/if}</span>
        </button>
      {/each}
    </div>

  {:else if focusP}
    {@const p = focusP}
    {@const sg = stage(p)}
    {@const zero = p.team.filter(isZero)}
    {@const live = p.team.filter((s) => !isZero(s))}
    <div class="fnav">
      <button class="gh" onclick={prev}>←</button>
      <span class="num">{cur + 1} / {agenda.length}</span>
      <button class="gh" onclick={next}>→</button>
      <span class="mut">{p.unit ?? $t('Proposal')}</span>
    </div>
    <div class="ft">
      <input class="fn fnin" value={p.name} title={$t('Rename')}
        onchange={(e) => { const v = (e.target as HTMLInputElement).value.trim(); if (v && v !== p.name) acts.rename(p, v); }} />
      <span class="stc lg {sg >= 0 ? STC[Math.min(sg, 3)] : 'gy'}">{$t(sg >= 0 ? STEPS[Math.min(sg, 3)] : 'On hold')}</span>
    </div>
    <div class="ctl">
      <label>{$t('Stage')}<select value={statuses.find((x) => x.name === p.status)?.id ?? ''} disabled={busy === 'st' + p.id}
        onchange={(e) => acts.setStatus(p, (e.target as HTMLSelectElement).value)}>
        {#each statuses as x}<option value={x.id}>{$t(x.name)}</option>{/each}</select></label>
      <label>{$t('Working group')}<select value={p.unitId ?? ''} onchange={(e) => acts.setUnit(p, (e.target as HTMLSelectElement).value)}>
        <option value="">{$t('Proposal (no group)')}</option>{#each wgs as u}<option value={u.id}>{u.name}</option>{/each}</select></label>
      <label>{$t('Venue')}<select value={p.venueId ?? ''} onchange={(e) => acts.setVenue(p, (e.target as HTMLSelectElement).value)}>
        <option value="">{$t('TBD')}</option>{#each venues as v}<option value={v.id}>{venLabel(v)}</option>{/each}</select></label>
      {#if sg === 2}<label>{$t('Result date')}<input type="date" value={p.decision ?? p.venueNotif ?? ''}
        onchange={(e) => acts.setDeadline(p, (e.target as HTMLInputElement).value)} /></label>{/if}
    </div>
    <div class="tiles four">
      <div class="tile"><div class="tl">{$t('Venue')}</div><div class="tv2">{p.venueYr || $t('TBD')}</div></div>
      <div class="tile"><div class="tl">{sg === 2 ? $t('Result') : $t('Deadline')}</div>
        <div class="tv2 num" class:bl={sg === 2} class:rd={sg !== 2 && p.ddlDays != null && p.ddlDays <= 14}>
          {#if sg === 2}{p.decision ?? p.venueNotif ?? '—'}{#if resultDays(p) != null} · {resultDays(p)}d{/if}{:else}{p.ddlLabel ? (p.ddlLabel === 'rolling' ? $t('rolling') : p.ddlLabel) : '—'}{/if}</div></div>
      <div class="tile"><div class="tl">{$t('Pool')}</div><div class="tv2 num yl">{p.pool.toLocaleString()} STR</div></div>
      <div class="tile"><div class="tl">{$t('Hours')}</div><div class="tv2"><span class="num">{hoursOf(p)}h</span>{#if zero.length}<span class="rd sm2"> · {$t('{n} of {m} unset', { n: zero.length, m: p.team.length })}</span>{/if}</div></div>
    </div>
    <div class="fcols">
      <div class="seats">
        {#each live as s, i (s.memberId)}
          <div class="seat">
            <span class="num idx">{i + 1}</span>
            <button class="lnk sn" onclick={() => goPerson(s.memberId)}>{s.name}</button>
            {#if sg <= 2}
              <select class="rolec rsel {roleCls(s.authorship)}" value={s.authorship}
                onchange={(e) => { const v = (e.target as HTMLSelectElement).value; s.authorship = v; acts.setSeatRole(p, s.memberId, v); }}>
                <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
              </select>
            {:else}<span class="rolec {roleCls(s.authorship)}">{$t(ROLE[s.authorship] ?? 'Author')}</span>{/if}
            <span class="give">
              {#if s.amount}<input class="num" type="number" min="1" value={s.amount}
                onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h > 0 && h !== s.amount) onsethours(p, s, h); }} />h{/if}
              {#each s.gives as g (g.slotId)}<span class="gv" title={g.unit}>{g.rtype}<input class="num" type="number" min="1" value={g.amount}
                onchange={(e) => { const q = Number((e.target as HTMLInputElement).value); if (q > 0 && q !== g.amount) onsetgive(s.memberId, g.slotId, q); }} /></span>{/each}
            </span>
            <span class="pts-x"><span class="num pts">{s.nominal.toLocaleString()}</span>
              {#if sg <= 2}<button class="rel" title={$t('Remove')} onclick={() => acts.removeSeat(p, s)}>×</button>{/if}</span>
          </div>
        {/each}
        {#if !live.length && !zero.length}<div class="mut">{$t('no members yet')}</div>{/if}

        {#each p.slots.filter((x) => x.slot_kind !== 'leader' || sg <= 2).sort((a, b) => Number(b.slot_kind === 'leader') - Number(a.slot_kind === 'leader')) as sl (sl.id)}
          <div class="seat open">
            <span class="num idx mut">○</span>
            <span class="ask"><span class="mut">{askOf(sl)}{#if sl.quota} · {sl.quota}{sl.slot_kind === 'work_resource' ? '' : 'h'}/{$t('mo')}{/if}</span></span>
            {#if sg <= 2}
              <select class="rolec rsel {roleCls(sl.authorship ?? (sl.slot_kind === 'leader' ? 'first' : 'normal'))}"
                value={sl.authorship ?? (sl.slot_kind === 'leader' ? 'first' : 'normal')}
                onchange={(e) => acts.setSlotRole(sl.id, (e.target as HTMLSelectElement).value)}>
                <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option>
              </select>
              <span class="fill">
                <PersonPick placeholder={$t('Choose member')} {people} onpick={(id) => (pd.pick[sl.id] = id)} />
                <input class="num" type="number" min="1" placeholder={String(sl.quota ?? 5)} bind:value={pd.qty[sl.id]} style="width:3.4rem" />
                <button class="gh sm" disabled={busy === sl.id}
                  onclick={() => { const m = pd.pick[sl.id]; if (m) acts.assign(sl.id, m, Number(pd.qty[sl.id]) || Number(sl.quota) || 5); }}>{$t('Seat')}</button>
              </span>
              <span class="pts-x"><button class="rel" title={$t('Close opening')} onclick={() => acts.closeSlot(sl.id)}>×</button></span>
            {:else}<span class="rolec {roleCls(sl.authorship ?? 'normal')}">{$t(ROLE[sl.authorship ?? 'normal'] ?? 'Author')}</span><span></span><span></span>{/if}
          </div>
        {/each}

        {#if sg <= 2}
          <div class="addbox">
            <div class="addrow"><span class="al">+ {$t('Author')}</span>
              <PersonPick placeholder={$t('Search member…')} {people} onpick={(id) => (pd.authorId = id)} />
              <select bind:value={pd.authorRole}>
                <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option></select>
              <select bind:value={pd.authorGive} title={$t('Contributes')}>
                <option value="">{$t('Hours')} (h)</option>
                {#each resourceTypes.filter((r) => r.name !== 'Labor') as r}<option value={r.id}>{r.name}{r.unit ? ` (${r.unit})` : ''}</option>{/each}</select>
              <input class="num" type="number" min="1" placeholder="5" bind:value={pd.authorQty} style="width:3.4rem" />
              <button class="gh sm" disabled={busy === 'au' + p.id}
                onclick={() => { if (pd.authorId) acts.addAuthor(p.id, pd.authorId, pd.authorRole, pd.authorGive, Number(pd.authorQty) || 5); }}>{$t('Add')}</button>
            </div>
            <div class="addrow"><span class="al">+ {$t('Opening')}</span>
              <select bind:value={pd.openRole}>
                <option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option>
                <option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option></select>
              <select bind:value={pd.openNeed} title={$t('Needs')}>
                <option value="">{$t('Hours')}</option>
                {#each skills as sk}<option value={sk.id}>{sk.name}</option>{/each}
                {#each resourceTypes.filter((r) => r.name !== 'Labor') as r}<option value={'rt:' + r.id}>{r.name} ({$t('resource')})</option>{/each}</select>
              <input class="num" type="number" min="1" placeholder="8" bind:value={pd.openQty} style="width:3.4rem" />
              <button class="gh sm" disabled={busy === 'open' + p.id}
                onclick={() => acts.addOpening(p, pd.openRole, pd.openNeed, Number(pd.openQty) || 8)}>{$t('Add')}</button>
            </div>
          </div>
        {/if}
      </div>
      <div class="zeros">
        {#if zero.length}
          <div class="zt">{$t('{n} authors at 0 h/mo', { n: zero.length })}</div>
          <div class="zchips">
            {#each zero as s (s.memberId)}
              <span class="zchip"><button class="lnk" onclick={() => goPerson(s.memberId)}>{s.name}</button><input class="num" type="number" min="1" placeholder="h"
                onchange={(e) => { const h = Number((e.target as HTMLInputElement).value); if (h > 0) onsethours(p, s, h); }} /></span>
            {/each}
          </div>
          <div class="mut">{$t('type hours to set them without leaving the meeting')}</div>
        {/if}
      </div>
    </div>

  {:else if focusM}
    {@const x = focusM}
    <div class="fnav">
      <button class="gh" onclick={prev}>←</button>
      <span class="num">{cur + 1} / {agenda.length}</span>
      <button class="gh" onclick={next}>→</button>
      <span class="mut">{x.unit ?? $t('No chapter')}</span>
    </div>
    <PersonFocus m={x} commits={commitsOf(x)} offers={offersOf(x)} nominal={nominalOf(x)}
      settled={settled[x.id] ?? 0} {busy} {skills} {resourceTypes} {gpuModels}
      {onsetcapacity} {onsetskill} {onaddresource} {onsetquota} {onsetgive} onsethours={seatCommit}
      onseat={(o, mm, h) => onseat(o.slotId, mm.id, h)} onproject={goProject} />
  {/if}

  {#if sheet === 'project'}
    <div class="scrim" role="presentation" onclick={() => (sheet = '')}></div>
    <div class="sheet" role="dialog">
      <div class="sh"><span class="st">{$t('New project')}</span><span class="mut">{np.unitId ? $t('in') + ' ' + (wgs.find((u) => u.id === np.unitId)?.name ?? '') : $t('Proposal (no group)')}</span></div>
      <label class="fld"><span>{$t('Name')}</span><input class="big" bind:value={np.name} placeholder={$t('Project name')} /></label>
      <div class="two">
        <label class="fld"><span>{$t('Working group')}</span><select bind:value={np.unitId}><option value="">{$t('Proposal (no group)')}</option>{#each wgs as u}<option value={u.id}>{u.name}</option>{/each}</select></label>
        <label class="fld"><span>{$t('Venue')}</span><select bind:value={np.venueId}><option value="">{$t('TBD')}</option>{#each venues as v}<option value={v.id}>{venLabel(v)}</option>{/each}</select></label>
      </div>
      <div class="fld"><span>{$t('First author')}</span>
        <div class="two">
          <PersonPick placeholder={$t('Search member…')} {people} onpick={(id) => (np.firstId = id)} />
          <label class="inl"><input class="num" type="number" min="1" bind:value={np.hours} placeholder="5" style="width:4rem" />h/{$t('mo')}</label>
        </div></div>
      <div class="acts"><button class="pri" disabled={busy === 'newp'} onclick={submitProject}>{$t('Create project')}</button>
        <button class="gh" onclick={() => (sheet = '')}>{$t('Cancel')}</button>
        <span class="mut">{$t('lands as a Start card, first author seated')}</span></div>
    </div>
  {:else if sheet === 'member'}
    <div class="scrim" role="presentation" onclick={() => (sheet = '')}></div>
    <div class="sheet" role="dialog">
      <div class="sh"><span class="st">{$t('New member')}</span><span class="mut">{$t('card only — they sign in later with this email')}</span></div>
      <div class="two">
        <label class="fld"><span>{$t('Name')}</span><input class="big" bind:value={nm.name} placeholder={$t('Full name')} /></label>
        <label class="fld"><span>{$t('Affiliation')}</span><input bind:value={nm.affiliation} /></label>
      </div>
      <div class="two">
        <label class="fld"><span>{$t('Chapter')}</span><select bind:value={nm.unitId}><option value="">{$t('No chapter')}</option>{#each chapters as u}<option value={u.id}>{u.name}</option>{/each}</select></label>
        <label class="fld"><span>{$t('Email')} <i>· {$t('optional')}</i></span><input bind:value={nm.email} placeholder={$t('blank → chapter chair backfills')} /></label>
      </div>
      <div class="fld"><span>{$t('Seat on a project now')} <i>· {$t('optional')}</i></span>
        <div class="three">
          <select bind:value={nm.projectId}><option value="">—</option>{#each all.filter((p) => !memberWg || p.unitId === memberWg) as p}<option value={p.id}>{p.name}</option>{/each}</select>
          <select bind:value={nm.role}><option value="normal">{$t('Author')}</option><option value="first">{$t('First author')}</option><option value="corresponding">{$t('Co-corresponding')}</option><option value="last">{$t('Last author')}</option></select>
          <label class="inl"><input class="num" type="number" min="1" bind:value={nm.hours} placeholder="5" style="width:4rem" />/{$t('mo')}</label>
        </div>
        <select bind:value={nm.give} title={$t('Contributes')}>
          <option value="">{$t('Contributes')}: {$t('Hours')} (h)</option>
          {#each resourceTypes.filter((r) => r.name !== 'Labor') as r}<option value={r.id}>{$t('Contributes')}: {r.name}{r.unit ? ` (${r.unit})` : ''}</option>{/each}
        </select></div>
      <div class="acts"><button class="pri" disabled={busy === 'add'} onclick={submitMember}>{$t('Add member')}</button>
        <button class="gh" onclick={() => (sheet = '')}>{$t('Cancel')}</button></div>
    </div>
  {/if}
</div>

<style>
  .mt { position: relative; width: 100vw; margin-left: calc(50% - 50vw); min-height: 100vh; background: #fff; color: #37352f;
    padding: 20px 48px 40px; box-sizing: border-box; font-size: 16px;
    font-family: -apple-system, "SF Pro SC", "PingFang SC", system-ui, "Segoe UI", sans-serif; }
  .num { font-family: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace; font-variant-numeric: tabular-nums; }
  .mut { color: #9b9a97; }
  .rd { color: #93382a; } .or { color: #9a5b13; } .bl { color: #2b5a75; } .gn { color: #1c513f; } .yl { color: #6f5615; }
  .hd { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 10px 16px; margin-bottom: 22px; }
  .crumbs { display: flex; align-items: center; gap: 10px; min-width: 0; }
  .crumbs button { font: inherit; font-size: 26px; font-weight: 600; letter-spacing: -.01em; background: none; border: 0; color: #9b9a97; cursor: pointer; padding: 2px 6px; border-radius: 6px;
    white-space: nowrap; max-width: 34vw; overflow: hidden; text-overflow: ellipsis; }
  .crumbs button.on { color: #37352f; }
  .crumbs button:hover { background: #f7f7f5; }
  .crumbs .num { font-size: 15px; font-weight: 500; color: #9b9a97; margin-left: 8px; }
  .sheet :global(.ppick input) { font: inherit; font-size: 16px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 9px 12px; width: 100%; box-sizing: border-box; }
  .sep { color: #e9e9e7; font-size: 22px; }
  .hr { display: flex; align-items: center; gap: 8px; flex: none; }
  .hr .gh { white-space: nowrap; }
  .hint { font-size: 13px; color: #9b9a97; margin-right: 8px; }
  .gh { font: inherit; font-size: 14px; color: #6b6a66; background: #fff; border: 1px solid #e9e9e7; border-radius: 6px; padding: 6px 12px; cursor: pointer; }
  .gh:hover { background: #f7f7f5; color: #37352f; }
  .gh.sm { font-size: 12.5px; padding: 3px 9px; }
  .pri { font: inherit; font-size: 15px; font-weight: 500; color: #fff; background: #37352f; border: 0; border-radius: 6px; padding: 10px 18px; cursor: pointer; }
  .pri:disabled { opacity: .5; }
  .tiles { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; margin-bottom: 26px; }
  .tiles.four { grid-template-columns: repeat(4, minmax(0, 1fr)); }
  .tile { border: 1px solid #e9e9e7; border-radius: 8px; padding: 14px 18px; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .tl { font-size: 12.5px; font-weight: 600; color: #9b9a97; text-transform: uppercase; letter-spacing: .04em; }
  .tv { display: flex; align-items: baseline; gap: 10px; min-width: 0; }
  .big { font-size: 34px; font-weight: 600; }
  .tx { font-size: 15px; color: #6b6a66; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tv2 { font-size: 22px; font-weight: 600; }
  .sm2 { font-size: 15px; font-weight: 500; }
  .bh { font-size: 12.5px; font-weight: 600; color: #9b9a97; text-transform: uppercase; letter-spacing: .06em;
    border-top: 1px solid #e9e9e7; padding-top: 14px; margin: 4px 0 14px; }
  .lnk { font: inherit; text-align: left; background: none; border: 0; color: #37352f; cursor: pointer;
    padding: 2px 6px; margin-left: -6px; border-radius: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .lnk:hover { background: #f7f7f5; }
  .chip.gn { background: #dbeddb; color: #1c513f; }
  .grp { display: flex; flex-direction: column; gap: 10px; margin-bottom: 26px; }
  .gh2 { display: flex; align-items: center; gap: 12px; }
  .gname { font: inherit; font-size: 18px; font-weight: 600; color: #37352f; background: none; border: 0; padding: 2px 6px; margin-left: -6px; border-radius: 6px; cursor: pointer; }
  .gname:hover { background: #f7f7f5; }
  .gnav { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
  .gtitle { font-size: 22px; font-weight: 600; }
  .gh:disabled { opacity: .4; cursor: default; }
  .gc { font-size: 14px; color: #9b9a97; margin-right: 6px; }
  .cards { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; }
  .card { font: inherit; text-align: left; color: inherit; border: 1px solid #e9e9e7; border-radius: 8px; padding: 16px 18px; background: #fbfbfa;
    display: flex; flex-direction: column; gap: 10px; cursor: pointer; min-width: 0; }
  .card:hover { border-color: #c9c8c4; background: #f7f7f5; }
  .ch { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
  .cn { font-size: 20px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cv { display: flex; align-items: baseline; gap: 8px; font-size: 15px; }
  .cv .num.rd { font-weight: 600; }
  .ct { display: flex; align-items: center; gap: 6px; font-size: 14px; }
  .cf { display: flex; gap: 6px; min-height: 22px; }
  .av { width: 28px; height: 28px; border-radius: 50%; font-size: 11px; font-weight: 600; display: inline-flex; align-items: center; justify-content: center; }
  .stc { font-size: 13px; border-radius: 4px; padding: 2px 9px; white-space: nowrap; }
  .stc.lg { font-size: 15px; padding: 3px 11px; }
  .stc.or { background: #fadec9; color: #9a5b13; } .stc.gn { background: #dbeddb; color: #1c513f; }
  .stc.bl { background: #d3e5ef; color: #2b5a75; } .stc.yl { background: #fdecc8; color: #6f5615; } .stc.gy { background: #f1f0ef; color: #57564f; }
  .chip { font-size: 12.5px; border-radius: 4px; padding: 2px 8px; white-space: nowrap; }
  .chip.or { background: #fadec9; color: #9a5b13; } .chip.rd { background: #ffe2dd; color: #93382a; }
  .rows { display: flex; flex-direction: column; border-top: 1px solid #e9e9e7; }
  .row { font: inherit; text-align: left; color: inherit; background: none; border: 0; border-bottom: 1px solid #f1f1ef; cursor: pointer;
    display: grid; grid-template-columns: 44px minmax(140px, 2fr) 110px minmax(150px, 1.3fr) minmax(0, 1.4fr) minmax(0, 1.6fr);
    grid-template-areas: "idx name stage venue info need"; gap: 10px 16px; align-items: center; padding: 14px 8px; min-width: 0; }
  .row > * { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .row .idx { grid-area: idx; } .row .rn { grid-area: name; } .row .stc { grid-area: stage; justify-self: start; }
  .row .rv { grid-area: venue; } .row .ri { grid-area: info; } .row .rt { grid-area: need; }
  .row:hover { background: #f7f7f5; }
  .row.onhold { opacity: .55; }
  .idx { font-size: 15px; color: #9b9a97; }
  .rn { font-size: 20px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .rv { font-size: 15px; }
  .rv .num.rd { font-weight: 600; }
  .rt { justify-self: start; }
  .fnav { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
  .fnav .num { font-size: 15px; color: #9b9a97; }
  .ft { display: flex; align-items: baseline; gap: 20px; margin-bottom: 14px; }
  .fnin { font: inherit; font-size: 44px; font-weight: 600; letter-spacing: -.015em; border: 1px solid transparent; border-radius: 6px;
    padding: 0 6px; margin-left: -6px; background: none; color: inherit; min-width: 0; flex: 0 1 36rem; }
  .fnin:hover, .fnin:focus { border-color: #e9e9e7; background: #fff; outline: none; }
  .ctl { display: flex; flex-wrap: wrap; gap: 10px 22px; margin-bottom: 22px; }
  .ctl label { display: inline-flex; align-items: center; gap: 8px; font-size: 13px; color: #6b6a66; }
  .ctl select, .ctl input { font: inherit; font-size: 15px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 5px 10px; background: #fff; color: #37352f; max-width: 22rem; }
  .rsel { font: inherit; border: 0; cursor: pointer; appearance: auto; }
  .pts-x { justify-self: end; display: inline-flex; align-items: center; gap: 6px; }
  .rel { font: inherit; background: none; border: 0; color: #9b9a97; cursor: pointer; font-weight: 600; padding: 0 4px; }
  .rel:hover { color: #93382a; }
  .seat.open { grid-template-columns: 36px minmax(0, 1fr) 150px minmax(0, 2fr) 40px; }
  .seat.open > * { min-width: 0; }
  .seat.open .ask { font-size: 15px; }
  .fill { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; min-width: 0; }
  .fill :global(.ppick) { flex: 1; min-width: 8rem; }
  .fill :global(.ppick input), .fill input { font: inherit; font-size: 14px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 4px 8px; width: 100%; box-sizing: border-box; }
  .addbox { display: flex; flex-direction: column; gap: 8px; margin-top: 14px; }
  .addrow { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
  .addrow .al { font-size: 13px; color: #6b6a66; min-width: 5rem; }
  .addrow :global(.ppick) { min-width: 10rem; }
  .addrow :global(.ppick input), .addrow select, .addrow input { font: inherit; font-size: 14px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 5px 8px; background: #fff; color: #37352f; }
  .fn { font-size: 44px; font-weight: 600; letter-spacing: -.015em; }
  .fcols { display: grid; grid-template-columns: minmax(0, 3fr) minmax(0, 2fr); gap: 0 40px; }
  .seats, .zeros { min-width: 0; }
  .seats { display: flex; flex-direction: column; }
  .seat { display: grid; grid-template-columns: 36px 1fr 150px minmax(100px, auto) 80px; gap: 12px; align-items: center; padding: 12px 8px; border-bottom: 1px solid #f1f1ef; }
  .sn { font-size: 19px; font-weight: 500; }
  .rolec { font-size: 13px; color: #6b6a66; justify-self: start; border-radius: 4px; padding: 2px 8px; }
  .rolec.rd { background: #ffe2dd; color: #93382a; } .rolec.bl { background: #d3e5ef; color: #2b5a75; } .rolec.gn { background: #dbeddb; color: #1c513f; }
  .give { justify-self: end; font-size: 17px; }
  .give input, .zchip input { font: inherit; font-size: 17px; width: 4rem; text-align: right; border: 1px solid transparent; border-radius: 4px; padding: 2px 4px; background: none; }
  .give input:hover, .give input:focus, .zchip input:hover, .zchip input:focus { border-color: #e9e9e7; background: #fff; outline: none; }
  .gv { display: inline-flex; align-items: center; gap: 2px; font-size: 13px; background: #e8deee; color: #5a4a72; border-radius: 4px; padding: 1px 2px 1px 8px; margin-left: 6px; }
  .gv input { width: 3.2rem !important; font-size: 14px !important; }
  .pu { color: #5a4a72; }
  .pts { justify-self: end; font-size: 14px; color: #6f5615; background: #fdecc8; border-radius: 4px; padding: 2px 8px; }
  .zeros { display: flex; flex-direction: column; gap: 10px; padding-top: 12px; }
  .zt { font-size: 13px; color: #93382a; font-weight: 600; }
  .zchips { display: flex; flex-wrap: wrap; gap: 8px; }
  .zchip { font-size: 15px; border: 1px dashed #e9e9e7; border-radius: 6px; padding: 4px 6px 4px 12px; color: #6b6a66; display: inline-flex; align-items: center; gap: 6px; }
  .zchip input { font-size: 15px; width: 3rem; }
  /* name it scrim, never dim: a `.dim` utility also matched the agenda rows
     (class:dim) and turned every in-review row into a full-screen veil */
  .scrim { position: fixed; inset: 0; background: rgba(255, 255, 255, .65); z-index: 60; }
  .sheet { position: fixed; left: 50%; top: 14vh; transform: translateX(-50%); width: min(680px, 92vw); z-index: 61; background: #fff; border: 1px solid #e9e9e7;
    border-radius: 10px; box-shadow: 0 8px 28px rgba(55, 53, 47, .12); padding: 28px 32px; box-sizing: border-box; display: flex; flex-direction: column; gap: 20px; }
  .sh { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
  .st { font-size: 22px; font-weight: 600; }
  .fld { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .fld > span { font-size: 13px; color: #6b6a66; }
  .fld i { font-style: normal; color: #9b9a97; }
  .fld input, .fld select { font: inherit; font-size: 16px; border: 1px solid #e9e9e7; border-radius: 6px; padding: 9px 12px; background: #fff; color: #37352f; min-width: 0; }
  .fld input.big { font-size: 22px; font-weight: 500; border: 0; border-bottom: 2px solid #37352f; border-radius: 0; padding: 6px 0; }
  .fld input:focus, .fld select:focus { outline: none; border-color: #c9c8c4; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; align-items: end; }
  .three { display: grid; grid-template-columns: 1fr 170px 110px; gap: 10px; align-items: center; }
  .inl { display: inline-flex; align-items: center; gap: 4px; font-size: 15px; color: #6b6a66; }
  .acts { display: flex; align-items: center; gap: 12px; padding-top: 4px; font-size: 13px; }
  .acts .mut { margin-left: auto; }
  @media (max-width: 1100px) { .crumbs button { font-size: 20px; } .hint { display: none; } .gtitle { font-size: 18px; } .cards { grid-template-columns: repeat(2, minmax(0, 1fr)); } .tiles.four { grid-template-columns: repeat(2, minmax(0, 1fr)); } .fcols { grid-template-columns: 1fr; }
    .row { grid-template-columns: 36px minmax(0, 1fr) 110px minmax(120px, auto); grid-template-areas: "idx name stage venue" ". info info need"; } }
</style>
