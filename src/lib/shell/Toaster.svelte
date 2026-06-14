<script lang="ts">
  // Global toast outlet — one per app, mounted in the layout. Renders write
  // feedback (success/error/info) with an optional Undo.
  import { toasts, dismiss, type Toast } from '$lib/toast';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';
  async function doUndo(x: Toast) { dismiss(x.id); await x.undo?.(); }
</script>

<div class="toaster" aria-live="polite">
  {#each $toasts as x (x.id)}
    <div class="toast {x.kind}" role="status">
      <span class="tk-mark"><Icon name={x.kind === 'success' ? 'check' : x.kind === 'error' ? 'close' : 'info'} size={15} strokeWidth={2} /></span>
      <span class="tk-text">{x.text}</span>
      {#if x.undo}<button class="tk-undo" onclick={() => doUndo(x)}>{$t('Undo')}</button>{/if}
      <button class="tk-x" aria-label={$t('Dismiss')} onclick={() => dismiss(x.id)}><Icon name="close" size={13} /></button>
    </div>
  {/each}
</div>

<style>
  .toaster {
    position: fixed; left: 50%; transform: translateX(-50%);
    bottom: 1.2rem; z-index: var(--z-toast);
    display: flex; flex-direction: column-reverse; gap: .5rem; width: max-content; max-width: 92vw;
    pointer-events: none;
  }
  .toast {
    pointer-events: auto;
    display: flex; align-items: center; gap: .6rem;
    background: var(--elevate); color: var(--text);
    border: 1px solid var(--rule-ink); border-left: 3px solid var(--text);
    border-radius: var(--r-md); padding: .55rem .7rem .55rem .75rem;
    box-shadow: var(--shadow-pop); font-size: .88rem;
    animation: toastIn .2s ease-out both;
  }
  @keyframes toastIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: none; } }
  .toast.success { border-left-color: var(--up); }
  .toast.error { border-left-color: var(--down); }
  .toast.info { border-left-color: var(--info); }
  .tk-mark { font-weight: 700; }
  .toast.success .tk-mark { color: var(--up); }
  .toast.error .tk-mark { color: var(--down); }
  .toast.info .tk-mark { color: var(--info); }
  .tk-text { font-weight: 500; }
  .tk-undo {
    background: transparent; border: 1px solid var(--border-2); color: var(--accent);
    border-radius: var(--r-sm); padding: .15rem .55rem; font-size: .8rem; font-weight: 700; cursor: pointer;
  }
  .tk-undo:hover { background: var(--accent-soft); border-color: var(--accent); }
  .tk-x {
    background: transparent; border: 0; color: var(--muted); cursor: pointer; font-size: .8rem;
    padding: 0 .15rem; line-height: 1;
  }
  .tk-x:hover { color: var(--text); }
</style>
