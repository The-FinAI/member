<script lang="ts">
  // BUILD PLAN P2 — the People surface: the roster. Each person shows their
  // skills (tag · level) and capacity. Chapter stewards see their own roster
  // first; everyone can browse. (Matching onto Needs arrives in P3.)
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { goto } from '$app/navigation';
  import { get } from 'svelte/store';
  import Icon from '$lib/Icon.svelte';

  type Person = {
    id: string; full_name: string; kind: string; affiliation: string | null;
    home_unit_id: string | null; monthly_hours: number | null;
  };
  type PSkill = { member_id: string; skill_id: string; level: string };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };
  const LEVEL_RANK: Record<string, number> = { lead: 3, independent: 2, learning: 1 };

  let people = $state<Person[]>([]);
  let capacity = $state<Record<string, { total: number | null; free: number | null }>>({});
  let skillsBy = $state<Record<string, { name: string; level: string }[]>>({});
  let loading = $state(true);
  let q = $state('');
  let mineOnly = $state(false);

  const isOfficer = $derived($officerUnits.length > 0 || $capabilities.has('manage_members'));
  const myUnitIds = $derived(new Set($officerUnits.map((u: any) => u.unit_id ?? u.id)));
  const myChapters = $derived($officerUnits.filter((u: any) => u.kind === 'chapter'));

  // add a person (forge a member card into a chapter) — moved here from the
  // retired officer console; skills/hours are set on the person card after.
  let addOpen = $state(false);
  let aName = $state(''); let aEmail = $state(''); let aAffil = $state(''); let aUnit = $state('');
  let aBusy = $state(false); let aErr = $state(''); let aMsg = $state('');
  async function addPerson() {
    aErr = ''; aMsg = '';
    const unit = aUnit || (myChapters[0] as any)?.unit_id || (myChapters[0] as any)?.id;
    if (!aName.trim() || !aEmail.trim()) { aErr = $t('Name and email are required.'); return; }
    if (!unit) { aErr = $t('No chapter to add to.'); return; }
    aBusy = true;
    const { data, error } = await supabase.rpc('forge_member_card', {
      p_full_name: aName.trim(), p_email: aEmail.trim(), p_unit: unit, p_affiliation: aAffil.trim() || null
    });
    aBusy = false;
    if (error) { aErr = error.message; return; }
    aName = ''; aEmail = ''; aAffil = '';
    // onboard: drop the officer straight onto the new person's card to set
    // their skills & capacity (else they're added but un-matchable, with no cue)
    if (data) { goto(`/members/${data}`); return; }
    aMsg = $t('Person added.'); load();
  }

  const filtered = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    return people.filter((p) => {
      if (mineOnly && !myUnitIds.has(p.home_unit_id)) return false;
      if (needle && !p.full_name.toLowerCase().includes(needle)) return false;
      return true;
    });
  });

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const ym = new Date().toISOString().slice(0, 7);
    const [mem, sk, skn, cap] = await Promise.all([
      supabase.from('member').select('id,full_name,kind,affiliation,home_unit_id,monthly_hours').order('full_name'),
      supabase.from('person_skill').select('member_id,skill_id,level'),
      supabase.from('skill').select('id,name'),
      supabase.rpc('member_capacity_all', { p_ym: ym })
    ]);
    people = (mem.data as Person[]) ?? [];
    capacity = {};
    for (const c of (cap.data as { member_id: string; total: number | null; free: number | null }[]) ?? [])
      capacity[c.member_id] = { total: c.total == null ? null : Number(c.total), free: c.free == null ? null : Number(c.free) };
    const nameOf: Record<string, string> = {};
    for (const s of (skn.data as any[]) ?? []) nameOf[s.id] = s.name;
    const by: Record<string, { name: string; level: string }[]> = {};
    for (const r of (sk.data as PSkill[]) ?? []) {
      (by[r.member_id] ??= []).push({ name: nameOf[r.skill_id] ?? '?', level: r.level });
    }
    for (const k in by) by[k].sort((a, b) => (LEVEL_RANK[b.level] ?? 0) - (LEVEL_RANK[a.level] ?? 0));
    skillsBy = by;
    loading = false;
  }
  onMount(() => { if (isOfficer) mineOnly = true; load(); });
</script>

<svelte:head><title>{$t('People')} · The Fin AI</title></svelte:head>

<section class="pp">
  <div class="pp-head">
    <div class="pp-titlerow">
      <h1>{$t('People')}</h1>
      {#if isOfficer}<button class="pp-add" onclick={() => (addOpen = !addOpen)}>＋ {$t('Add a person')}</button>{/if}
    </div>
    <p class="pp-sub">{$t('Researchers across the community — their skills and how much time they have.')}</p>
  </div>

  {#if addOpen}
    <div class="pp-addform">
      <input placeholder={$t('Full name (required)')} bind:value={aName} required />
      <input type="email" placeholder={$t('Email (required)')} bind:value={aEmail} required />
      <input placeholder={$t('Affiliation')} bind:value={aAffil} />
      {#if myChapters.length > 1}
        <select bind:value={aUnit}>
          <option value="">{$t('Chapter')}</option>
          {#each myChapters as c}<option value={(c as any).unit_id ?? (c as any).id}>{(c as any).name}</option>{/each}
        </select>
      {/if}
      <button class="pp-go" disabled={aBusy} onclick={addPerson}>{$t('Add')}</button>
      {#if aErr}<span class="pp-err">{aErr}</span>{/if}
      {#if aMsg}<span class="pp-ok">{aMsg}</span>{/if}
    </div>
  {/if}

  <!-- Matching moved INTO the project ledger (assign in place from a project's
       open needs). People is now the pure roster — see people, manage their
       skills & capacity. -->

  <div class="pp-tools">
    <input class="pp-search" placeholder={$t('Search by name…')} bind:value={q} />
    {#if isOfficer}
      <label class="pp-toggle"><input type="checkbox" bind:checked={mineOnly} /> {$t('My roster only')}</label>
    {/if}
  </div>

  {#if loading}
    <p class="pp-dim">{$t('Loading…')}</p>
  {:else if !filtered.length}
    <p class="pp-dim">{$t('No people match.')}</p>
  {:else}
    <div class="pp-grid">
      {#each filtered as p (p.id)}
        <a class="pcard" href={`/members/${p.id}`}>
          <div class="pc-top">
            <span class="pc-name">{p.full_name}</span>
            {#if p.kind === 'card'}<span class="pc-tag">{$t('card')}</span>{/if}
          </div>
          {#if p.affiliation}<div class="pc-aff">{p.affiliation}</div>{/if}
          <div class="pc-cap">
            <span class="pc-cap-label">{$t('Available')}</span>
            {#if (capacity[p.id]?.total ?? p.monthly_hours) == null}
              <span class="pc-cap-val pc-unset">{$t('time not set')}</span>
            {:else}
              {@const cap = capacity[p.id]}
              {@const free = cap?.free ?? cap?.total ?? p.monthly_hours ?? 0}
              <span class="pc-cap-val" class:pc-over={free < 0}><b>{Math.max(0, free)}</b>/{cap?.total ?? p.monthly_hours} {$t('h/mo')}{#if free < 0} <Icon name="warn" size={12} />{/if}</span>
            {/if}
          </div>
          <div class="pc-skills">
            {#each (skillsBy[p.id] ?? []).slice(0, 5) as s}
              <span class="pc-skill lv-{s.level}">{s.name} · {$t(LEVEL_LABEL[s.level] ?? s.level)}</span>
            {/each}
            {#if !(skillsBy[p.id] ?? []).length}<span class="pc-noskill">{$t('No skills listed')}</span>{/if}
          </div>
        </a>
      {/each}
    </div>
  {/if}
</section>

<style>
  .pp { padding: 1rem 0 3rem; max-width: 1100px; }
  .pp-titlerow { display: flex; align-items: center; gap: 1rem; }
  .pp-head h1 { margin: 0; }
  .pp-add { border: 1px solid var(--accent, var(--accent)); color: var(--accent, var(--accent)); background: none; border-radius: var(--r-sm); padding: .25rem .7rem; cursor: pointer; font-size: .85rem; }
  .pp-sub { color: var(--muted, #888); margin: .2rem 0 1rem; font-size: .9rem; }
  .pp-addform { display: flex; gap: .4rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; padding: .6rem .7rem; border: 1px solid var(--line, #eee); border-radius: var(--r-md); }
  .pp-addform input, .pp-addform select { padding: .35rem .5rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .pp-go { border: none; background: var(--accent, var(--accent)); color: #fff; border-radius: var(--r-sm); padding: .35rem .8rem; cursor: pointer; }
  .pp-go:disabled { opacity: .5; }
  .pp-err { color: var(--neg, var(--down)); font-size: .82rem; }
  .pp-ok { color: var(--up); font-size: .82rem; }
  .pp-tools { display: flex; gap: 1rem; align-items: center; margin-bottom: 1rem; }
  .pp-search { flex: 0 1 22rem; padding: .4rem .6rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .pp-toggle { font-size: .85rem; color: var(--muted, #666); display: flex; gap: .35rem; align-items: center; }
  .pp-dim { color: var(--muted, #999); }
  .pp-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr)); gap: .8rem; }
  .pcard { display: block; text-decoration: none; color: inherit; background: var(--card, #fff); border: 1px solid var(--line, #eee); border-radius: var(--r-md); padding: .75rem .85rem; }
  .pcard:hover { border-color: var(--accent, var(--accent)); }
  .pc-top { display: flex; align-items: center; gap: .4rem; }
  .pc-name { font-weight: 600; }
  .pc-tag { font-size: .68rem; background: var(--line, #eee); border-radius: var(--r-full); padding: 0 .4rem; color: var(--muted, #888); }
  .pc-aff { font-size: .8rem; color: var(--muted, #999); margin-top: .1rem; }
  .pc-cap { display: flex; gap: .4rem; align-items: baseline; margin: .5rem 0 .4rem; }
  .pc-cap-label { font-size: .72rem; color: var(--muted, #aaa); }
  .pc-cap-val { font-size: .85rem; font-weight: 600; }
  .pc-cap-val b { font-family: var(--font-mono, monospace); }
  .pc-unset { color: var(--muted, #999); font-weight: 500; font-style: italic; }
  .pc-over { color: var(--down, var(--down)); }
  .pc-skills { display: flex; flex-wrap: wrap; gap: .3rem; }
  .pc-skill { font-size: .73rem; padding: .1rem .45rem; border-radius: var(--r-full); border: 1px solid var(--line, #e6e6e6); color: var(--muted, #666); }
  .pc-skill.lv-lead { border-color: #c9a227; color: var(--gold); }
  .pc-skill.lv-independent { border-color: var(--info); color: var(--info); }
  .pc-noskill { font-size: .73rem; color: var(--muted, #bbb); }
</style>
