<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import EntityCard from '$lib/EntityCard.svelte';
  import NeedsYou from '$lib/shell/NeedsYou.svelte';
  import ProjectDetailBody from '$lib/cards/ProjectDetailBody.svelte';
  import Icon from '$lib/Icon.svelte';
  import { type Slot } from '$lib/cards/ProjectSlotCard.svelte';

  // the ledger expands a project in place — every operation (tasks, needs +
  // matching, status, settle, credit) happens here, no navigation.
  let expanded = $state<string | null>(null);

  // Projects = the community portfolio. Each project belongs to a working group
  // and exposes a slot map (1 leader/first-author + N need slots). Members are
  // seated into slots by WG officers; this page is the read-only browse surface.

  type PType = { id: string; name: string; leader_stake: number; join_stake: number; finish_bonus: number };
  type PStatus = { id: string; name: string; rank: number };
  type Venue = { id: string; name: string; kind: string; deadline: string | null };
  type WGroup = { id: string; code: string; name: string };
  // one fully-denormalised grid row
  type Grid = {
    id: string;
    name: string;
    type: string;
    status: string;
    statusRank: number;
    venue: string;
    venueKind: string;
    deadline: string | null;
    wg: string;
    wgUnitId: string | null;
    leader: string;
    seatsFilled: number;
    seatsTotal: number;
    openNeeds: number;
    pool: number;          // Σ nominal_str across the project's commitments
    emoji: string;
    code: string;
    openTasks: number;     // tasks not done/confirmed — the living-record backlog
    summary: string | null;
    active: boolean;       // status.is_active — false for Finished & Hold
    finished: boolean;
    claimable: boolean;    // leader slot empty → first-author seat is open
  };

  let grid = $state<Grid[]>([]);
  let slotsByProject = $state<Record<string, Slot[]>>({});
  let types = $state<PType[]>([]);
  let statuses = $state<PStatus[]>([]);
  let venues = $state<Venue[]>([]);
  let workingGroups = $state<WGroup[]>([]);
  let loading = $state(true);

  // status name → EntityCard status dot kind
  function projKind(name: string): 'pos' | 'warn' | 'dim' {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold' || name === 'Under review') return 'warn';
    return 'dim';
  }
  // can the viewer seat cards into slots? admin (any card) or chapter officer
  // (own chapter's cards). The work_seat RPC enforces the precise rule.
  const canSeat = $derived(
    $capabilities.has('manage_members') || $capabilities.has('edit_any_project') || $officerUnits.length > 0
  );

  // filters / search / sort
  let q = $state('');
  let typeFilter = $state('');
  let statusFilter = $state('');
  let venueFilter = $state('');
  type SortKey = 'deadline' | 'openTasks' | 'openNeeds' | 'name';
  let sortKey = $state<SortKey>('deadline');
  let sortDir = $state<1 | -1>(1);

  // create form
  let myBalance = $state(0);
  type LeaderReq = { skill_id: string; skill_name: string; min_level: string; have: string | null };
  let leaderMissing = $state<LeaderReq[]>([]);
  const leaderReady = $derived(leaderMissing.length === 0);
  const GUILD_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };
  let showForm = $state(false);
  let cName = $state(''); let cType = $state(''); let cStatus = $state('');
  let cVenueId = $state(''); let cSummary = $state(''); let cProposal = $state('');
  let cOrgUnit = $state('');
  let creating = $state(false);
  let error = $state('');

  const chosenType = $derived(types.find((t) => t.id === cType) ?? null);
  const leaderStake = $derived(chosenType?.leader_stake ?? 0);

  async function loadGrid() {
    // org_unit name map is fetched separately (rather than embedded) so an
    // ambiguous-FK embed can never blank out the whole project list.
    const [{ data: pr }, { data: ou }] = await Promise.all([
      supabase.from('project')
        .select('id, name, target_venue, deadline, summary, org_unit_id, venue:venue_id(name, kind, deadline), project_type(name), project_status!project_status_id_fkey(name, rank, is_active)')
        .is('archived_at', null),
      supabase.from('org_unit').select('id, name')
    ]);
    const unitName: Record<string, string> = {};
    for (const u of (ou as { id: string; name: string }[]) ?? []) unitName[u.id] = u.name;
    const projects = (pr as any[]) ?? [];
    const pids = projects.map((p) => p.id);

    // pull the full slot map (mirrors SlotBoard) for every project at once
    let slots: any[] = [];
    const memMap: Record<string, { id: string; name: string; amount: number; unit: string }[]> = {};
    // pool = Σ nominal_str per project (by project_id) so legacy commitments
    // migrated with a null slot_id still count — same way a member's nominal is
    // summed. Per-slot member lists still key on slot_id.
    const pool: Record<string, number> = {};
    const openTasks: Record<string, number> = {};
    const emojiOf: Record<string, string> = {};
    const codeOf: Record<string, string> = {};
    if (pids.length) {
      const { data: sl } = await supabase.from('project_slot')
        .select('id, project_id, slot_kind, req_access, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name)')
        .in('project_id', pids);
      slots = (sl as any[]) ?? [];
      const { data: wc } = await supabase.from('work_commitment')
        .select('project_id, slot_id, member_id, monthly_amount, nominal_str, member:member_id(full_name), resource:resource_id(unit)')
        .in('project_id', pids);
      for (const w of (wc as any[]) ?? []) {
        pool[w.project_id] = (pool[w.project_id] ?? 0) + (Number(w.nominal_str) || 0);
        if (!w.slot_id) continue;
        const arr = (memMap[w.slot_id] ??= []);
        if (arr.some((m) => m.id === w.member_id)) continue;
        arr.push({ id: w.member_id, name: w.member?.full_name ?? '—', amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h' });
      }
      // output axis: verified milestones add to each project's nominal pool
      const { data: vms } = await supabase.from('project_milestone')
        .select('project_id, nominal_value').eq('status', 'verified').in('project_id', pids);
      for (const m of (vms as any[]) ?? [])
        pool[m.project_id] = (pool[m.project_id] ?? 0) + (Number(m.nominal_value) || 0);

      // P0 living-record: emoji/code + open-task count. Fetched defensively in
      // their own queries so a pre-migration DB (columns/table absent) degrades
      // to empty rather than blanking the whole list.
      const { data: meta } = await supabase.from('project').select('id, emoji, code').in('id', pids);
      for (const r of (meta as any[]) ?? []) { emojiOf[r.id] = r.emoji ?? ''; codeOf[r.id] = r.code ?? ''; }
      const { data: tk } = await supabase.from('task').select('project_id, state').in('project_id', pids);
      for (const r of (tk as any[]) ?? [])
        if (r.state !== 'done' && r.state !== 'confirmed')
          openTasks[r.project_id] = (openTasks[r.project_id] ?? 0) + 1;
    }

    // group slots per project (Slot shape for ProjectSlotCard) + roll up metrics
    const byP: Record<string, Slot[]> = {};
    const leaderName: Record<string, string> = {};
    const seatsFilled: Record<string, number> = {};
    const seatsTotal: Record<string, number> = {};
    const openNeeds: Record<string, number> = {};
    const hasLeader: Record<string, boolean> = {};
    for (const s of slots) {
      const members = memMap[s.id] ?? [];
      (byP[s.project_id] ??= []).push({
        id: s.id, slot_kind: s.slot_kind, skill_name: s.skill?.name ?? null,
        resource_type_name: s.resource_type?.name ?? null, req_access: s.req_access,
        quota: s.quota, headcount: s.headcount ?? 1, status: s.status, members
      });
      // every slot — leader (first-author seat) included — counts toward seats &
      // open needs, so an unfilled lead reads as 0/1 seats · 1 open need.
      const head = s.headcount ?? 1;
      seatsTotal[s.project_id] = (seatsTotal[s.project_id] ?? 0) + head;
      seatsFilled[s.project_id] = (seatsFilled[s.project_id] ?? 0) + Math.min(members.length, head);
      if (members.length < head) openNeeds[s.project_id] = (openNeeds[s.project_id] ?? 0) + 1;
      if (s.slot_kind === 'leader' && members.length) { hasLeader[s.project_id] = true; leaderName[s.project_id] = members[0].name; }
    }
    slotsByProject = byP;

    grid = projects.map((p) => {
      // PostgREST can return an embedded to-one as an array when the target
      // table has multiple FKs from this row (project → project_status via
      // status_id AND held_from_status_id). Normalise to a single object.
      const ps = Array.isArray(p.project_status) ? p.project_status[0] : p.project_status;
      // defensive: normalise away any invisible junk (zero-width, nbsp, BOM)
      // so name-based comparisons (statusClass / Hold chip) stay reliable.
      const statusName = (ps?.name ?? '—')
        .replace(/[ - ​-‍⁠﻿]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
      const finished = statusName.toLowerCase() === 'finished';
      // is_active is the real source of truth for "still in play" — Finished
      // and Hold are both is_active=false in project_status.
      const active = ps?.is_active !== false;
      return {
        id: p.id,
        name: p.name,
        type: p.project_type?.name ?? '—',
        status: statusName,
        statusRank: ps?.rank ?? 999,
        venue: p.venue?.name ?? p.target_venue ?? '',
        venueKind: p.venue?.kind ?? '',
        deadline: p.deadline ?? p.venue?.deadline ?? null,
        wg: (p.org_unit_id && unitName[p.org_unit_id]) || '',
        wgUnitId: p.org_unit_id ?? null,
        leader: leaderName[p.id] ?? '',
        seatsFilled: seatsFilled[p.id] ?? 0,
        seatsTotal: seatsTotal[p.id] ?? 0,
        openNeeds: openNeeds[p.id] ?? 0,
        pool: pool[p.id] ?? 0,
        summary: p.summary ?? null,
        emoji: emojiOf[p.id] ?? '',
        code: codeOf[p.id] ?? '',
        openTasks: openTasks[p.id] ?? 0,
        active,
        finished,
        claimable: !hasLeader[p.id] && !finished
      };
    });
  }

  const effId = $derived($member?.id ?? null);
  const asArg = null;

  async function loadMyBalance(id: string) {
    const { data } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', id).maybeSingle();
    myBalance = Number((data as { balance: number } | null)?.balance ?? 0);
  }

  async function loadLeaderReadiness(id: string) {
    const { data } = await supabase.rpc('leader_reqs_missing', { mid: id });
    leaderMissing = (data as LeaderReq[]) ?? [];
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [, { data: ty }, { data: st }, { data: vn }, { data: wg }] = await Promise.all([
      loadGrid(),
      supabase.from('project_type').select('id, name, leader_stake, join_stake, finish_bonus').order('rank'),
      supabase.from('project_status').select('id, name, rank').order('rank'),
      supabase.from('venue').select('id, name, kind, deadline').eq('is_active', true).order('rank'),
      supabase.from('org_unit').select('id, code, name').eq('kind', 'working_group').order('rank')
    ]);
    types = (ty as PType[]) ?? [];
    statuses = (st as PStatus[]) ?? [];
    venues = (vn as Venue[]) ?? [];
    workingGroups = (wg as WGroup[]) ?? [];
    cStatus = statuses.find((s) => s.name === 'Proposal')?.id ?? statuses[0]?.id ?? '';
    loading = false;
  });
  // balance + leader readiness follow the effective identity (self or acting card)
  $effect(() => { if (effId) { loadMyBalance(effId); loadLeaderReadiness(effId); } });

  async function createProject() {
    error = '';
    if (!cName.trim() || !cType) { error = get(t)('Name and type are required.'); return; }
    if (!cProposal.trim()) { error = get(t)('A proposal link is required to start a project.'); return; }
    let proposal = cProposal.trim();
    if (!/^https?:\/\//i.test(proposal)) proposal = 'https://' + proposal;
    creating = true;
    // Phase 1: free — no leader bond. You become the project's leader (first author).
    const { data, error: err } = await supabase.rpc('create_project_phase1', {
      p_name: cName.trim(), p_type_id: cType, p_status_id: cStatus,
      p_wg_unit: cOrgUnit || null, p_summary: cSummary.trim() || null,
      p_venue_id: cVenueId || null, p_proposal_url: proposal
    });
    creating = false;
    if (err) { error = err.message; return; }
    cName = ''; cVenueId = ''; cSummary = ''; cProposal = ''; cOrgUnit = ''; showForm = false;
    await Promise.all([loadGrid(), effId ? loadMyBalance(effId) : Promise.resolve()]);
    // hand off to the WG slot board so the new owner can forge needs immediately
    if (data && cOrgUnit) window.location.href = `/officer/${cOrgUnit}`;
  }

  // status → accent colour for the card (left border + faint tint)
  function statusColor(name: string): string {
    switch (name) {
      case 'Proposal': return '#6b7280';
      case 'Data Collecting': return '#3fb6c6';
      case 'Work in progress': return 'var(--warn)';
      case 'Under review': return '#a371f7';
      case 'Hold': return '#9ca3af';
      case 'Finished': return '#3fb950';
      default: return '#8b95a5';
    }
  }
  // deterministic colour per working group, for the decorative WG tag
  function wgColor(name: string): string {
    let h = 0;
    for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 360;
    return `hsl(${h} 52% 52%)`;
  }

  // status → color class
  function statusClass(name: string) {
    switch (name) {
      case 'Proposal': return 'st-proposal';
      case 'Data Collecting': return 'st-data';
      case 'Work in progress': return 'st-wip';
      case 'Under review': return 'st-review';
      case 'Finished': return 'st-finished';
      case 'Hold': return 'st-hold';
      default: return 'st-proposal';
    }
  }

  // venue kind → label + color class + glyph (journal vs conference at a glance)
  function venueKindMeta(kind: string) {
    switch (kind) {
      case 'journal':    return { label: 'Journal',    cls: 'vk-journal',    icon: '📚' };
      case 'conference': return { label: 'Conference', cls: 'vk-conference', icon: '🎤' };
      case 'workshop':   return { label: 'Workshop',   cls: 'vk-workshop',   icon: '🛠' };
      case 'rolling':    return { label: 'Rolling',    cls: 'vk-rolling',    icon: '🔁' };
      default:           return { label: 'Other',      cls: 'vk-other',      icon: '📄' };
    }
  }

  function fmtDate(d: string | null) {
    if (!d) return '';
    return new Date(d + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
  function ddlClass(d: string | null) {
    if (!d) return 'dim';
    const days = (new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000;
    if (days < 0) return 'neg';
    if (days < 14) return 'warn';
    return 'dim';
  }

  const typeNames = $derived([...new Set(grid.map((r) => r.type))].filter((x) => x !== '—').sort());

  // venues actually in use (excluding finished), grouped by kind for the dropdown
  const venueGroups = $derived.by(() => {
    const byKind = new Map<string, Set<string>>();
    for (const r of grid) {
      if (r.finished || !r.venue) continue;
      const k = r.venueKind || 'other';
      if (!byKind.has(k)) byKind.set(k, new Set());
      byKind.get(k)!.add(r.venue);
    }
    const order = ['conference', 'journal', 'workshop', 'rolling', 'other'];
    return order
      .filter((k) => byKind.has(k))
      .map((k) => ({ kind: k, meta: venueKindMeta(k), names: [...byKind.get(k)!].sort() }));
  });
  const statusNames = $derived(
    [...new Map(grid.filter((r) => !r.finished).map((r) => [r.status, r.statusRank])).entries()]
      .sort((a, b) => a[1] - b[1]).map((e) => e[0]).filter((x) => x !== '—')
  );

  // a project is shown in the default grid only when it's in play: not Finished
  // (those go to Hall of fame) and status.is_active (Hold is parked). A status
  // chip overrides the is-active gate so Hold/etc. stay one click away.
  function keepRow(r: Grid, needle: string): boolean {
    if (r.finished) return false;
    if (!r.wgUnitId) return false; // unassigned projects live in the "adopt" section, not the ledger
    if (statusFilter ? r.status !== statusFilter : !r.active) return false;
    if (typeFilter && r.type !== typeFilter) return false;
    if (venueFilter) {
      const ok = venueFilter.startsWith('kind:') ? r.venueKind === venueFilter.slice(5) : r.venue === venueFilter;
      if (!ok) return false;
    }
    if (needle) {
      const hay = `${r.name} ${r.venue} ${r.leader} ${r.wg} ${r.type}`.toLowerCase();
      if (!hay.includes(needle)) return false;
    }
    return true;
  }

  const rows = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    let out = grid.filter((r) => keepRow(r, needle));
    out = [...out].sort((a, b) => {
      if (sortKey === 'deadline') {
        // deadline board: soonest upcoming on top; past-due then dateless sink below
        if (!a.deadline && !b.deadline) return 0;
        if (!a.deadline) return 1;
        if (!b.deadline) return -1;
        const now = Date.now();
        const at = new Date(a.deadline + 'T00:00:00').getTime();
        const bt = new Date(b.deadline + 'T00:00:00').getTime();
        const aPast = at < now, bPast = bt < now;
        if (aPast !== bPast) return aPast ? 1 : -1;
        return (at - bt) * sortDir;
      }
      if (sortKey === 'name') return a.name.localeCompare(b.name) * sortDir;
      const av = sortKey === 'seats' ? a.seatsFilled : (a as any)[sortKey];
      const bv = sortKey === 'seats' ? b.seatsFilled : (b as any)[sortKey];
      return ((Number(av) || 0) - (Number(bv) || 0)) * sortDir;
    });
    return out;
  });

  // KPI summary — "active" = status.is_active (excludes Finished & Hold)
  const kActive = $derived(grid.filter((r) => r.active && !r.finished && r.wgUnitId).length);
  const kUpcoming = $derived(grid.filter((r) => {
    if (!r.active || r.finished || !r.deadline) return false;
    const days = (new Date(r.deadline + 'T00:00:00').getTime() - Date.now()) / 86400000;
    return days >= 0 && days <= 60;
  }).length);

  // status counts over the *unfiltered* grid, in pipeline order
  const statusCounts = $derived.by(() => {
    const m = new Map<string, number>();
    for (const r of grid) if (!r.finished) m.set(r.status, (m.get(r.status) ?? 0) + 1);
    return statusNames.map((n) => ({ name: n, count: m.get(n) ?? 0 }));
  });

  // Hall of fame: finished projects, settled & minted — collapsed by default.
  let showHof = $state(false);
  const finished = $derived(
    grid.filter((r) => r.finished).sort((a, b) => b.pool - a.pool)
  );
  const hofMinted = $derived(finished.reduce((a, r) => a + r.pool, 0));

  // Unassigned projects (no working group yet) that a WG officer can ADOPT into
  // their group — setting org_unit_id is what unlocks posting needs & editing.
  const myWgUnits = $derived($officerUnits.filter((u: any) => u.kind === 'working_group'));
  const unassigned = $derived(grid.filter((r) => !r.wgUnitId && !r.finished));
  let adoptInto = $state('');   // chosen WG when the officer leads more than one
  let adopting = $state('');
  async function adopt(projectId: string) {
    const wg = myWgUnits.length === 1 ? (myWgUnits[0] as any).unit_id : adoptInto;
    if (!wg) { error = get(t)('Pick a working group to adopt into.'); return; }
    adopting = projectId; error = '';
    const { error: err } = await supabase.rpc('forge_claim', { p_project: projectId, p_wg_unit: wg });
    adopting = '';
    if (err) { error = err.message; return; }
    await loadGrid();
  }

  function initials(name: string) {
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }
  // status pipeline (Hold excluded) for the drawer's "step n of N" indicator
  const pipeline = $derived(statuses.filter((s) => s.name !== 'Hold').sort((a, b) => a.rank - b.rank).map((s) => s.name));
  function pipeIndex(name: string) { return pipeline.indexOf(name); }
  // short deadline label, e.g. "Aug 12" — urgency conveyed by relDays alongside
  function relDays(d: string | null) {
    if (!d) return '';
    const days = Math.round((new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000);
    if (days === 0) return get(t)('today');
    if (days > 0) return get(t)('in {d}d', { d: days });
    return get(t)('{d}d overdue', { d: -days });
  }
</script>

<div class="stack">
  {#if $member}<NeedsYou />{/if}

  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div class="stack" style="gap:.15rem;">
      <h1 style="margin:0;">{$t('Projects')}</h1>
      <span class="muted" style="font-size:.88rem;">
        {$t('{n} active projects across the community — working groups, slots, and open roles.', { n: kActive })}{#if finished.length > 0} · <a href="#hall-of-fame">{$t('{n} shipped', { n: finished.length })}</a>{/if}{#if kUpcoming > 0} · <span class="warn">{$t('{n} with a deadline ≤ 60d', { n: kUpcoming })}</span>{/if}
      </span>
    </div>
    {#if $member}
      <button onclick={() => (showForm = !showForm)}>{showForm ? $t('Cancel') : $t('Start a project')}</button>
    {/if}
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  {#if showForm}
    <div class="card stack">
      <h2 style="margin:0;">{$t('Start a project')}</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {@html $t('A new project starts at <span class="badge dim">Proposal</span> with a proposal on file. Phase 1: free — no bond. The first-author (leader) seat stays open for someone to take.')}
      </p>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Name *')}</span>
        <input bind:value={cName} placeholder={$t('Project / paper name')} /></label>
      <div class="row" style="flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type *')}</span>
          <select bind:value={cType}><option value="">—</option>{#each types as pt}<option value={pt.id}>{pt.name}</option>{/each}</select></label>
        <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">{$t('Target venue')}</span>
          <select bind:value={cVenueId}>
            <option value="">{$t('— none —')}</option>
            {#each venues as v}<option value={v.id}>{v.name}{v.deadline ? ` · ${$t('ddl')} ${fmtDate(v.deadline)}` : ''}</option>{/each}
          </select></label>
      </div>
      {#if workingGroups.length}
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Working Group')}</span>
          <select bind:value={cOrgUnit}>
            <option value="">{$t('— unattributed —')}</option>
            {#each workingGroups as w}<option value={w.id}>{w.name}</option>{/each}
          </select></label>
      {/if}
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Proposal link *')} <span class="dim">{$t('(PDF on Drive, Overleaf, OpenReview…)')}</span></span>
        <input bind:value={cProposal} placeholder="https://…" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Summary')}</span>
        <textarea bind:value={cSummary} rows="2" placeholder={$t('One-line description')}></textarea></label>
      <div class="row" style="gap:.5rem;">
        <button onclick={createProject} disabled={creating}>
          {creating ? $t('Creating…') : $t('Create project')}</button>
        <button type="button" class="ghost" onclick={() => (showForm = false)} disabled={creating}>{$t('Cancel')}</button>
      </div>
    </div>
  {/if}

  <!-- hall of fame: finished projects, settled & minted -->
  {#if finished.length > 0}
    <div class="hof card" id="hall-of-fame">
      <div
        class="hof-head"
        role="button" tabindex="0"
        onclick={() => (showHof = !showHof)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') showHof = !showHof; }}
      >
        <div class="row" style="gap:.5rem; align-items:baseline;">
          <h2 style="margin:0;">🏆 {$t('Hall of fame')}</h2>
          <span class="muted" style="font-size:.85rem;">{$t('{n} shipped', { n: finished.length })}</span>
        </div>
        <div class="row" style="gap:.6rem; align-items:center;">
          <span class="chev" class:open={showHof}>▾</span>
        </div>
      </div>
      {#if showHof}
        <div class="hof-grid">
          {#each finished as r}
            <a class="hof-card" href={`/projects/${r.id}`}>
              <div class="hof-card-top">
                <span class="hof-name">{r.name}</span>
                <span class="badge up">✓ {$t('shipped')}</span>
              </div>
              <span class="psub">
                <span>{r.type}</span>
                {#if r.wg}<span class="sep">·</span><span>{r.wg}</span>{/if}
                {#if r.venue}<span class="sep">·</span><span>{r.venue}</span>{/if}
              </span>
              <div class="hof-stats">
                <div class="hof-stat">
                  <span class="mono">{r.seatsFilled}</span>
                  <span class="muted">{$t('contributors')}</span>
                </div>
              </div>
              <div class="hof-team">
                {#if r.leader}
                  <span class="ava" title={r.leader}>{initials(r.leader)}</span>
                  <span class="dim" style="font-size:.82rem;">{r.leader}</span>
                  <span class="psub">· {$t('first author')}</span>
                {/if}
              </div>
            </a>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  <!-- status filter chips -->
  <div class="row" style="gap:.4rem;">
    <span
      class="chip toggle {statusFilter === '' ? 'on' : ''}"
      role="button" tabindex="0"
      onclick={() => (statusFilter = '')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') statusFilter = ''; }}
    >{$t('All')} <span class="ct">{kActive}</span></span>
    {#each statusCounts as s}
      <span
        class="chip toggle {statusFilter === s.name ? 'on' : ''}"
        role="button" tabindex="0"
        onclick={() => (statusFilter = statusFilter === s.name ? '' : s.name)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') statusFilter = statusFilter === s.name ? '' : s.name; }}
      >
        <span class="cdot {statusClass(s.name)}"></span>
        <span>{$t(s.name)}</span>
        <span class="ct">{s.count}</span>
      </span>
    {/each}
  </div>

  <!-- toolbar: search + type/venue filters -->
  <div class="row" style="gap:.6rem;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder={$t('Search name, leader, group, venue…')} bind:value={q} style="width:100%;" />
    </div>
    <select bind:value={typeFilter}>
      <option value="">{$t('All types')}</option>
      {#each typeNames as tn}<option value={tn}>{tn}</option>{/each}
    </select>
    <select bind:value={venueFilter}>
      <option value="">{$t('All venues')}</option>
      {#each venueGroups as g}
        <optgroup label={`${g.meta.icon} ${$t(g.meta.label)}`}>
          <option value={`kind:${g.kind}`}>{$t('All {label}', { label: $t(g.meta.label) })}</option>
          {#each g.names as vn}<option value={vn}>{vn}</option>{/each}
        </optgroup>
      {/each}
    </select>
    {#if q || typeFilter || statusFilter || venueFilter}
      <button class="ghost" onclick={() => { q = ''; typeFilter = ''; statusFilter = ''; venueFilter = ''; }}>{$t('Reset')}</button>
    {/if}
    <div class="row" style="gap:.3rem; align-items:center;">
      <select bind:value={sortKey} title={$t('Sort by')}>
        <option value="deadline">{$t('Deadline')}</option>
        <option value="openTasks">{$t('Open tasks')}</option>
        <option value="openNeeds">{$t('Open needs')}</option>
        <option value="name">{$t('Name')}</option>
      </select>
      <button class="ghost" onclick={() => (sortDir = sortDir === 1 ? -1 : 1)} title={$t('Toggle sort direction')} aria-label={$t('Toggle sort direction')}>{sortDir === 1 ? '▲' : '▼'}</button>
    </div>
  </div>

  {#if myWgUnits.length && unassigned.length}
    <div class="adopt card">
      <div class="adopt-head">
        <strong>{$t('Projects looking for a working group')}</strong>
        <span class="muted">{$t('Adopt one into your group to manage it — post its needs, edit it, run its board.')}</span>
      </div>
      {#if myWgUnits.length > 1}
        <select class="adopt-pick" bind:value={adoptInto}>
          <option value="">{$t('Adopt into…')}</option>
          {#each myWgUnits as u}<option value={(u as any).unit_id}>{(u as any).name}</option>{/each}
        </select>
      {/if}
      <div class="adopt-list">
        {#each unassigned as r (r.id)}
          <div class="adopt-row">
            <span class="adopt-name">{r.emoji} {r.name}</span>
            {#if r.summary}<span class="muted adopt-sum">{r.summary}</span>{/if}
            <button class="adopt-go" disabled={adopting === r.id} onclick={() => adopt(r.id)}>
              {adopting === r.id ? $t('Adopting…') : myWgUnits.length === 1 ? $t('Adopt into {wg}', { wg: (myWgUnits[0] as any).name }) : $t('Adopt')}
            </button>
          </div>
        {/each}
      </div>
      {#if error}<p class="adopt-err">{error}</p>{/if}
    </div>
  {/if}

  {#if loading}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('Loading…')}</p></div>
  {:else if rows.length === 0 && finished.length === 0 && !(myWgUnits.length && unassigned.length)}
    <!-- COLD START: nothing to show this user — no ledger rows, none shipped, and
         no project they could adopt. Orient the newcomer instead of "no match" —
         what this is + what to do — instead of a bare "no match" (which reads as
         "you searched wrong" to someone who never searched). -->
    <div class="card stack" style="padding:1.2rem; gap:.5rem;" id="first-run">
      <strong style="font-size:1.05rem;">{$t('No projects yet.')}</strong>
      <p class="muted" style="margin:0; line-height:1.5;">{$t('This is your group’s living record of projects — each holds a task board, a team and its open needs. Start one to begin, or go to People to add researchers. New here? The Guide explains how it all fits together.')}</p>
      <div class="row" style="gap:.5rem; margin-top:.3rem;">
        <button class="btn" onclick={() => (showForm = true)}>{$t('Start a project')}</button>
        <a class="btn ghost" href="/people">{$t('Open People →')}</a>
        <a class="btn ghost" href="/guide">{$t('Read the guide')}</a>
      </div>
    </div>
  {:else if rows.length === 0 && kActive === 0 && finished.length > 0}
    <!-- not a failed search: every project the community has has already shipped.
         Point to where they live instead of "you searched wrong". -->
    <div class="card"><p class="muted" style="padding:1rem;">{$t('No active projects right now — every project has shipped. See the 🏆 Hall of fame above.')}</p></div>
  {:else if rows.length === 0}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('No projects match your filters.')}</p></div>
  {:else}
    <div class="ledger">
      {#each rows as r (r.id)}
        <div class="lrow" class:open={expanded === r.id}>
          <button class="lrow-head" onclick={() => (expanded = expanded === r.id ? null : r.id)} aria-expanded={expanded === r.id}>
            <span class="lr-chev" class:open={expanded === r.id}><Icon name="chevron" size={14} /></span>
            <span class="lr-main">
              <span class="lr-title">{r.emoji ? r.emoji + ' ' : ''}{r.code || r.name}</span>
              {#if r.wg || r.venue}<span class="lr-sub">{[r.wg, r.venue].filter(Boolean).join(' · ')}</span>{/if}
            </span>
            {#if r.claimable}<span class="badge warn">{$t('1st-author open')}</span>{:else}<span class="status st-{projKind(r.status) === 'pos' ? 'finished' : projKind(r.status) === 'warn' ? 'review' : 'proposal'}"><span class="sdot"></span>{$t(r.status)}</span>{/if}
            <span class="lr-facts">
              <span class="lf"><b>{r.openTasks}</b> {$t('tasks')}</span>
              <span class="lf"><b>{r.openNeeds}</b> {$t('needs')}</span>
              <span class="lf"><b>{r.seatsFilled}</b> {$t('team')}</span>
              {#if r.deadline}<span class="lf lf-ddl">{fmtDate(r.deadline)} · {relDays(r.deadline)}</span>{/if}
            </span>
          </button>
          {#if expanded === r.id}
            <div class="lrow-body">
              <a class="lr-open" href={`/projects/${r.id}`}>{$t('Open full page')} →</a>
              <ProjectDetailBody projectId={r.id} showHeader={false} onChanged={loadGrid} />
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: .8rem; }
  /* the ledger: one full-width row per project, expands in place */
  .ledger { display: flex; flex-direction: column; }
  .lrow { border-bottom: 1px solid var(--border); }
  .lrow.open { border: 1px solid var(--rule-ink); border-radius: var(--r-md); margin: .3rem 0; background: var(--card); }
  .lrow-head {
    display: flex; align-items: center; gap: .75rem; width: 100%; text-align: left;
    background: transparent; border: 0; border-radius: 0; padding: .7rem .5rem; cursor: pointer; color: var(--text);
  }
  .lrow-head:hover { background: var(--card-2); }
  .lrow.open .lrow-head { background: transparent; border-bottom: 1px solid var(--border); }
  .lr-chev { color: var(--muted); width: 1rem; flex: none; display: inline-flex; transition: transform .12s; }
  .lr-chev.open { transform: rotate(90deg); }
  .lr-main { display: flex; flex-direction: column; min-width: 0; flex: 1; }
  .lr-title { font-weight: 600; font-size: 1rem; }
  .lr-sub { font-size: .76rem; color: var(--muted); }
  .lr-facts { display: flex; gap: 1rem; align-items: center; flex-wrap: wrap; }
  .lr-facts .lf { font-size: .8rem; color: var(--text-dim); white-space: nowrap; }
  .lr-facts .lf b { font-family: var(--font-mono); font-weight: 700; color: var(--text); }
  .lr-facts .lf-ddl { font-family: var(--font-mono); color: var(--muted); }
  .lrow-body { padding: .9rem 1.1rem 1.1rem; }
  .lr-open { display: inline-block; font-size: .8rem; margin-bottom: .6rem; }
  @media (max-width: 720px) { .lr-facts { gap: .5rem; } }
  /* mobile: the row stacks so the status badge never overlaps the title and the
     facts get their own line under it (issue #36) */
  @media (max-width: 600px) {
    .lrow-head { flex-wrap: wrap; align-items: flex-start; row-gap: .35rem; padding: .65rem .4rem; }
    .lr-chev { margin-top: .15rem; }
    .lr-main { flex: 1 1 8rem; }
    .lr-title { font-size: .95rem; line-height: 1.25; }
    .lrow-head > .badge, .lrow-head > .status { flex: 0 0 auto; align-self: flex-start; white-space: nowrap; }
    .lr-facts { flex: 1 1 100%; padding-left: 1.75rem; gap: .35rem .9rem; }
  }
  .btn {
    display: inline-flex; align-items: center; gap: .3rem; padding: .5rem .9rem;
    background: var(--accent); color: #fff; border: 1px solid transparent; border-radius: var(--r-sm);
    text-decoration: none; font: inherit; font-weight: 600; cursor: pointer;
  }
  .btn.ghost { background: transparent; color: var(--accent); border-color: var(--border); }

  /* project drawer — the full project card */
  .pdrawer { display: flex; flex-direction: column; gap: 1rem; }
  .pd-open { align-self: flex-end; font-size: .8rem; color: var(--accent); text-decoration: none; }
  .pd-open:hover { text-decoration: underline; }
  .pd-meta { display: flex; gap: .5rem; align-items: flex-start; justify-content: space-between; }
  .pd-meta-chips { display: flex; flex-wrap: wrap; gap: .4rem; align-items: center; flex: 1; min-width: 0; }
  .pd-chip {
    display: inline-flex; align-items: center; gap: .3rem;
    font-size: .76rem; color: var(--text-dim); background: var(--card-2);
    border: 1px solid var(--border); border-radius: var(--r-full); padding: .15rem .55rem;
  }
  .pd-chip.warn { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 35%, transparent); }
  .pd-chip.neg { color: var(--down); border-color: color-mix(in srgb, var(--down) 35%, transparent); }
  .pd-stats {
    display: flex; flex-wrap: wrap; gap: .3rem 1.4rem;
    padding: .7rem .9rem; border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card);
  }
  .pd-stat { display: flex; flex-direction: column; gap: .1rem; }
  .pd-v { font-weight: 700; font-size: 1rem; color: var(--text); }
  .pd-l { font-size: .68rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .pd-summary { margin: 0; font-size: .88rem; line-height: 1.5; color: var(--text); }
  .pd-section { display: flex; flex-direction: column; gap: .45rem; }
  .pd-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }

  .hof { padding: 0; overflow: hidden; }
  .hof-head {
    display: flex; align-items: center; justify-content: space-between;
    gap: .6rem; padding: .85rem 1rem; cursor: pointer; user-select: none;
  }
  .hof-head:hover { background: var(--accent-soft); }
  .chev { display: inline-block; transition: transform .15s ease; color: var(--muted); }
  .chev.open { transform: rotate(180deg); }
  .hof-grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: .7rem; padding: 0 1rem 1rem;
  }
  .hof-card {
    display: flex; flex-direction: column; gap: .5rem; text-align: left;
    padding: .8rem .9rem; border: 1px solid var(--border-2, var(--border));
    border-radius: var(--r-md); background: var(--bg-elev, transparent);
    cursor: pointer; font: inherit; color: inherit;
    transition: border-color .15s ease, transform .15s ease;
  }
  .hof-card:hover { border-color: var(--up); transform: translateY(-2px); }
  .hof-card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
  .hof-name { font-weight: 600; line-height: 1.25; }
  .hof-stats { display: flex; gap: .9rem; padding-top: .15rem; }
  .hof-stat { display: flex; flex-direction: column; gap: .1rem; }
  .hof-stat .mono { font-size: 1.02rem; font-weight: 600; }
  .hof-stat .muted { font-size: .68rem; text-transform: uppercase; letter-spacing: .03em; }
  .hof-team { display: flex; align-items: center; gap: .4rem; padding-top: .15rem; }

  .adopt { margin-bottom: 1rem; padding: .9rem 1rem; border-left: 3px solid var(--accent); display: flex; flex-direction: column; gap: .55rem; }
  .adopt-head { display: flex; flex-direction: column; gap: .15rem; }
  .adopt-head strong { font-size: .95rem; }
  .adopt-head .muted { font-size: .8rem; }
  .adopt-pick { align-self: flex-start; padding: .3rem .5rem; border: 1px solid var(--border); border-radius: var(--r-sm); }
  .adopt-list { display: flex; flex-direction: column; gap: .4rem; }
  .adopt-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
  .adopt-name { font-weight: 600; font-size: .9rem; }
  .adopt-sum { font-size: .8rem; flex: 1; min-width: 8rem; }
  .adopt-go { background: var(--accent); color: #fff; border: 0; border-radius: var(--r-sm); padding: .35rem .7rem; font-weight: 600; font-size: .82rem; cursor: pointer; }
  .adopt-go:disabled { opacity: .6; cursor: default; }
  .adopt-err { color: var(--danger, #c0392b); font-size: .8rem; margin: 0; }
</style>
