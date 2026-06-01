<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type PType = { id: string; name: string; leader_stake: number; join_stake: number; finish_bonus: number };
  type PStatus = { id: string; name: string; rank: number };
  type Venue = { id: string; name: string; kind: string; deadline: string | null };
  // one fully-denormalised grid row
  type Grid = {
    id: string;
    name: string;
    type: string;
    status: string;
    statusRank: number;
    venue: string;
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
  let loading = $state(true);

  // filters / search / sort
  let q = $state('');
  let typeFilter = $state('');
  let statusFilter = $state('');
  type SortKey = 'name' | 'type' | 'status' | 'leader' | 'members' | 'openNeeds' | 'escrow' | 'pool' | 'multiplier' | 'msVerified' | 'venue' | 'deadline';
  let sortKey = $state<SortKey>('pool');
  let sortDir = $state<1 | -1>(1);

  // create form
  let myBalance = $state(0);
  let showForm = $state(false);
  let cName = $state(''); let cType = $state(''); let cStatus = $state('');
  let cVenueId = $state(''); let cSummary = $state(''); let cProposal = $state('');
  let creating = $state(false);
  let error = $state('');

  const chosenType = $derived(types.find((t) => t.id === cType) ?? null);
  const leaderStake = $derived(chosenType?.leader_stake ?? 0);

  async function loadGrid() {
    const [{ data: pr }, { data: pm }, { data: nd }, { data: esc }, { data: mnom }, { data: pms }] = await Promise.all([
      supabase.from('project')
        .select('id, name, target_venue, venue:venue_id(name, deadline), project_type(name), project_status!project_status_id_fkey(name, rank)'),
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

  async function loadMyBalance() {
    if (!$member) return;
    const { data } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle();
    myBalance = Number((data as { balance: number } | null)?.balance ?? 0);
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [, { data: ty }, { data: st }, { data: vn }] = await Promise.all([
      loadGrid(),
      supabase.from('project_type').select('id, name, leader_stake, join_stake, finish_bonus').order('rank'),
      supabase.from('project_status').select('id, name, rank').order('rank'),
      supabase.from('venue').select('id, name, kind, deadline').eq('is_active', true).order('rank')
    ]);
    types = (ty as PType[]) ?? [];
    statuses = (st as PStatus[]) ?? [];
    venues = (vn as Venue[]) ?? [];
    cStatus = statuses.find((s) => s.name === 'Proposal')?.id ?? statuses[0]?.id ?? '';
    loading = false;
    const unsub = member.subscribe((m) => { if (m) loadMyBalance(); });
    return unsub;
  });

  async function createProject() {
    error = '';
    if (!cName.trim() || !cType) { error = 'Name and type are required.'; return; }
    if (!cProposal.trim()) { error = 'A proposal link is required to start a project.'; return; }
    if (leaderStake > myBalance) { error = `Leader stake is ${leaderStake} STR but you only have ${myBalance}.`; return; }
    let proposal = cProposal.trim();
    if (!/^https?:\/\//i.test(proposal)) proposal = 'https://' + proposal;
    creating = true;
    const { data, error: err } = await supabase.rpc('create_project_with_leader_stake', {
      p_name: cName.trim(), p_type_id: cType, p_status_id: cStatus,
      p_venue: null, p_summary: cSummary.trim() || null,
      p_venue_id: cVenueId || null, p_proposal_url: proposal
    });
    creating = false;
    if (err) { error = err.message; return; }
    cName = ''; cVenueId = ''; cSummary = ''; cProposal = ''; showForm = false;
    await Promise.all([loadGrid(), loadMyBalance()]);
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
  const statusNames = $derived(
    [...new Map(grid.map((r) => [r.status, r.statusRank])).entries()]
      .sort((a, b) => a[1] - b[1]).map((e) => e[0]).filter((x) => x !== '—')
  );

  const rows = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    let out = grid.filter((r) =>
      (!typeFilter || r.type === typeFilter) &&
      (!statusFilter || r.status === statusFilter) &&
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
  $effect(() => { q; typeFilter; statusFilter; pageSize; pageNum = 1; });
  const pageRows = $derived(rows.slice((pageNum - 1) * pageSize, pageNum * pageSize));
  const rangeFrom = $derived(rows.length === 0 ? 0 : (pageNum - 1) * pageSize + 1);
  const rangeTo = $derived(Math.min(pageNum * pageSize, rows.length));

  // pipeline (rank order, Hold excluded) for the mini progress indicator
  const pipeline = $derived(statuses.filter((s) => s.name !== 'Hold').sort((a, b) => a.rank - b.rank).map((s) => s.name));
  function pipeIndex(name: string) { return pipeline.indexOf(name); }

  // status counts over the *unfiltered* grid, in pipeline order
  const statusCounts = $derived.by(() => {
    const m = new Map<string, number>();
    for (const r of grid) m.set(r.status, (m.get(r.status) ?? 0) + 1);
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

  function initials(name: string) {
    const p = name.trim().split(/\s+/);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }
  function relDays(d: string | null) {
    if (!d) return '';
    const days = Math.round((new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000);
    if (days === 0) return 'today';
    if (days > 0) return days <= 365 ? `in ${days}d` : '';
    return `${-days}d ago`;
  }
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:center;">
    <div>
      <h1 style="margin:0;">Projects</h1>
      <span class="muted" style="font-size:.85rem;">{grid.length} research projects · contribution pools, milestones & open needs</span>
    </div>
    {#if $member}
      <button onclick={() => (showForm = !showForm)}>{showForm ? 'Cancel' : 'Start a project'}</button>
    {/if}
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  {#if showForm}
    <div class="card stack">
      <h2 style="margin:0;">Start a project</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        A new project always starts at <span class="badge dim">Proposal</span> with a proposal on file and the
        leader initiation bond staked into its escrow.
      </p>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Name *</span>
        <input bind:value={cName} placeholder="Project / paper name" /></label>
      <div class="row" style="flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Type *</span>
          <select bind:value={cType}><option value="">—</option>{#each types as t}<option value={t.id}>{t.name} (stake {t.leader_stake})</option>{/each}</select></label>
        <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">Target venue</span>
          <select bind:value={cVenueId}>
            <option value="">— none —</option>
            {#each venues as v}<option value={v.id}>{v.name}{v.deadline ? ` · ddl ${fmtDate(v.deadline)}` : ''}</option>{/each}
          </select></label>
      </div>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Proposal link * <span class="dim">(PDF on Drive, Overleaf, OpenReview…)</span></span>
        <input bind:value={cProposal} placeholder="https://…" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Summary</span>
        <textarea bind:value={cSummary} rows="2" placeholder="One-line description"></textarea></label>
      <div class="card" style="background:var(--accent-soft); border-color:transparent; padding:.6rem .8rem;">
        <div class="row" style="justify-content:space-between;">
          <span class="muted" style="font-size:.8rem;">Leader initiation stake</span>
          <span class="mono" style="font-weight:600;">{leaderStake.toLocaleString()} STR</span>
        </div>
        <div class="row" style="justify-content:space-between;">
          <span class="muted" style="font-size:.8rem;">Your balance after</span>
          <span class="mono {myBalance - leaderStake < 0 ? 'neg' : ''}">{(myBalance - leaderStake).toLocaleString()} STR</span>
        </div>
      </div>
      <div class="row">
        <button onclick={createProject} disabled={creating || leaderStake > myBalance}>
          {creating ? 'Creating…' : `Stake ${leaderStake} STR & create`}</button>
        {#if leaderStake > myBalance}<span class="neg" style="font-size:.8rem;">Insufficient balance to stake.</span>{/if}
      </div>
    </div>
  {/if}

  <!-- KPI summary -->
  <div class="kpis">
    <div class="kpi">
      <span class="k-label">Projects</span>
      <span class="k-value">{grid.length}</span>
      <span class="k-sub">{kActive} active · {kFinished} finished</span>
    </div>
    <div class="kpi">
      <span class="k-label">Nominal pool</span>
      <span class="k-value accent">{kPool.toLocaleString()}</span>
      <span class="k-sub">accrued contribution · {kEscrow.toLocaleString()} STR bonded</span>
    </div>
    <div class="kpi">
      <span class="k-label">Projected mint</span>
      <span class="k-value">{kProjected.toLocaleString()}</span>
      <span class="k-sub">at settlement, pool × multiplier</span>
    </div>
    <div class="kpi">
      <span class="k-label">Open needs</span>
      <span class="k-value">{kNeeds}</span>
      <span class="k-sub">roles seeking contributors</span>
    </div>
    <div class="kpi">
      <span class="k-label">Deadlines ≤ 60d</span>
      <span class="k-value">{kUpcoming}</span>
      <span class="k-sub">venues approaching</span>
    </div>
  </div>

  <!-- status filter chips -->
  <div class="row" style="gap:.4rem;">
    <span
      class="chip toggle {statusFilter === '' ? 'on' : ''}"
      role="button" tabindex="0"
      onclick={() => (statusFilter = '')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') statusFilter = ''; }}
    >All <span class="ct">{grid.length}</span></span>
    {#each statusCounts as s}
      <span
        class="chip toggle {statusFilter === s.name ? 'on' : ''}"
        role="button" tabindex="0"
        onclick={() => (statusFilter = statusFilter === s.name ? '' : s.name)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') statusFilter = statusFilter === s.name ? '' : s.name; }}
      >
        <span class="cdot {statusClass(s.name)}"></span>
        <span>{s.name}</span>
        <span class="ct">{s.count}</span>
      </span>
    {/each}
  </div>

  <!-- toolbar: search + type filter -->
  <div class="row" style="gap:.6rem;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder="Search name, leader, venue, type…" bind:value={q} style="width:100%;" />
    </div>
    <select bind:value={typeFilter}>
      <option value="">All types</option>
      {#each typeNames as t}<option value={t}>{t}</option>{/each}
    </select>
    {#if q || typeFilter || statusFilter}
      <button class="ghost" onclick={() => { q = ''; typeFilter = ''; statusFilter = ''; }}>Reset</button>
    {/if}
  </div>

  <div class="card" style="padding:0; overflow-x:auto;">
    {#if loading}
      <p class="muted" style="padding:1rem;">Loading…</p>
    {:else if rows.length === 0}
      <p class="muted" style="padding:1rem;">No projects match.</p>
    {:else}
      <table>
        <thead class="sticky">
          <tr>
            <th class="sortable" onclick={() => setSort('name')}>Project <span class="arrow">{arrow('name')}</span></th>
            <th class="sortable" onclick={() => setSort('status')}>Status <span class="arrow">{arrow('status')}</span></th>
            <th class="sortable" onclick={() => setSort('leader')}>Team <span class="arrow">{arrow('leader')}</span></th>
            <th class="sortable num" onclick={() => setSort('openNeeds')}>Open needs <span class="arrow">{arrow('openNeeds')}</span></th>
            <th class="sortable num" onclick={() => setSort('pool')}>Nominal pool <span class="arrow">{arrow('pool')}</span></th>
            <th class="sortable num" onclick={() => setSort('multiplier')}>×Mult <span class="arrow">{arrow('multiplier')}</span></th>
            <th class="sortable num" onclick={() => setSort('msVerified')}>Milestones <span class="arrow">{arrow('msVerified')}</span></th>
            <th class="sortable" onclick={() => setSort('deadline')}>Target deadline <span class="arrow">{arrow('deadline')}</span></th>
          </tr>
        </thead>
        <tbody>
          {#each pageRows as r}
            <tr>
              <td>
                <a href={`/projects/${r.id}`} class="proj">
                  <span class="pname">{r.name}{#if r.claimable}<span class="badge warn" style="margin-left:.4rem; font-size:.66rem; vertical-align:middle;">lead open</span>{/if}</span>
                  <span class="psub">
                    <span>{r.type}</span>
                    {#if r.venue}<span class="sep">·</span><span>{r.venue}</span>{/if}
                  </span>
                </a>
              </td>
              <td>
                <span class="status {statusClass(r.status)}">
                  <span class="sdot" style="background:currentColor;"></span>{r.status}
                </span>
                {#if pipeIndex(r.status) >= 0 && r.status !== 'Hold'}
                  <span class="pipe {statusClass(r.status)}" title={`Step ${pipeIndex(r.status) + 1} of ${pipeline.length}`}>
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
                      <span class="psub">{r.members} member{r.members === 1 ? '' : 's'}</span>
                    </span>
                  </span>
                {:else}
                  <span class="muted">{r.members} member{r.members === 1 ? '' : 's'}</span>
                {/if}
              </td>
              <td class="num">
                {#if r.openNeeds > 0}
                  <span class="row" style="gap:.25rem; justify-content:flex-end;">
                    {#if r.laborNeeds > 0}<span class="badge info" title="labor needs">{r.laborNeeds}L</span>{/if}
                    {#if r.resourceNeeds > 0}<span class="badge dim" title="resource needs">{r.resourceNeeds}R</span>{/if}
                    {#if r.openNeeds - r.laborNeeds - r.resourceNeeds > 0}<span class="badge" title="seat needs">{r.openNeeds - r.laborNeeds - r.resourceNeeds}S</span>{/if}
                  </span>
                {:else}<span class="muted">—</span>{/if}
              </td>
              <td class="num">
                <span class="mono">{r.pool.toLocaleString()}</span>
                {#if r.pool > 0}<span class="bar"><i style={`width:${Math.round((r.pool / maxPool) * 100)}%`}></i></span>{/if}
                {#if r.escrow > 0}<span class="rel dim" style="display:block;">{r.escrow.toLocaleString()} bonded</span>{/if}
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
            <td class="muted" style="font-size:.78rem;">{rows.length} total</td>
            <td></td><td></td>
            <td class="num mono muted" style="font-size:.78rem;">{totalNeeds}</td>
            <td class="num mono muted" style="font-size:.78rem;" title={`${totalEscrow.toLocaleString()} STR bonded`}>{totalPool.toLocaleString()}</td>
            <td></td>
            <td></td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    {/if}
  </div>

  {#if !loading && rows.length > 0}
    <div class="row" style="justify-content:space-between; align-items:center;">
      <div class="row" style="gap:.5rem;">
        <span class="muted" style="font-size:.8rem;">{rangeFrom}–{rangeTo} of {rows.length}</span>
        <select bind:value={pageSize} style="padding:.3rem .5rem; font-size:.82rem;">
          {#each [10, 25, 50, 100] as n}<option value={n}>{n} / page</option>{/each}
        </select>
      </div>
      {#if pageCount > 1}
        <div class="row" style="gap:.35rem;">
          <button class="ghost" onclick={() => (pageNum = 1)} disabled={pageNum === 1} title="First">«</button>
          <button class="ghost" onclick={() => (pageNum = Math.max(1, pageNum - 1))} disabled={pageNum === 1}>‹ Prev</button>
          <span class="muted mono" style="font-size:.82rem; padding:0 .3rem;">{pageNum} / {pageCount}</span>
          <button class="ghost" onclick={() => (pageNum = Math.min(pageCount, pageNum + 1))} disabled={pageNum === pageCount}>Next ›</button>
          <button class="ghost" onclick={() => (pageNum = pageCount)} disabled={pageNum === pageCount} title="Last">»</button>
        </div>
      {/if}
    </div>
  {/if}
</div>
