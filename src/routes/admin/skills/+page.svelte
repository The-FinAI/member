<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Skill = { id: string; parent_id: string | null; name: string };

  let skills = $state<Skill[]>([]);
  let loading = $state(true);
  let error = $state('');
  let newName = $state('');
  let newParent = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const { data, error: err } = await supabase.from('skill').select('*').order('name');
    if (err) error = err.message;
    skills = (data as Skill[]) ?? [];
    loading = false;
  }

  onMount(load);

  const roots = $derived(skills.filter((s) => !s.parent_id));
  function childrenOf(id: string) {
    return skills.filter((s) => s.parent_id === id);
  }

  async function add() {
    error = '';
    if (!newName.trim()) return;
    const { error: err } = await supabase
      .from('skill')
      .insert({ name: newName.trim(), parent_id: newParent || null });
    if (err) { error = err.message; return; }
    newName = '';
    await load();
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from('skill').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Skill Tree</h1>
  <p class="muted" style="margin-top:-.75rem;">
    Hierarchical skills. Members self-rate (Beginner→Expert) and can be endorsed; needs filter on these.
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card row">
    <input placeholder="New skill name" bind:value={newName} />
    <select bind:value={newParent}>
      <option value="">— top-level category —</option>
      {#each roots as r}<option value={r.id}>{r.name}</option>{/each}
    </select>
    <button onclick={add}>Add skill</button>
  </div>

  <div class="card">
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if roots.length === 0}
      <p class="muted">No skills yet.</p>
    {:else}
      {#each roots as root}
        <div style="margin-bottom:1rem;">
          <div class="row" style="justify-content:space-between;">
            <strong>{root.name}</strong>
            <button class="danger" onclick={() => remove(root.id)}>Delete</button>
          </div>
          <ul style="margin:.4rem 0 0; padding-left:1.2rem;">
            {#each childrenOf(root.id) as child}
              <li class="row" style="justify-content:space-between; max-width:420px;">
                <span>{child.name}</span>
                <button class="danger" onclick={() => remove(child.id)}>Delete</button>
              </li>
            {/each}
          </ul>
        </div>
      {/each}
    {/if}
  </div>
</div>
