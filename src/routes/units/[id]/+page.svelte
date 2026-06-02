<script lang="ts">
  import { page } from '$app/stores';
  import UnitDetail from '$lib/UnitDetail.svelte';

  const id = $derived($page.params.id);
</script>

<UnitDetail {id} />
