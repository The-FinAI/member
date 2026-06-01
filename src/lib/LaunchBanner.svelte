<script lang="ts">
  // Dismissible Phase-1 launch announcement, shown on the dashboard.
  // Dismissal is remembered per-browser via localStorage (bump KEY to re-show).
  import { t } from '$lib/i18n';

  const KEY = 'phase1_launch_dismissed_v1';
  let show = $state(false);

  $effect(() => {
    if (typeof window === 'undefined') return;
    show = window.localStorage.getItem(KEY) !== '1';
  });

  function dismiss() {
    show = false;
    if (typeof window !== 'undefined') window.localStorage.setItem(KEY, '1');
  }
</script>

{#if show}
  <div class="launch-banner">
    <span class="lb-badge">{$t('Phase 1 · live now')}</span>
    <div class="lb-body">
      <strong>{$t('The Guild is open — mint & claim your role cards')}</strong>
      <span class="lb-sub">{$t('Phase 1: every Chapter and Working Group bootstraps the Guild. Officers mint cards onto members; you claim or request your own.')}</span>
    </div>
    <div class="lb-actions">
      <a class="lb-btn" href="/skills">{$t('Open the Guild →')}</a>
      <a class="lb-link" href="/guide#rollout">{$t('What is this? →')}</a>
    </div>
    <button class="lb-x" aria-label={$t('Dismiss')} onclick={dismiss}>×</button>
  </div>
{/if}

<style>
  .launch-banner {
    position: relative;
    display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;
    border: 1px solid var(--accent); border-left: 3px solid var(--accent);
    background: var(--accent-soft); border-radius: 12px;
    padding: .75rem 2.4rem .75rem 1rem;
  }
  .lb-badge {
    font-family: var(--font-mono); font-size: .68rem; font-weight: 700;
    letter-spacing: .03em; text-transform: uppercase; color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
    padding: .2rem .5rem; border-radius: 6px; white-space: nowrap;
  }
  .lb-body { display: flex; flex-direction: column; gap: .1rem; flex: 1; min-width: 220px; }
  .lb-body strong { font-size: .95rem; }
  .lb-sub { color: var(--text-dim); font-size: .82rem; line-height: 1.45; }
  .lb-actions { display: flex; align-items: center; gap: .8rem; flex-wrap: wrap; }
  .lb-btn {
    display: inline-block; background: var(--accent); color: #fff;
    font-weight: 600; font-size: .84rem; padding: .4rem .85rem;
    border-radius: 8px; text-decoration: none; white-space: nowrap;
  }
  .lb-btn:hover { filter: brightness(1.08); }
  .lb-link { color: var(--accent); font-size: .82rem; text-decoration: none; white-space: nowrap; }
  .lb-link:hover { text-decoration: underline; }
  .lb-x {
    position: absolute; top: .5rem; right: .6rem;
    background: none; border: none; color: var(--muted);
    font-size: 1.2rem; line-height: 1; cursor: pointer; padding: .1rem .3rem;
  }
  .lb-x:hover { color: var(--text); }
</style>
