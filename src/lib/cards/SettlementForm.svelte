<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // The settlement builder: split a finished project's pool into payout weights.
  // Weights default to each contributor's accumulated nominal_str (officer may
  // adjust). First author = the leader; corresponding author defaults to a
  // resource contributor (officer may adjust). Submitting is final.
  let { projectId, onSubmitted, onCancel }: {
    projectId: string;
    onSubmitted?: () => void;
    onCancel?: () => void;
  } = $props();

  type Row = {
    member_id: string; name: string; nominal: number;
    isLeader: boolean; isResource: boolean;
    weight: number; isAuthor: boolean;
  };

  let rows = $state<Row[]>([]);
  let corresponding = $state<string>('');   // member_id of corresponding author
  let notes = $state('');
  let loading = $state(true);
  let busy = $state(false); let err = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = '';
    const { data: wc } = await supabase.from('work_commitment')
      .select('member_id, nominal_str, slot:slot_id(slot_kind), member:member_id(full_name)')
      .eq('project_id', projectId);
    const agg: Record<string, Row> = {};
    for (const w of (wc as any[]) ?? []) {
      const id = w.member_id;
      const r = (agg[id] ??= { member_id: id, name: w.member?.full_name ?? '—', nominal: 0, isLeader: false, isResource: false, weight: 0, isAuthor: true });
      r.nominal += Number(w.nominal_str) || 0;
      if (w.slot?.slot_kind === 'leader') r.isLeader = true;
      if (w.slot?.slot_kind === 'work_resource') r.isResource = true;
    }
    // weight defaults to accumulated nominal; leader floats to the top, then by nominal
    const list = Object.values(agg).map((r) => ({ ...r, weight: r.nominal }));
    list.sort((a, b) => Number(b.isLeader) - Number(a.isLeader) || b.nominal - a.nominal);
    rows = list;
    // corresponding default: first resource contributor, else the last author
    corresponding = list.find((r) => r.isResource)?.member_id ?? list[list.length - 1]?.member_id ?? '';
    loading = false;
  }

  const totalWeight = $derived(rows.reduce((s, r) => s + (r.isAuthor ? Number(r.weight) || 0 : 0), 0));
  function pct(r: Row) {
    if (!r.isAuthor || totalWeight <= 0) return 0;
    return Math.round(((Number(r.weight) || 0) / totalWeight) * 1000) / 10;
  }
  // author order: authors only, leader first, then current display order
  function authorOrder(r: Row): number | null {
    if (!r.isAuthor) return null;
    return rows.filter((x) => x.isAuthor).indexOf(r) + 1;
  }

  async function submit() {
    const authors = rows.filter((r) => r.isAuthor);
    if (!authors.length) { err = get(t)('At least one author is required.'); return; }
    if (totalWeight <= 0) { err = get(t)('Total weight must be greater than zero.'); return; }
    busy = true; err = '';
    const items = rows.map((r) => ({
      member_id: r.member_id,
      role: r.isLeader ? 'Leader' : r.isResource ? 'Resource' : 'Contributor',
      final_payout_weight: Number(r.weight) || 0,
      is_author: r.isAuthor,
      author_order: authorOrder(r),
      is_corresponding: r.member_id === corresponding,
      notes: null
    }));
    const { error: e } = await supabase.rpc('submit_settlement', { p: projectId, notes: notes.trim() || null, items });
    busy = false;
    if (e) { err = e.message; return; }
    onSubmitted?.();
  }

  $effect(() => { if (projectId) load(); });
</script>

<div class="sf">
  <div class="sf-head">
    <span class="sf-title">💰 {$t('Settlement')}</span>
    <span class="sf-sub">{$t('Split the pool by payout weight. Submitting is final.')}</span>
  </div>

  {#if err}<p class="sf-err">{err}</p>{/if}

  {#if loading}
    <p class="sf-muted">{$t('Loading…')}</p>
  {:else if !rows.length}
    <p class="sf-muted">{$t('No seated contributors to settle.')}</p>
  {:else}
    <table class="sf-table">
      <thead>
        <tr>
          <th>{$t('Contributor')}</th>
          <th class="num">{$t('Nominal')}</th>
          <th class="num">{$t('Weight')}</th>
          <th class="num">{$t('Share')}</th>
          <th class="ctr">{$t('Author')}</th>
          <th class="ctr">{$t('Corresp.')}</th>
        </tr>
      </thead>
      <tbody>
        {#each rows as r (r.member_id)}
          <tr>
            <td>
              <span class="sf-name">{r.name}</span>
              {#if r.isLeader}<span class="badge warn sf-tag">{$t('first author')}</span>{/if}
              {#if r.isResource && !r.isLeader}<span class="badge pos sf-tag">{$t('Resource')}</span>{/if}
            </td>
            <td class="num mono dim">{r.nominal.toLocaleString()}</td>
            <td class="num"><input class="sf-w" type="number" min="0" step="any" bind:value={r.weight} /></td>
            <td class="num mono">{r.isAuthor ? pct(r) + '%' : '—'}</td>
            <td class="ctr">
              <input type="checkbox" bind:checked={r.isAuthor} disabled={r.isLeader} title={r.isLeader ? $t('The leader is always first author') : ''} />
              {#if r.isAuthor}<span class="sf-ord">#{authorOrder(r)}</span>{/if}
            </td>
            <td class="ctr"><input type="radio" name="corr" value={r.member_id} bind:group={corresponding} /></td>
          </tr>
        {/each}
      </tbody>
    </table>

    <label class="sf-field"><span>{$t('Settlement notes')} <span class="dim">{$t('(meeting decision, optional)')}</span></span>
      <textarea rows="2" bind:value={notes} placeholder={$t('How the split was agreed…')}></textarea></label>

    <div class="sf-actions">
      <button type="button" class="sf-go" disabled={busy} onclick={submit}>
        {#if busy}<span class="spin"></span>{/if}{$t('Submit settlement for review')}
      </button>
      <button type="button" class="sf-ghost" onclick={() => onCancel?.()}>{$t('Cancel')}</button>
    </div>
    <p class="sf-muted">{$t('Goes to the {h}h review window, then pays out STR.', { h: 72 })}</p>
  {/if}
</div>

<style>
  .sf { display: flex; flex-direction: column; gap: .7rem; padding: .8rem; border: 1px solid color-mix(in srgb, var(--up) 30%, transparent); border-radius: 12px; background: color-mix(in srgb, var(--up) 6%, transparent); }
  .sf-head { display: flex; flex-direction: column; gap: .15rem; }
  .sf-title { font-weight: 600; color: var(--text); }
  .sf-sub { font-size: .78rem; color: var(--muted); }
  .sf-err { font-size: .82rem; color: var(--down); margin: 0; }
  .sf-muted { font-size: .8rem; color: var(--muted); margin: 0; }
  .sf-table { width: 100%; border-collapse: collapse; font-size: .84rem; }
  .sf-table th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); padding: .3rem .4rem; border-bottom: 1px solid var(--border); }
  .sf-table td { padding: .35rem .4rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
  .sf-table .num { text-align: right; }
  .sf-table .ctr { text-align: center; }
  .sf-name { font-weight: 500; color: var(--text); }
  .sf-tag { margin-left: .35rem; font-size: .62rem; }
  .sf-w { width: 5rem; padding: .3rem .4rem; border-radius: 6px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .82rem; text-align: right; }
  .sf-ord { font-size: .72rem; color: var(--muted); margin-left: .2rem; }
  .sf-field { display: flex; flex-direction: column; gap: .25rem; font-size: .78rem; color: var(--muted); }
  .sf-field textarea { padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .88rem; font-family: inherit; }
  .sf-actions { display: flex; gap: .5rem; align-items: center; }
  .sf-go { display: inline-flex; align-items: center; gap: .4rem; padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent; background: var(--up); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .sf-go:disabled { opacity: .55; cursor: not-allowed; }
  .sf-ghost { padding: .5rem .9rem; border-radius: 8px; border: 1px solid var(--border); background: transparent; color: var(--text); font: inherit; cursor: pointer; }
</style>
