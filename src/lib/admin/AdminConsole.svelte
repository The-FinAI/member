<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';
  import type { Snippet } from 'svelte';

  // Direction-C shell for an admin domain console: a title, a short blurb, and a
  // tab row. The active tab is kept in the URL (?tab=) so links can deep-link
  // and the back button works. Each tab's body is a snippet keyed by tab.key.
  let {
    title, blurb = '', tabs, children
  }: {
    title: string;
    blurb?: string;
    tabs: { key: string; label: string; count?: number }[];
    // children receives the active tab key; the console renders the matching panel
    children: Snippet<[string]>;
  } = $props();

  const active = $derived.by(() => {
    const q = $page.url.searchParams.get('tab');
    return tabs.some((t) => t.key === q) ? (q as string) : tabs[0]?.key;
  });
  function select(key: string) {
    const u = new URL($page.url);
    u.searchParams.set('tab', key);
    goto(u, { replaceState: false, keepFocus: true, noScroll: true });
  }
</script>

<div class="console">
  <header class="con-head">
    <h1>{$t(title)}</h1>
    {#if blurb}<p class="muted con-blurb">{$t(blurb)}</p>{/if}
  </header>

  <div class="tabs" role="tablist">
    {#each tabs as tb (tb.key)}
      <button type="button" class="tab" class:on={active === tb.key} role="tab" aria-selected={active === tb.key}
        onclick={() => select(tb.key)}>
        {$t(tb.label)}
        {#if tb.count}<span class="tab-count">{tb.count}</span>{/if}
      </button>
    {/each}
  </div>

  <div class="panel">
    {@render children(active)}
  </div>
</div>

<style>
  .console { display: flex; flex-direction: column; gap: 1rem; max-width: 940px; }
  .con-head h1 { margin: 0; font-size: 1.5rem; }
  .con-blurb { margin: .25rem 0 0; font-size: .88rem; }
  .tabs { display: flex; flex-wrap: wrap; gap: .3rem; border-bottom: 1px solid var(--border); padding-bottom: .1rem; }
  .tab {
    display: inline-flex; align-items: center; gap: .4rem; padding: .45rem .8rem;
    border: 0; border-bottom: 2px solid transparent; background: transparent;
    color: var(--muted); font: inherit; font-size: .9rem; cursor: pointer; border-radius: 6px 6px 0 0;
  }
  .tab:hover { color: var(--text); background: var(--card-2); }
  .tab.on { color: var(--text); border-bottom-color: var(--accent); font-weight: 600; }
  .tab-count {
    font-size: .72rem; font-weight: 700; font-variant-numeric: tabular-nums;
    background: var(--accent); color: #fff; border-radius: 999px; padding: 0 .4rem; min-width: 1.2rem; text-align: center;
  }
  .panel { display: flex; flex-direction: column; gap: 1rem; }
</style>
