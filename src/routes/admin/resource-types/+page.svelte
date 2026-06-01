<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Resource Types')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('Categories of resources members and the community can offer. Unit + STR-per-unit set how a monthly quantity mints into a project pool (e.g. GPU-hour × 2 STR).')}</p>
  <LookupEditor
    table="resource_type"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'unit', label: 'Unit' },
      { key: 'str_per_unit', label: 'STR / unit', type: 'number' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'description', label: 'Description' }
    ]}
  />
</div>
