<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import EntityCard from '$lib/EntityCard.svelte';
  import CardDrawer from '$lib/CardDrawer.svelte';
  import ProjectSlotCard, { type Slot } from '$lib/cards/ProjectSlotCard.svelte';
  import SlotSeater from '$lib/cards/SlotSeater.svelte';
  import ProjectCardBody from '$lib/cards/ProjectCardBody.svelte';

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
    summary: string | null;
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

  // quick-view drawer
  let sel = $state<Grid | null>(null);
  function openProject(r: Grid) { sel = r; }
  function closeDrawer() { sel = null; }
  // after an in-drawer edit: reload the grid and re-point sel at the fresh row
  async function refreshSel() {
    const id = sel?.id;
    await loadGrid();
    if (id) sel = grid.find((g) => g.id === id) ?? sel;
  }
  // status name → EntityCard status dot kind
  function projKind(name: string): 'pos' | 'warn' | 'dim' {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold' || name === 'Under review') return 'warn';
    return 'dim';
  }
  // can the viewer manage this project's slot board? (WG officer or global editor)
  const canManageSel = $derived.by(() => {
    if (!sel) return false;
    if ($capabilities.has('edit_any_project')) return true;
    return !!sel.wgUnitId && $officerUnits.some((u) => u.unit_id === sel!.wgUnitId);
  });
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
  type SortKey = 'deadline' | 'pool' | 'seats' | 'openNeeds' | 'name';
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
        .select('id, name, target_venue, deadline, summary, org_unit_id, venue:venue_id(name, kind, deadline), project_type(name), project_status!project_status_id_fkey(name, rank)'),
      supabase.from('org_unit').select('id, name')
    ]);
    const unitName: Record<string, string> = {};
    for (const u of (ou as { id: string; name: string }[]) ?? []) unitName[u.id] = u.name;
    const projects = (pr as any[]) ?? [];
    const pids = projects.map((p) => p.id);

    // pull the full slot map (mirrors SlotBoard) for every project at once
    let slots: any[] = [];
    const memMap: Record<string, { id: string; name: string; amount: number; unit: string }[]> = {};
    const nominalBySlot: Record<string, number> = {};
    if (pids.length) {
      const { data: sl } = await supabase.from('project_slot')
        .select('id, project_id, slot_kind, req_access, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name)')
        .in('project_id', pids);
      slots = (sl as any[]) ?? [];
      const slotIds = slots.map((s) => s.id);
      if (slotIds.length) {
        const { data: wc } = await supabase.from('work_commitment')
          .select('slot_id, member_id, monthly_amount, nominal_str, member:member_id(full_name), resource:resource_id(unit)')
          .in('slot_id', slotIds);
        for (const w of (wc as any[]) ?? []) {
          nominalBySlot[w.slot_id] = (nominalBySlot[w.slot_id] ?? 0) + (Number(w.nominal_str) || 0);
          const arr = (memMap[w.slot_id] ??= []);
          if (arr.some((m) => m.id === w.member_id)) continue;
          arr.push({ id: w.member_id, name: w.member?.full_name ?? '—', amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h' });
        }
      }
    }

    // group slots per project (Slot shape for ProjectSlotCard) + roll up metrics
    const byP: Record<string, Slot[]> = {};
    const leaderName: Record<string, string> = {};
    const seatsFilled: Record<string, number> = {};
    const seatsTotal: Record<string, number> = {};
    const openNeeds: Record<string, number> = {};
    const pool: Record<string, number> = {};
    const hasLeader: Record<string, boolean> = {};
    for (const s of slots) {
      const members = memMap[s.id] ?? [];
      (byP[s.project_id] ??= []).push({
        id: s.id, slot_kind: s.slot_kind, skill_name: s.skill?.name ?? null,
        resource_type_name: s.resource_type?.name ?? null, req_access: s.req_access,
        quota: s.quota, headcount: s.headcount ?? 1, status: s.status, members
      });
      pool[s.project_id] = (pool[s.project_id] ?? 0) + (nominalBySlot[s.id] ?? 0);
      if (s.slot_kind === 'leader') {
        if (members.length) { hasLeader[s.project_id] = true; leaderName[s.project_id] = members[0].name; }
      } else {
        const head = s.headcount ?? 1;
        seatsTotal[s.project_id] = (seatsTotal[s.project_id] ?? 0) + head;
        seatsFilled[s.project_id] = (seatsFilled[s.project_id] ?? 0) + Math.min(members.length, head);
        if (members.length < head) openNeeds[s.project_id] = (openNeeds[s.project_id] ?? 0) + 1;
      }
    }
    slotsByProject = byP;

    grid = projects.map((p) => {
      const statusName = (p.project_status?.name ?? '—').trim();
      // robust terminal-state match: tolerate stray casing/whitespace in the
      // seeded status name so a delivered project never leaks into the grid
      const finished = /^finished$/i.test(statusName);
      return {
        id: p.id,
        name: p.name,
        type: p.project_type?.name ?? '—',
        status: statusName,
        statusRank: p.project_status?.rank ?? 999,
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
    // hand off to the WG slot board so the new owner can forge needs immediately
    if (data && cOrgUnit) window.location.href = `/officer/wg/${cOrgUnit}`;
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

  const rows = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    let out = grid.filter((r) =>
      !r.finished &&
      (!typeFilter || r.type === typeFilter) &&
      // Finished → Hall of fame; Hold (paused) is parked out of the default
      // "All" view too, but stays one click away via its own status chip.
      (statusFilter ? r.status === statusFilter : r.status !== 'Hold') &&
      (!venueFilter ||
        (venueFilter.startsWith('kind:') ? r.venueKind === venueFilter.slice(5) : r.venue === venueFilter)) &&
      (!needle ||
        r.name.toLowerCase().includes(needle) ||
        r.venue.toLowerCase().includes(needle) ||
        r.leader.toLowerCase().includes(needle) ||
        r.wg.toLowerCase().includes(needle) ||
        r.type.toLowerCase().includes(needle))
    );
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

  // KPI summary — "active" excludes both Finished (Hall of fame) and Hold (parked)
  const kActive = $derived(grid.filter((r) => !r.finished && r.status !== 'Hold').length);
  const kUpcoming = $derived(grid.filter((r) => {
    if (r.finished || r.status === 'Hold' || !r.deadline) return false;
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
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div class="stack" style="gap:.15rem;">
      <h1 style="margin:0;">{$t('Projects')}</h1>
      <span class="muted" style="font-size:.88rem;">
        {$t('{n} projects across the community — working groups, slots, and open roles.', { n: kActive })}{#if kUpcoming > 0} · <span class="warn">{$t('{n} with a deadline ≤ 60d', { n: kUpcoming })}</span>{/if}
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
          <span class="dim" style="font-size:.76rem; display:block; margin-top:.4rem;">{$t('Request a badge in the Guild or ask an officer to award one, then come back.')}</span>
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
          {#if hofMinted > 0}<span class="muted" style="font-size:.82rem;">{$t('{n} STR minted', { n: hofMinted.toLocaleString() })}</span>{/if}
          <span class="chev" class:open={showHof}>▾</span>
        </div>
      </div>
      {#if showHof}
        <div class="hof-grid">
          {#each finished as r}
            <button type="button" class="hof-card" onclick={() => openProject(r)}>
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
                  <span class="mono accent">{r.pool.toLocaleString()}</span>
                  <span class="muted">{$t('STR minted')}</span>
                </div>
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
            </button>
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
        <option value="pool">{$t('Nominal pool')}</option>
        <option value="seats">{$t('Seats')}</option>
        <option value="openNeeds">{$t('Open needs')}</option>
        <option value="name">{$t('Name')}</option>
      </select>
      <button class="ghost" onclick={() => (sortDir = sortDir === 1 ? -1 : 1)} title={$t('Toggle sort direction')} aria-label={$t('Toggle sort direction')}>{sortDir === 1 ? '▲' : '▼'}</button>
    </div>
  </div>

  {#if loading}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('Loading…')}</p></div>
  {:else if rows.length === 0}
    <div class="card"><p class="muted" style="padding:1rem;">{$t('No projects match.')}</p></div>
  {:else}
    <div class="card-grid">
      {#each rows as r}
        <EntityCard
          type={r.type}
          title={r.name}
          subtitle={[r.wg, r.venue].filter(Boolean).join(' · ')}
          status={r.claimable ? $t('lead open') : r.status}
          statusKind={r.claimable ? 'warn' : projKind(r.status)}
          accent={r.claimable}
          stats={[
            { label: 'Nominal pool', value: r.pool.toLocaleString() },
            { label: 'Seats', value: `${r.seatsFilled}/${r.seatsTotal}` },
            { label: 'Open needs', value: String(r.openNeeds) },
            ...(r.deadline ? [{ label: relDays(r.deadline), value: fmtDate(r.deadline) }] : [])
          ]}
          onclick={() => openProject(r)}
        />
      {/each}
    </div>
  {/if}
</div>

<!-- quick-view drawer: read-only slot map + officer hand-off -->
{#if sel}
  {@const r = sel}
  <CardDrawer
    open={sel !== null}
    type={r.type}
    title={r.name}
    subtitle={[r.wg, r.venue].filter(Boolean).join(' · ')}
    onClose={closeDrawer}
  >
    <div class="pdrawer">
      <!-- meta: status pipeline · type · working group · venue · deadline -->
      <div class="pd-meta">
        <span class="status {statusClass(r.status)}" title={pipeIndex(r.status) >= 0 ? $t('Step {n} of {total}', { n: pipeIndex(r.status) + 1, total: pipeline.length }) : undefined}>
          <span class="sdot" style="background:currentColor;"></span>{r.claimable ? $t('lead open') : $t(r.status)}
        </span>
        <span class="pd-chip">{$t(r.type)}</span>
        {#if r.wg}<span class="pd-chip">{r.wg}</span>{/if}
        {#if r.venue}
          <span class="pd-chip" title={$t(venueKindMeta(r.venueKind).label)}>{venueKindMeta(r.venueKind).icon} {r.venue}</span>
        {/if}
        {#if r.deadline}
          <span class="pd-chip {ddlClass(r.deadline)}">⏱ {fmtDate(r.deadline)} · {relDays(r.deadline)}</span>
        {/if}
      </div>

      <!-- key economy numbers -->
      <div class="pd-stats">
        <div class="pd-stat"><span class="pd-v mono">{r.pool.toLocaleString()}</span><span class="pd-l">{$t('Nominal pool')}</span></div>
        <div class="pd-stat"><span class="pd-v mono">{r.seatsFilled}/{r.seatsTotal}</span><span class="pd-l">{$t('Seats')}</span></div>
        <div class="pd-stat"><span class="pd-v mono">{r.openNeeds}</span><span class="pd-l">{$t('Open needs')}</span></div>
        {#if r.leader}<div class="pd-stat"><span class="pd-v">{r.leader}</span><span class="pd-l">{$t('first author')}</span></div>{/if}
      </div>

      {#if r.summary}
        <p class="pd-summary">{r.summary}</p>
      {/if}

      <!-- team & slots -->
      <div class="pd-section">
        <span class="pd-h">{$t('Team & slots')}</span>
        <ProjectSlotCard
          project={{ id: r.id, name: r.name, status: r.status, deadline: r.deadline }}
          slots={slotsByProject[r.id] ?? []}
          canManage={false}
        />
      </div>

      {#if canSeat && !r.finished}
        <SlotSeater projectId={r.id} projectName={r.name} onSeated={loadGrid} />
      {/if}
      {#if !r.wg}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('This project isn’t attributed to a working group yet.')}</p>
      {/if}

      <!-- editable details · media links · history -->
      <ProjectCardBody projectId={r.id} {venues} {workingGroups} onChanged={refreshSel} />
    </div>
    {#snippet actions()}
      {#if canManageSel && r.wgUnitId}
        <a class="btn" href={`/officer/wg/${r.wgUnitId}`}>{$t('Manage in slot board')} →</a>
      {:else if r.wgUnitId}
        <a class="btn ghost" href={`/officer/wg/${r.wgUnitId}`}>{$t('Open slot board')} →</a>
      {/if}
    {/snippet}
  </CardDrawer>
{/if}

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: .8rem; }
  .btn {
    display: inline-flex; align-items: center; gap: .3rem; padding: .5rem .9rem;
    background: var(--accent); color: #fff; border: 1px solid transparent; border-radius: 8px;
    text-decoration: none; font: inherit; font-weight: 600; cursor: pointer;
  }
  .btn.ghost { background: transparent; color: var(--accent); border-color: var(--border); }

  /* project drawer — the full project card */
  .pdrawer { display: flex; flex-direction: column; gap: 1rem; }
  .pd-meta { display: flex; flex-wrap: wrap; gap: .4rem; align-items: center; }
  .pd-chip {
    display: inline-flex; align-items: center; gap: .3rem;
    font-size: .76rem; color: var(--text-dim); background: var(--card-2);
    border: 1px solid var(--border); border-radius: 999px; padding: .15rem .55rem;
  }
  .pd-chip.warn { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 35%, transparent); }
  .pd-chip.neg { color: var(--down); border-color: color-mix(in srgb, var(--down) 35%, transparent); }
  .pd-stats {
    display: flex; flex-wrap: wrap; gap: .3rem 1.4rem;
    padding: .7rem .9rem; border: 1px solid var(--border); border-radius: 12px; background: var(--card);
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
    border-radius: 12px; background: var(--bg-elev, transparent);
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
</style>
