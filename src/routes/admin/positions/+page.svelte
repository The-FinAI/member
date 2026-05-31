<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Positions</h1>
  <p class="muted" style="margin-top:-.75rem;">Community-level titles. Lower rank sorts first.</p>
  <LookupEditor
    table="position"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'description', label: 'Description' }
    ]}
  />
  <p class="muted" style="font-size:.82rem;">Capability grants per position are edited next (position_capability).</p>
</div>
