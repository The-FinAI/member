<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Announcement = {
    id: string; title: string; body: string | null; href: string | null;
    cta_label: string | null; level: string; pinned: boolean;
    is_active: boolean; created_at: string;
  };

  const LEVELS = ['info', 'success', 'warn'];

  let rows = $state<Announcement[]>([]);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  // new announcement form
  let title = $state('');
  let body = $state('');
  let href = $state('');
  let ctaLabel = $state('');
  let level = $state('info');
  let pinned = $state(true);

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const { data } = await supabase
      .from('announcement')
      .select('id, title, body, href, cta_label, level, pinned, is_active, created_at')
      .order('created_at', { ascending: false });
    rows = (data as Announcement[]) ?? [];
    loading = false;
  }

  onMount(load);

  async function add() {
    error = '';
    if (!title.trim()) { error = get(t)('A title is required.'); return; }
    const { error: err } = await supabase.from('announcement').insert({
      title: title.trim(), body: body.trim() || null,
      href: href.trim() || null, cta_label: ctaLabel.trim() || null,
      level, pinned, is_active: true,
      created_by: get(member)?.id ?? null
    });
    if (err) { error = err.message; return; }
    title = ''; body = ''; href = ''; ctaLabel = ''; level = 'info'; pinned = true;
    await load();
  }

  async function patch(id: string, fields: Partial<Announcement>) {
    error = ''; busy = id;
    const { error: err } = await supabase.from('announcement').update(fields).eq('id', id);
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }

  async function remove(id: string) {
    error = ''; busy = id;
    const { error: err } = await supabase.from('announcement').delete().eq('id', id);
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Announcements')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Pinned notices show in a banner at the top of every page. Retire one to take it off the banner while keeping it for the record.')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card stack">
    <h2>{$t('Post an announcement')}</h2>
    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Title')}</span>
      <input bind:value={title} placeholder={$t('e.g. Phase 1 is live')} /></label>
    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Body (optional)')}</span>
      <input bind:value={body} placeholder={$t('One short line of detail')} /></label>
    <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Link (optional)')}</span>
        <input bind:value={href} placeholder="/skills" style="width:180px;" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Button label')}</span>
        <input bind:value={ctaLabel} placeholder={$t('Open the Guild →')} style="width:180px;" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Level')}</span>
        <select bind:value={level}>{#each LEVELS as l}<option value={l}>{$t(l)}</option>{/each}</select></label>
      <label class="row" style="gap:.35rem; align-items:center;"><input type="checkbox" bind:checked={pinned} /> {$t('Pin to banner')}</label>
      <button onclick={add}>{$t('Post')}</button>
    </div>
  </div>

  <div class="card">
    <h2>{$t('All announcements')}</h2>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if rows.length === 0}
      <p class="muted">{$t('None yet.')}</p>
    {:else}
      <table>
        <thead><tr><th>{$t('Title')}</th><th>{$t('Level')}</th><th>{$t('Pinned')}</th><th>{$t('Status')}</th><th></th></tr></thead>
        <tbody>
          {#each rows as r}
            <tr style="opacity:{r.is_active ? 1 : 0.55};">
              <td>
                <strong>{r.title}</strong>
                {#if r.body}<div class="muted" style="font-size:.8rem;">{r.body}</div>{/if}
                {#if r.href}<div class="muted" style="font-size:.78rem;">→ <code>{r.href}</code>{r.cta_label ? ` · ${r.cta_label}` : ''}</div>{/if}
              </td>
              <td><span class="badge">{$t(r.level)}</span></td>
              <td>
                <button class="ghost" disabled={busy === r.id} onclick={() => patch(r.id, { pinned: !r.pinned })}>
                  {r.pinned ? $t('Pinned') : $t('Pin')}
                </button>
              </td>
              <td>
                {#if r.is_active}<span class="badge info">{$t('Active')}</span>
                {:else}<span class="badge dim">{$t('Retired')}</span>{/if}
              </td>
              <td class="row">
                {#if r.is_active}
                  <button disabled={busy === r.id} onclick={() => patch(r.id, { is_active: false, pinned: false })}>{$t('Retire')}</button>
                {:else}
                  <button disabled={busy === r.id} onclick={() => patch(r.id, { is_active: true })}>{$t('Restore')}</button>
                {/if}
                <button class="danger" disabled={busy === r.id} onclick={() => remove(r.id)}>{$t('Delete')}</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
