<script lang="ts">
  import { goto } from '$app/navigation';
  // Unit applications now live at /admin/review.
  $effect(() => { goto('/admin/review', { replaceState: true }); });
</script>
<svelte:head><title>Unit applications · The Fin AI</title></svelte:head>
