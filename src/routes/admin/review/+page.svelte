<script lang="ts">
  import UnitApplications from '$lib/admin/UnitApplications.svelte';
  import { t } from '$lib/i18n';
</script>

<svelte:head><title>Unit applications · The Fin AI</title></svelte:head>

<section class="wrap">
  <header>
    <h1>{$t('Unit applications')}</h1>
    <p class="muted sub">{$t('Members applying to join a chapter or working group. Officers review applications to the units they run.')}</p>
  </header>
  <UnitApplications />
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 820px; }
  .sub { margin-top: -.5rem; font-size: .88rem; }
</style>
