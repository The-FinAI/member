<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Positions')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('Community-level titles. Lower rank sorts first.')}</p>
  <LookupEditor
    table="position"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'description', label: 'Description' }
    ]}
  />
  <p class="muted" style="font-size:.82rem;">{@html $t('Grant capabilities to each position in <a href="/admin/capabilities">Capabilities</a>.')}</p>
</div>
