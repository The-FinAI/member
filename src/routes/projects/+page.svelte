<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Row = {
    id: string;
    name: string;
    target_venue: string | null;
    deadline: string | null;
    project_type: { name: string } | null;
    project_status: { name: string } | null;
  };

  let rows = $state<Row[]>([]);
  let loading = $state(true);
  let typeFilter = $state('');
  let statusFilter = $state('');

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const { data } = await supabase
      .from('project')
      .select('id, name, target_venue, deadline, project_type(name), project_status(name)')
      .order('name');
    rows = (data as Row[]) ?? [];
    loading = false;
  });

  const types = $derived([...new Set(rows.map((r) => r.project_type?.name).filter(Boolean))] as string[]);
  const statuses = $derived([...new Set(rows.map((r) => r.project_status?.name).filter(Boolean))] as string[]);
  const filtered = $derived(
    rows.filter(
      (r) =>
        (!typeFilter || r.project_type?.name === typeFilter) &&
        (!statusFilter || r.project_status?.name === statusFilter)
    )
  );
</script>

<div class="stack">
  <h1>Projects</h1>

  <div class="row">
    <select bind:value={typeFilter}>
      <option value="">All types</option>
      {#each types as t}<option value={t}>{t}</option>{/each}
    </select>
    <select bind:value={statusFilter}>
      <option value="">All statuses</option>
      {#each statuses as s}<option value={s}>{s}</option>{/each}
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
