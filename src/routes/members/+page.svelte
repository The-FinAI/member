<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Row = {
    id: string;
    full_name: string;
    affiliation: string | null;
    status: string;
    member_position: { position: { name: string } }[];
  };

  let rows = $state<Row[]>([]);
  let loading = $state(true);
  let q = $state('');

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const { data } = await supabase
      .from('member')
      .select('id, full_name, affiliation, status, member_position(position(name))')
      .order('full_name');
    rows = (data as Row[]) ?? [];
    loading = false;
  });

  const filtered = $derived(
    rows.filter((r) => r.full_name.toLowerCase().includes(q.toLowerCase()))
  );
</script>

<div class="stack">
  <h1>Members</h1>
  <input placeholder="Search by name…" bind:value={q} style="max-width:320px;" />

  <div class="card">
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if filtered.length === 0}
      <p class="muted">No members.</p>
    {:else}
      <table>
        <thead><tr><th>Name</th><th>Affiliation</th><th>Position</th><th>Status</th></tr></thead>
        <tbody>
          {#each filtered as r}
            <tr>
              <td>{r.full_name}</td>
              <td>{r.affiliation ?? '—'}</td>
              <td>{r.member_position?.map((p) => p.position?.name).filter(Boolean).join(', ') || '—'}</td>
              <td><span class="badge">{r.status}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
