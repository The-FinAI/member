<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';
  // The Task Market is now the "Open needs" view of the Projects surface.
  onMount(() => goto('/projects?tab=needs', { replaceState: true }));
</script>

<p class="muted">{$t('Loading…')} <a href="/projects?tab=needs">{$t('Open needs')} →</a></p>
