<script lang="ts">
  import { t } from '$lib/i18n';
  import type { Snippet } from 'svelte';

  // The universal card shell. Every entity in the product — a person, a project,
  // a resource, an admin config row — wears this same face: a type tag and a
  // status dot up top, a title + subtitle, an optional badge row, and a row of
  // key numbers at the foot. The whole card is one click → its edit drawer.
  let {
    type, title, subtitle = '', status = '', statusKind = 'dim',
    stats = [], onclick, badges, accent = false
  }: {
    type: string;
    title: string;
    subtitle?: string;
    status?: string;
    statusKind?: 'pos' | 'warn' | 'dim' | 'down';
    stats?: { label: string; value: string }[];
    onclick?: () => void;
    badges?: Snippet;
    accent?: boolean;
  } = $props();
</script>

<button class="ecard" class:accent {onclick} type="button">
  <div class="ec-top">
    <span class="ec-type">{$t(type)}</span>
    {#if status}<span class="ec-status {statusKind}">{$t(status)}</span>{/if}
  </div>
  <div class="ec-title">{title}</div>
  {#if subtitle}<div class="ec-sub">{subtitle}</div>{/if}
  {#if badges}<div class="ec-badges">{@render badges()}</div>{/if}
  {#if stats.length}
    <div class="ec-stats">
      {#each stats as s}
        <span class="ec-stat"><span class="ecs-v">{s.value}</span> <span class="ecs-l">{$t(s.label)}</span></span>
      {/each}
    </div>
  {/if}
</button>

<style>
  .ecard {
    display: flex; flex-direction: column; gap: .4rem; text-align: left;
    background: var(--card); border: 1px solid var(--border); border-radius: 12px;
    padding: .8rem .9rem; cursor: pointer; width: 100%;
    color: var(--text); font: inherit;
    transition: border-color .12s, box-shadow .12s, transform .12s;
  }
  .ecard:hover { border-color: var(--accent); box-shadow: 0 4px 16px -8px var(--accent); transform: translateY(-1px); }
  .ecard.accent { border-left: 3px solid var(--accent); }
  .ec-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
  .ec-type {
    font-family: var(--font-mono); font-size: .66rem; font-weight: 700;
    letter-spacing: .04em; text-transform: uppercase; color: var(--muted);
  }
  .ec-status {
    font-size: .66rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em;
    padding: .1rem .4rem; border-radius: 999px;
  }
  .ec-status.dim { color: var(--muted); background: var(--card-2); }
  .ec-status.pos { color: var(--up); background: color-mix(in srgb, var(--up) 14%, transparent); }
  .ec-status.warn { color: var(--accent); background: var(--accent-soft); }
  .ec-status.down { color: var(--down); background: color-mix(in srgb, var(--down) 14%, transparent); }
  .ec-title { font-weight: 700; font-size: 1rem; line-height: 1.2; color: var(--text); }
  .ec-sub { font-size: .8rem; color: var(--text-dim); margin-top: -.15rem; word-break: break-word; }
  .ec-badges { display: flex; flex-wrap: wrap; gap: .3rem; }
  .ec-stats {
    display: flex; flex-wrap: wrap; gap: .15rem 1rem; margin-top: auto;
    padding-top: .5rem; border-top: 1px solid var(--border);
  }
  .ec-stat { font-size: .78rem; }
  .ecs-v { font-family: var(--font-mono); font-weight: 700; }
  .ecs-l { color: var(--muted); font-size: .9em; }
</style>
