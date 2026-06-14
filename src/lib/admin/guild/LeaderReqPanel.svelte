<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';

  // The leader requirement: skills a member must hold (at level) to create or
  // claim a project. Enforced server-side via member_meets_requirements.
  type Skill = { id: string; parent_id: string | null; name: string };
  type Req = { skill_id: string; min_level: string; rank: number; skill: { name: string } | null };

  const LADDER = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LABEL: Record<string, string> = { apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master' };

  let skills = $state<Skill[]>([]);
  let reqs = $state<Req[]>([]);
  let loading = $state(true);
  let error = $state('');
  let reqSkill = $state(''); let reqLevel = $state('journeyman');

  const leaves = $derived(skills.filter((s) => !skills.some((c) => c.parent_id === s.id)));
  const free = $derived(leaves.filter((s) => !reqs.some((r) => r.skill_id === s.id)));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: sk }, { data: lr }] = await Promise.all([
      supabase.from('skill').select('id, parent_id, name').order('name'),
      supabase.from('leader_skill_requirement').select('skill_id, min_level, rank, skill(name)').order('rank')
    ]);
    skills = (sk as Skill[]) ?? [];
    reqs = (lr as Req[]) ?? [];
    loading = false;
  }
  onMount(load);

  async function add() {
    error = '';
    if (!reqSkill) return;
    const nextRank = (reqs.reduce((m, r) => Math.max(m, r.rank), 0) || 0) + 10;
    const { error: err } = await supabase.from('leader_skill_requirement').upsert({ skill_id: reqSkill, min_level: reqLevel, rank: nextRank }, { onConflict: 'skill_id' });
    if (err) { error = err.message; return; }
    reqSkill = '';
    await load();
  }
  async function setLevel(skillId: string, level: string) {
    error = '';
    const { error: err } = await supabase.from('leader_skill_requirement').update({ min_level: level }).eq('skill_id', skillId);
    if (err) error = err.message; else await load();
  }
  async function remove(skillId: string) {
    error = '';
    const { error: err } = await supabase.from('leader_skill_requirement').delete().eq('skill_id', skillId);
    if (err) error = err.message; else await load();
  }
</script>

<p class="muted blurb">{$t('To create or claim a project a member must hold every skill below at or above its level. Enforced server-side.')}</p>
{#if error}<p class="err">{error}</p>{/if}

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  {#if reqs.length === 0}
    <p class="muted">{$t('No leader requirements set.')}</p>
  {:else}
    <div class="reqs">
      {#each reqs as r (r.skill_id)}
        <div class="req">
          <span class="r-skill">{$t(r.skill?.name ?? '—')}</span>
          <select value={r.min_level} onchange={(e) => setLevel(r.skill_id, e.currentTarget.value)}>
            {#each LADDER as g}<option value={g}>{$t(LABEL[g])}</option>{/each}
          </select>
          <button class="x" onclick={() => remove(r.skill_id)} aria-label={$t('Remove')}><Icon name="close" size={12} /></button>
        </div>
      {/each}
    </div>
  {/if}

  <div class="card add">
    <label><span>{$t('Add skill')}</span>
      <select bind:value={reqSkill}><option value="">—</option>{#each free as s (s.id)}<option value={s.id}>{s.name}</option>{/each}</select>
    </label>
    <label><span>{$t('Min guild level')}</span>
      <select bind:value={reqLevel}>{#each LADDER as g}<option value={g}>{$t(LABEL[g])}</option>{/each}</select>
    </label>
    <button class="go" onclick={add} disabled={!reqSkill}>{$t('Add requirement')}</button>
  </div>
{/if}

<style>
  .blurb { margin: 0; font-size: .85rem; }
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .reqs { display: flex; flex-direction: column; gap: .4rem; }
  .req { display: flex; align-items: center; gap: .6rem; padding: .5rem .7rem; border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); }
  .r-skill { flex: 1; font-weight: 500; color: var(--text); }
  .req select { padding: .3rem .5rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .85rem; }
  .x { border: 0; background: transparent; color: var(--muted); cursor: pointer; font-size: .8rem; }
  .x:hover { color: var(--down); filter: none; }
  .add { display: flex; flex-wrap: wrap; gap: .6rem; align-items: flex-end; }
  .add label { display: flex; flex-direction: column; gap: .2rem; }
  .add label span { font-size: .75rem; color: var(--muted); }
  .add select { padding: .4rem .55rem; border-radius: var(--r-sm); border: 1px solid var(--border-2); background: var(--card); color: var(--text); }
  .go { padding: .5rem .9rem; border-radius: var(--r-sm); border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
  .go:disabled { opacity: .55; cursor: not-allowed; }
</style>
