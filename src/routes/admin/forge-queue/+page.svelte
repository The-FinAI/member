<script lang="ts">
  import ForgeQueue from '$lib/cards/ForgeQueue.svelte';
  import { t } from '$lib/i18n';
</script>

<svelte:head><title>Forge queue · The Fin AI</title></svelte:head>

<section class="wrap">
  <header>
    <h1>{$t('Forge queue')}</h1>
    <p class="muted sub">{$t('Approve forged credentials & contributions — badges, member cards, needs, resources, over-capacity commitments & settlements.')}</p>
  </header>
  <ForgeQueue />
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 920px; }
  .sub { margin-top: -.5rem; font-size: .88rem; }
</style>
