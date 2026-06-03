<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Access & permissions console.
  $effect(() => { goto('/admin/access?tab=officers', { replaceState: true }); });
</script>
<svelte:head><title>Access · Admin · The Fin AI</title></svelte:head>
