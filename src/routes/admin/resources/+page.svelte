<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Resources & economy console.
  $effect(() => { goto('/admin/economy?tab=resources', { replaceState: true }); });
</script>
<svelte:head><title>Economy · Admin · The Fin AI</title></svelte:head>
