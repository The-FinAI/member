<script lang="ts">
  import { t } from '$lib/i18n';

  // A single click-to-edit field: shows a value (with a ✎ icon + double-click to
  // edit for permitted users) and swaps to an input / textarea / select in place.
  // Enter (or change, for selects) commits via onSave; Esc / blur-without-change
  // cancels. Stays open and shows an error if onSave throws.
  let {
    label, value = '', display = '', type = 'text', options = [],
    canEdit = false, placeholder = '', onSave
  }: {
    label: string;
    value?: string;
    display?: string;
    type?: 'text' | 'textarea' | 'select';
    options?: { value: string; label: string }[];
    canEdit?: boolean;
    placeholder?: string;
    onSave?: (v: string) => Promise<void> | void;
  } = $props();

  let editing = $state(false);
  let draft = $state('');
  let busy = $state(false);
  let err = $state('');
  let el = $state<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | null>(null);

  function start() {
    if (!canEdit || busy) return;
    draft = value; err = ''; editing = true;
    queueMicrotask(() => el?.focus());
  }
  async function commit() {
    if (!editing || busy) return;
    if (draft === value) { editing = false; return; }
    busy = true; err = '';
    try {
      await onSave?.(draft);
      editing = false;
    } catch (e: any) {
      err = e?.message ?? String(e);
    } finally {
      busy = false;
    }
  }
  function cancel() { editing = false; err = ''; }
  function onKey(e: KeyboardEvent) {
    if (e.key === 'Escape') { e.preventDefault(); cancel(); }
    else if (e.key === 'Enter' && type !== 'textarea') { e.preventDefault(); commit(); }
    else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); commit(); }
  }
</script>

<div class="if-row">
  <span class="if-label">{label}</span>

  {#if editing}
    <div class="if-edit-wrap">
      {#if type === 'select'}
        <select bind:this={el} bind:value={draft} disabled={busy} onchange={commit} onkeydown={onKey} onblur={cancel}>
          {#each options as o}<option value={o.value}>{o.label}</option>{/each}
        </select>
      {:else if type === 'textarea'}
        <textarea bind:this={el} bind:value={draft} rows="2" disabled={busy} {placeholder} onkeydown={onKey} onblur={commit}></textarea>
      {:else}
        <input bind:this={el} bind:value={draft} disabled={busy} {placeholder} onkeydown={onKey} onblur={commit} />
      {/if}
      {#if busy}<span class="spin"></span>{/if}
    </div>
    {#if err}<span class="if-err">{err}</span>{/if}
  {:else}
    {@const readText = display || (type === 'select' ? '' : value)}
    <span
      class="if-val"
      class:editable={canEdit}
      role={canEdit ? 'button' : undefined}
      tabindex={canEdit ? 0 : undefined}
      ondblclick={start}
      onkeydown={(e) => { if (canEdit && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); start(); } }}
    >
      <span class="if-text" class:muted={!readText}>{readText || '—'}</span>
      {#if canEdit}<button type="button" class="if-pen" onclick={start} title={$t('Edit')} aria-label={$t('Edit')}>✎</button>{/if}
    </span>
  {/if}
</div>

<style>
  .if-row { display: flex; flex-direction: column; gap: .2rem; }
  .if-label { font-size: .7rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .if-val { display: inline-flex; align-items: baseline; gap: .35rem; max-width: 100%; }
  .if-val.editable { cursor: text; border-radius: var(--r-sm); }
  .if-val.editable:hover .if-pen { opacity: 1; }
  .if-text { font-size: .9rem; color: var(--text); line-height: 1.4; word-break: break-word; }
  .if-text.muted { color: var(--muted); }
  .if-pen {
    flex: none; background: transparent; border: 0; color: var(--accent); cursor: pointer;
    font-size: .82rem; padding: 0 .15rem; opacity: 0; transition: opacity .12s;
  }
  .if-val.editable:focus-within .if-pen, .if-pen:focus { opacity: 1; }
  .if-edit-wrap { display: flex; align-items: center; gap: .4rem; }
  .if-edit-wrap input, .if-edit-wrap textarea, .if-edit-wrap select {
    flex: 1; min-width: 0; padding: .4rem .55rem; border-radius: var(--r-sm); border: 1px solid var(--accent);
    background: var(--card-2); color: var(--text); font-size: .9rem; font-family: inherit;
  }
  .if-err { font-size: .74rem; color: var(--down); }
</style>
