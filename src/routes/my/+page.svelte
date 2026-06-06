<script lang="ts">
  // BUILD PLAN P1 — the My surface (personal). Tasks first; profile/skills and
  // the quiet wallet (P2/P4) become tabs here later.
  import MyTasks from '$lib/my/MyTasks.svelte';
  import Wallet from '$lib/my/Wallet.svelte';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
</script>

<svelte:head><title>{$t('My tasks')} · The Fin AI</title></svelte:head>

<section class="my">
  {#if $member}
    <Wallet />
    <MyTasks />
  {:else}
    <p class="my-dim">{$t('Sign in to see your tasks.')}</p>
  {/if}
</section>

<style>
  .my { padding: 1rem 0 3rem; }
  .my-dim { color: var(--muted, #888); }
</style>
