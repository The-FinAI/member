<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // Per-skill labour rate (STR minted per hour, before the level multiplier).
  // A work_labor hour mints rate(skill) × level_mult × hours.
  type Skill = { id: string; parent_id: string | null; name: string };
  let skills = $state<Skill[]>([]);
  let rateOf = $state<Record<string, number>>({});
  let loading = $state(true); let error = $state(''); let saved = $state('');

  const DEFAULT = 10;
  // certifiable leaves grouped by domain
  const groups = $derived.by(() => {
    const nameOf = (id: string | null) => (id ? skills.find((s) => s.id === id)?.name ?? '—' : '—');
    const leaves = skills.filter((s) => !skills.some((c) => c.parent_id === s.id) && s.parent_id);
    const by: Record<string, { domain: string; items: Skill[] }> = {};
    for (const s of leaves) {
      const d = nameOf(s.parent_id);
      (by[d] ??= { domain: d, items: [] }).items.push(s);
    }
    return Object.values(by).sort((a, b) => a.domain.localeCompare(b.domain));
  });

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: sk }, { data: rt }] = await Promise.all([
      supabase.from('skill').select('id, parent_id, name').order('name'),
      supabase.from('stater_skill_rate').select('skill_id, rate')
    ]);
    skills = (sk as Skill[]) ?? [];
    const m: Record<string, number> = {};
    for (const r of (rt as { skill_id: string; rate: number }[]) ?? []) m[r.skill_id] = Number(r.rate);
    rateOf = m;
    loading = false;
  }
  onMount(load);

  async function save(skillId: string, value: number) {
    error = ''; saved = '';
    const rate = Math.max(0, Math.round(Number(value) || 0));
    rateOf = { ...rateOf, [skillId]: rate };
    const { error: err } = await supabase.from('stater_skill_rate').upsert({ skill_id: skillId, rate }, { onConflict: 'skill_id' });
    if (err) error = err.message; else saved = skillId;
  }
</script>

<p class="muted blurb">{$t('STR minted per hour for a labour need in this skill, before the badge-level multiplier. Default 10 = the baseline writing rate ($50/hr × 0.2).')}</p>
{#if error}<p class="err">{error}</p>{/if}

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  {#each groups as g (g.domain)}
    <section class="grp">
      <span class="sec">{g.domain}</span>
      <div class="rows">
        {#each g.items as s (s.id)}
          <div class="row" class:on={saved === s.id}>
            <span class="r-name">{s.name}</span>
            <label class="r-rate">
              <input type="number" min="0" step="1" value={rateOf[s.id] ?? DEFAULT} onchange={(e) => save(s.id, +e.currentTarget.value)} />
              <span class="r-unit">{$t('STR/hr')}</span>
            </label>
          </div>
        {/each}
      </div>
    </section>
  {/each}
{/if}

<style>
  .blurb { margin: 0; font-size: .85rem; }
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .grp { display: flex; flex-direction: column; gap: .4rem; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .rows { display: flex; flex-direction: column; gap: .3rem; }
  .row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .45rem .7rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); transition: border-color .3s; }
  .row.on { border-color: var(--up, var(--accent)); }
  .r-name { font-size: .88rem; color: var(--text); }
  .r-rate { display: inline-flex; align-items: center; gap: .4rem; }
  .r-rate input { width: 4.5rem; padding: .35rem .5rem; border-radius: 7px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); text-align: right; }
  .r-unit { font-size: .76rem; color: var(--muted); }
</style>
