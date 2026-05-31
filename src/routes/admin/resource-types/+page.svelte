<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Resource Types</h1>
  <p class="muted" style="margin-top:-.75rem;">Categories of resources members and the community can offer.</p>
  <LookupEditor
    table="resource_type"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'description', label: 'Description' }
    ]}
  />
</div>
