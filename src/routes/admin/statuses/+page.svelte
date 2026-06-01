<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Project Statuses')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('Workflow states. "Active" marks states still in flight.')}</p>
  <LookupEditor
    table="project_status"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'is_active', label: 'Active', type: 'bool' }
    ]}
  />
</div>
