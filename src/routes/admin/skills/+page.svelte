<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities } from '$lib/session';
  import { t } from '$lib/i18n';

  type Skill = { id: string; parent_id: string | null; name: string };
  type LeaderReq = { skill_id: string; min_level: string; rank: number; skill: { name: string } | null };

  let skills = $state<Skill[]>([]);
  let leaderReqs = $state<LeaderReq[]>([]);
  let loading = $state(true);
  let error = $state('');
  let newName = $state('');
  let newParent = $state('');

  const GUILD_LADDER = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const GUILD_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };

  // add-requirement form
  let reqSkill = $state(''); let reqLevel = $state('journeyman');

  const canGuild = $derived($capabilities.has('manage_guild'));
  // certifiable leaves (skills that have no children) for requirement picker
  const leaves = $derived(skills.filter((s) => !skills.some((c) => c.parent_id === s.id)));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data, error: err }, { data: lr }] = await Promise.all([
      supabase.from('skill').select('id, parent_id, name').order('name'),
      supabase.from('leader_skill_requirement').select('skill_id, min_level, rank, skill(name)').order('rank')
    ]);
    if (err) error = err.message;
    skills = (data as Skill[]) ?? [];
    leaderReqs = (lr as LeaderReq[]) ?? [];
    loading = false;
  }

  onMount(load);

  const roots = $derived(skills.filter((s) => !s.parent_id));
  function childrenOf(id: string) { return skills.filter((s) => s.parent_id === id); }

  async function add() {
    error = '';
    if (!newName.trim()) return;
    const { error: err } = await supabase
      .from('skill')
      .insert({ name: newName.trim(), parent_id: newParent || null });
    if (err) { error = err.message; return; }
    newName = '';
    await load();
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from('skill').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }

  // ---- leader requirements ----
  async function addRequirement() {
    error = '';
    if (!reqSkill) return;
    const nextRank = (leaderReqs.reduce((m, r) => Math.max(m, r.rank), 0) || 0) + 10;
    const { error: err } = await supabase
      .from('leader_skill_requirement')
      .upsert({ skill_id: reqSkill, min_level: reqLevel, rank: nextRank }, { onConflict: 'skill_id' });
    if (err) { error = err.message; return; }
    reqSkill = '';
    await load();
  }
  async function setReqLevel(skillId: string, level: string) {
    error = '';
    const { error: err } = await supabase.from('leader_skill_requirement').update({ min_level: level }).eq('skill_id', skillId);
    if (err) { error = err.message; return; }
    await load();
  }
  async function removeRequirement(skillId: string) {
    error = '';
    const { error: err } = await supabase.from('leader_skill_requirement').delete().eq('skill_id', skillId);
    if (err) { error = err.message; return; }
    await load();
  }

</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Skill Tree')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {@html $t('Hierarchical skills. Leaves are certifiable crafts in <a href="/community?tab=crafts">the Guild</a>; needs filter on these.')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card row">
    <input placeholder={$t('New skill name')} bind:value={newName} />
    <select bind:value={newParent}>
      <option value="">{$t('— top-level category —')}</option>
      {#each roots as r}<option value={r.id}>{r.name}</option>{/each}
    </select>
    <button onclick={add}>{$t('Add skill')}</button>
  </div>

  <div class="card">
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if roots.length === 0}
      <p class="muted">{$t('No skills yet.')}</p>
    {:else}
      {#each roots as root}
        <div style="margin-bottom:1rem;">
          <div class="row" style="justify-content:space-between;">
            <strong>{root.name}</strong>
            <button class="danger" onclick={() => remove(root.id)}>{$t('Delete')}</button>
          </div>
          <ul style="margin:.4rem 0 0; padding-left:1.2rem; list-style:none;">
            {#each childrenOf(root.id) as child}
              <li class="row" style="justify-content:space-between; align-items:center; gap:.6rem; max-width:640px; padding:.2rem 0;">
                <span style="flex:1;">{child.name}</span>
                <button class="danger" onclick={() => remove(child.id)}>{$t('Delete')}</button>
              </li>
            {/each}
          </ul>
        </div>
      {/each}
    {/if}
  </div>

  {#if canGuild}
    <!-- leader skill requirements (hard gate) -->
    <div class="card stack">
      <h2 style="margin:0;">{$t('Leader requirements')}</h2>
      <p class="muted" style="font-size:.85rem; margin:0;">
        {$t('To create or claim a project a member must hold every skill below at or above its certified guild level. Enforced server-side.')}
      </p>
      {#if leaderReqs.length === 0}
        <p class="muted">{$t('No leader requirements set.')}</p>
      {:else}
        <ul style="margin:0; padding:0; list-style:none;">
          {#each leaderReqs as r}
            <li class="row" style="justify-content:space-between; align-items:center; gap:.6rem; max-width:560px; padding:.25rem 0;">
              <span style="flex:1;">{$t(r.skill?.name ?? '—')}</span>
              <select value={r.min_level} onchange={(e) => setReqLevel(r.skill_id, e.currentTarget.value)} style="max-width:160px;">
                {#each GUILD_LADDER as g}<option value={g}>{$t(GUILD_LABEL[g])}</option>{/each}
              </select>
              <button class="danger" onclick={() => removeRequirement(r.skill_id)}>{$t('Remove')}</button>
            </li>
          {/each}
        </ul>
      {/if}
      <div class="row" style="align-items:flex-end; flex-wrap:wrap; gap:.6rem; border-top:1px dashed var(--border); padding-top:.75rem;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Add skill')}</span>
          <select bind:value={reqSkill} style="max-width:220px;">
            <option value="">—</option>
            {#each leaves.filter((s) => !leaderReqs.some((r) => r.skill_id === s.id)) as s}<option value={s.id}>{s.name}</option>{/each}
          </select>
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Min guild level')}</span>
          <select bind:value={reqLevel}>{#each GUILD_LADDER as g}<option value={g}>{$t(GUILD_LABEL[g])}</option>{/each}</select>
        </label>
        <button onclick={addRequirement} disabled={!reqSkill}>{$t('Add requirement')}</button>
      </div>
    </div>
  {/if}
</div>
