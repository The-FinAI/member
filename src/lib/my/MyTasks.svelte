<script lang="ts">
  // BUILD PLAN P1 — my cross-project worklist. Every task I own, across all
  // projects, in three lanes (Doing · Open · Done) + what changed this week.
  // Reads the P0 `task` table; the owner can flip a task's state in place
  // (optimistic) — the same DoD as the project board.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import { goto } from '$app/navigation';
  import Icon from '$lib/Icon.svelte';

  type Row = {
    id: string; project_id: string; name: string; state: string;
    note: string | null; updated_at: string;
    project: { name: string; emoji: string | null; code: string | null } | null;
  };

  let rows = $state<Row[]>([]);
  let loading = $state(true);
  let err = $state('');
  let busy = $state<string | null>(null);

  const LANES = [
    { key: 'doing', label: 'Doing', states: ['doing', 'checking'] },
    { key: 'open',  label: 'To do', states: ['open', 'potential'] },
    { key: 'done',  label: 'Done',  states: ['done', 'confirmed'] }
  ];
  const laneOf = (s: string) => LANES.find((l) => l.states.includes(s)) ?? LANES[1];
  const inLane = (k: string) => rows.filter((r) => laneOf(r.state).key === k);

  const WEEK = 7 * 24 * 3600 * 1000;
  const changedThisWeek = $derived(
    rows.filter((r) => r.updated_at && (Date.now() - new Date(r.updated_at).getTime()) < WEEK)
        .sort((a, b) => b.updated_at.localeCompare(a.updated_at))
  );

  const projLabel = (r: Row) =>
    `${r.project?.emoji ? r.project.emoji + ' ' : ''}${r.project?.code || r.project?.name || ''}`;

  async function load() {
    const me = $member?.id;
    if (!supabaseConfigured || !me) { loading = false; return; }
    loading = true; err = '';
    const { data, error } = await supabase
      .from('task')
      .select('id,project_id,name,state,note,updated_at,project:project_id(name,emoji,code)')
      .eq('owner_member_id', me);
    if (error) err = error.message;
    rows = (data as Row[]) ?? [];
    loading = false;
  }
  $effect(() => { $member; load(); });

  // advance/flip state in place (optimistic) — done ⇄ doing ⇄ open cycle
  async function setState(r: Row, state: string) {
    const before = r.state;
    r.state = state; rows = rows; busy = r.id; err = '';
    const { error } = await supabase.rpc('task_update', { p_task: r.id, p_patch: { state } });
    busy = null;
    if (error) { r.state = before; rows = rows; err = error.message; }
  }
</script>

<section class="mt">
  <div class="mt-head">
    <h2>{$t('My tasks')}</h2>
    {#if err}<span class="mt-err">{err}</span>{/if}
  </div>

  {#if loading}
    <p class="mt-dim">{$t('Loading…')}</p>
  {:else if !rows.length}
    <p class="mt-dim">{$t('No tasks assigned to you yet.')}</p>
  {:else}
    <div class="mt-lanes">
      {#each LANES as lane}
        {@const items = inLane(lane.key)}
        <div class="lane">
          <div class="lane-h">{$t(lane.label)} <span class="lane-n">{items.length}</span></div>
          {#each items as r (r.id)}
            <div class="card" class:busy={busy === r.id}>
              <button class="card-main" onclick={() => goto(`/projects/${r.project_id}`)} title={$t('Open project')}>
                <span class="card-proj">{projLabel(r)}</span>
                <span class="card-name">{r.name}</span>
                {#if r.note}<span class="card-note">{r.note}</span>{/if}
              </button>
              <div class="card-acts">
                {#if lane.key !== 'done'}
                  <button class="chip" onclick={() => setState(r, 'done')} title={$t('Mark done')}><Icon name="check" size={14} /></button>
                {/if}
                {#if lane.key === 'open'}
                  <button class="chip" onclick={() => setState(r, 'doing')} title={$t('Start')}><Icon name="play" size={13} /></button>
                {/if}
                {#if lane.key === 'done'}
                  <button class="chip" onclick={() => setState(r, 'open')} title={$t('Reopen')}><Icon name="undo" size={13} /></button>
                {/if}
              </div>
            </div>
          {/each}
          {#if !items.length}<p class="lane-empty">—</p>{/if}
        </div>
      {/each}
    </div>

    {#if changedThisWeek.length}
      <div class="mt-week">
        <div class="mt-week-h">{$t('Changed this week')}</div>
        {#each changedThisWeek.slice(0, 8) as r (r.id)}
          <a class="week-row" href={`/projects/${r.project_id}`}>
            <span class="wk-proj">{projLabel(r)}</span>
            <span class="wk-name">{r.name}</span>
            <span class="wk-state st-{r.state}">{$t(r.state)}</span>
          </a>
        {/each}
      </div>
    {/if}
  {/if}
</section>

<style>
  .mt { max-width: 1000px; }
  .mt-head { display: flex; align-items: baseline; gap: .75rem; }
  .mt-head h2 { margin: 0 0 .75rem; }
  .mt-err { color: var(--neg, var(--down)); font-size: .82rem; }
  .mt-dim { color: var(--muted, #888); }
  .mt-lanes { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
  .lane { background: var(--card-bg, #fafafa); border: 1px solid var(--line, #eee); border-radius: var(--r-md); padding: .6rem; }
  .lane-h { font-weight: 600; font-size: .85rem; color: var(--muted, #666); margin-bottom: .5rem; display: flex; gap: .4rem; align-items: center; }
  .lane-n { background: var(--line, #e8e8e8); border-radius: var(--r-full); padding: 0 .45rem; font-size: .72rem; }
  .lane-empty { color: var(--muted, #ccc); text-align: center; margin: .5rem 0; }
  .card { display: flex; gap: .4rem; background: var(--card, #fff); border: 1px solid var(--line, #eee); border-radius: var(--r-sm); padding: .45rem .55rem; margin-bottom: .45rem; align-items: flex-start; }
  .card.busy { opacity: .55; }
  .card-main { flex: 1; text-align: left; background: none; border: none; cursor: pointer; padding: 0; display: flex; flex-direction: column; gap: .1rem; color: inherit; }
  .card-proj { font-size: .72rem; color: var(--muted, #999); }
  .card-name { font-size: .9rem; }
  .card-note { font-size: .76rem; color: var(--muted, #aaa); }
  .card-acts { display: flex; gap: .2rem; }
  .chip { border: 1px solid var(--line, #ddd); background: none; border-radius: var(--r-sm); width: 1.5rem; height: 1.5rem; cursor: pointer; font-size: .8rem; line-height: 1; color: var(--muted, #888); }
  .chip:hover { border-color: var(--accent, var(--accent)); color: var(--accent, var(--accent)); }
  .mt-week { margin-top: 1.5rem; }
  .mt-week-h { font-weight: 600; font-size: .82rem; color: var(--muted, #777); margin-bottom: .4rem; }
  .week-row { display: flex; gap: .6rem; align-items: baseline; padding: .3rem .2rem; border-bottom: 1px solid var(--line, #f3f3f3); text-decoration: none; color: inherit; font-size: .85rem; }
  .wk-proj { color: var(--muted, #999); font-size: .76rem; min-width: 6rem; }
  .wk-name { flex: 1; }
  .wk-state { font-size: .74rem; color: var(--muted, #999); }
  .st-done, .st-confirmed { color: var(--up); }
  .st-doing, .st-checking { color: var(--warn); }
</style>
