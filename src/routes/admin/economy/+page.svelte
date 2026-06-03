<script lang="ts">
  import AdminConsole from '$lib/admin/AdminConsole.svelte';
  import StrEconomyPanel from '$lib/admin/economy/StrEconomyPanel.svelte';
  import CommunityResourcesPanel from '$lib/admin/economy/CommunityResourcesPanel.svelte';
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';

  const tabs = [
    { key: 'str', label: 'STR economy' },
    { key: 'resources', label: 'Community resources' },
    { key: 'types', label: 'Resource types' }
  ];
</script>

<svelte:head><title>Economy · Admin · The Fin AI</title></svelte:head>

<AdminConsole title="Resources & economy" blurb="The STR supply and its policy knobs, the resources the community owns, and the types those resources are valued as." {tabs}>
  {#snippet children(active)}
    {#if active === 'resources'}
      <CommunityResourcesPanel />
    {:else if active === 'types'}
      <p class="muted blurb">{@html $t('Categories of resources, and how a monthly quantity is priced into nominal STR: gpu = TFLOPs × hours, api = $/1M-tokens, usd = dollars, flat = quantity × USD-per-unit. <strong>USD / unit</strong> applies only to <em>flat</em>.')}</p>
      <LookupEditor table="resource_type" columns={[
        { key: 'name', label: 'Name' },
        { key: 'valuation_method', label: 'Valuation', type: 'select', options: ['flat', 'usd', 'gpu', 'api'] },
        { key: 'unit', label: 'Unit' },
        { key: 'usd_per_unit', label: 'USD / unit', type: 'number' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'description', label: 'Description' }
      ]} />
    {:else}
      <StrEconomyPanel />
    {/if}
  {/snippet}
</AdminConsole>

<style>.blurb { margin: 0 0 .2rem; font-size: .85rem; }</style>
