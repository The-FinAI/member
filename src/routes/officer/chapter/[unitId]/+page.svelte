<script lang="ts">
  import { page } from '$app/stores';
  import CardBinder from '$lib/cards/CardBinder.svelte';

  const unitId = $derived($page.params.unitId);
</script>

<svelte:head><title>Chapter binder · The Fin AI</title></svelte:head>

<section class="wrap">
  <a href="/officer" class="back">← Officer</a>
  <CardBinder {unitId} />
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 880px; }
  .back { font-size: .8rem; color: var(--muted); text-decoration: none; }
  .back:hover { color: var(--text); }
</style>
