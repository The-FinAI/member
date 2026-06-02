<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import EntityCard from '$lib/EntityCard.svelte';
  import TaskMarket from '$lib/TaskMarket.svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  // top-level segment: the project portfolio vs the open-needs task market.
  // A "need" is an open slot on a project card, so both live on this surface.
  let surface = $state<'projects' | 'needs'>('projects');

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
    leader: string;
    members: number;
    openNeeds: number;
    laborNeeds: number;
    resourceNeeds: number;
    escrow: number;
    pool: number;          // nominal pool (member nominal + verified milestone nominal)
    multiplier: number;    // settlement mint multiplier
    msVerified: number;
    msTotal: number;
    claimable: boolean;    // leaderless → anyone can take the lead
  };

  let grid = $state<Grid[]>([]);
  let types = $state<PType[]>([]);
  let statuses = $state<PStatus[]>([]);
  let venues = $state<Venue[]>([]);
  let workingGroups = $state<WGroup[]>([]);
  let loading = $state(true);

  // card grid is the default face; the dense table stays one click away
  let view = $state<'cards' | 'table'>('cards');
  // status name → EntityCard status dot kind
  function projKind(name: string): 'pos' | 'warn' | 'dim' {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold' || name === 'Under review') return 'warn';
    return 'dim';
  }

  // filters / search / sort
  let q = $state('');
  let typeFilter = $state('');
  let statusFilter = $state('');
  let venueFilter = $state('');
  type SortKey = 'name' | 'type' | 'status' | 'leader' | 'members' | 'openNeeds' | 'escrow' | 'pool' | 'multiplier' | 'msVerified' | 'venue' | 'deadline';
  let sortKey = $state<SortKey>('pool');
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
    const [{ data: pr }, { data: pm }, { data: nd }, { data: esc }, { data: mnom }, { data: pms }] = await Promise.all([
      supabase.from('project')
        .select('id, name, target_venue, venue:venue_id(name, kind, deadline), project_type(name), project_status!project_status_id_fkey(name, rank)'),
      supabase.from('project_member')
        .select('project_id, member(full_name), project_role(name, can_manage)'),
      supabase.from('open_need').select('project_id, status, contribution_kind'),
      supabase.from('stater_balance').select('project_id, balance').not('project_id', 'is', null),
      supabase.from('stater_project_member_nominal').select('project_id, nominal'),
      supabase.from('project_milestone').select('project_id, status, milestone_catalog(nominal_value, multiplier_bonus)')
    ]);

    const memberCount: Record<string, number> = {};
    const leaderName: Record<string, string> = {};
    for (const r of (pm as any[]) ?? []) {
      memberCount[r.project_id] = (memberCount[r.project_id] ?? 0) + 1;
      if (r.project_role?.name === 'Leader' && r.member?.full_name) leaderName[r.project_id] = r.member.full_name;
      else if (!leaderName[r.project_id] && r.project_role?.can_manage && r.member?.full_name) leaderName[r.project_id] = r.member.full_name;
    }
    const hasManager: Record<string, boolean> = {};
    for (const r of (pm as any[]) ?? []) if (r.project_role?.can_manage) hasManager[r.project_id] = true;

    const openCount: Record<string, number> = {};
    const laborCount: Record<string, number> = {};
    const resCount: Record<string, number> = {};
    for (const r of (nd as any[]) ?? [])
      if (r.status === 'open') {
        openCount[r.project_id] = (openCount[r.project_id] ?? 0) + 1;
        if (r.contribution_kind === 'labor') laborCount[r.project_id] = (laborCount[r.project_id] ?? 0) + 1;
        else if (r.contribution_kind === 'resource') resCount[r.project_id] = (resCount[r.project_id] ?? 0) + 1;
      }
    const escrowOf: Record<string, number> = {};
    for (const r of (esc as any[]) ?? []) escrowOf[r.project_id] = Number(r.balance) || 0;

    // nominal pool = Σ member nominal + Σ verified-milestone nominal; multiplier from verified bonuses
    const memberNomSum: Record<string, number> = {};
    for (const r of (mnom as any[]) ?? []) memberNomSum[r.project_id] = (memberNomSum[r.project_id] ?? 0) + Number(r.nominal);
    const msNomSum: Record<string, number> = {};
    const msBonus: Record<string, number> = {};
    const msVer: Record<string, number> = {};
    const msTot: Record<string, number> = {};
    for (const r of (pms as any[]) ?? []) {
      msTot[r.project_id] = (msTot[r.project_id] ?? 0) + 1;
      if (r.status === 'verified') {
        msVer[r.project_id] = (msVer[r.project_id] ?? 0) + 1;
        msNomSum[r.project_id] = (msNomSum[r.project_id] ?? 0) + Number(r.milestone_catalog?.nominal_value ?? 0);
        msBonus[r.project_id] = (msBonus[r.project_id] ?? 0) + Number(r.milestone_catalog?.multiplier_bonus ?? 0);
      }
    }

    grid = ((pr as any[]) ?? []).map((p) => ({
      id: p.id,
      name: p.name,
      type: p.project_type?.name ?? '—',
      status: p.project_status?.name ?? '—',
      statusRank: p.project_status?.rank ?? 999,
      venue: p.venue?.name ?? p.target_venue ?? '',
      venueKind: p.venue?.kind ?? '',
      deadline: p.venue?.deadline ?? null,
      leader: leaderName[p.id] ?? '',
      members: memberCount[p.id] ?? 0,
      openNeeds: openCount[p.id] ?? 0,
      laborNeeds: laborCount[p.id] ?? 0,
      resourceNeeds: resCount[p.id] ?? 0,
      escrow: escrowOf[p.id] ?? 0,
      pool: (memberNomSum[p.id] ?? 0) + (msNomSum[p.id] ?? 0),
      multiplier: Math.min(1 + (msBonus[p.id] ?? 0), 3),
      msVerified: msVer[p.id] ?? 0,
      msTotal: msTot[p.id] ?? 0,
      claimable: !hasManager[p.id] && (p.project_status?.name !== 'Finished')
    }));
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
    const initial = $page.url.searchParams.get('tab');
    if (initial === 'needs') surface = 'needs';
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
    if (!leaderReady) { error = get(t)('You don’t yet meet the leader skill requirements.'); return; }
    if (!cProposal.trim()) { error = get(t)('A proposal link is required to start a project.'); return; }
    if (leaderStake > myBalance) { error = get(t)('Leader stake is {n} STR but you only have {bal}.', { n: leaderStake, bal: myBalance }); return; }
    let proposal = cProposal.trim();
    if (!/^https?:\/\//i.test(proposal)) proposal = 'https://' + proposal;
    creating = true;
    const { data, error: err } = await supabase.rpc('create_project_with_leader_stake', {
      p_name: cName.trim(), p_type_id: cType, p_status_id: cStatus,
      p_venue: null, p_summary: cSummary.trim() || null,
      p_venue_id: cVenueId || null, p_proposal_url: proposal, p_as: asArg
    });
    creating = false;
    if (err) { error = err.message; return; }
    if (data && cOrgUnit) await supabase.from('project').update({ org_unit_id: cOrgUnit }).eq('id', data);
    cName = ''; cVenueId = ''; cSummary = ''; cProposal = ''; cOrgUnit = ''; showForm = false;
    await Promise.all([loadGrid(), effId ? loadMyBalance(effId) : Promise.resolve()]);
    if (data) window.location.href = `/projects/${data}`;
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
    if (!d) return 'muted';
    const days = (new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000;
    if (days < 0) return 'neg';
    if (days < 14) return 'warn';
    return 'dim';
  }

  function setSort(k: SortKey) {
    if (sortKey === k) sortDir = (sortDir === 1 ? -1 : 1) as 1 | -1;
    else { sortKey = k; sortDir = 1; }
  }
  function arrow(k: SortKey) { return sortKey === k ? (sortDir === 1 ? '▲' : '▼') : ''; }

  const typeNames = $derived([...new Set(grid.map((r) => r.type))].filter((x) => x !== '—').sort());

  // venues actually in use (excluding finished), grouped by kind for the dropdown
  const venueGroups = $derived.by(() => {
    const byKind = new Map<string, Set<string>>();
    for (const r of grid) {
      if (r.status === 'Finished' || !r.venue) continue;
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
    [...new Map(grid.filter((r) => r.status !== 'Finished').map((r) => [r.status, r.statusRank])).entries()]
      .sort((a, b) => a[1] - b[1]).map((e) => e[0]).filter((x) => x !== '—')
  );

  const rows = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    let out = grid.filter((r) =>
      r.status !== 'Finished' &&
      (!typeFilter || r.type === typeFilter) &&
      (!statusFilter || r.status === statusFilter) &&
      (!venueFilter ||
        (venueFilter.startsWith('kind:') ? r.venueKind === venueFilter.slice(5) : r.venue === venueFilter)) &&
      (!needle ||
        r.name.toLowerCase().includes(needle) ||
        r.venue.toLowerCase().includes(needle) ||
        r.leader.toLowerCase().includes(needle) ||
        r.type.toLowerCase().includes(needle))
    );
    const key = sortKey;
    out = [...out].sort((a, b) => {
      // deadline: upcoming first (soonest on top); past deadlines sink below all
      // upcoming ones; projects without a deadline sink to the very bottom.
      if (key === 'deadline') {
        if (!a.deadline && !b.deadline) return 0;
        if (!a.deadline) return 1;
        if (!b.deadline) return -1;
        const now = Date.now();
        const at = new Date(a.deadline + 'T00:00:00').getTime();
        const bt = new Date(b.deadline + 'T00:00:00').getTime();
        const aPast = at < now, bPast = bt < now;
        if (aPast !== bPast) return aPast ? 1 : -1; // past always below upcoming
        return (at - bt) * sortDir;                 // within group, chronological
      }
      let av: string | number = key === 'status' ? a.statusRank : ((a as any)[key] ?? '');
      let bv: string | number = key === 'status' ? b.statusRank : ((b as any)[key] ?? '');
      if (typeof av === 'string' && typeof bv === 'string') {
        return av.localeCompare(bv) * sortDir;
      }
      return ((av as number) - (bv as number)) * sortDir;
    });
    return out;
  });

  // aggregate footer
  const totalEscrow = $derived(rows.reduce((a, r) => a + r.escrow, 0));
  const totalNeeds = $derived(rows.reduce((a, r) => a + r.openNeeds, 0));
  const totalPool = $derived(rows.reduce((a, r) => a + r.pool, 0));
  const maxEscrow = $derived(Math.max(1, ...rows.map((r) => r.escrow)));
  const maxPool = $derived(Math.max(1, ...rows.map((r) => r.pool)));

  // pagination
  let pageSize = $state(10);
  let pageNum = $state(1);
  const pageCount = $derived(Math.max(1, Math.ceil(rows.length / pageSize)));
  // keep the current page in range when filters/sort/size shrink the result set
  $effect(() => { if (pageNum > pageCount) pageNum = pageCount; });
  // reset to first page whenever the filter inputs change
  $effect(() => { q; typeFilter; statusFilter; venueFilter; pageSize; pageNum = 1; });
  const pageRows = $derived(rows.slice((pageNum - 1) * pageSize, pageNum * pageSize));
  const rangeFrom = $derived(rows.length === 0 ? 0 : (pageNum - 1) * pageSize + 1);
  const rangeTo = $derived(Math.min(pageNum * pageSize, rows.length));

  // pipeline (rank order, Hold excluded) for the mini progress indicator
  const pipeline = $derived(statuses.filter((s) => s.name !== 'Hold').sort((a, b) => a.rank - b.rank).map((s) => s.name));
  function pipeIndex(name: string) { return pipeline.indexOf(name); }

  // status counts over the *unfiltered* grid, in pipeline order
  const statusCounts = $derived.by(() => {
    const m = new Map<string, number>();
    for (const r of grid) if (r.status !== 'Finished') m.set(r.status, (m.get(r.status) ?? 0) + 1);
    const ordered = statusNames.map((n) => ({ name: n, count: m.get(n) ?? 0 }));
    return ordered;
  });

  // KPI summary (whole portfolio, not just filtered rows)
  const kActive = $derived(grid.filter((r) => r.status !== 'Finished').length);
  const kFinished = $derived(grid.filter((r) => r.status === 'Finished').length);
  const kEscrow = $derived(grid.reduce((a, r) => a + r.escrow, 0));
  const kPool = $derived(grid.reduce((a, r) => a + r.pool, 0));
  const kProjected = $derived(grid.reduce((a, r) => a + Math.floor(r.pool * r.multiplier), 0));
  const kNeeds = $derived(grid.reduce((a, r) => a + r.openNeeds, 0));
  const kUpcoming = $derived(grid.filter((r) => {
    if (!r.deadline) return false;
    const days = (new Date(r.deadline + 'T00:00:00').getTime() - Date.now()) / 86400000;
    return days >= 0 && days <= 60;
  }).length);

  // Finished projects live in their own "hall of fame" — settled, minted, archived —
  // so the working grid below only carries projects still moving through the pipeline.
  let showHof = $state(true);
  const finished = $derived(
    grid
      .filter((r) => r.status === 'Finished')
      .map((r) => ({ ...r, minted: Math.floor(r.pool * r.multiplier) }))
      .sort((a, b) => b.minted - a.minted)
  );
  const hofMinted = $derived(finished.reduce((a, r) => a + r.minted, 0));

  function initials(name: string) {
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }
  function relDays(d: string | null) {
    if (!d) return '';
    const days = Math.round((new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000);
    if (days === 0) return get(t)('today');
    if (days > 0) return days <= 365 ? get(t)('in {d}d', { d: days }) : '';
    return get(t)('{d}d ago', { d: -days });
  }
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:center;">
    <div>
      <h1 style="margin:0;">{$t('Projects')}</h1>
      <span class="muted" style="font-size:.85rem;">{$t('{n} research projects · contribution pools, milestones & open needs', { n: grid.length })}</span>
    </div>
    {#if $member && surface === 'projects'}
      <button onclick={() => (showForm = !showForm)}>{showForm ? $t('Cancel') : $t('Start a project')}</button>
    {/if}
  </div>

  <!-- portfolio vs open-needs market -->
  <div class="row" style="gap:.4rem;">
    <span class="chip toggle {surface === 'projects' ? 'on' : ''}" role="button" tabindex="0"
      onclick={() => (surface = 'projects')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') surface = 'projects'; }}
    >{$t('Projects')} <span class="ct">{kActive}</span></span>
    <span class="chip toggle {surface === 'needs' ? 'on' : ''}" role="button" tabindex="0"
      onclick={() => (surface = 'needs')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') surface = 'needs'; }}
    >{$t('Open needs')} <span class="ct">{kNeeds}</span></span>
  </div>

  {#if surface === 'needs'}
    <TaskMarket showHeader={false} />
  {:else}

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  {#if showForm}
    <div class="card stack">
      <h2 style="margin:0;">{$t('Start a project')}</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {@html $t('A new project always starts at <span class="badge dim">Proposal</span> with a proposal on file and the leader initiation bond staked into its escrow.')}
      </p>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Name *')}</span>
        <input bind:value={cName} placeholder={$t('Project / paper name')} /></label>
      <div class="row" style="flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type *')}</span>
          <select bind:value={cType}><option value="">—</option>{#each types as pt}<option value={pt.id}>{pt.name} ({$t('stake')} {pt.leader_stake})</option>{/each}</select></label>
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
      {#if !leaderReady}
        <div class="card" style="background:color-mix(in srgb, var(--neg) 9%, transparent); border-color:color-mix(in srgb, var(--neg) 35%, transparent); padding:.6rem .8rem;">
          <span class="muted" style="font-size:.8rem;">{$t('Leading a project requires these certified guild skills:')}</span>
          <div class="row" style="flex-wrap:wrap; gap:.4rem; margin-top:.4rem;">
            {#each leaderMissing as r}
              <span class="badge warn" title={$t('You have {have}', { have: r.have ? $t(GUILD_LABEL[r.have]) : $t('none') })}>
                {$t(r.skill_name)} · {$t('needs {lvl}', { lvl: $t(GUILD_LABEL[r.min_level]) })}
              </span>
            {/each}
          </div>
          <span class="dim" style="font-size:.76rem; display:block; margin-top:.4rem;">{$t('Request a role card in the Guild or ask an officer to mint one, then come back.')}</span>
        </div>
      {/if}
      <div class="card" style="background:var(--accent-soft); border-color:transparent; padding:.6rem .8rem;">
        <div class="row" style="justify-content:space-between;">
          <span class="muted" style="font-size:.8rem;">{$t('Leader initiation stake')}</span>
          <span class="mono" style="font-weight:600;">{leaderStake.toLocaleString()} STR</span>
        </div>
        <div class="row" style="justify-content:space-between;">
          <span class="muted" style="font-size:.8rem;">{$t('Your balance after')}</span>
          <span class="mono {myBalance - leaderStake < 0 ? 'neg' : ''}">{(myBalance - leaderStake).toLocaleString()} STR</span>
        </div>
      </div>
      <div class="row">
        <button onclick={createProject} disabled={creating || leaderStake > myBalance || !leaderReady}>
          {creating ? $t('Creating…') : $t('Stake {n} STR & create', { n: leaderStake })}</button>
        {#if !leaderReady}<span class="neg" style="font-size:.8rem;">{$t('Leader skill requirements not met.')}</span>
        {:else if leaderStake > myBalance}<span class="neg" style="font-size:.8rem;">{$t('Insufficient balance to stake.')}</span>{/if}
      </div>
    </div>
  {/if}

  <!-- KPI summary -->
  <div class="kpis">
    <div class="kpi">
      <span class="k-label">{$t('Projects')}</span>
      <span class="k-value">{grid.length}</span>
      <span class="k-sub">{$t('{a} active · {f} finished', { a: kActive, f: kFinished })}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Nominal pool')}</span>
      <span class="k-value accent">{kPool.toLocaleString()}</span>
      <span class="k-sub">{$t('accrued contribution · {n} STR bonded', { n: kEscrow.toLocaleString() })}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Projected mint')}</span>
      <span class="k-value">{kProjected.toLocaleString()}</span>
      <span class="k-sub">{$t('at settlement, pool × multiplier')}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Open needs')}</span>
      <span class="k-value">{kNeeds}</span>
      <span class="k-sub">{$t('roles seeking contributors')}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Deadlines ≤ 60d')}</span>
      <span class="k-value">{kUpcoming}</span>
      <span class="k-sub">{$t('venues approaching')}</span>
    </div>
  </div>

  <!-- hall of fame: finished projects, settled & minted -->
  {#if finished.length > 0}
    <div class="hof card">
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
          <span class="muted" style="font-size:.82rem;">{$t('{n} STR minted', { n: hofMinted.toLocaleString() })}</span>
          <span class="chev" class:open={showHof}>▾</span>
        </div>
      </div>
      {#if showHof}
        <div class="hof-grid">
          {#each finished as r}
            <a href={`/projects/${r.id}`} class="hof-card">
              <div class="hof-card-top">
                <span class="hof-name">{r.name}</span>
                <span class="badge up">✓ {$t('shipped')}</span>
              </div>
              <span class="psub">
                <span>{r.type}</span>
                {#if r.venue}<span class="sep">·</span><span>{r.venue}</span>{/if}
              </span>
              <div class="hof-stats">
                <div class="hof-stat">
                  <span class="mono accent">{r.minted.toLocaleString()}</span>
                  <span class="muted">{$t('STR minted')}</span>
                </div>
                <div class="hof-stat">
                  <span class="mono">×{r.multiplier.toFixed(2)}</span>
                  <span class="muted">{$t('multiplier')}</span>
                </div>
                <div class="hof-stat">
                  <span class="mono up">✓{r.msVerified}<span class="dim">/{r.msTotal}</span></span>
                  <span class="muted">{$t('milestones')}</span>
                </div>
              </div>
              <div class="hof-team">
                {#if r.leader}
                  <span class="ava" title={r.leader}>{initials(r.leader)}</span>
                  <span class="dim" style="font-size:.82rem;">{r.leader}</span>
                  <span class="psub">· {r.members} {r.members === 1 ? $t('member') : $t('members')}</span>
                {:else}
                  <span class="muted" style="font-size:.82rem;">{r.members} {r.members === 1 ? $t('member') : $t('members')}</span>
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

  <!-- toolbar: search + type filter -->
  <div class="row" style="gap:.6rem;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder={$t('Search name, leader, venue, type…')} bind:value={q} style="width:100%;" />
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
    <div class="viewtoggle">
      <button class:on={view === 'cards'} onclick={() => (view = 'cards')} title={$t('Card view')} aria-label={$t('Card view')}>▤</button>
      <button class:on={view === 'table'} onclick={() => (view = 'table')} title={$t('Table view')} aria-label={$t('Table view')}>≣</button>
    </div>
  </div>

  {#if loading}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('Loading…')}</p></div>
  {:else if rows.length === 0}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('No projects match.')}</p></div>
  {:else if view === 'cards'}
    <div class="card-grid">
      {#each pageRows as r}
        <EntityCard
          type={r.type}
          title={r.name}
          subtitle={r.venue || ''}
          status={r.claimable ? $t('lead open') : r.status}
          statusKind={r.claimable ? 'warn' : projKind(r.status)}
          accent={r.claimable}
          stats={[
            { label: 'Nominal pool', value: r.pool.toLocaleString() },
            { label: 'Open needs', value: String(r.openNeeds) },
            { label: 'members', value: String(r.members) },
            ...(r.multiplier > 1 ? [{ label: '×Mult', value: '×' + r.multiplier.toFixed(2) }] : [])
          ]}
          onclick={() => goto(`/projects/${r.id}`)}
        />
      {/each}
    </div>
  {:else}
    <div class="card" style="padding:0; overflow-x:auto;">
      <table>
        <thead class="sticky">
          <tr>
            <th class="sortable" onclick={() => setSort('name')}>{$t('Project')} <span class="arrow">{arrow('name')}</span></th>
            <th class="sortable" onclick={() => setSort('status')}>{$t('Status')} <span class="arrow">{arrow('status')}</span></th>
            <th class="sortable" onclick={() => setSort('leader')}>{$t('Team')} <span class="arrow">{arrow('leader')}</span></th>
            <th class="sortable num" onclick={() => setSort('openNeeds')}>{$t('Open needs')} <span class="arrow">{arrow('openNeeds')}</span></th>
            <th class="sortable num" onclick={() => setSort('pool')}>{$t('Nominal pool')} <span class="arrow">{arrow('pool')}</span></th>
            <th class="sortable num" onclick={() => setSort('multiplier')}>{$t('×Mult')} <span class="arrow">{arrow('multiplier')}</span></th>
            <th class="sortable num" onclick={() => setSort('msVerified')}>{$t('Milestones')} <span class="arrow">{arrow('msVerified')}</span></th>
            <th class="sortable" onclick={() => setSort('venue')}>{$t('Venue')} <span class="arrow">{arrow('venue')}</span></th>
            <th class="sortable" onclick={() => setSort('deadline')}>{$t('Target deadline')} <span class="arrow">{arrow('deadline')}</span></th>
          </tr>
        </thead>
        <tbody>
          {#each pageRows as r}
            <tr>
              <td>
                <a href={`/projects/${r.id}`} class="proj">
                  <span class="pname">{r.name}{#if r.claimable}<span class="badge warn" style="margin-left:.4rem; font-size:.66rem; vertical-align:middle;">{$t('lead open')}</span>{/if}</span>
                  <span class="psub">
                    <span>{r.type}</span>
                  </span>
                </a>
              </td>
              <td>
                <span class="status {statusClass(r.status)}">
                  <span class="sdot" style="background:currentColor;"></span>{$t(r.status)}
                </span>
                {#if pipeIndex(r.status) >= 0 && r.status !== 'Hold'}
                  <span class="pipe {statusClass(r.status)}" title={$t('Step {n} of {total}', { n: pipeIndex(r.status) + 1, total: pipeline.length })}>
                    {#each pipeline as _, i}<i class:fill={i <= pipeIndex(r.status)}></i>{/each}
                  </span>
                {/if}
              </td>
              <td>
                {#if r.leader}
                  <span class="team">
                    <span class="ava" title={r.leader}>{initials(r.leader)}</span>
                    <span class="proj" style="gap:0;">
                      <span class="dim" style="font-size:.82rem;">{r.leader}</span>
                      <span class="psub">{r.members} {r.members === 1 ? $t('member') : $t('members')}</span>
                    </span>
                  </span>
                {:else}
                  <span class="muted">{r.members} {r.members === 1 ? $t('member') : $t('members')}</span>
                {/if}
              </td>
              <td class="num">
                {#if r.openNeeds > 0}
                  <span class="row" style="gap:.25rem; justify-content:flex-end;">
                    {#if r.laborNeeds > 0}<span class="badge info" title={$t('labor needs')}>{r.laborNeeds}L</span>{/if}
                    {#if r.resourceNeeds > 0}<span class="badge dim" title={$t('resource needs')}>{r.resourceNeeds}R</span>{/if}
                    {#if r.openNeeds - r.laborNeeds - r.resourceNeeds > 0}<span class="badge" title={$t('seat needs')}>{r.openNeeds - r.laborNeeds - r.resourceNeeds}S</span>{/if}
                  </span>
                {:else}<span class="muted">—</span>{/if}
              </td>
              <td class="num">
                <span class="mono">{r.pool.toLocaleString()}</span>
                {#if r.pool > 0}<span class="bar"><i style={`width:${Math.round((r.pool / maxPool) * 100)}%`}></i></span>{/if}
                {#if r.escrow > 0}<span class="rel dim" style="display:block;">{$t('{n} bonded', { n: r.escrow.toLocaleString() })}</span>{/if}
              </td>
              <td class="num mono">
                {#if r.multiplier > 1}<span class="badge {r.multiplier >= 2 ? 'up' : 'info'}">×{r.multiplier.toFixed(2)}</span>{:else}<span class="muted">×1.00</span>{/if}
              </td>
              <td class="num mono">
                {#if r.msTotal > 0}
                  <span class="{r.msVerified > 0 ? 'up' : 'muted'}">✓{r.msVerified}</span><span class="dim">/{r.msTotal}</span>
                {:else}<span class="muted">—</span>{/if}
              </td>
              <td>
                {#if r.venue}
                  <span class="venue-cell">
                    {#if r.venueKind}
                      <span class="vk {venueKindMeta(r.venueKind).cls}" title={$t(venueKindMeta(r.venueKind).label)}>{venueKindMeta(r.venueKind).icon}</span>
                    {/if}
                    <span class="vname">{r.venue}</span>
                  </span>
                {:else}<span class="muted">—</span>{/if}
              </td>
              <td>
                {#if r.deadline}
                  <span class="mono {ddlClass(r.deadline)}" style="font-size:.82rem; white-space:nowrap;">{fmtDate(r.deadline)}</span>
                  <span class="rel {ddlClass(r.deadline)}" style="display:block;">{relDays(r.deadline)}</span>
                {:else}
                  <span class="muted">—</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr style="border-top:1px solid var(--border-2);">
            <td class="muted" style="font-size:.78rem;">{$t('{n} total', { n: rows.length })}</td>
            <td></td><td></td>
            <td class="num mono muted" style="font-size:.78rem;">{totalNeeds}</td>
            <td class="num mono muted" style="font-size:.78rem;" title={$t('{n} STR bonded', { n: totalEscrow.toLocaleString() })}>{totalPool.toLocaleString()}</td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    </div>
  {/if}

  {#if !loading && rows.length > 0}
    <div class="row" style="justify-content:space-between; align-items:center;">
      <div class="row" style="gap:.5rem;">
        <span class="muted" style="font-size:.8rem;">{rangeFrom}–{rangeTo} {$t('of')} {rows.length}</span>
        <select bind:value={pageSize} style="padding:.3rem .5rem; font-size:.82rem;">
          {#each [10, 25, 50, 100] as n}<option value={n}>{$t('{n} / page', { n })}</option>{/each}
        </select>
      </div>
      {#if pageCount > 1}
        <div class="row" style="gap:.35rem;">
          <button class="ghost" onclick={() => (pageNum = 1)} disabled={pageNum === 1} title={$t('First')}>«</button>
          <button class="ghost" onclick={() => (pageNum = Math.max(1, pageNum - 1))} disabled={pageNum === 1}>‹ {$t('Prev')}</button>
          <span class="muted mono" style="font-size:.82rem; padding:0 .3rem;">{pageNum} / {pageCount}</span>
          <button class="ghost" onclick={() => (pageNum = Math.min(pageCount, pageNum + 1))} disabled={pageNum === pageCount}>{$t('Next')} ›</button>
          <button class="ghost" onclick={() => (pageNum = pageCount)} disabled={pageNum === pageCount} title={$t('Last')}>»</button>
        </div>
      {/if}
    </div>
  {/if}
  {/if}
</div>

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: .8rem; }
  .viewtoggle { display: inline-flex; border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
  .viewtoggle button {
    background: transparent; border: none; padding: .35rem .6rem; cursor: pointer;
    color: var(--muted); font-size: 1rem; line-height: 1;
  }
  .viewtoggle button.on { background: var(--accent-soft); color: var(--accent); }

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
    display: flex; flex-direction: column; gap: .5rem;
    padding: .8rem .9rem; border: 1px solid var(--border-2, var(--border));
    border-radius: 12px; background: var(--bg-elev, transparent);
    text-decoration: none; color: inherit; transition: border-color .15s ease, transform .15s ease;
  }
  .hof-card:hover { border-color: var(--up); transform: translateY(-2px); }
  .hof-card-top { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
  .hof-name { font-weight: 600; line-height: 1.25; }
  .hof-stats { display: flex; gap: .9rem; padding-top: .15rem; }
  .hof-stat { display: flex; flex-direction: column; gap: .1rem; }
  .hof-stat .mono { font-size: 1.02rem; font-weight: 600; }
  .hof-stat .muted { font-size: .68rem; text-transform: uppercase; letter-spacing: .03em; }
  .hof-team { display: flex; align-items: center; gap: .4rem; padding-top: .15rem; }

  /* venue column */
  .venue-cell { display: inline-flex; align-items: center; gap: .4rem; max-width: 220px; }
  .vname { font-size: .85rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .vk {
    display: inline-flex; align-items: center; justify-content: center;
    width: 1.45rem; height: 1.45rem; border-radius: 7px; font-size: .8rem; flex: none;
    border: 1px solid transparent; line-height: 1;
  }
  .vk-conference { background: color-mix(in srgb, var(--accent) 16%, transparent); border-color: color-mix(in srgb, var(--accent) 35%, transparent); }
  .vk-journal    { background: color-mix(in srgb, #a371f7 18%, transparent);     border-color: color-mix(in srgb, #a371f7 38%, transparent); }
  .vk-workshop   { background: color-mix(in srgb, #f0a35e 18%, transparent);     border-color: color-mix(in srgb, #f0a35e 38%, transparent); }
  .vk-rolling    { background: color-mix(in srgb, #3fb6c6 18%, transparent);     border-color: color-mix(in srgb, #3fb6c6 38%, transparent); }
  .vk-other      { background: var(--bg-elev, transparent); border-color: var(--border-2, var(--border)); }
</style>
