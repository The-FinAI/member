<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <h1>{$t('Project Types')}</h1>
  <LookupEditor
    table="project_type"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'rank', label: 'Rank', type: 'number' }
    ]}
  />
</div>
