<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { get } from 'svelte/store';
  import { t } from '$lib/i18n';

  // Forge community-owned resources (compute / data / fund the community holds).
  // A resource needs an in-community holder (the steward). forge_resource routes
  // it through the forge queue.
  type ResType = { id: string; name: string; unit: string | null };
  type Member = { id: string; full_name: string };
  type Resrc = {
    id: string; name: string; monthly_quota: number; unit: string | null;
    resource_type: { name: string } | null; holder: { full_name: string } | null;
    forge_request: { status: string } | null;
  };

  let types = $state<ResType[]>([]);
  let members = $state<Member[]>([]);
  let resources = $state<Resrc[]>([]);
  let loading = $state(true); let error = $state(''); let ok = $state(''); let busy = $state(false);

  let fType = $state(''), fName = $state(''), fHolder = $state(''), fQuota = $state(0), fUnit = $state(''), fUsd = $state<number | null>(null);

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: rt }, { data: mem }, { data: rs }] = await Promise.all([
      supabase.from('resource_type').select('id, name, unit').order('rank'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('resource')
        .select('id, name, monthly_quota, unit, resource_type:type_id(name), holder:holder_member_id(full_name), forge_request:forge_request_id(status)')
        .eq('scope', 'community').order('created_at', { ascending: false })
    ]);
    types = (rt as ResType[]) ?? []; members = (mem as Member[]) ?? []; resources = (rs as Resrc[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function forge() {
    error = ''; ok = '';
    if (!fType || !fName.trim() || !fHolder) { error = get(t)('Type, name and holder are required.'); return; }
    busy = true;
    const { error: err } = await supabase.rpc('forge_resource', {
      p_type: fType, p_name: fName.trim(), p_holder: fHolder, p_scope: 'community',
      p_monthly_quota: Number(fQuota) || 0, p_unit: fUnit || null, p_usd_per_unit: fUsd
    });
    busy = false;
    if (err) { error = err.message; return; }
    ok = get(t)('Resource forged — pending review.'); fName = ''; fQuota = 0; fUnit = ''; fUsd = null;
    await load();
  }
</script>

<p class="muted blurb">{$t('Resources the community owns — compute, data, funding. Each needs an in-community holder (steward) and goes through the forge queue.')}</p>
{#if error}<p class="err">{error}</p>{/if}
{#if ok}<p class="ok">{ok}</p>{/if}

<div class="card forge-form">
  <label><span>{$t('Type')}</span><select bind:value={fType}><option value="">—</option>{#each types as ty (ty.id)}<option value={ty.id}>{ty.name}</option>{/each}</select></label>
  <label><span>{$t('Name')}</span><input bind:value={fName} /></label>
  <label><span>{$t('Holder (steward)')}</span><select bind:value={fHolder}><option value="">—</option>{#each members as m (m.id)}<option value={m.id}>{m.full_name}</option>{/each}</select></label>
  <label><span>{$t('Monthly quota')}</span><input type="number" step="any" bind:value={fQuota} style="max-width:7rem;" /></label>
  <label><span>{$t('Unit')}</span><input bind:value={fUnit} style="max-width:6rem;" /></label>
  <label><span>{$t('USD / unit')}</span><input type="number" step="any" bind:value={fUsd} style="max-width:6rem;" /></label>
  <button class="go" onclick={forge} disabled={busy}>{busy ? $t('Forging…') : $t('Forge resource')}</button>
</div>

<section>
  <span class="sec">{$t('Community resources')}{#if resources.length}<span class="ct"> · {resources.length}</span>{/if}</span>
  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if resources.length === 0}
    <p class="muted">{$t('None yet.')}</p>
  {:else}
    <div class="rlist">
      {#each resources as r (r.id)}
        <div class="r">
          <div class="r-main">
            <span class="r-name">{r.name}</span>
            <span class="r-sub">{r.resource_type?.name ?? '—'} · {r.holder?.full_name ?? '—'}</span>
          </div>
          <span class="r-quota mono">{r.monthly_quota?.toLocaleString()} {r.unit ?? ''}/mo</span>
          {#if r.forge_request?.status && r.forge_request.status !== 'approved'}<span class="badge dim">{$t(r.forge_request.status)}</span>{/if}
        </div>
      {/each}
    </div>
  {/if}
</section>

<style>
  .blurb { margin: 0; font-size: .85rem; }
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .ok { color: var(--up); font-size: .85rem; margin: 0; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .ct { color: var(--text-dim); }
  .forge-form { display: flex; flex-wrap: wrap; gap: .6rem; align-items: flex-end; }
  .forge-form label { display: flex; flex-direction: column; gap: .2rem; }
  .forge-form label span { font-size: .75rem; color: var(--muted); }
  .forge-form input, .forge-form select { padding: .4rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .85rem; }
  .go { padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; cursor: not-allowed; }
  .rlist { display: flex; flex-direction: column; gap: .4rem; margin-top: .4rem; }
  .r { display: flex; align-items: center; gap: .8rem; padding: .55rem .8rem; border: 1px solid var(--border); border-radius: 10px; background: var(--card); }
  .r-main { display: flex; flex-direction: column; gap: .1rem; flex: 1; min-width: 0; }
  .r-name { font-weight: 600; color: var(--text); }
  .r-sub { font-size: .78rem; color: var(--muted); }
  .r-quota { font-size: .82rem; color: var(--text-dim); white-space: nowrap; }
</style>
