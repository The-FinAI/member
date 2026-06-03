<script lang="ts">
  import { goto } from '$app/navigation';
  // Folded into the Resources & economy console.
  $effect(() => { goto('/admin/economy?tab=types', { replaceState: true }); });
</script>
<svelte:head><title>Economy · Admin · The Fin AI</title></svelte:head>
