<script lang="ts">
  // Global confirm outlet — one per app, mounted in the layout. Renders the
  // pending confirm request (see lib/confirm.ts) as a modal gate. Enter confirms,
  // Esc / backdrop cancels. z above popovers, below toast.
  import { confirmRequest, resolveConfirm } from '$lib/confirm';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';

  function onKey(e: KeyboardEvent) {
    if (!$confirmRequest) return;
    if (e.key === 'Escape') { e.preventDefault(); resolveConfirm(false); }
    if (e.key === 'Enter') { e.preventDefault(); resolveConfirm(true); }
  }
</script>

<svelte:window on:keydown={onKey} />

{#if $confirmRequest}
  {@const r = $confirmRequest}
  <div class="cf-backdrop" role="presentation" onclick={() => resolveConfirm(false)}></div>
  <div class="cf-modal" role="alertdialog" aria-modal="true" aria-label={r.title}>
    <div class="cf-head">
      <span class="cf-mark" class:danger={r.tone === 'danger'}>
        <Icon name={r.tone === 'danger' ? 'warn' : 'info'} size={18} strokeWidth={1.8} />
      </span>
      <span class="cf-title">{r.title}</span>
    </div>
    {#if r.body}<p class="cf-body">{r.body}</p>{/if}
    <div class="cf-acts">
      <button class="cf-cancel" onclick={() => resolveConfirm(false)}>{r.cancelLabel ?? $t('Cancel')}</button>
      <button class="cf-ok" class:danger={r.tone === 'danger'} onclick={() => resolveConfirm(true)}>{r.confirmLabel ?? $t('Confirm')}</button>
    </div>
  </div>
{/if}

<style>
  .cf-backdrop {
    position: fixed; inset: 0; z-index: var(--z-backdrop);
    background: color-mix(in srgb, var(--rule-ink) 38%, transparent);
  }
  .cf-modal {
    position: fixed; left: 50%; top: 32%; transform: translate(-50%, -50%);
    z-index: var(--z-tooltip);
    width: min(30rem, 92vw);
    background: var(--elevate); color: var(--text);
    border: 1px solid var(--rule-ink); border-radius: var(--r-lg);
    box-shadow: var(--shadow-pop); padding: 1.1rem 1.2rem 1rem;
    animation: cfIn .14s ease-out both;
  }
  @keyframes cfIn { from { opacity: 0; transform: translate(-50%, calc(-50% + 6px)); } to { opacity: 1; transform: translate(-50%, -50%); } }
  .cf-head { display: flex; align-items: flex-start; gap: .6rem; }
  .cf-mark { color: var(--info); flex: none; margin-top: .05rem; }
  .cf-mark.danger { color: var(--down); }
  .cf-title { font-weight: 700; font-size: 1.02rem; line-height: 1.3; }
  .cf-body { margin: .55rem 0 0 2.05rem; color: var(--text-dim); font-size: .9rem; }
  .cf-acts { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.1rem; }
  .cf-cancel {
    background: transparent; border: 1px solid var(--border-2); color: var(--text);
    border-radius: var(--r-sm); padding: .4rem .9rem; font: inherit; font-weight: 600; cursor: pointer;
  }
  .cf-cancel:hover { background: var(--card); }
  .cf-ok {
    background: var(--accent); border: 1px solid transparent; color: #fff;
    border-radius: var(--r-sm); padding: .4rem 1rem; font: inherit; font-weight: 700; cursor: pointer;
  }
  .cf-ok:hover { filter: brightness(1.05); }
  .cf-ok.danger { background: var(--down); }
</style>
