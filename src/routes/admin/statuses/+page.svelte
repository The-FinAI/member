<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Projects console.
  $effect(() => { goto('/admin/projects?tab=statuses', { replaceState: true }); });
</script>
<svelte:head><title>Projects · Admin · The Fin AI</title></svelte:head>
