<script lang="ts">
  import { page } from '$app/stores';
  import { t } from '$lib/i18n';

  // Shared chrome for every admin page (Direction C): one consistent back link
  // to the admin hub. Individual pages no longer hand-roll their own.
  let { children } = $props();
  const isIndex = $derived($page.url.pathname.replace(/\/+$/, '') === '/admin');
</script>

<div class="admin-shell">
  {#if !isIndex}
    <a class="admin-back" href="/admin">← {$t('Admin')}</a>
  {/if}
  {@render children()}
</div>

<style>
  .admin-shell { display: flex; flex-direction: column; gap: .6rem; }
  .admin-back { align-self: flex-start; font-size: .82rem; color: var(--muted); text-decoration: none; }
  .admin-back:hover { color: var(--accent); }
</style>
