<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  type Position = { id: string; name: string };
  type Capability = { key: string; description: string | null };

  let positions = $state<Position[]>([]);
  let caps = $state<Capability[]>([]);
  let grants = $state<Set<string>>(new Set()); // `${position_id}|${capability_key}`
  let loading = $state(true);
  let error = $state('');
  let busy = $state<string | null>(null);

  const cellKey = (pid: string, key: string) => `${pid}|${key}`;

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
    grants = new Set(((pc as { position_id: string; capability_key: string }[]) ?? []).map((r) => cellKey(r.position_id, r.capability_key)));
    loading = false;
  }

  onMount(load);

  async function toggle(pid: string, key: string, on: boolean) {
    error = '';
    const k = cellKey(pid, key);
    busy = k;
    if (on) {
      const { error: err } = await supabase.from('position_capability').insert({ position_id: pid, capability_key: key });
      if (err) { error = err.message; busy = null; return; }
      grants = new Set([...grants, k]);
    } else {
      const { error: err } = await supabase
        .from('position_capability').delete().eq('position_id', pid).eq('capability_key', key);
      if (err) { error = err.message; busy = null; return; }
      const next = new Set(grants); next.delete(k); grants = next;
    }
    busy = null;
  }

  async function saveDesc(cap: Capability) {
    error = '';
    const { error: err } = await supabase.from('capability').update({ description: cap.description }).eq('key', cap.key);
    if (err) error = err.message;
  }
</script>

<div class="stack">
  <h1>{$t('Capabilities')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Grant capabilities to positions. A member gets the union of capabilities across their positions. Capability keys are referenced in code — descriptions are editable, keys are fixed.')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  {#if loading}
    <div class="card"><p class="muted">{$t('Loading…')}</p></div>
  {:else}
    <div class="card" style="overflow-x:auto;">
      <h2>{$t('Grant matrix')}</h2>
      <table>
        <thead>
          <tr>
            <th>{$t('Position')}</th>
            {#each caps as c}<th style="text-align:center;"><code>{c.key}</code></th>{/each}
          </tr>
        </thead>
        <tbody>
          {#each positions as p}
            <tr>
              <td><strong>{p.name}</strong></td>
              {#each caps as c}
                <td style="text-align:center;">
                  <input
                    type="checkbox"
                    checked={grants.has(cellKey(p.id, c.key))}
                    disabled={busy === cellKey(p.id, c.key)}
                    onchange={(e) => toggle(p.id, c.key, (e.target as HTMLInputElement).checked)}
                  />
                </td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>{$t('Capability descriptions')}</h2>
      <table>
        <thead><tr><th>{$t('Key')}</th><th>{$t('Description')}</th><th></th></tr></thead>
        <tbody>
          {#each caps as c}
            <tr>
              <td><code>{c.key}</code></td>
              <td><input bind:value={c.description} style="width:100%;" /></td>
              <td><button class="ghost" onclick={() => saveDesc(c)}>{$t('Save')}</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
