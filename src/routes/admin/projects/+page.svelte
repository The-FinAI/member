<script lang="ts">
  import AdminConsole from '$lib/admin/AdminConsole.svelte';
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';

  const tabs = [
    { key: 'types', label: 'Types' },
    { key: 'statuses', label: 'Statuses' },
    { key: 'roles', label: 'Roles' },
    { key: 'venues', label: 'Venues' }
  ];
</script>

<svelte:head><title>Projects · Admin · The Fin AI</title></svelte:head>

<AdminConsole title="Projects" blurb="The shape of every project — its types, its workflow states, the roles members hold, and the venues it can target." {tabs}>
  {#snippet children(active)}
    {#if active === 'statuses'}
      <p class="muted blurb">{$t('Workflow states. “Active” marks states still in flight; Finished & Hold sit out of the active board.')}</p>
      <LookupEditor table="project_status" columns={[
        { key: 'name', label: 'Name' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'is_active', label: 'Active', type: 'bool' }
      ]} />
    {:else if active === 'roles'}
      <p class="muted blurb">{$t('Roles members hold within a project. “Can manage” grants edit rights on that project.')}</p>
      <LookupEditor table="project_role" orderBy="name" columns={[
        { key: 'name', label: 'Name' },
        { key: 'can_manage', label: 'Can manage', type: 'bool' }
      ]} />
    {:else if active === 'venues'}
      <p class="muted blurb">{@html $t('Conferences &amp; journals projects target — each with its next submission deadline.')}</p>
      <LookupEditor table="venue" columns={[
        { key: 'name', label: 'Name' },
        { key: 'kind', label: 'Kind', type: 'select', options: ['conference', 'journal', 'workshop', 'rolling', 'other'] },
        { key: 'deadline', label: 'Deadline', type: 'date' },
        { key: 'url', label: 'URL' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'is_active', label: 'Active', type: 'bool' }
      ]} />
    {:else}
      <p class="muted blurb">{$t('The kinds of project your community runs. Add, rename or reorder them here.')}</p>
      <LookupEditor table="project_type" columns={[
        { key: 'name', label: 'Name' },
        { key: 'rank', label: 'Rank', type: 'number' }
      ]} />
    {/if}
  {/snippet}
</AdminConsole>

<style>
  .blurb { margin: 0 0 .2rem; font-size: .85rem; }
</style>
