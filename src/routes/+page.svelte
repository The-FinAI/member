<script lang="ts">
  // The Project Ledger is the single landing surface — the old standalone Home
  // triage now rides atop /projects as <NeedsYou/>. Root redirects there so the
  // project list IS the home.
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  onMount(() => goto('/projects', { replaceState: true }));
</script>

<p class="muted" style="padding:1.5rem;">…</p>
