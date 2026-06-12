<script lang="ts">
  import { t } from '$lib/i18n';

  export type MatchSlot = {
    id: string;
    project_id: string;
    project_name: string;
    slot_kind: 'leader' | 'work_labor' | 'work_resource';
    req_access: string | null;
    skill_id: string | null;
    skill_name: string | null;
    resource_type_id: string | null;
    resource_type_name: string | null;
    quota: number | null;
    headcount: number;
    filled: number;
    deadline?: string | null;
  };
  export type CardBadge = { skill_id: string; level: string };
  export type HeldResource = { id: string; name: string; type_id: string; unit: string | null };

  let {
    cardName = '',
    slots = [],
    badges = [],
    resources = [],
    busy = '',
    onSeat,
    onClose
  }: {
    cardName?: string;
    slots?: MatchSlot[];
    badges?: CardBadge[];
    resources?: HeldResource[];
    busy?: string;
    onSeat?: (slot: MatchSlot, resourceId: string | null, amount: number) => void;
    onClose?: () => void;
  } = $props();

  const RANK: Record<string, number> = { apprentice: 1, journeyman: 2, craftsman: 3, master: 4 };
  const rank = (l: string | null | undefined) => (l ? RANK[l] ?? 0 : 0);

  // qualification per slot: { ok, reason }
  function qualify(s: MatchSlot): { ok: boolean; reason: string } {
    if (s.filled >= s.headcount) return { ok: false, reason: $t('Filled') };
    if (s.req_access && s.skill_id) {
      const have = badges.find((b) => b.skill_id === s.skill_id);
      if (!have || rank(have.level) < rank(s.req_access)) {
        return { ok: false, reason: $t('Needs {lvl} badge', { lvl: $t(s.req_access) }) };
      }
    }
    if (s.slot_kind === 'work_resource' && s.resource_type_id) {
      const match = resources.find((r) => r.type_id === s.resource_type_id);
      if (!match) return { ok: false, reason: $t('No matching resource held') };
    }
    return { ok: true, reason: '' };
  }

  const decorated = $derived(
    slots
      .map((s) => ({ s, q: qualify(s), gap: Math.max(0, s.headcount - s.filled) }))
      .sort((a, b) => {
        if (a.q.ok !== b.q.ok) return a.q.ok ? -1 : 1; // qualified first
        return b.gap - a.gap; // then by urgency (gap)
      })
  );

  let openId = $state<string | null>(null);
  let amount = $state<number>(0);
  let resId = $state<string>('');

  function pick(d: { s: MatchSlot; q: { ok: boolean } }) {
    if (!d.q.ok) return;
    if (openId === d.s.id) { openId = null; return; }
    openId = d.s.id;
    amount = d.s.quota ?? 0;
    // default resource: a held resource matching the slot's resource_type
    const m = d.s.resource_type_id ? resources.find((r) => r.type_id === d.s.resource_type_id) : null;
    resId = m?.id ?? '';
  }

  function confirm(s: MatchSlot) {
    onSeat?.(s, resId || null, Number(amount) || 0);
  }

  function kindLabel(k: string) {
    return k === 'work_resource' ? $t('Resource need') : k === 'work_labor' ? $t('Labor need') : $t('Leader');
  }
</script>

<div class="matcher-backdrop" onclick={onClose} role="presentation"></div>
<aside class="matcher" role="dialog" aria-label={$t('Invest in project')}>
  <header class="m-head">
    <div>
      <div class="m-title">{$t('Invest in project')}</div>
      <div class="m-sub">{$t('Open slots {name} can fill', { name: cardName })}</div>
    </div>
    <button type="button" class="x" onclick={onClose} aria-label={$t('Close')}>✕</button>
  </header>

  <div class="m-list">
    {#if !decorated.length}
      <p class="m-empty">{$t('No open slots right now.')}</p>
    {/if}
    {#each decorated as d (d.s.id)}
      <div class="m-item">
        <button
          type="button"
          class="match-row"
          class:qualified={d.q.ok}
          class:blocked={!d.q.ok}
          disabled={!d.q.ok}
          onclick={() => pick(d)}
        >
          <span class="mr-main">
            <span class="mr-title">{d.s.project_name}</span>
            <span class="mr-sub">
              {kindLabel(d.s.slot_kind)}
              {#if d.s.skill_name}· {d.s.skill_name}{/if}
              {#if d.s.resource_type_name}· {d.s.resource_type_name}{/if}
              {#if d.s.req_access}· {$t('needs {lvl}', { lvl: $t(d.s.req_access) })}{/if}
              {#if !d.q.ok}· <span class="mr-reason">{d.q.reason}</span>{/if}
            </span>
          </span>
          <span class="mr-gap">{Math.max(0, d.s.headcount - d.s.filled)}/{d.s.headcount}</span>
        </button>

        {#if openId === d.s.id}
          <div class="m-form">
            <label class="m-field">
              <span>{$t('Monthly amount')}{#if d.s.quota}<span class="m-hint"> · {$t('need {q}', { q: d.s.quota })}</span>{/if}</span>
              <input type="number" min="0" step="any" bind:value={amount} />
            </label>
            {#if d.s.slot_kind === 'work_resource'}
              <label class="m-field">
                <span>{$t('Resource')}</span>
                <select bind:value={resId}>
                  <option value="">{$t('Select resource')}</option>
                  {#each resources.filter((r) => !d.s.resource_type_id || r.type_id === d.s.resource_type_id) as r (r.id)}
                    <option value={r.id}>{r.name}</option>
                  {/each}
                </select>
              </label>
            {/if}
            <button
              type="button"
              class="stake"
              disabled={busy === d.s.id || (d.s.slot_kind === 'work_resource' && !resId)}
              onclick={() => confirm(d.s)}
            >
              {#if busy === d.s.id}<span class="spin"></span>{/if}
              {$t('Seat')}
            </button>
          </div>
        {/if}
      </div>
    {/each}
  </div>
</aside>

<style>
  .matcher-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 80; animation: fadeIn .15s ease; }
  .matcher {
    position: fixed; top: 0; right: 0; bottom: 0; width: min(440px, 100vw); z-index: 90;
    background: var(--card); border-left: 1px solid var(--border-2); box-shadow: var(--shadow);
    display: flex; flex-direction: column; animation: fadeInUp .2s cubic-bezier(.21,.61,.35,1) both;
  }
  .m-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1rem 1.1rem; border-bottom: 1px solid var(--border); }
  .m-title { font-weight: 600; color: var(--text); }
  .m-sub { font-size: .78rem; color: var(--muted); margin-top: .15rem; }
  .x { background: transparent; border: 0; color: var(--muted); font-size: 1rem; cursor: pointer; padding: .2rem .4rem; }
  .x:hover { color: var(--text); filter: none; }
  .m-list { overflow-y: auto; padding: .8rem; display: flex; flex-direction: column; gap: .55rem; }
  .m-empty { font-size: .85rem; color: var(--muted); text-align: center; padding: 2rem 0; }
  .m-item { display: flex; flex-direction: column; gap: .5rem; }
  .mr-reason { color: var(--down); }
  .m-form { display: flex; flex-direction: column; gap: .55rem; padding: .2rem .2rem .4rem; }
  .m-field { display: flex; flex-direction: column; gap: .25rem; font-size: .78rem; color: var(--muted); }
  .m-hint { color: var(--info); }
  .m-field input, .m-field select {
    padding: .45rem .55rem; border-radius: var(--r-sm); border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem;
  }
</style>
