<script lang="ts">
  // Pinned, site-wide announcements. Rendered from the layout so they sit at the
  // top of every page. Rows come from the `announcement` table (admins curate
  // them at /admin/announcements). A member can collapse a notice for the
  // current visit (sessionStorage, keyed by row id + updated_at, so editing a
  // notice re-broadcasts it); it returns next visit.
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  type Notice = {
    id: string; title: string; body: string | null;
    href: string | null; cta_label: string | null; level: string;
    updated_at: string;
  };

  let notices = $state<Notice[]>([]);
  let dismissed = $state<Set<string>>(new Set());

  function keyOf(n: Notice) { return `ann_${n.id}_${n.updated_at}`; }

  onMount(async () => {
    if (!supabaseConfigured) return;
    const { data } = await supabase
      .from('announcement')
      .select('id, title, body, href, cta_label, level, updated_at')
      .eq('is_active', true).eq('pinned', true)
      .order('created_at', { ascending: false });
    notices = (data as Notice[]) ?? [];
    if (typeof window !== 'undefined') {
      const d = new Set<string>();
      for (const n of notices) if (window.sessionStorage.getItem(keyOf(n)) === '1') d.add(n.id);
      dismissed = d;
    }
  });

  function dismiss(n: Notice) {
    const d = new Set(dismissed); d.add(n.id); dismissed = d;
    if (typeof window !== 'undefined') window.sessionStorage.setItem(keyOf(n), '1');
  }
  function restore(n: Notice) {
    const d = new Set(dismissed); d.delete(n.id); dismissed = d;
    if (typeof window !== 'undefined') window.sessionStorage.removeItem(keyOf(n));
  }

  const visible = $derived(notices.filter((n) => !dismissed.has(n.id)));
  const hidden = $derived(notices.filter((n) => dismissed.has(n.id)));
</script>

{#each visible as n (n.id)}
  <div class="pin-bar lvl-{n.level}">
    <span class="pin-badge">{$t('Notice')}</span>
    <span class="pin-text">
      <strong>{n.title}</strong>
      {#if n.body}<span class="pin-sub">{n.body}</span>{/if}
    </span>
    {#if n.href}
      <span class="pin-actions">
        <a class="pin-btn" href={n.href}>{n.cta_label || $t('Open →')}</a>
      </span>
    {/if}
    <button class="pin-x" aria-label={$t('Dismiss')} title={$t('Hide for now')} onclick={() => dismiss(n)}>×</button>
  </div>
{/each}

{#if hidden.length}
  <div class="pin-tabs">
    {#each hidden as n (n.id)}
      <button class="pin-tab" onclick={() => restore(n)} title={$t('Show this notice')}>
        <span class="pin-dot">📣</span> {n.title}
      </button>
    {/each}
  </div>
{/if}

<style>
  .pin-bar {
    position: relative;
    display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;
    border: 1px solid var(--accent); border-left: 3px solid var(--accent);
    background: var(--accent-soft); border-radius: var(--r-md);
    padding: .55rem 2.3rem .55rem .9rem; margin-bottom: 1rem;
  }
  .pin-bar.lvl-success { border-color: var(--up, #2e9e5b); }
  .pin-bar.lvl-success { border-left-color: var(--up, #2e9e5b); }
  .pin-bar.lvl-warn { border-color: var(--warn, #c9851f); }
  .pin-bar.lvl-warn { border-left-color: var(--warn, #c9851f); }
  .pin-badge {
    font-family: var(--font-mono); font-size: .66rem; font-weight: 700;
    letter-spacing: .03em; text-transform: uppercase; color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent);
    padding: .2rem .5rem; border-radius: var(--r-sm); white-space: nowrap;
  }
  .pin-text { flex: 1; min-width: 220px; font-size: .9rem; line-height: 1.4; }
  .pin-text strong { font-weight: 600; }
  .pin-sub { color: var(--text-dim); margin-left: .4rem; }
  .pin-actions { display: flex; align-items: center; gap: .8rem; flex-wrap: wrap; }
  .pin-btn {
    display: inline-block; background: var(--accent); color: #fff;
    font-weight: 600; font-size: .82rem; padding: .35rem .8rem;
    border-radius: var(--r-sm); text-decoration: none; white-space: nowrap;
  }
  .pin-btn:hover { filter: brightness(1.08); }
  .pin-x {
    position: absolute; top: .4rem; right: .55rem;
    background: none; border: none; color: var(--muted);
    font-size: 1.15rem; line-height: 1; cursor: pointer; padding: .1rem .3rem;
  }
  .pin-x:hover { color: var(--text); }

  /* collapsed pills */
  .pin-tabs { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: 1rem; }
  .pin-tab {
    display: inline-flex; align-items: center; gap: .35rem;
    border: 1px solid var(--accent); background: var(--accent-soft);
    color: var(--accent); font-size: .76rem; font-weight: 600;
    padding: .25rem .65rem; border-radius: var(--r-full); cursor: pointer;
  }
  .pin-tab:hover { filter: brightness(1.05); }
  .pin-dot { font-size: .8rem; }
</style>
