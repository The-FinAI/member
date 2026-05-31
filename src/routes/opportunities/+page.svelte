<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Row = {
    id: string;
    description: string | null;
    headcount: number;
    min_level: string | null;
    status: string;
    project: { name: string } | null;
    project_role: { name: string } | null;
    skill: { name: string } | null;
  };

  let rows = $state<Row[]>([]);
  let loading = $state(true);

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const { data } = await supabase
      .from('open_need')
      .select('id, description, headcount, min_level, status, project(name), project_role(name), skill(name)')
      .eq('status', 'open')
      .order('created_at', { ascending: false });
    rows = (data as Row[]) ?? [];
    loading = false;
  });
</script>

<div class="stack">
  <h1>Open Opportunities</h1>
  <p class="muted" style="margin-top:-.75rem;">Projects looking for collaborators. Apply to express interest.</p>

  {#if loading}
    <p class="muted">Loading…</p>
  {:else if rows.length === 0}
    <div class="card"><p class="muted">No open opportunities right now.</p></div>
  {:else}
    <div class="stack">
      {#each rows as r}
        <div class="card">
          <div class="row" style="justify-content:space-between;">
            <h2 style="margin:0;">{r.project?.name ?? 'Project'}</h2>
            <span class="badge">{r.project_role?.name ?? 'Contributor'}</span>
          </div>
          <p class="muted" style="margin:.4rem 0;">{r.description ?? ''}</p>
          <div class="row muted" style="font-size:.82rem;">
            {#if r.skill}<span>Skill: {r.skill.name}{r.min_level ? ` (≥ ${r.min_level})` : ''}</span>{/if}
            <span>Openings: {r.headcount}</span>
          </div>
          <div style="margin-top:.6rem;"><button>I can help</button></div>
        </div>
      {/each}
    </div>
  {/if}
</div>
