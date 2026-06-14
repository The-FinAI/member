<script lang="ts">
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';
  import type { Snippet } from 'svelte';

  // The universal edit surface. Click any EntityCard and its full detail +
  // editor slides in from the right. One drawer pattern for every entity, so
  // officers, members and admins all edit through the same motion.
  let {
    open = false, type = '', title = '', subtitle = '', onClose, children, actions
  }: {
    open?: boolean;
    type?: string;
    title?: string;
    subtitle?: string;
    onClose: () => void;
    children: Snippet;
    actions?: Snippet;
  } = $props();
</script>

{#if open}
  <div class="drawer-backdrop" onclick={onClose} role="presentation"></div>
  <div class="drawer" role="dialog" aria-modal="true">
    <header class="drawer-head">
      <div class="dh-text">
        {#if type}<span class="dh-type">{$t(type)}</span>{/if}
        <div class="dh-title">{title}</div>
        {#if subtitle}<div class="dh-sub">{subtitle}</div>{/if}
      </div>
      <button class="icon-btn" onclick={onClose} aria-label={$t('Close')}><Icon name="close" size={16} /></button>
    </header>
    <div class="drawer-body">{@render children()}</div>
    {#if actions}
      <footer class="drawer-foot">{@render actions()}</footer>
    {/if}
  </div>
{/if}

<style>
  .drawer-backdrop {
    position: fixed; inset: 0; background: rgba(0, 0, 0, .45);
    z-index: var(--z-backdrop); animation: fade .15s ease;
  }
  .drawer {
    position: fixed; top: 0; right: 0; bottom: 0; z-index: var(--z-popover);
    width: min(440px, 92vw); display: flex; flex-direction: column;
    background: var(--bg); border-left: 1px solid var(--border);
    box-shadow: -12px 0 40px -16px rgba(0, 0, 0, .5);
    animation: slide .18s cubic-bezier(.2, .7, .3, 1);
  }
  .drawer-head {
    display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
    padding: 1rem 1.1rem .8rem; border-bottom: 1px solid var(--border);
  }
  .dh-type {
    font-family: var(--font-mono); font-size: .66rem; font-weight: 700;
    letter-spacing: .04em; text-transform: uppercase; color: var(--accent);
  }
  .dh-title { font-weight: 700; font-size: 1.15rem; line-height: 1.2; }
  .dh-sub { font-size: .82rem; color: var(--text-dim); margin-top: .1rem; word-break: break-word; }
  .drawer-body { flex: 1; overflow-y: auto; padding: 1rem 1.1rem; display: flex; flex-direction: column; gap: 1rem; }
  .drawer-foot {
    padding: .8rem 1.1rem; border-top: 1px solid var(--border);
    display: flex; gap: .5rem; flex-wrap: wrap; align-items: center;
  }
  @keyframes fade { from { opacity: 0; } }
  @keyframes slide { from { transform: translateX(100%); } }
  @media (prefers-reduced-motion: reduce) {
    .drawer, .drawer-backdrop { animation: none; }
  }
</style>
