<script lang="ts">
  import ForgeQueue from '$lib/cards/ForgeQueue.svelte';
  import { t } from '$lib/i18n';
  import { capabilities } from '$lib/session';

  // Admin-only: the forge queue is for capability-holding reviewers. Officers
  // forge & match; they don't see or approve the queue.
  const canReview = $derived(
    $capabilities.has('manage_stater') || $capabilities.has('edit_any_project') ||
    $capabilities.has('manage_resources') || $capabilities.has('review_skillcard') ||
    $capabilities.has('manage_members')
  );
</script>

<svelte:head><title>Forge queue · The Fin AI</title></svelte:head>

<section class="wrap">
  <header>
    <h1>{$t('Forge queue')}</h1>
    <p class="muted sub">{$t('Approve forged credentials & contributions — badges, member cards, needs, resources, over-capacity commitments & settlements.')}</p>
  </header>
  {#if canReview}
    <ForgeQueue />
  {:else}
    <p class="muted">{$t('The forge queue is for administrators with review authority.')}</p>
  {/if}
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 920px; }
  .sub { margin-top: -.5rem; font-size: .88rem; }
</style>
