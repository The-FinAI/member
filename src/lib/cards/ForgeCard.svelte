<script lang="ts">
  import { t } from '$lib/i18n';
  import SkillLevelPicker from '$lib/admin/economy/SkillLevelPicker.svelte';

  export type Skill = { id: string; name: string; parent_id: string | null };
  export type ResType = { id: string; name: string; unit: string | null };

  // Unified Forge form shell. `mode` selects which card is being forged.
  // Parent owns the RPC; this emits a typed payload via onSubmit.
  let {
    mode,
    skills = [],
    resourceTypes = [],
    title = '',
    busy = false,
    onSubmit,
    onCancel
  }: {
    mode: 'member' | 'badge' | 'resource' | 'need';
    skills?: Skill[];
    resourceTypes?: ResType[];
    title?: string;
    busy?: boolean;
    onSubmit?: (payload: Record<string, any>) => void;
    onCancel?: () => void;
  } = $props();

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };

  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  const leaves = $derived((domainId: string) =>
    skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name)));

  // member
  let mName = $state(''); let mEmail = $state(''); let mAffil = $state('');
  // badge
  let bSkill = $state(''); let bLevel = $state('apprentice');
  // resource
  let rType = $state(''); let rName = $state(''); let rScope = $state('member');
  let rQuota = $state<number>(0); let rUnit = $state('');
  // need
  let nKind = $state('work_labor'); let nAccess = $state(''); let nSkill = $state('');
  let nResType = $state(''); let nQuota = $state<number>(0); let nHead = $state<number>(1);
  let nSkillLevels = $state<Record<string, string>>({}); // skill_id → min_level (multi)
  const nReqs = $derived(Object.entries(nSkillLevels).map(([skill_id, min_level]) => ({ skill_id, min_level })));

  function submit() {
    if (mode === 'member') onSubmit?.({ full_name: mName, email: mEmail, affiliation: mAffil });
    else if (mode === 'badge') onSubmit?.({ skill: bSkill, level: bLevel });
    else if (mode === 'resource') onSubmit?.({ type: rType, name: rName, scope: rScope, monthly_quota: rQuota, unit: rUnit });
    else onSubmit?.({
      slot_kind: nKind, resource_type: nResType || null, quota: nQuota || null, headcount: nHead,
      // labour needs carry a multi-skill requirements list; first one feeds skill_id/req_access for display
      requirements: nKind === 'work_labor' ? nReqs : [],
      skill: nKind === 'work_labor' ? (nReqs[0]?.skill_id ?? null) : null,
      req_access: nKind === 'work_labor' ? (nReqs[0]?.min_level ?? null) : null
    });
  }

  const valid = $derived(
    mode === 'member' ? !!mName.trim() && !!mEmail.trim()
    : mode === 'badge' ? !!bSkill && !!bLevel
    : mode === 'resource' ? !!rType && !!rName.trim() && rQuota >= 0
    : nKind === 'work_resource' ? !!nResType : nReqs.length > 0
  );
</script>

<form class="forge" onsubmit={(e) => { e.preventDefault(); if (valid) submit(); }}>
  {#if title}<div class="f-title">{title}</div>{/if}

  {#if mode === 'member'}
    <label class="f-field"><span>{$t('Full name')}</span><input bind:value={mName} required /></label>
    <label class="f-field"><span>{$t('Email')}</span><input type="email" bind:value={mEmail} required /></label>
    <label class="f-field"><span>{$t('Affiliation')}</span><input bind:value={mAffil} /></label>

  {:else if mode === 'badge'}
    <label class="f-field"><span>{$t('Skill')}</span>
      <select bind:value={bSkill} required>
        <option value="">{$t('Select skill')}</option>
        {#each domains as d (d.id)}
          <optgroup label={d.name}>
            {#each leaves(d.id) as s (s.id)}<option value={s.id}>{s.name}</option>{/each}
          </optgroup>
        {/each}
      </select>
    </label>
    <label class="f-field"><span>{$t('Level')}</span>
      <select bind:value={bLevel}>
        {#each LEVELS as l}<option value={l}>{$t(LEVEL_LABEL[l])}</option>{/each}
      </select>
    </label>

  {:else if mode === 'resource'}
    <label class="f-field"><span>{$t('Type')}</span>
      <select bind:value={rType} required>
        <option value="">{$t('Select type')}</option>
        {#each resourceTypes as rt (rt.id)}<option value={rt.id}>{rt.name}</option>{/each}
      </select>
    </label>
    <label class="f-field"><span>{$t('Name')}</span><input bind:value={rName} required /></label>
    <div class="f-grid">
      <label class="f-field"><span>{$t('Monthly quota')}</span><input type="number" min="0" step="any" bind:value={rQuota} /></label>
      <label class="f-field"><span>{$t('Unit')}</span><input bind:value={rUnit} placeholder="h / GPU·h / USD" /></label>
    </div>
    <label class="f-field"><span>{$t('Scope')}</span>
      <select bind:value={rScope}>
        <option value="member">{$t('Member')}</option>
        <option value="community">{$t('Community')}</option>
      </select>
    </label>

  {:else}
    <label class="f-field"><span>{$t('Need type')}</span>
      <select bind:value={nKind}>
        <option value="work_labor">{$t('Labor (co-author)')}</option>
        <option value="work_resource">{$t('Resource (corresponding)')}</option>
      </select>
    </label>
    {#if nKind === 'work_labor'}
      <div class="f-field"><span>{$t('Required skills & levels')}<span class="muted"> · {$t('a contributor (or their working-hours resource) must meet every skill')}</span></span>
        <SkillLevelPicker bind:value={nSkillLevels} />
      </div>
    {:else}
      <label class="f-field"><span>{$t('Resource type')}</span>
        <select bind:value={nResType} required>
          <option value="">{$t('Select type')}</option>
          {#each resourceTypes as rt (rt.id)}<option value={rt.id}>{rt.name}</option>{/each}
        </select>
      </label>
    {/if}
    <div class="f-grid">
      <label class="f-field"><span>{$t('Monthly quota')}</span><input type="number" min="0" step="any" bind:value={nQuota} /></label>
      <label class="f-field"><span>{$t('Headcount')}</span><input type="number" min="1" step="1" bind:value={nHead} /></label>
    </div>
  {/if}

  <div class="f-actions">
    {#if onCancel}<button type="button" class="chip toggle" onclick={onCancel}>{$t('Cancel')}</button>{/if}
    <button type="submit" class="stake" disabled={busy || !valid}>
      {#if busy}<span class="spin"></span>{/if}
      {$t('Forge')}
    </button>
  </div>
</form>

<style>
  .forge { display: flex; flex-direction: column; gap: .6rem; }
  .f-title { font-weight: 600; color: var(--text); font-size: .92rem; }
  .f-field { display: flex; flex-direction: column; gap: .25rem; font-size: .76rem; color: var(--muted); }
  .f-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
  .f-field input, .f-field select {
    padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem;
  }
  .f-actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .3rem; }
</style>
