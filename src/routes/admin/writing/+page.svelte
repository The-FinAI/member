<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Laggard = {
    project_id: string;
    project_name: string;
    leader_id: string;
    leader_name: string;
    leader_email: string;
    year_month: string;
    hours: number;
    required: number;
  };

  let laggards = $state<Laggard[]>([]);
  let loading = $state(true);
  let error = $state('');
  let notice = $state('');
  let sending = $state(false);
  let picked = $state<Record<string, boolean>>({});

  const monthLabel = $derived(
    laggards[0]?.year_month
      ? (() => {
          const [y, m] = laggards[0].year_month.split('-').map(Number);
          return new Date(y, m - 1, 1).toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
        })()
      : new Date().toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
  );
  const selectedIds = $derived(
    [...new Set(laggards.filter((l) => picked[l.leader_id]).map((l) => l.leader_id))]
  );

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    error = '';
    const { data, error: err } = await supabase.rpc('writing_laggards');
    if (err) { error = err.message; loading = false; return; }
    laggards = (data as Laggard[]) ?? [];
    picked = {};
    loading = false;
  }

  onMount(load);

  async function remind(leader_ids: string[] | null) {
    error = ''; notice = '';
    sending = true;
    const { data, error: err } = await supabase.functions.invoke('notify-writing-laggards', {
      body: leader_ids && leader_ids.length ? { leader_ids } : {}
    });
    sending = false;
    if (err) { error = err.message; return; }
    if ((data as any)?.error) { error = (data as any).error; return; }
    const sent = (data as any)?.sent ?? 0;
    if ((data as any)?.email_error) { error = (data as any).email_error; return; }
    notice = get(t)('Reminder sent to {n} leader(s).', { n: sent });
  }
</script>

<div class="stack">
  <h1>{$t('First-author writing')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Project leaders owe {n}h of first-author writing every month. These leaders are short for {month} — remind them by email.', { n: 20, month: monthLabel })}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}
  {#if notice}<p style="color:var(--up);">{notice}</p>{/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if laggards.length === 0}
    <div class="card"><p class="muted" style="margin:0;">{$t('Everyone is on track this month. 🎉')}</p></div>
  {:else}
    <div class="row" style="gap:.6rem; flex-wrap:wrap;">
      <button onclick={() => remind(null)} disabled={sending}>
        {sending ? $t('Sending…') : $t('Remind all ({n})', { n: laggards.length })}
      </button>
      <button class="ghost" onclick={() => remind(selectedIds)} disabled={sending || selectedIds.length === 0}>
        {$t('Remind selected ({n})', { n: selectedIds.length })}
      </button>
    </div>
    <div class="card" style="padding:0; overflow:hidden;">
      <table>
        <thead>
          <tr>
            <th></th>
            <th>{$t('Leader')}</th>
            <th>{$t('Project')}</th>
            <th>{$t('Hours')}</th>
            <th>{$t('Required')}</th>
          </tr>
        </thead>
        <tbody>
          {#each laggards as l}
            <tr>
              <td><input type="checkbox" bind:checked={picked[l.leader_id]} /></td>
              <td><strong>{l.leader_name}</strong><div class="muted" style="font-size:.76rem;">{l.leader_email}</div></td>
              <td><a href={`/projects/${l.project_id}`}>{l.project_name}</a></td>
              <td class="mono"><span class="badge neg">{l.hours}h</span></td>
              <td class="mono">{l.required}h</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
