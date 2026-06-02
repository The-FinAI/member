<script lang="ts">
  import { page } from '$app/stores';
  import MemberDetail from '$lib/MemberDetail.svelte';

  const id = $derived($page.params.id);
</script>

<MemberDetail {id} />
