<script lang="ts">
  import { page } from '$app/stores';
  import MatchConsole from '$lib/cards/MatchConsole.svelte';
  import { t } from '$lib/i18n';

  // Unified officer console — one matching desk for both chapters and working
  // groups (MatchConsole adapts the supply/demand scope to the unit kind).
  const unitId = $derived($page.params.unitId);
</script>

<svelte:head><title>Officer console · The Fin AI</title></svelte:head>

<section class="wrap">
  <a href="/officer" class="back">← {$t('Officer console')}</a>
  <MatchConsole {unitId} />
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 920px; }
  .back { font-size: .8rem; color: var(--muted); text-decoration: none; }
  .back:hover { color: var(--text); }
</style>
