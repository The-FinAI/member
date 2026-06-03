<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';

  // Legacy route — the chapter binder + WG slot board are now one unified
  // matching console at /officer/[unitId]. Forward.
  const unitId = $derived($page.params.unitId);
  let last = '';
  $effect(() => { if (unitId && unitId !== last) { last = unitId; goto(`/officer/${unitId}`, { replaceState: true }); } });
</script>

<svelte:head><title>Officer console · The Fin AI</title></svelte:head>
<section class="redir"><div class="spin"></div></section>

<style>.redir { display: flex; justify-content: center; padding: 4rem 1rem; }</style>
