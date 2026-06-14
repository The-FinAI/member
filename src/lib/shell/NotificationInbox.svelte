<script lang="ts">
  // BUILD PLAN P5 — the notification inbox (async spine). A bell with an unread
  // count; opens a dropdown of recent notifications; click marks read + follows
  // the link. Reads own notifications via RLS.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';
  import { goto } from '$app/navigation';

  type N = { id: string; kind: string; title: string; body: string | null; link: string | null; read_at: string | null; created_at: string };

  let items = $state<N[]>([]);
  let open = $state(false);
  const unread = $derived(items.filter((n) => !n.read_at).length);

  async function load() {
    const me = $member?.id;
    if (!supabaseConfigured || !me) { items = []; return; }
    const { data } = await supabase.from('notification')
      .select('id,kind,title,body,link,read_at,created_at')
      .order('created_at', { ascending: false }).limit(20);
    items = (data as N[]) ?? [];
  }
  $effect(() => { $member; load(); });

  async function openItem(n: N) {
    if (!n.read_at) {
      n.read_at = new Date().toISOString(); items = items;
      await supabase.rpc('notification_read', { p_id: n.id });
    }
    open = false;
    if (n.link) goto(n.link);
  }
  async function readAll() {
    for (const n of items) n.read_at ||= new Date().toISOString();
    items = items;
    await supabase.rpc('notification_read_all');
  }
  function rel(ts: string) {
    const d = (Date.now() - new Date(ts).getTime()) / 86400000;
    if (d < 1) return $t('today'); if (d < 2) return $t('yesterday');
    return Math.floor(d) + $t('d ago');
  }
</script>

{#if $member}
  <div class="ni">
    <button class="ni-bell" onclick={() => { open = !open; if (open) load(); }} aria-label={$t('Notifications')} title={$t('Notifications')}>
      <Icon name="bell" size={16} />{#if unread}<span class="ni-badge">{unread}</span>{/if}
    </button>
    {#if open}
      <button class="ni-backdrop" onclick={() => (open = false)} aria-label="close"></button>
      <div class="ni-pop">
        <div class="ni-head">
          <span>{$t('Notifications')}</span>
          {#if unread}<button class="ni-readall" onclick={readAll}>{$t('Mark all read')}</button>{/if}
        </div>
        {#if !items.length}
          <p class="ni-empty">{$t('Nothing yet.')}</p>
        {:else}
          {#each items as n (n.id)}
            <button class="ni-item" class:unread={!n.read_at} onclick={() => openItem(n)}>
              <span class="ni-title">{n.title}</span>
              {#if n.body}<span class="ni-body">{n.body}</span>{/if}
              <span class="ni-time">{rel(n.created_at)}</span>
            </button>
          {/each}
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  .ni { position: relative; margin: 0 .25rem; }
  .ni-bell { border: none; background: none; cursor: pointer; font-size: 1.05rem; position: relative; padding: .2rem; }
  .ni-badge { position: absolute; top: -.2rem; right: -.3rem; background: var(--down); color: #fff; font-size: .62rem; border-radius: var(--r-full); padding: 0 .3rem; min-width: 1rem; }
  .ni-backdrop { position: fixed; inset: 0; background: none; border: none; z-index: var(--z-backdrop); }
  .ni-pop { position: absolute; right: 0; top: 2rem; width: 22rem; max-width: 90vw; background: var(--card, #fff); border: 1px solid var(--line, #e2e2e2); border-radius: var(--r-md); box-shadow: 0 8px 28px rgba(0,0,0,.12); z-index: var(--z-popover); max-height: 70vh; overflow: auto; }
  .ni-head { display: flex; justify-content: space-between; align-items: center; padding: .55rem .7rem; border-bottom: 1px solid var(--line, #f0f0f0); font-weight: 600; font-size: .85rem; }
  .ni-readall { border: none; background: none; color: var(--accent, var(--accent)); cursor: pointer; font-size: .78rem; }
  .ni-empty { padding: 1rem .7rem; color: var(--muted, #999); font-size: .85rem; }
  .ni-item { display: flex; flex-direction: column; gap: .12rem; width: 100%; text-align: left; background: none; border: none; border-bottom: 1px solid var(--line, #f5f5f5); padding: .5rem .7rem; cursor: pointer; }
  .ni-item:hover { background: var(--card-bg, #fafafa); }
  .ni-item.unread { background: color-mix(in srgb, var(--accent, var(--accent)) 7%, transparent); }
  .ni-title { font-size: .86rem; font-weight: 500; }
  .ni-body { font-size: .78rem; color: var(--text, #555); }
  .ni-time { font-size: .72rem; color: var(--muted, #aaa); }
</style>
