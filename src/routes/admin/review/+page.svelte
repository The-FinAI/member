<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import AdminConsole from '$lib/admin/AdminConsole.svelte';
  import ForgeQueue from '$lib/cards/ForgeQueue.svelte';
  import UnitApplications from '$lib/admin/UnitApplications.svelte';

  let forgeN = $state(0), unitN = $state(0);
  onMount(async () => {
    if (!supabaseConfigured) return;
    const c = (q: any) => q.select('id', { count: 'exact', head: true });
    const [fr, cm, st, ua] = await Promise.all([
      c(supabase.from('forge_request')).eq('status', 'submitted'),
      c(supabase.from('work_commitment')).eq('approval', 'needs_review'),
      c(supabase.from('stater_settlement')).in('status', ['submitted', 'under_review']),
      c(supabase.from('org_unit_member')).eq('status', 'pending')
    ]);
    forgeN = (fr.count ?? 0) + (cm.count ?? 0) + (st.count ?? 0);
    unitN = ua.count ?? 0;
  });
  const tabs = $derived([
    { key: 'forge', label: 'Forge queue', count: forgeN },
    { key: 'units', label: 'Unit applications', count: unitN }
  ]);
</script>

<svelte:head><title>Review · The Fin AI</title></svelte:head>

<AdminConsole title="Review queue" blurb="Everything waiting on a decision — forged credentials & contributions, and members joining a unit." {tabs}>
  {#snippet children(active)}
    {#if active === 'units'}
      <UnitApplications />
    {:else}
      <ForgeQueue />
    {/if}
  {/snippet}
</AdminConsole>
