<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Guild & skills console.
  $effect(() => { goto('/admin/guild?tab=skills', { replaceState: true }); });
</script>
<svelte:head><title>Guild · Admin · The Fin AI</title></svelte:head>
