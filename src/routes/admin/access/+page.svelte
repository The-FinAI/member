<script lang="ts">
  import AdminConsole from '$lib/admin/AdminConsole.svelte';
  import OfficersPanel from '$lib/admin/access/OfficersPanel.svelte';
  import PermissionsPanel from '$lib/admin/access/PermissionsPanel.svelte';
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';

  const tabs = [
    { key: 'officers', label: 'Officers' },
    { key: 'positions', label: 'Positions' },
    { key: 'permissions', label: 'Permissions' }
  ];
</script>

<svelte:head><title>Access · Admin · The Fin AI</title></svelte:head>

<AdminConsole title="Officers & access" blurb="Forge the officers who steward people and projects, give them positions, and decide what each position is allowed to do." {tabs}>
  {#snippet children(active)}
    {#if active === 'positions'}
      <p class="muted blurb">{$t('Community-level titles. Lower rank sorts first. A member’s authority comes from the capabilities granted to their positions.')}</p>
      <LookupEditor table="position" columns={[
        { key: 'name', label: 'Name' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'description', label: 'Description' }
      ]} />
    {:else if active === 'permissions'}
      <PermissionsPanel />
    {:else}
      <OfficersPanel />
    {/if}
  {/snippet}
</AdminConsole>

<style>.blurb { margin: 0 0 .2rem; font-size: .85rem; }</style>
