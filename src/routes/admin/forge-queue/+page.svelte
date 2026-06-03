<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Review console.
  $effect(() => { goto('/admin/review?tab=forge', { replaceState: true }); });
</script>
<svelte:head><title>Review · The Fin AI</title></svelte:head>
