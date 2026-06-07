<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  type Col = { key: string; label: string; type?: 'text' | 'number' | 'bool' | 'date' | 'select'; options?: string[] };

  let {
    table,
    columns,
    orderBy = 'rank'
  }: { table: string; columns: Col[]; orderBy?: string } = $props();

  let rows = $state<Record<string, any>[]>([]);
  let loading = $state(true);
  let error = $state('');
  let draft = $state<Record<string, any>>({});

  function emptyDraft() {
    const d: Record<string, any> = {};
    for (const c of columns)
      d[c.key] = c.type === 'bool' ? false : c.type === 'number' ? 0
        : c.type === 'select' ? (c.options?.[0] ?? '') : null;
    return d;
  }

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const { data, error: err } = await supabase.from(table).select('*').order(orderBy);
    if (err) error = err.message;
    rows = data ?? [];
    loading = false;
  }

  onMount(() => {
    draft = emptyDraft();
    load();
  });

  async function add() {
    error = '';
    const { error: err } = await supabase.from(table).insert(draft);
    if (err) { error = err.message; return; }
    draft = emptyDraft();
    await load();
  }

  async function save(row: Record<string, any>) {
    error = '';
    const { id, ...rest } = row;
    const { error: err } = await supabase.from(table).update(rest).eq('id', id);
    if (err) error = err.message;
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from(table).delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="card stack">
  {#if error}<p style="color:var(--down);">{error}</p>{/if}
  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else}
    <div class="le-scroll">
    <table>
      <thead>
        <tr>{#each columns as c}<th>{$t(c.label)}</th>{/each}<th></th></tr>
      </thead>
      <tbody>
        {#each rows as row (row.id)}
          <tr>
            {#each columns as c}
              <td>
                {#if c.type === 'bool'}
                  <input type="checkbox" bind:checked={row[c.key]} />
                {:else if c.type === 'number'}
                  <input type="number" bind:value={row[c.key]} style="width:80px;" />
                {:else if c.type === 'date'}
                  <input type="date" bind:value={row[c.key]} />
                {:else if c.type === 'select'}
                  <select bind:value={row[c.key]}>{#each c.options ?? [] as o}<option value={o}>{$t(o)}</option>{/each}</select>
                {:else}
                  <input bind:value={row[c.key]} />
                {/if}
              </td>
            {/each}
            <td class="row">
              <button class="ghost" onclick={() => save(row)}>{$t('Save')}</button>
              <button class="danger" onclick={() => remove(row.id)}>{$t('Delete')}</button>
            </td>
          </tr>
        {/each}
        <tr>
          {#each columns as c}
            <td>
              {#if c.type === 'bool'}
                <input type="checkbox" bind:checked={draft[c.key]} />
              {:else if c.type === 'number'}
                <input type="number" bind:value={draft[c.key]} style="width:80px;" />
              {:else if c.type === 'date'}
                <input type="date" bind:value={draft[c.key]} />
              {:else if c.type === 'select'}
                <select bind:value={draft[c.key]}>{#each c.options ?? [] as o}<option value={o}>{$t(o)}</option>{/each}</select>
              {:else}
                <input placeholder={$t('new {label}', { label: $t(c.label).toLowerCase() })} bind:value={draft[c.key]} />
              {/if}
            </td>
          {/each}
          <td><button onclick={add}>{$t('Add')}</button></td>
        </tr>
      </tbody>
    </table>
    </div>
  {/if}
</div>

<style>
  /* keep wide config tables (e.g. Venues: name·kind·deadline·url·actions) from
     pushing the Save/Add buttons off-screen on narrow viewports */
  .le-scroll { overflow-x: auto; }
  .le-scroll table { min-width: max-content; }
</style>
