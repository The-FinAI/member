<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';

  // Members applying to join a chapter / working group. Admins (manage_members)
  // see every pending application; an officer sees applications to the units
  // they run. Approve / decline via decide_unit_member.
  type UnitApp = {
    org_unit_id: string; member_id: string; applied_on: string;
    member: { full_name: string; affiliation: string | null } | null;
    org_unit: { name: string; kind: string } | null;
  };

  const isAdmin = $derived($capabilities.has('manage_members'));
  const canReview = $derived(isAdmin || $officerUnits.length > 0);

  let apps = $state<UnitApp[]>([]);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; error = '';
    const officerIds = $officerUnits.map((u) => u.unit_id);
    if (!isAdmin && !officerIds.length) { apps = []; loading = false; return; }
    let q = supabase.from('org_unit_member')
      .select('org_unit_id, member_id, applied_on, member:member_id(full_name, affiliation), org_unit:org_unit_id(name, kind)')
      .eq('status', 'pending').order('applied_on');
    if (!isAdmin) q = q.in('org_unit_id', officerIds);
    const { data, error: err } = await q;
    if (err) error = err.message;
    apps = (data as UnitApp[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function decide(a: UnitApp, ok: boolean) {
    busy = a.member_id + a.org_unit_id; error = '';
    const { error: err } = await supabase.rpc('decide_unit_member', { p_unit: a.org_unit_id, p_member: a.member_id, p_approve: ok });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  function when(d: string) {
    if (!d) return '';
    return new Date(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
</script>

{#if error}<p class="err">{error}</p>{/if}
{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else if !canReview}
  <div class="card"><p class="muted">{$t('You don’t review any units.')}</p></div>
{:else if apps.length === 0}
  <div class="card empty"><p class="muted">{$t('Nothing pending. ✓')}</p></div>
{:else}
  <div class="list">
    {#each apps as a (a.member_id + a.org_unit_id)}
      <div class="app">
        <div class="app-main">
          <a class="app-name" href={`/members/${a.member_id}`}>{a.member?.full_name ?? '—'}</a>
          <span class="app-sub">
            {#if a.member?.affiliation}{a.member.affiliation} · {/if}
            {$t('applied to')} <strong>{a.org_unit?.name ?? '—'}</strong>{#if a.applied_on} · {when(a.applied_on)}{/if}
          </span>
        </div>
        <div class="app-act">
          <button class="btn" disabled={busy === a.member_id + a.org_unit_id} onclick={() => decide(a, true)}>{$t('Approve')}</button>
          <button class="btn ghost" disabled={busy === a.member_id + a.org_unit_id} onclick={() => decide(a, false)}>{$t('Decline')}</button>
        </div>
      </div>
    {/each}
  </div>
{/if}

<style>
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .empty { display: flex; justify-content: center; padding: 1.4rem; }
  .list { display: flex; flex-direction: column; gap: .5rem; }
  .app { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: 11px; background: var(--card); }
  .app-main { display: flex; flex-direction: column; gap: .15rem; min-width: 0; }
  .app-name { font-weight: 600; color: var(--text); text-decoration: none; }
  .app-name:hover { color: var(--accent); }
  .app-sub { font-size: .8rem; color: var(--muted); }
  .app-act { display: flex; gap: .4rem; flex: none; }
  .btn { padding: .4rem .8rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .btn:disabled { opacity: .55; cursor: not-allowed; }
  .btn.ghost { background: transparent; color: var(--text); border-color: var(--border-2); }
  .btn.ghost:hover { background: var(--card-2); }
</style>
