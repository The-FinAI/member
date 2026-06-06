<script lang="ts">
  // R4 — retired; matching now lives on People. Redirect.
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  onMount(() => goto('/people', { replaceState: true }));
</script>
<p style="padding:2rem; color:var(--muted);">Moved to <a href="/people">People</a>…</p>
