<script lang="ts">
  // R4 — the officer console is retired. Its jobs moved to the domain surfaces:
  // matching people → People, project ops → Projects. Redirect; nothing deleted.
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  onMount(() => goto('/people', { replaceState: true }));
</script>
<p style="padding:2rem; color:var(--muted);">Moved to <a href="/people">People</a> & <a href="/projects">Projects</a>…</p>
