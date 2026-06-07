<script lang="ts">
  // BUILD PLAN P2 — a person's capacity + skills, redesigned (redesign-hci §15).
  // Capacity = monthly hours (a plain attribute). Skills = a tag + a 3-level
  // behavioural proficiency (Learning/Independent/Lead) shown WITH evidence from
  // the record (tasks · shipped). One-tap level; the system suggests raises the
  // record has earned. No badge tree, no certification queue. Optimistic.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  let { memberId, canEdit = false }: { memberId: string; canEdit?: boolean } = $props();

  type PSkill = { skill_id: string; level: string };
  type Ev = { skill_id: string; tasks: number; shipped: number };
  type Sug = { skill_id: string; skill_name: string; suggested_level: string; tasks: number; shipped: number };
  type Skill = { id: string; name: string };

  const LEVELS = ['learning', 'independent', 'lead'];
  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };

  let skills = $state<PSkill[]>([]);
  let evidence = $state<Record<string, Ev>>({});
  let suggestions = $state<Sug[]>([]);
  let allSkills = $state<Skill[]>([]);
  let hours = $state<number | null>(null);
  let hoursDraft = $state<string>('');
  let loading = $state(true);
  let err = $state('');
  let busy = $state<string | null>(null);
  let addOpen = $state(false);
  let addSkill = $state('');

  const skillName = (id: string) => allSkills.find((s) => s.id === id)?.name ?? '';
  const owned = $derived(new Set(skills.map((s) => s.skill_id)));
  const addable = $derived(allSkills.filter((s) => !owned.has(s.id)));

  async function load() {
    if (!supabaseConfigured || !memberId) { loading = false; return; }
    loading = true; err = '';
    const [ps, ev, sk, mem, sug] = await Promise.all([
      supabase.from('person_skill').select('skill_id,level').eq('member_id', memberId),
      supabase.from('person_skill_evidence').select('skill_id,tasks,shipped').eq('member_id', memberId),
      supabase.from('skill').select('id,name,parent_id'),
      supabase.from('member').select('monthly_hours').eq('id', memberId).maybeSingle(),
      supabase.rpc('skill_raise_suggestions', { p_member: memberId })
    ]);
    skills = (ps.data as PSkill[]) ?? [];
    const em: Record<string, Ev> = {};
    for (const e of (ev.data as Ev[]) ?? []) em[e.skill_id] = e;
    evidence = em;
    const rows = (sk.data as any[]) ?? [];
    const parents = new Set(rows.map((r) => r.parent_id).filter(Boolean));
    allSkills = rows.filter((r) => r.parent_id && !parents.has(r.id)).map((r) => ({ id: r.id, name: r.name }));
    hours = (mem.data as any)?.monthly_hours ?? null;
    hoursDraft = hours == null ? '' : String(hours);
    suggestions = (sug.data as Sug[]) ?? [];
    loading = false;
  }
  $effect(() => { memberId; load(); });

  async function setLevel(skill_id: string, level: string | null) {
    const before = skills.map((s) => ({ ...s }));
    if (level == null) skills = skills.filter((s) => s.skill_id !== skill_id);
    else {
      const ex = skills.find((s) => s.skill_id === skill_id);
      if (ex) ex.level = level; else skills = [...skills, { skill_id, level }];
    }
    skills = skills; busy = skill_id; err = '';
    const { error } = await supabase.rpc('person_skill_set', { p_skill: skill_id, p_level: level, p_member: memberId });
    busy = null;
    if (error) { skills = before; err = error.message; return; }
    suggestions = suggestions.filter((s) => s.skill_id !== skill_id);
  }

  function addNow() {
    if (!addSkill) return;
    setLevel(addSkill, 'learning');
    addSkill = ''; addOpen = false;
  }

  async function saveHours() {
    const v = hoursDraft.trim() === '' ? 0 : Math.max(0, Math.floor(Number(hoursDraft) || 0));
    const before = hours;
    hours = v; busy = 'hours'; err = '';
    const { error } = await supabase.rpc('person_set_capacity', { p_hours: v, p_member: memberId });
    busy = null;
    if (error) { hours = before; hoursDraft = before == null ? '' : String(before); err = error.message; }
  }
</script>

<section class="sc">
  <div class="sc-head"><h3>{$t('Skills & capacity')}</h3>{#if canEdit}<span class="sc-edit" title={$t('You manage this person. Tap a skill level, add a skill, or edit their monthly hours — changes save instantly.')}>✎ {$t('editable')}</span>{/if}{#if err}<span class="sc-err">{err}</span>{/if}</div>

  {#if loading}
    <p class="sc-dim">{$t('Loading…')}</p>
  {:else}
    <!-- capacity -->
    <div class="sc-cap">
      <span class="sc-label">{$t('Capacity')}</span>
      {#if canEdit}
        <input class="sc-hours" type="number" min="0" bind:value={hoursDraft}
          onchange={saveHours} disabled={busy === 'hours'} /> <span class="sc-unit">{$t('hours / month')}</span>
      {:else}
        <span>{hours ?? '—'} {$t('hours / month')}</span>
      {/if}
    </div>

    <!-- earned-raise suggestions -->
    {#if canEdit && suggestions.length}
      {#each suggestions as g (g.skill_id)}
        <div class="sc-sug">
          <span>{$t('Owned')} {g.tasks} · {g.shipped} {$t('shipped')} — {$t('mark')} <b>{$t(LEVEL_LABEL[g.suggested_level])}</b>?</span>
          <button class="sc-go" onclick={() => setLevel(g.skill_id, g.suggested_level)}>{$t('Yes')}</button>
        </div>
      {/each}
    {/if}

    <!-- skills -->
    {#if !skills.length && !canEdit}
      <p class="sc-dim">{$t('No skills listed yet.')}</p>
    {:else}
      <ul class="sc-list">
        {#each skills as s (s.skill_id)}
          <li class:busy={busy === s.skill_id}>
            <span class="sc-skill">{skillName(s.skill_id)}</span>
            {#if canEdit}
              <span class="sc-seg">
                {#each LEVELS as lv}
                  <button class="seg" class:on={s.level === lv} onclick={() => setLevel(s.skill_id, lv)}>{$t(LEVEL_LABEL[lv])}</button>
                {/each}
              </span>
            {:else}
              <span class="sc-lvl">{$t(LEVEL_LABEL[s.level] ?? s.level)}</span>
            {/if}
            {#if evidence[s.skill_id]}
              <span class="sc-ev">{evidence[s.skill_id].tasks} {$t('tasks')} · {evidence[s.skill_id].shipped} {$t('shipped')}</span>
            {/if}
            {#if canEdit}<button class="sc-x" title={$t('Remove')} onclick={() => setLevel(s.skill_id, null)}>✕</button>{/if}
          </li>
        {/each}
      </ul>

      {#if canEdit}
        {#if addOpen}
          <div class="sc-add">
            <select bind:value={addSkill}>
              <option value="">{$t('Pick a skill')}</option>
              {#each addable as a}<option value={a.id}>{a.name}</option>{/each}
            </select>
            <button class="sc-go" disabled={!addSkill} onclick={addNow}>{$t('Add')}</button>
            <button class="sc-ghost" onclick={() => { addOpen = false; addSkill = ''; }}>{$t('Cancel')}</button>
          </div>
        {:else}
          <button class="sc-addrow" onclick={() => (addOpen = true)}>＋ {$t('Add a skill')}</button>
        {/if}
      {/if}
    {/if}
  {/if}
</section>

<style>
  .sc { margin: 1rem 0; }
  .sc-head { display: flex; align-items: baseline; gap: .7rem; }
  .sc-head h3 { margin: 0 0 .5rem; font-size: 1rem; }
  .sc-edit { font-size: .7rem; font-weight: 700; letter-spacing: .02em; text-transform: uppercase;
    color: var(--accent); background: var(--accent-soft); padding: .1rem .45rem; border-radius: 999px; cursor: help; }
  .sc-err { color: var(--neg, #c0392b); font-size: .82rem; }
  .sc-dim { color: var(--muted, #999); font-size: .9rem; }
  .sc-cap { display: flex; align-items: center; gap: .5rem; margin-bottom: .6rem; }
  .sc-label { font-weight: 600; font-size: .85rem; color: var(--muted, #666); }
  .sc-hours { width: 5rem; padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .sc-unit { color: var(--muted, #999); font-size: .85rem; }
  .sc-sug { display: flex; align-items: center; justify-content: space-between; gap: .6rem; background: #fff8e6; border: 1px solid #f0d98a; border-radius: 8px; padding: .35rem .6rem; margin-bottom: .4rem; font-size: .85rem; }
  .sc-list { list-style: none; padding: 0; margin: .3rem 0; }
  .sc-list li { display: flex; align-items: center; gap: .55rem; padding: .3rem 0; border-bottom: 1px solid var(--line, #f3f3f3); }
  .sc-list li.busy { opacity: .55; }
  .sc-skill { font-weight: 500; min-width: 8rem; }
  .sc-seg { display: inline-flex; border: 1px solid var(--line, #ddd); border-radius: 7px; overflow: hidden; }
  .seg { border: none; background: none; padding: .2rem .55rem; cursor: pointer; font-size: .8rem; color: var(--muted, #888); border-right: 1px solid var(--line, #eee); }
  .seg:last-child { border-right: none; }
  .seg.on { background: var(--accent, #6a7cff); color: #fff; }
  .sc-lvl { font-size: .82rem; }
  .sc-ev { font-size: .76rem; color: var(--muted, #aaa); margin-left: auto; }
  .sc-x { border: none; background: none; cursor: pointer; color: var(--muted, #bbb); }
  .sc-x:hover { color: var(--neg, #c0392b); }
  .sc-add { display: flex; gap: .4rem; margin-top: .4rem; }
  .sc-add select { padding: .3rem .4rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .sc-addrow { border: 1px dashed var(--line, #ddd); background: none; border-radius: 8px; padding: .3rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .85rem; margin-top: .4rem; }
  .sc-addrow:hover { border-color: var(--accent, #6a7cff); color: var(--accent, #6a7cff); }
  .sc-go { border: none; background: var(--accent, #6a7cff); color: #fff; border-radius: 7px; padding: .3rem .75rem; cursor: pointer; }
  .sc-go:disabled { opacity: .5; cursor: default; }
  .sc-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: 7px; padding: .3rem .65rem; cursor: pointer; }
</style>
