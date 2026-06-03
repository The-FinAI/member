<script lang="ts">
  import { page } from '$app/stores';
  import ProjectDetailBody from '$lib/cards/ProjectDetailBody.svelte';

  // Dedicated project page — renders the same rich body as the projects-grid
  // quick-view drawer, so WG / community drawers can link straight here.
  const id = $derived($page.params.id);
</script>

<svelte:head><title>Project · The Fin AI</title></svelte:head>

<section class="proj-page">
  <ProjectDetailBody projectId={id} showHeader={true} />
</section>

<style>
  .proj-page { max-width: 880px; margin: 0 auto; padding: 1.5rem 1rem 4rem; }
</style>
