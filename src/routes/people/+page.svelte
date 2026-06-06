<script lang="ts">
  // BUILD PLAN P2 — the People surface: the roster. Each person shows their
  // skills (tag · level) and capacity. Chapter stewards see their own roster
  // first; everyone can browse. (Matching onto Needs arrives in P3.)
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import MatchBoard from '$lib/people/MatchBoard.svelte';

  type Person = {
    id: string; full_name: string; kind: string; affiliation: string | null;
    home_unit_id: string | null; monthly_hours: number | null;
  };
  type PSkill = { member_id: string; skill_id: string; level: string };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };
  const LEVEL_RANK: Record<string, number> = { lead: 3, independent: 2, learning: 1 };

  let people = $state<Person[]>([]);
  let skillsBy = $state<Record<string, { name: string; level: string }[]>>({});
  let loading = $state(true);
  let q = $state('');
  let mineOnly = $state(false);

  const isOfficer = $derived($officerUnits.length > 0 || $capabilities.has('manage_members'));
  const myUnitIds = $derived(new Set($officerUnits.map((u: any) => u.unit_id ?? u.id)));

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
    const [mem, sk, skn] = await Promise.all([
      supabase.from('member').select('id,full_name,kind,affiliation,home_unit_id,monthly_hours').order('full_name'),
      supabase.from('person_skill').select('member_id,skill_id,level'),
      supabase.from('skill').select('id,name')
    ]);
    people = (mem.data as Person[]) ?? [];
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
    <h1>{$t('People')}</h1>
    <p class="pp-sub">{$t('Researchers across the community — their skills and how much time they have.')}</p>
  </div>

  {#if isOfficer}
    <MatchBoard />
  {/if}

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
            <span class="pc-cap-label">{$t('Capacity')}</span>
            <span class="pc-cap-val">{p.monthly_hours ?? '—'} {$t('h/mo')}</span>
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
  .pp-head h1 { margin: 0; }
  .pp-sub { color: var(--muted, #888); margin: .2rem 0 1rem; font-size: .9rem; }
  .pp-tools { display: flex; gap: 1rem; align-items: center; margin-bottom: 1rem; }
  .pp-search { flex: 0 1 22rem; padding: .4rem .6rem; border: 1px solid var(--line, #ddd); border-radius: 8px; }
  .pp-toggle { font-size: .85rem; color: var(--muted, #666); display: flex; gap: .35rem; align-items: center; }
  .pp-dim { color: var(--muted, #999); }
  .pp-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr)); gap: .8rem; }
  .pcard { display: block; text-decoration: none; color: inherit; background: var(--card, #fff); border: 1px solid var(--line, #eee); border-radius: 12px; padding: .75rem .85rem; }
  .pcard:hover { border-color: var(--accent, #6a7cff); }
  .pc-top { display: flex; align-items: center; gap: .4rem; }
  .pc-name { font-weight: 600; }
  .pc-tag { font-size: .68rem; background: var(--line, #eee); border-radius: 999px; padding: 0 .4rem; color: var(--muted, #888); }
  .pc-aff { font-size: .8rem; color: var(--muted, #999); margin-top: .1rem; }
  .pc-cap { display: flex; gap: .4rem; align-items: baseline; margin: .5rem 0 .4rem; }
  .pc-cap-label { font-size: .72rem; color: var(--muted, #aaa); }
  .pc-cap-val { font-size: .85rem; font-weight: 600; }
  .pc-skills { display: flex; flex-wrap: wrap; gap: .3rem; }
  .pc-skill { font-size: .73rem; padding: .1rem .45rem; border-radius: 999px; border: 1px solid var(--line, #e6e6e6); color: var(--muted, #666); }
  .pc-skill.lv-lead { border-color: #c9a227; color: #9a7b12; }
  .pc-skill.lv-independent { border-color: #8aa0ff; color: #5566cc; }
  .pc-noskill { font-size: .73rem; color: var(--muted, #bbb); }
</style>
