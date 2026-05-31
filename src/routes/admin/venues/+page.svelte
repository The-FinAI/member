<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Venues</h1>
  <p class="muted" style="margin-top:-.75rem;">Conferences &amp; journals projects target — each with its next submission deadline.</p>
  <LookupEditor
    table="venue"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'kind', label: 'Kind', type: 'select', options: ['conference', 'journal', 'workshop', 'rolling', 'other'] },
      { key: 'deadline', label: 'Deadline', type: 'date' },
      { key: 'url', label: 'URL' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'is_active', label: 'Active', type: 'bool' }
    ]}
  />
</div>
