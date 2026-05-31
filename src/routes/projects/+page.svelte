<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type Row = {
    id: string;
    name: string;
    target_venue: string | null;
    deadline: string | null;
    project_type: { name: string } | null;
    project_status: { name: string } | null;
  };
  type PType = { id: string; name: string; leader_stake: number; join_stake: number; finish_bonus: number };
  type PStatus = { id: string; name: string };

  let rows = $state<Row[]>([]);
  let loading = $state(true);
  let typeFilter = $state('');
  let statusFilter = $state('');

  // creation form
  let types = $state<PType[]>([]);
  let statuses = $state<PStatus[]>([]);
  let myBalance = $state(0);
  let showForm = $state(false);
  let cName = $state('');
  let cType = $state('');
  let cStatus = $state('');
  let cVenue = $state('');
  let cSummary = $state('');
  let creating = $state(false);
  let error = $state('');

  const chosenType = $derived(types.find((t) => t.id === cType) ?? null);
  const leaderStake = $derived(chosenType?.leader_stake ?? 0);

  async function loadList() {
    const { data } = await supabase
      .from('project')
      .select('id, name, target_venue, deadline, project_type(name), project_status(name)')
      .order('name');
    rows = (data as Row[]) ?? [];
  }

  async function loadMyBalance() {
    if (!$member) return;
    const { data } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle();
    myBalance = Number((data as { balance: number } | null)?.balance ?? 0);
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [, { data: ty }, { data: st }] = await Promise.all([
      loadList(),
      supabase.from('project_type').select('id, name, leader_stake, join_stake, finish_bonus').order('rank'),
      supabase.from('project_status').select('id, name').order('rank')
    ]);
    types = (ty as PType[]) ?? [];
    statuses = (st as PStatus[]) ?? [];
    cStatus = statuses.find((s) => s.name === 'Proposal')?.id ?? statuses[0]?.id ?? '';
    loading = false;
    const unsub = member.subscribe((m) => { if (m) loadMyBalance(); });
    return unsub;
  });

  async function createProject() {
    error = '';
    if (!cName.trim() || !cType || !cStatus) { error = 'Name, type and status are required.'; return; }
    if (leaderStake > myBalance) { error = `Leader stake is ${leaderStake} STR but you only have ${myBalance}.`; return; }
    creating = true;
    const { data, error: err } = await supabase.rpc('create_project_with_leader_stake', {
      p_name: cName.trim(), p_type_id: cType, p_status_id: cStatus,
      p_venue: cVenue.trim() || null, p_summary: cSummary.trim() || null
    });
    creating = false;
    if (err) { error = err.message; return; }
    cName = ''; cVenue = ''; cSummary = ''; showForm = false;
    await Promise.all([loadList(), loadMyBalance()]);
    if (data) window.location.href = `/projects/${data}`;
  }

  const typeNames = $derived([...new Set(rows.map((r) => r.project_type?.name).filter(Boolean))] as string[]);
  const statusNames = $derived([...new Set(rows.map((r) => r.project_status?.name).filter(Boolean))] as string[]);
  const filtered = $derived(
    rows.filter(
      (r) =>
        (!typeFilter || r.project_type?.name === typeFilter) &&
        (!statusFilter || r.project_status?.name === statusFilter)
    )
  );
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:center;">
    <h1 style="margin:0;">Projects</h1>
    {#if $member}
      <button onclick={() => (showForm = !showForm)}>{showForm ? 'Cancel' : 'Start a project'}</button>
    {/if}
  </div>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  {#if showForm}
    <div class="card stack">
      <h2 style="margin:0;">Start a project</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        Starting a project stakes the leader initiation bond into its escrow. Your balance:
        <strong>{myBalance.toLocaleString()}</strong> STR. Leader stake for the chosen type:
        <strong>{leaderStake}</strong> STR.
      </p>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Name</span>
        <input bind:value={cName} placeholder="Project / paper name" /></label>
      <div class="row" style="flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Type</span>
          <select bind:value={cType}><option value="">—</option>{#each types as t}<option value={t.id}>{t.name} (stake {t.leader_stake})</option>{/each}</select></label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Status</span>
          <select bind:value={cStatus}>{#each statuses as s}<option value={s.id}>{s.name}</option>{/each}</select></label>
        <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">Target venue</span>
          <input bind:value={cVenue} placeholder="e.g. NeurIPS" /></label>
      </div>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Summary</span>
        <textarea bind:value={cSummary} rows="2" placeholder="One-line description"></textarea></label>
      <div class="row">
        <button onclick={createProject} disabled={creating}>{creating ? 'Creating…' : `Stake ${leaderStake} STR & create`}</button>
      </div>
    </div>
  {/if}

  <div class="row">
    <select bind:value={typeFilter}>
      <option value="">All types</option>
      {#each typeNames as t}<option value={t}>{t}</option>{/each}
    </select>
    <select bind:value={statusFilter}>
      <option value="">All statuses</option>
      {#each statusNames as s}<option value={s}>{s}</option>{/each}
    </select>
    <span class="muted">{filtered.length} project{filtered.length === 1 ? '' : 's'}</span>
  </div>

  <div class="card">
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if filtered.length === 0}
      <p class="muted">No projects.</p>
    {:else}
      <table>
        <thead>
          <tr><th>Name</th><th>Type</th><th>Status</th><th>Target</th></tr>
        </thead>
        <tbody>
          {#each filtered as r}
            <tr>
              <td><a href={`/projects/${r.id}`}>{r.name}</a></td>
              <td>{r.project_type?.name ?? '—'}</td>
              <td><span class="badge">{r.project_status?.name ?? '—'}</span></td>
              <td>{r.target_venue ?? '—'}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
