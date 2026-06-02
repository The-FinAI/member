<script lang="ts">
  import { page } from '$app/stores';
  import ProjectDetail from '$lib/ProjectDetail.svelte';

  const id = $derived($page.params.id);
</script>

<ProjectDetail {id} />
