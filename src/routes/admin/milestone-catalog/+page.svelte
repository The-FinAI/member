<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <h1>{$t('Milestone Catalog')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('The catalog of project achievements that can be claimed as milestones. Each entry adds its nominal value to the project pool and bumps the settlement multiplier when a reviewer verifies the claim.')}</p>
  <LookupEditor
    table="milestone_catalog"
    columns={[
      { key: 'category', label: 'Category' },
      { key: 'item', label: 'Item' },
      { key: 'nominal_value', label: 'Nominal STR', type: 'number' },
      { key: 'multiplier_bonus', label: 'Multiplier bonus', type: 'number' },
      { key: 'rank', label: 'Rank', type: 'number' }
    ]}
  />
  <p class="muted" style="font-size:.8rem;">{@html $t('Claimed milestones are reviewed under <a href="/admin/approvals">Approvals</a>. <strong>Nominal STR</strong> is added to the pool on verification; <strong>multiplier bonus</strong> is added to the project settlement multiplier.')}</p>
</div>
