<script lang="ts">
  import ForgeQueue from '$lib/cards/ForgeQueue.svelte';
</script>

<svelte:head><title>Forge queue · The Fin AI</title></svelte:head>

<section class="wrap">
  <ForgeQueue />
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 880px; }
</style>
