<script lang="ts">
  // Breadcrumb trail for detail pages. Pass the trail from root → current.
  // Items with an href render as links; the last item (or any without href)
  // renders as the current, non-clickable crumb. Labels are run through i18n,
  // so pass translation keys for fixed labels and raw strings for entity names
  // (unknown keys fall back to the string itself).
  import { t } from '$lib/i18n';

  let { items = [] }: { items: { label: string; href?: string }[] } = $props();
</script>

{#if items.length}
  <nav class="crumbs" aria-label="Breadcrumb">
    {#each items as it, i}
      {#if it.href && i < items.length - 1}
        <a href={it.href}>{$t(it.label)}</a>
        <span class="sep" aria-hidden="true">/</span>
      {:else}
        <span class="cur" aria-current="page">{$t(it.label)}</span>
      {/if}
    {/each}
  </nav>
{/if}

<style>
  .crumbs {
    display: flex; align-items: center; gap: .4rem; flex-wrap: wrap;
    font-size: .82rem; color: var(--muted); margin-bottom: .2rem;
  }
  .crumbs a { color: var(--muted); text-decoration: none; }
  .crumbs a:hover { color: var(--accent); }
  .crumbs .sep { color: var(--muted); opacity: .5; }
  .crumbs .cur { color: var(--text); font-weight: 600; max-width: 40ch; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
