<script lang="ts">
  // Pinned, site-wide Phase-1 announcement. Rendered from the layout so it sits
  // at the top of every page. Stays pinned across navigation; a member can
  // collapse it for the current visit (sessionStorage), and it returns next visit.
  // Bump KEY to re-broadcast after a member has collapsed it.
  import { t } from '$lib/i18n';

  const KEY = 'phase1_pin_collapsed_v1';
  let collapsed = $state(false);

  $effect(() => {
    if (typeof window === 'undefined') return;
    collapsed = window.sessionStorage.getItem(KEY) === '1';
  });

  function setCollapsed(v: boolean) {
    collapsed = v;
    if (typeof window !== 'undefined') {
      if (v) window.sessionStorage.setItem(KEY, '1');
      else window.sessionStorage.removeItem(KEY);
    }
  }
</script>

{#if collapsed}
  <button class="pin-tab" onclick={() => setCollapsed(false)} title={$t('Show the Phase 1 notice')}>
    <span class="pin-dot">📣</span> {$t('Phase 1 · live now')}
  </button>
{:else}
  <div class="pin-bar">
    <span class="pin-badge">{$t('Phase 1 · live now')}</span>
    <span class="pin-text">
      <strong>{$t('The Guild is open — mint & claim your role cards')}</strong>
      <span class="pin-sub">{$t('Every Chapter and Working Group bootstraps the Guild first.')}</span>
    </span>
    <span class="pin-actions">
      <a class="pin-btn" href="/skills">{$t('Open the Guild →')}</a>
      <a class="pin-link" href="/guide#rollout">{$t('Details →')}</a>
    </span>
    <button class="pin-x" aria-label={$t('Dismiss')} title={$t('Hide for now')} onclick={() => setCollapsed(true)}>×</button>
  </div>
{/if}

<style>
  .pin-bar {
    position: relative;
    display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;
    border: 1px solid var(--accent); border-left: 3px solid var(--accent);
    background: var(--accent-soft); border-radius: 10px;
    padding: .55rem 2.3rem .55rem .9rem; margin-bottom: 1rem;
  }
  .pin-badge {
    font-family: var(--font-mono); font-size: .66rem; font-weight: 700;
    letter-spacing: .03em; text-transform: uppercase; color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
    padding: .2rem .5rem; border-radius: 6px; white-space: nowrap;
  }
  .pin-text { flex: 1; min-width: 220px; font-size: .9rem; line-height: 1.4; }
  .pin-text strong { font-weight: 600; }
  .pin-sub { color: var(--text-dim); }
  .pin-actions { display: flex; align-items: center; gap: .8rem; flex-wrap: wrap; }
  .pin-btn {
    display: inline-block; background: var(--accent); color: #fff;
    font-weight: 600; font-size: .82rem; padding: .35rem .8rem;
    border-radius: 8px; text-decoration: none; white-space: nowrap;
  }
  .pin-btn:hover { filter: brightness(1.08); }
  .pin-link { color: var(--accent); font-size: .82rem; text-decoration: none; white-space: nowrap; }
  .pin-link:hover { text-decoration: underline; }
  .pin-x {
    position: absolute; top: .4rem; right: .55rem;
    background: none; border: none; color: var(--muted);
    font-size: 1.15rem; line-height: 1; cursor: pointer; padding: .1rem .3rem;
  }
  .pin-x:hover { color: var(--text); }

  /* collapsed pill */
  .pin-tab {
    display: inline-flex; align-items: center; gap: .35rem;
    border: 1px solid var(--accent); background: var(--accent-soft);
    color: var(--accent); font-size: .76rem; font-weight: 600;
    padding: .25rem .65rem; border-radius: 999px; cursor: pointer;
    margin-bottom: 1rem;
  }
  .pin-tab:hover { filter: brightness(1.05); }
  .pin-dot { font-size: .8rem; }
</style>
