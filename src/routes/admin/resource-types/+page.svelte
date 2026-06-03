<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <h1>{$t('Resource Types')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('Categories of resources members and the community can offer. The valuation method decides how a monthly quantity is priced in USD, then minted to nominal STR: gpu = TFLOPs × hours, api = $/1M-tokens, usd = dollars, flat = quantity × USD-per-unit.')}</p>
  <LookupEditor
    table="resource_type"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'valuation_method', label: 'Valuation', type: 'select', options: ['flat', 'usd', 'gpu', 'api'] },
      { key: 'unit', label: 'Unit' },
      { key: 'usd_per_unit', label: 'USD / unit', type: 'number' },
      { key: 'rank', label: 'Rank', type: 'number' },
      { key: 'description', label: 'Description' }
    ]}
  />
  <p class="muted" style="font-size:.8rem;">{@html $t('GPU and API models (with their built-in TFLOPs / token prices) are managed under <a href="/admin/resources">Community Resources</a>. <strong>USD / unit</strong> only applies to <em>flat</em> and is ignored for gpu / api / usd.')}</p>
</div>
