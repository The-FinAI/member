<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { get } from 'svelte/store';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import SkillLevelPicker from '$lib/admin/economy/SkillLevelPicker.svelte';

  // Shared resource-forge form — the ONE place a member/community resource is
  // declared. Type-adaptive by valuation_method: gpu → GPU model + GPU-hours;
  // api → API model + 1M tokens; usd → dollars; flat non-labour → USD/unit
  // override; a labour type (flat · hour) → per-skill level picker. Always goes
  // through forge_resource (→ review queue). Used by the member profile and the
  // community resources console.
  // mode 'supply' → forge a resource someone HOLDS (forge_resource).
  // mode 'need'   → post a project NEED for that same kind of resource/skill
  //                 (forge_need). Same type-adaptive shape, so supply and demand
  //                 are declared in one vocabulary.
  let { holder = $bindable(''), scope = 'member', holderPicker = false, members = [],
        mode = 'supply', project = '', editId = '', onForged }:
    { holder?: string; scope?: 'member' | 'community'; holderPicker?: boolean;
      members?: { id: string; full_name: string }[];
      mode?: 'supply' | 'need'; project?: string; editId?: string; onForged?: () => void } = $props();

  type ResType = { id: string; name: string; unit: string | null; valuation_method: string; usd_per_unit: number | null; described: boolean };
  type Gpu = { id: string; name: string; tflops: number };
  type Api = { id: string; provider: string; name: string; usd_per_million: number };

  let types = $state<ResType[]>([]);
  let gpus = $state<Gpu[]>([]);
  let apis = $state<Api[]>([]);
  let myBadges = $state<Record<string, string>>({});
  let error = $state(''); let ok = $state(''); let busy = $state(false);

  let fType = $state(''), fName = $state(''), fQuota = $state(0);
  let fUsd = $state<number | null>(null), fGpu = $state(''), fApi = $state('');
  let fSkillLevels = $state<Record<string, string>>({});
  let fHeadcount = $state(1); let fDetails = $state('');

  const selType = $derived(types.find((x) => x.id === fType) ?? null);
  const meth = $derived(selType?.valuation_method ?? '');
  const isLabour = $derived(meth === 'flat' && (selType?.unit ?? '') === 'hour');
  const isDescribed = $derived(!!selType?.described);
  const quotaUnit = $derived(
    meth === 'gpu' ? get(t)('GPU-hours') : meth === 'api' ? get(t)('1M tokens') :
    meth === 'usd' ? get(t)('USD') : (selType?.unit ?? get(t)('units'))
  );

  // prefill skills from the holder's badges when they are the current user
  let lastHolder = '';
  $effect(() => {
    const me = get(member)?.id;
    if (holder && holder !== lastHolder) {
      lastHolder = holder;
      if (me && holder === me) fSkillLevels = { ...myBadges };
    }
  });

  async function load() {
    if (!supabaseConfigured) return;
    const me = get(member)?.id ?? null;
    const [{ data: rt }, { data: gp }, { data: ap }, { data: bg }] = await Promise.all([
      supabase.from('resource_type').select('id, name, unit, valuation_method, usd_per_unit, described').order('rank'),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank'),
      me ? supabase.from('badge').select('skill_id, level').eq('member_id', me) : Promise.resolve({ data: [] as any[] })
    ]);
    types = (rt as ResType[]) ?? []; gpus = (gp as Gpu[]) ?? []; apis = (ap as Api[]) ?? [];
    const bmap: Record<string, string> = {};
    for (const b of (bg as { skill_id: string; level: string }[]) ?? []) bmap[b.skill_id] = b.level;
    myBadges = bmap;
  }
  onMount(load);

  // edit mode: prefill the form from an existing resource
  let lastEdit = '';
  $effect(() => {
    if (editId && editId !== lastEdit) { lastEdit = editId; loadForEdit(editId); }
    else if (!editId && lastEdit) { lastEdit = ''; reset(); fType = ''; }
  });
  async function loadForEdit(rid: string) {
    const { data } = await supabase.from('resource')
      .select('type_id, name, monthly_quota, usd_per_unit, skills, gpu_model_id, api_model_id, details')
      .eq('id', rid).maybeSingle();
    if (!data) return;
    const d = data as any;
    fType = d.type_id ?? ''; fName = d.name ?? ''; fQuota = d.monthly_quota ?? 0;
    fUsd = d.usd_per_unit; fGpu = d.gpu_model_id ?? ''; fApi = d.api_model_id ?? ''; fDetails = d.details ?? '';
    const sl: Record<string, string> = {};
    for (const x of (d.skills ?? []) as { skill_id: string; level: string }[]) sl[x.skill_id] = x.level;
    fSkillLevels = sl;
  }

  function reset() { fName = ''; fQuota = 0; fUsd = null; fGpu = ''; fApi = ''; fSkillLevels = {}; fHeadcount = 1; fDetails = ''; lastHolder = ''; }

  async function postNeed() {
    error = ''; ok = '';
    if (!fType) { error = get(t)('Pick a type.'); return; }
    const reqs = isLabour
      ? Object.entries(fSkillLevels).map(([skill_id, level]) => ({ skill_id, min_level: level }))
      : [];
    if (isLabour && reqs.length === 0) { error = get(t)('Pick at least one skill.'); return; }
    busy = true;
    const { error: err } = await supabase.rpc('forge_need', {
      p_project: project,
      p_slot_kind: isLabour ? 'work_labor' : 'work_resource',
      p_req_access: isLabour ? (reqs[0]?.min_level ?? null) : null,
      p_skill: isLabour ? (reqs[0]?.skill_id ?? null) : null,
      p_resource_type: isLabour ? null : fType,
      p_quota: Number(fQuota) || null,
      p_headcount: Number(fHeadcount) || 1,
      p_requirements: reqs
    });
    busy = false;
    if (err) { error = err.message; return; }
    ok = get(t)('Need submitted for review.'); reset();
    onForged?.();
  }

  async function forge() {
    if (mode === 'need') { await postNeed(); return; }
    error = ''; ok = '';
    if (!fType || !fName.trim() || (!editId && !holder)) { error = get(t)('Type, name and holder are required.'); return; }
    if (meth === 'gpu' && !fGpu) { error = get(t)('Pick a GPU model.'); return; }
    if (meth === 'api' && !fApi) { error = get(t)('Pick an API model.'); return; }
    const quota = isDescribed ? 1 : (Number(fQuota) || 0);
    const skills = isLabour ? Object.entries(fSkillLevels).map(([skill_id, level]) => ({ skill_id, level })) : [];
    const usd = meth === 'flat' && !isLabour && !isDescribed ? fUsd : null;
    const details = isDescribed ? (fDetails || null) : null;
    busy = true;
    let err;
    if (editId) {
      ({ error: err } = await supabase.rpc('update_resource', {
        p_resource: editId, p_name: fName.trim(), p_monthly_quota: quota,
        p_usd_per_unit: usd, p_skills: skills,
        p_gpu_model: meth === 'gpu' ? fGpu : null, p_api_model: meth === 'api' ? fApi : null,
        p_details: details
      }));
    } else {
      ({ error: err } = await supabase.rpc('forge_resource', {
        p_type: fType, p_name: fName.trim(), p_holder: holder, p_scope: scope,
        p_monthly_quota: quota, p_unit: null, p_usd_per_unit: usd, p_skills: skills, p_level: null,
        p_gpu_model: meth === 'gpu' ? fGpu : null, p_api_model: meth === 'api' ? fApi : null,
        p_details: details
      }));
    }
    busy = false;
    if (err) { error = err.message; return; }
    ok = editId ? get(t)('Saved — re-submitted for review.') : get(t)('Resource forged — pending review.'); reset();
    onForged?.();
  }
</script>

{#if error}<p class="err">{error}</p>{/if}
{#if ok}<p class="ok">{ok}</p>{/if}

<div class="forge-form">
  <label><span>{$t('Type')}</span>
    <select bind:value={fType}><option value="">—</option>{#each types as ty (ty.id)}<option value={ty.id}>{ty.name}</option>{/each}</select>
  </label>
  {#if mode === 'supply'}
    <label><span>{$t('Name')}</span><input bind:value={fName} /></label>
    {#if holderPicker}
      <label><span>{$t('Holder (steward)')}</span>
        <select bind:value={holder}><option value="">—</option>{#each members as m (m.id)}<option value={m.id}>{m.full_name}</option>{/each}</select>
      </label>
    {/if}

    {#if meth === 'gpu'}
      <label><span>{$t('GPU model')}</span>
        <select bind:value={fGpu}><option value="">—</option>{#each gpus as g (g.id)}<option value={g.id}>{g.name} · {g.tflops} TFLOPs</option>{/each}</select>
      </label>
    {:else if meth === 'api'}
      <label><span>{$t('API model')}</span>
        <select bind:value={fApi}><option value="">—</option>{#each apis as a (a.id)}<option value={a.id}>{a.provider} {a.name} · ${a.usd_per_million}/1M</option>{/each}</select>
      </label>
    {/if}
  {/if}

  {#if mode === 'supply' && isDescribed}
    <label style="flex-basis:100%;"><span>{$t('Description')}<span class="muted"> · {$t('describe what you’re offering — value set by the steward')}</span></span>
      <textarea bind:value={fDetails} rows="2"></textarea></label>
  {:else}
    <label><span>{mode === 'need' ? $t('Quota / month') : $t('Monthly quota')}<span class="muted"> · {quotaUnit}</span></span><input type="number" step="any" bind:value={fQuota} style="max-width:8rem;" /></label>
  {/if}

  {#if mode === 'need'}
    <label><span>{$t('Headcount')}</span><input type="number" min="1" step="1" bind:value={fHeadcount} style="max-width:5rem;" /></label>
  {/if}

  {#if mode === 'supply' && meth === 'flat' && !isLabour && !isDescribed}
    <label><span>{$t('USD / unit')}<span class="muted"> · {selType?.usd_per_unit != null ? $t('default {n}', { n: selType.usd_per_unit }) : ''}</span></span>
      <input type="number" step="any" bind:value={fUsd} placeholder={selType?.usd_per_unit != null ? String(selType.usd_per_unit) : ''} style="max-width:6rem;" /></label>
  {/if}

  <button class="go" onclick={forge} disabled={busy}>{busy ? $t('Working…') : editId ? $t('Save changes') : mode === 'need' ? $t('Post need') : $t('Forge resource')}</button>

  {#if isLabour}
    <div class="skills-row">
      <span class="skills-h">{mode === 'need' ? $t('Required skills & levels') : $t('Skills & level these hours can fill')}<span class="muted"> · {mode === 'need' ? $t('a contributor must meet every skill') : $t('set each skill’s rank; a holder = you defaults to your badges')}</span></span>
      <SkillLevelPicker bind:value={fSkillLevels} />
    </div>
  {/if}
</div>

<style>
  .err { color: var(--down); font-size: .85rem; margin: 0 0 .4rem; }
  .ok { color: var(--up); font-size: .85rem; margin: 0 0 .4rem; }
  .forge-form { display: flex; flex-wrap: wrap; gap: .6rem; align-items: flex-end; }
  .forge-form label { display: flex; flex-direction: column; gap: .2rem; }
  .forge-form label span { font-size: .75rem; color: var(--muted); }
  .forge-form input, .forge-form select, .forge-form textarea { padding: .4rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .85rem; font-family: inherit; }
  .forge-form textarea { width: 100%; resize: vertical; }
  .skills-row { flex-basis: 100%; display: flex; flex-direction: column; gap: .35rem; }
  .skills-h { font-size: .75rem; color: var(--muted); }
  .go { padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; cursor: not-allowed; }
</style>
