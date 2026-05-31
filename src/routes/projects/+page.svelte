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
    escrow: number;
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
  type SortKey = 'name' | 'type' | 'status' | 'leader' | 'members' | 'openNeeds' | 'escrow' | 'venue' | 'deadline';
  let sortKey = $state<SortKey>('status');
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
    const [{ data: pr }, { data: pm }, { data: nd }, { data: esc }] = await Promise.all([
      supabase.from('project')
        .select('id, name, target_venue, venue:venue_id(name, deadline), project_type(name), project_status!project_status_id_fkey(name, rank)'),
      supabase.from('project_member')
        .select('project_id, member(full_name), project_role(name, can_manage)'),
      supabase.from('open_need').select('project_id, status'),
      supabase.from('stater_balance').select('project_id, balance').not('project_id', 'is', null)
    ]);

    const memberCount: Record<string, number> = {};
    const leaderName: Record<string, string> = {};
    for (const r of (pm as any[]) ?? []) {
      memberCount[r.project_id] = (memberCount[r.project_id] ?? 0) + 1;
      if (r.project_role?.name === 'Leader' && r.member?.full_name) leaderName[r.project_id] = r.member.full_name;
      else if (!leaderName[r.project_id] && r.project_role?.can_manage && r.member?.full_name) leaderName[r.project_id] = r.member.full_name;
    }
    const openCount: Record<string, number> = {};
    for (const r of (nd as any[]) ?? [])
      if (r.status === 'open') openCount[r.project_id] = (openCount[r.project_id] ?? 0) + 1;
    const escrowOf: Record<string, number> = {};
    for (const r of (esc as any[]) ?? []) escrowOf[r.project_id] = Number(r.balance) || 0;

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
      escrow: escrowOf[p.id] ?? 0
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
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:center;">
    <div>
      <h1 style="margin:0;">Projects</h1>
      <span class="muted" style="font-size:.85rem;">{grid.length} research projects · live escrow & staffing</span>
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

  <!-- toolbar: search + filters -->
  <div class="row" style="gap:.6rem;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder="Search name, leader, venue, type…" bind:value={q} style="width:100%;" />
    </div>
    <select bind:value={typeFilter}>
      <option value="">All types</option>
      {#each typeNames as t}<option value={t}>{t}</option>{/each}
    </select>
    <select bind:value={statusFilter}>
      <option value="">All statuses</option>
      {#each statusNames as s}<option value={s}>{s}</option>{/each}
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
        <thead>
          <tr>
            <th class="sortable" onclick={() => setSort('name')}>Project <span class="arrow">{arrow('name')}</span></th>
            <th class="sortable" onclick={() => setSort('type')}>Type <span class="arrow">{arrow('type')}</span></th>
            <th class="sortable" onclick={() => setSort('status')}>Status <span class="arrow">{arrow('status')}</span></th>
            <th class="sortable" onclick={() => setSort('leader')}>Leader <span class="arrow">{arrow('leader')}</span></th>
            <th class="sortable num" onclick={() => setSort('members')}>Members <span class="arrow">{arrow('members')}</span></th>
            <th class="sortable num" onclick={() => setSort('openNeeds')}>Open needs <span class="arrow">{arrow('openNeeds')}</span></th>
            <th class="sortable num" onclick={() => setSort('escrow')}>Escrow <span class="arrow">{arrow('escrow')}</span></th>
            <th class="sortable" onclick={() => setSort('venue')}>Target <span class="arrow">{arrow('venue')}</span></th>
            <th class="sortable" onclick={() => setSort('deadline')}>Deadline <span class="arrow">{arrow('deadline')}</span></th>
          </tr>
        </thead>
        <tbody>
          {#each rows as r}
            <tr>
              <td><a href={`/projects/${r.id}`} style="font-weight:500;">{r.name}</a></td>
              <td class="dim">{r.type}</td>
              <td>
                <span class="status {statusClass(r.status)}">
                  <span class="sdot" style="background:currentColor;"></span>{r.status}
                </span>
              </td>
              <td class="dim">{r.leader || '—'}</td>
              <td class="num mono">{r.members}</td>
              <td class="num mono">
                {#if r.openNeeds > 0}<span class="badge info">{r.openNeeds}</span>{:else}<span class="muted">0</span>{/if}
              </td>
              <td class="num mono">{r.escrow.toLocaleString()}</td>
              <td class="dim">{r.venue || '—'}</td>
              <td class="mono {ddlClass(r.deadline)}" style="font-size:.82rem; white-space:nowrap;">{r.deadline ? fmtDate(r.deadline) : '—'}</td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr style="border-top:1px solid var(--border-2);">
            <td class="muted" style="font-size:.78rem;">{rows.length} shown</td>
            <td></td><td></td><td></td><td></td>
            <td class="num mono muted" style="font-size:.78rem;">{totalNeeds}</td>
            <td class="num mono muted" style="font-size:.78rem;">{totalEscrow.toLocaleString()}</td>
            <td></td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    {/if}
  </div>
</div>
