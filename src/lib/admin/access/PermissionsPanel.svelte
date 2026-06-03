<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // Authority injection (Phase-1 design §2): a member's authority is the union
  // of capabilities across their positions. Grant per position by toggling
  // capability chips — clearer than a wide checkbox grid.
  type Position = { id: string; name: string };
  type Capability = { key: string; description: string | null };

  let positions = $state<Position[]>([]);
  let caps = $state<Capability[]>([]);
  let grants = $state<Set<string>>(new Set());
  let loading = $state(true);
  let error = $state(''); let busy = $state<string | null>(null);
  let editing = $state(false);

  const cell = (pid: string, key: string) => `${pid}|${key}`;

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: p }, { data: c }, { data: pc }] = await Promise.all([
      supabase.from('position').select('id, name').order('rank'),
      supabase.from('capability').select('key, description').order('key'),
      supabase.from('position_capability').select('position_id, capability_key')
    ]);
    positions = (p as Position[]) ?? [];
    caps = (c as Capability[]) ?? [];
    grants = new Set(((pc as { position_id: string; capability_key: string }[]) ?? []).map((r) => cell(r.position_id, r.capability_key)));
    loading = false;
  }
  onMount(load);

  async function toggle(pid: string, key: string) {
    error = '';
    const k = cell(pid, key); busy = k;
    if (grants.has(k)) {
      const { error: err } = await supabase.from('position_capability').delete().eq('position_id', pid).eq('capability_key', key);
      if (err) { error = err.message; busy = null; return; }
      const next = new Set(grants); next.delete(k); grants = next;
    } else {
      const { error: err } = await supabase.from('position_capability').insert({ position_id: pid, capability_key: key });
      if (err) { error = err.message; busy = null; return; }
      grants = new Set([...grants, k]);
    }
    busy = null;
  }
  async function saveDesc(c: Capability) {
    error = '';
    const { error: err } = await supabase.from('capability').update({ description: c.description }).eq('key', c.key);
    if (err) error = err.message;
  }
</script>

<p class="muted blurb">{$t('A member’s authority is the union of capabilities across their positions. Toggle a chip to grant or revoke.')}</p>
{#if error}<p class="err">{error}</p>{/if}

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  <div class="grid">
    {#each positions as p (p.id)}
      <div class="pos">
        <div class="pos-head"><span class="pos-name">{p.name}</span></div>
        <div class="chips">
          {#each caps as c (c.key)}
            {@const on = grants.has(cell(p.id, c.key))}
            <button type="button" class="cap" class:on disabled={busy === cell(p.id, c.key)}
              title={c.description ?? ''} onclick={() => toggle(p.id, c.key)}>{c.key}</button>
          {/each}
        </div>
      </div>
    {/each}
  </div>

  <section class="gloss">
    <div class="gloss-head">
      <span class="sec">{$t('Capability glossary')}</span>
      <button type="button" class="link" onclick={() => (editing = !editing)}>{editing ? $t('Done') : $t('Edit descriptions')}</button>
    </div>
    <ul class="glist">
      {#each caps as c (c.key)}
        <li>
          <code>{c.key}</code>
          {#if editing}
            <input bind:value={c.description} onblur={() => saveDesc(c)} />
          {:else}
            <span class="cd">{c.description ?? '—'}</span>
          {/if}
        </li>
      {/each}
    </ul>
  </section>
{/if}

<style>
  .blurb { margin: 0; font-size: .85rem; }
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: .6rem; }
  .pos { border: 1px solid var(--border); border-radius: 11px; background: var(--card); padding: .7rem .85rem; display: flex; flex-direction: column; gap: .5rem; }
  .pos-name { font-weight: 600; color: var(--text); }
  .chips { display: flex; flex-wrap: wrap; gap: .35rem; }
  .cap {
    font-family: var(--mono, ui-monospace, monospace); font-size: .72rem; padding: .2rem .5rem;
    border: 1px solid var(--border-2); border-radius: 999px; background: var(--card-2); color: var(--muted);
    cursor: pointer; transition: all .1s;
  }
  .cap:hover { border-color: var(--accent); }
  .cap.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent); font-weight: 600; }
  .cap:disabled { opacity: .5; cursor: wait; }
  .gloss { display: flex; flex-direction: column; gap: .4rem; }
  .gloss-head { display: flex; align-items: center; justify-content: space-between; }
  .link { background: transparent; border: 0; color: var(--accent); font: inherit; font-size: .8rem; cursor: pointer; padding: 0; }
  .link:hover { text-decoration: underline; }
  .glist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }
  .glist li { display: grid; grid-template-columns: 12rem 1fr; gap: .6rem; align-items: center; font-size: .82rem; padding: .35rem .6rem; border: 1px solid var(--border); border-radius: 8px; background: var(--card); }
  .glist code { color: var(--accent); }
  .cd { color: var(--muted); }
  .glist input { padding: .3rem .5rem; border-radius: 6px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .82rem; }
</style>
