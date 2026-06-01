<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';

  // Profile has been merged into the Portfolio hub at "/".
  onMount(() => { goto('/', { replaceState: true }); });
</script>

<div class="stack">
  <p class="muted">{$t('Loading…')} <a href="/">{$t('Portfolio')} →</a></p>
</div>
