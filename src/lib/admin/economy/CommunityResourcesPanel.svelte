<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { get } from 'svelte/store';
  import { member } from '$lib/session';
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
  let fSkills = $state<string[]>([]);
  let fLevel = $state('');
  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = { apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master' };
  let leaves = $state<{ id: string; name: string }[]>([]);
  let myBadges = $state<string[]>([]); // current user's badge skill_ids (for the self default)

  const skillName = (id: string) => leaves.find((s) => s.id === id)?.name ?? id;
  function toggleSkill(id: string) {
    fSkills = fSkills.includes(id) ? fSkills.filter((x) => x !== id) : [...fSkills, id];
  }
  // "self" = the current logged-in member; forging your own hours prefills your badges
  let lastHolder = '';
  $effect(() => {
    const me = get(member)?.id;
    if (fHolder && fHolder !== lastHolder) {
      lastHolder = fHolder;
      if (me && fHolder === me) fSkills = [...myBadges];
    }
  });

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const me = get(member)?.id ?? null;
    const [{ data: rt }, { data: mem }, { data: rs }, { data: sk }, { data: bg }] = await Promise.all([
      supabase.from('resource_type').select('id, name, unit').order('rank'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('resource')
        .select('id, name, monthly_quota, unit, resource_type:type_id(name), holder:holder_member_id(full_name), forge_request:forge_request_id(status)')
        .eq('scope', 'community').order('created_at', { ascending: false }),
      supabase.from('skill').select('id, parent_id, name').order('name'),
      me ? supabase.from('badge').select('skill_id').eq('member_id', me) : Promise.resolve({ data: [] as any[] })
    ]);
    types = (rt as ResType[]) ?? []; members = (mem as Member[]) ?? []; resources = (rs as Resrc[]) ?? [];
    const all = (sk as { id: string; parent_id: string | null; name: string }[]) ?? [];
    leaves = all.filter((s) => s.parent_id && !all.some((c) => c.parent_id === s.id)).map((s) => ({ id: s.id, name: s.name }));
    myBadges = ((bg as { skill_id: string }[]) ?? []).map((b) => b.skill_id);
    loading = false;
  }
  onMount(load);

  async function forge() {
    error = ''; ok = '';
    if (!fType || !fName.trim() || !fHolder) { error = get(t)('Type, name and holder are required.'); return; }
    busy = true;
    const { error: err } = await supabase.rpc('forge_resource', {
      p_type: fType, p_name: fName.trim(), p_holder: fHolder, p_scope: 'community',
      p_monthly_quota: Number(fQuota) || 0, p_unit: fUnit || null, p_usd_per_unit: fUsd,
      p_skills: fSkills, p_level: fLevel || null
    });
    busy = false;
    if (err) { error = err.message; return; }
    ok = get(t)('Resource forged — pending review.'); fName = ''; fQuota = 0; fUnit = ''; fUsd = null; fSkills = []; fLevel = ''; lastHolder = '';
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
  <div class="skills-row">
    <span class="skills-h">{$t('Skills these hours can fill')}<span class="muted"> · {$t('for stewarded labour; a holder = you defaults to your badges')}</span></span>
    <div class="skill-chips">
      {#each leaves as s (s.id)}
        <button type="button" class="skill" class:on={fSkills.includes(s.id)} onclick={() => toggleSkill(s.id)}>{s.name}</button>
      {/each}
      {#if !leaves.length}<span class="muted">{$t('No certifiable skills yet.')}</span>{/if}
    </div>
    <label class="lvl"><span>{$t('Expertise level')}<span class="muted"> · {$t('leave blank for your own hours (uses your badge level)')}</span></span>
      <select bind:value={fLevel}>
        <option value="">{$t('— from badge —')}</option>
        {#each LEVELS as l}<option value={l}>{$t(LEVEL_LABEL[l])}</option>{/each}
      </select>
    </label>
  </div>
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
  .skills-row { flex-basis: 100%; display: flex; flex-direction: column; gap: .35rem; }
  .skills-h { font-size: .75rem; color: var(--muted); }
  .skill-chips { display: flex; flex-wrap: wrap; gap: .3rem; }
  .skill { font-size: .78rem; padding: .2rem .55rem; border: 1px solid var(--border-2); border-radius: 999px; background: var(--card-2); color: var(--muted); cursor: pointer; }
  .skill:hover { border-color: var(--accent); }
  .skill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent); font-weight: 600; }
  .lvl { display: flex; flex-direction: column; gap: .2rem; }
  .lvl span { font-size: .75rem; color: var(--muted); }
  .lvl select { max-width: 14rem; padding: .4rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); }
  .go { padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; cursor: not-allowed; }
  .rlist { display: flex; flex-direction: column; gap: .4rem; margin-top: .4rem; }
  .r { display: flex; align-items: center; gap: .8rem; padding: .55rem .8rem; border: 1px solid var(--border); border-radius: 10px; background: var(--card); }
  .r-main { display: flex; flex-direction: column; gap: .1rem; flex: 1; min-width: 0; }
  .r-name { font-weight: 600; color: var(--text); }
  .r-sub { font-size: .78rem; color: var(--muted); }
  .r-quota { font-size: .82rem; color: var(--text-dim); white-space: nowrap; }
</style>
