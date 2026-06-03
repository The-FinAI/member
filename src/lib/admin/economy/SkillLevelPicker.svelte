<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // Pick a level per skill (the talent-tree shape) — each leaf skill gets its
  // own rank apprentice → master. Value is a { skill_id: level } map (bindable).
  let { value = $bindable({}) }: { value?: Record<string, string> } = $props();

  const LADDER = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const SHORT: Record<string, string> = { apprentice: 'A', journeyman: 'J', craftsman: 'C', master: 'M' };
  const FULL: Record<string, string> = { apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master' };
  const rank = (l?: string) => (l ? LADDER.indexOf(l) + 1 : 0);

  type Skill = { id: string; parent_id: string | null; name: string };
  let skills = $state<Skill[]>([]);
  let loading = $state(true);

  const groups = $derived.by(() => {
    const nameOf = (id: string | null) => (id ? skills.find((s) => s.id === id)?.name ?? '—' : '—');
    const leaves = skills.filter((s) => s.parent_id && !skills.some((c) => c.parent_id === s.id));
    const by: Record<string, { domain: string; items: Skill[] }> = {};
    for (const s of leaves) (by[nameOf(s.parent_id)] ??= { domain: nameOf(s.parent_id), items: [] }).items.push(s);
    return Object.values(by).sort((a, b) => a.domain.localeCompare(b.domain));
  });

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const { data } = await supabase.from('skill').select('id, parent_id, name').order('name');
    skills = (data as Skill[]) ?? [];
    loading = false;
  }
  onMount(load);

  function set(id: string, lvl: string) {
    const v = { ...value };
    if (v[id] === lvl) delete v[id]; else v[id] = lvl;
    value = v;
  }
</script>

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  <div class="tree">
    {#each groups as g (g.domain)}
      <div class="domain">
        <span class="dh">{g.domain}</span>
        <div class="rows">
          {#each g.items as s (s.id)}
            <div class="row" class:set={!!value[s.id]}>
              <span class="sn">{s.name}</span>
              <div class="ranks">
                {#each LADDER as lvl, i}
                  <button type="button" class="pip" class:on={rank(value[s.id]) >= i + 1}
                    title={FULL[lvl]} onclick={() => set(s.id, lvl)}>{SHORT[lvl]}</button>
                {/each}
              </div>
            </div>
          {/each}
        </div>
      </div>
    {/each}
  </div>
{/if}

<style>
  .tree { display: flex; flex-direction: column; gap: .6rem; }
  .domain { display: flex; flex-direction: column; gap: .3rem; }
  .dh { font-size: .68rem; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
  .rows { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: .3rem; }
  .row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; padding: .3rem .5rem; border: 1px solid var(--border); border-radius: 8px; background: var(--card); }
  .row.set { border-color: var(--accent); }
  .sn { font-size: .82rem; color: var(--text); min-width: 0; }
  .ranks { display: inline-flex; gap: .15rem; flex: none; }
  .pip { width: 1.4rem; height: 1.4rem; border: 1px solid var(--border-2); border-radius: 5px; background: var(--card-2); color: var(--muted); font-size: .7rem; font-weight: 600; cursor: pointer; padding: 0; }
  .pip:hover { border-color: var(--accent); }
  .pip.on { background: var(--accent); border-color: var(--accent); color: #fff; }
</style>
