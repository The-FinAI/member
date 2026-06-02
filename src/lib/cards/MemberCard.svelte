<script lang="ts">
  import { t } from '$lib/i18n';
  import Medal from '$lib/Medal.svelte';
  import CommitChip from './CommitChip.svelte';

  export type CardBadge = { skill_id: string; skill_name: string; level: string };
  export type CardCommit = {
    id: string;
    slot_id: string | null;
    project_id: string;
    project_name: string;
    monthly_amount: number;
    unit: string;
    share: number;
    approval: string;
  };
  export type Person = {
    id: string; full_name: string; affiliation: string | null;
    email?: string | null; status?: string;
  };

  let {
    card,
    badges = [],
    commitments = [],
    capacity = { quota: null, used: 0, unit: 'h' },
    seatCount = 0,
    expanded = false,
    onToggle,
    onMatch,
    onEditCommit,
    onForgeBadge
  }: {
    card: Person;
    badges?: CardBadge[];
    commitments?: CardCommit[];
    capacity?: { quota: number | null; used: number; unit: string };
    seatCount?: number;
    expanded?: boolean;
    onToggle?: () => void;
    onMatch?: () => void;
    onEditCommit?: (c: CardCommit) => void;
    onForgeBadge?: () => void;
  } = $props();

  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2)
      .map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }

  const usedPct = $derived(
    capacity.quota && capacity.quota > 0
      ? Math.min(100, (capacity.used / capacity.quota) * 100)
      : 0
  );
  const over = $derived(!!capacity.quota && capacity.used > capacity.quota);
</script>

<div class="mcard" class:expanded>
  <button type="button" class="mc-head" onclick={onToggle}>
    <span class="mc-ava">{initials(card.full_name)}</span>
    <span class="mc-id">
      <span class="mc-name">{card.full_name}</span>
      {#if card.affiliation}<span class="mc-sub">{card.affiliation}</span>{/if}
    </span>
    <span class="mc-medals">
      {#each badges.slice(0, 3) as b (b.skill_id)}
        <Medal name={b.skill_name} level={b.level} size="sm" />
      {/each}
      {#if badges.length > 3}<span class="mc-more">+{badges.length - 3}</span>{/if}
    </span>
    <span class="mc-cap">
      {#if capacity.quota}
        <span class="mc-cap-num" class:over>
          {capacity.used}/{capacity.quota}{capacity.unit}
        </span>
        <span class="alloc mc-alloc"><i class={over ? 'bonded over' : 'bonded'} style="width:{usedPct}%"></i></span>
      {:else}
        <span class="mc-cap-num muted">{$t('no quota')}</span>
      {/if}
      <span class="mc-seats">{$t('{n} slots', { n: seatCount })}</span>
    </span>
  </button>

  {#if expanded}
    <div class="mc-body">
      <div class="mc-row">
        <span class="mc-label">{$t('Commitments this month')}</span>
        <button type="button" class="chip toggle" onclick={onMatch}>+ {$t('Invest in project')}</button>
      </div>
      {#if commitments.length}
        <div class="mc-commits">
          {#each commitments as c (c.id)}
            <CommitChip
              name={c.project_name}
              amount={c.monthly_amount}
              unit={c.unit}
              share={c.share}
              review={c.approval === 'needs_review'}
              onEdit={onEditCommit ? () => onEditCommit(c) : undefined}
            />
          {/each}
        </div>
      {:else}
        <p class="mc-empty">{$t('No commitments yet — invest this card into an open project slot.')}</p>
      {/if}

      <div class="mc-row mc-badgerow">
        <span class="mc-label">{$t('Badges')}</span>
        {#if onForgeBadge}
          <button type="button" class="chip toggle" onclick={onForgeBadge}>+ {$t('Forge badge')}</button>
        {/if}
      </div>
      {#if badges.length}
        <div class="mc-medals-full">
          {#each badges as b (b.skill_id)}
            <Medal name={b.skill_name} level={b.level} size="sm" />
          {/each}
        </div>
      {:else}
        <p class="mc-empty">{$t('No badges yet.')}</p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .mcard { border: 1px solid var(--border); border-radius: 12px; background: var(--card); overflow: hidden; }
  .mcard.expanded { border-color: var(--border-2); }
  .mc-head {
    display: grid; grid-template-columns: auto 1fr auto auto; gap: .8rem; align-items: center;
    width: 100%; text-align: left; padding: .7rem .85rem; background: transparent;
    border: 0; cursor: pointer;
  }
  .mc-head:hover { background: var(--card-2); }
  .mc-ava {
    width: 34px; height: 34px; border-radius: 50%; flex: none;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: .8rem; font-weight: 700; color: var(--accent-ink); background: var(--accent);
  }
  .mc-id { min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
  .mc-name { font-weight: 600; color: var(--text); font-size: .92rem; }
  .mc-sub { font-size: .74rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .mc-medals { display: inline-flex; gap: .3rem; align-items: center; }
  .mc-more { font-size: .72rem; color: var(--muted); }
  .mc-cap { display: flex; flex-direction: column; align-items: flex-end; gap: .15rem; min-width: 110px; }
  .mc-cap-num { font-family: var(--font-mono); font-size: .78rem; color: var(--info); font-variant-numeric: tabular-nums; }
  .mc-cap-num.over { color: var(--down); }
  .mc-cap-num.muted { color: var(--muted); }
  .mc-alloc { width: 100px; margin-top: 0; height: 6px; }
  .mc-alloc i.over { background: var(--down); }
  .mc-seats { font-size: .7rem; color: var(--muted); }
  .mc-body { padding: .2rem .85rem .9rem; border-top: 1px solid var(--border); }
  .mc-row { display: flex; align-items: center; justify-content: space-between; margin: .75rem 0 .5rem; }
  .mc-badgerow { margin-top: 1rem; }
  .mc-label { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .mc-commits { display: flex; flex-wrap: wrap; gap: .5rem; }
  .mc-medals-full { display: flex; flex-wrap: wrap; gap: .4rem; }
  .mc-empty { font-size: .82rem; color: var(--muted); margin: .2rem 0; }
  @media (max-width: 640px) {
    .mc-head { grid-template-columns: auto 1fr; }
    .mc-medals, .mc-cap { grid-column: 1 / -1; align-items: flex-start; }
    .mc-cap { flex-direction: row; gap: .6rem; align-items: center; }
    .mc-alloc { width: 80px; }
  }
</style>
