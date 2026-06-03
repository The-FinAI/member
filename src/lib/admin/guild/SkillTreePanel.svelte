<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // The skill tree: top-level domains, each with certifiable leaf crafts. Leaves
  // are what badges certify and what needs filter on.
  type Skill = { id: string; parent_id: string | null; name: string };
  let skills = $state<Skill[]>([]);
  let loading = $state(true);
  let error = $state('');
  let newName = $state(''); let newParent = $state(''); let adding = $state(false);

  const roots = $derived(skills.filter((s) => !s.parent_id));
  const childrenOf = (id: string) => skills.filter((s) => s.parent_id === id);

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const { data, error: err } = await supabase.from('skill').select('id, parent_id, name').order('name');
    if (err) error = err.message;
    skills = (data as Skill[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function add() {
    error = '';
    if (!newName.trim()) return;
    adding = true;
    const { error: err } = await supabase.from('skill').insert({ name: newName.trim(), parent_id: newParent || null });
    adding = false;
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

<p class="muted blurb">{@html $t('Hierarchical skills. Leaves are the certifiable crafts in <a href="/community?tab=badges">the Guild</a>; needs and badges filter on these.')}</p>
{#if error}<p class="err">{error}</p>{/if}

<div class="card add">
  <input placeholder={$t('New skill name')} bind:value={newName} onkeydown={(e) => { if (e.key === 'Enter') add(); }} />
  <select bind:value={newParent}>
    <option value="">{$t('— top-level domain —')}</option>
    {#each roots as r (r.id)}<option value={r.id}>{r.name}</option>{/each}
  </select>
  <button class="go" onclick={add} disabled={adding}>{$t('Add skill')}</button>
</div>

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else if roots.length === 0}
  <p class="muted">{$t('No skills yet.')}</p>
{:else}
  <div class="tree">
    {#each roots as root (root.id)}
      <div class="domain">
        <div class="d-head">
          <span class="d-name">{root.name}</span>
          <span class="d-ct">{childrenOf(root.id).length}</span>
          <button class="x" onclick={() => remove(root.id)} aria-label={$t('Delete')}>✕</button>
        </div>
        <div class="leaves">
          {#each childrenOf(root.id) as c (c.id)}
            <span class="leaf">{c.name}<button class="lx" onclick={() => remove(c.id)} aria-label={$t('Delete')}>✕</button></span>
          {/each}
          {#if !childrenOf(root.id).length}<span class="muted none">{$t('No crafts yet')}</span>{/if}
        </div>
      </div>
    {/each}
  </div>
{/if}

<style>
  .blurb { margin: 0; font-size: .85rem; }
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .add { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
  .add input { flex: 1; min-width: 160px; }
  .go { padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; }
  .tree { display: flex; flex-direction: column; gap: .6rem; }
  .domain { border: 1px solid var(--border); border-radius: 11px; background: var(--card); padding: .7rem .9rem; }
  .d-head { display: flex; align-items: center; gap: .5rem; }
  .d-name { font-weight: 600; color: var(--text); }
  .d-ct { font-size: .72rem; color: var(--muted); background: var(--card-2); border-radius: 999px; padding: 0 .45rem; }
  .x { margin-left: auto; border: 0; background: transparent; color: var(--muted); cursor: pointer; font-size: .8rem; }
  .x:hover { color: var(--down); filter: none; }
  .leaves { display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .5rem; }
  .leaf { display: inline-flex; align-items: center; gap: .3rem; padding: .2rem .25rem .2rem .6rem; border: 1px solid var(--border-2); border-radius: 999px; background: var(--card-2); font-size: .82rem; color: var(--text); }
  .lx { border: 0; background: transparent; color: var(--muted); cursor: pointer; font-size: .72rem; padding: 0 .15rem; }
  .lx:hover { color: var(--down); filter: none; }
  .none { font-size: .8rem; }
</style>
