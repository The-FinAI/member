<script lang="ts">
  // BUILD PLAN P3 — a WG officer posts a labour Need on their project (applies
  // immediately, no review). Skill + desired level + monthly hours + headcount.
  // After posting it shows the candidate-pool size so demand isn't posted blind.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  let { projectId, onPosted }: { projectId: string; onPosted?: () => void } = $props();

  type Skill = { id: string; name: string };
  const LEVELS = [
    { v: 'learning', l: 'Learning' }, { v: 'independent', l: 'Independent' }, { v: 'lead', l: 'Lead' }
  ];

  let skills = $state<Skill[]>([]);
  let open = $state(false);
  let fSkill = $state('');
  let fLevel = $state('independent');
  let fHours = $state('');
  let fHead = $state('1');
  let busy = $state(false);
  let err = $state('');
  let pool = $state<number | null>(null);

  async function load() {
    if (!supabaseConfigured) return;
    const { data } = await supabase.from('skill').select('id,name,parent_id');
    const rows = (data as any[]) ?? [];
    const parents = new Set(rows.map((r) => r.parent_id).filter(Boolean));
    skills = rows.filter((r) => r.parent_id && !parents.has(r.id)).map((r) => ({ id: r.id, name: r.name }));
  }
  $effect(() => { if (open && !skills.length) load(); });

  async function post() {
    err = ''; pool = null;
    if (!fSkill) { err = $t('Pick a skill'); return; }
    busy = true;
    const { data, error } = await supabase.rpc('need_post', {
      p_project: projectId, p_skill: fSkill, p_level: fLevel,
      p_capacity: Number(fHours) || null, p_headcount: Number(fHead) || 1
    });
    if (error) { busy = false; err = error.message; return; }
    // show the candidate pool so demand isn't blind
    const slotId = (data as any)?.id;
    if (slotId) {
      const { data: c } = await supabase.rpc('match_candidates', { p_slot: slotId });
      pool = (c as any[])?.length ?? 0;
    }
    busy = false; fSkill = ''; fHours = '';
    onPosted?.();
  }
</script>

{#if open}
  <div class="np">
    <div class="np-row">
      <select bind:value={fSkill}>
        <option value="">{$t('Pick a skill')}</option>
        {#each skills as s}<option value={s.id}>{s.name}</option>{/each}
      </select>
      <select bind:value={fLevel}>
        {#each LEVELS as lv}<option value={lv.v}>{$t(lv.l)}</option>{/each}
      </select>
      <input class="np-n" type="number" min="1" placeholder={$t('h/mo')} bind:value={fHours} />
      <input class="np-n" type="number" min="1" placeholder="×" bind:value={fHead} />
      <button class="np-go" disabled={busy} onclick={post}>{$t('Post role')}</button>
      <button class="np-ghost" onclick={() => (open = false)}>{$t('Cancel')}</button>
    </div>
    {#if err}<span class="np-err">{err}</span>{/if}
    {#if pool !== null}<span class="np-pool">{$t('Posted')} · {pool} {$t('people qualify')}</span>{/if}
  </div>
{:else}
  <button class="np-toggle" onclick={() => (open = true)}>＋ {$t('Post a role')}</button>
{/if}

<style>
  .np { border: 1px solid var(--line, #eee); border-radius: 9px; padding: .55rem .7rem; margin: .4rem 0; }
  .np-row { display: flex; gap: .4rem; align-items: center; flex-wrap: wrap; }
  .np select, .np-n { padding: .3rem .4rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .np-n { width: 4rem; }
  .np-go { border: none; background: var(--accent, #6a7cff); color: #fff; border-radius: 7px; padding: .3rem .75rem; cursor: pointer; }
  .np-go:disabled { opacity: .5; }
  .np-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: 7px; padding: .3rem .6rem; cursor: pointer; }
  .np-err { color: var(--neg, #c0392b); font-size: .8rem; display: block; margin-top: .35rem; }
  .np-pool { color: #2e7d4f; font-size: .82rem; display: block; margin-top: .35rem; }
  .np-toggle { border: 1px dashed var(--line, #ddd); background: none; border-radius: 8px; padding: .3rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .85rem; }
  .np-toggle:hover { border-color: var(--accent, #6a7cff); color: var(--accent, #6a7cff); }
</style>
