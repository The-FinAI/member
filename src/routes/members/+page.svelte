<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';
  // /members is now the People tab of the unified Community surface.
  onMount(() => goto('/community', { replaceState: true }));
</script>

<p class="muted">{$t('Loading…')} <a href="/community">{$t('Community')} →</a></p>
