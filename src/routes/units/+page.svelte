<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';
  // /units is now the Chapters tab of the unified Community surface.
  onMount(() => goto('/community?tab=chapters', { replaceState: true }));
</script>

<p class="muted">{$t('Loading…')} <a href="/community?tab=chapters">{$t('Community')} →</a></p>
