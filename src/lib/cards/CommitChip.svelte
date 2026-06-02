<script lang="ts">
  import { t } from '$lib/i18n';

  // A Work commitment shown as a chip: project · amount · share-of-quota bar · [edit].
  // `share` is the fraction (0..1) of the card's monthly_quota this commitment uses.
  let {
    name = '',
    amount,
    unit = 'h',
    share = 0,
    review = false,
    onEdit
  }: {
    name?: string;
    amount: number;
    unit?: string;
    share?: number;
    review?: boolean;
    onEdit?: () => void;
  } = $props();

  const pct = $derived(Math.max(0, Math.min(1, share)) * 100);
  const over = $derived(share > 1);
</script>

<span class="commit-chip" class:over class:review title={review ? $t('Over capacity — awaiting review') : name}>
  <span class="cc-main">
    <span class="cc-name">{name} · <span class="cc-amt">{amount}{unit}</span></span>
    <span class="cc-bar"><i style="width:{pct}%"></i></span>
  </span>
  {#if onEdit}
    <button type="button" class="cc-edit" onclick={onEdit}>{$t('Edit')}</button>
  {/if}
</span>
