<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, officerUnits, actingAs } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Card = {
    id: string; full_name: string; email: string; affiliation: string | null;
    status: string; home_unit_id: string;
  };
  type Skill = { id: string; name: string; parent_id: string | null };
  type CardSkill = { member_id: string; certified_level: string | null; skill: { name: string } | null };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman',
    craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  let cards = $state<Card[]>([]);
  let balances = $state<Record<string, number>>({});
  let cardSkills = $state<Record<string, CardSkill[]>>({});
  let skills = $state<Skill[]>([]);
  let loading = $state(true);
  let error = $state('');
  let msg = $state('');
  let busy = $state('');

  // forge-card form: identity + staged skills
  let cName = $state(''); let cEmail = $state(''); let cAffil = $state(''); let cUnit = $state('');
  let staged = $state<Record<string, string>>({}); // skillId -> level

  // chapters this user is a chair/secretary of (cards belong to chapters only)
  const chapters = $derived($officerUnits.filter((u) => u.kind === 'chapter'));

  function unitName(id: string) {
    return chapters.find((c) => c.unit_id === id)?.name ?? '';
  }

  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name));
  }
  function stageAt(skillId: string, level: string) {
    msg = '';
    if (staged[skillId] === level) { const { [skillId]: _, ...rest } = staged; staged = rest; }
    else staged = { ...staged, [skillId]: level };
  }
  const stagedCount = $derived(Object.keys(staged).length);

  async function load() {
    if (!supabaseConfigured || chapters.length === 0) { loading = false; return; }
    loading = true;
    const ids = chapters.map((c) => c.unit_id);
    const [{ data: cs, error: err }, { data: sk }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, email, affiliation, status, home_unit_id')
        .eq('kind', 'card').in('home_unit_id', ids).order('full_name'),
      supabase.from('skill').select('id, name, parent_id').order('name')
    ]);
    skills = ((sk as any[]) ?? []).map((s) => ({ id: s.id, name: s.name, parent_id: s.parent_id }));
    if (err) { error = err.message; loading = false; return; }
    cards = (cs as Card[]) ?? [];

    const cardIds = cards.map((c) => c.id);
    if (cardIds.length) {
      const [{ data: bal }, { data: ms }] = await Promise.all([
        supabase.from('stater_balance').select('owner_member_id, balance').in('owner_member_id', cardIds),
        supabase.from('member_skill').select('member_id, certified_level, skill(name)').in('member_id', cardIds).not('certified_level', 'is', null)
      ]);
      const b: Record<string, number> = {};
      for (const r of (bal as any[]) ?? []) b[r.owner_member_id] = Number(r.balance) || 0;
      balances = b;
      const m: Record<string, CardSkill[]> = {};
      for (const r of (ms as CardSkill[]) ?? []) (m[r.member_id] ??= []).push(r);
      cardSkills = m;
    } else {
      balances = {}; cardSkills = {};
    }
    loading = false;
  }

  onMount(() => {
    // default the forge unit to the first chapter once known
    const c = get(officerUnits).filter((u) => u.kind === 'chapter');
    if (c.length) cUnit = c[0].unit_id;
    load();
  });

  async function forgeCard() {
    error = ''; msg = '';
    if (!cName.trim() || !cEmail.trim() || !cUnit) return;
    busy = 'forge';
    const items = Object.entries(staged).map(([skill, level]) => ({ skill, level }));
    const { error: err } = await supabase.rpc('forge_card', {
      p_full_name: cName.trim(), p_email: cEmail.trim(), p_unit: cUnit,
      p_affiliation: cAffil.trim() || null, p_items: items
    });
    busy = '';
    if (err) { error = err.message; return; }
    msg = items.length
      ? get(t)('Card forged for {name} with {n} skill(s) staged for review.', { name: cName.trim(), n: items.length })
      : get(t)('Card forged for {name}.', { name: cName.trim() });
    cName = ''; cEmail = ''; cAffil = ''; staged = {};
    await load();
  }

  function actAs(c: Card) {
    actingAs.set({ id: c.id, full_name: c.full_name });
    goto('/projects');
  }
</script>

<div class="stack">
  <h1>{$t('My Chapter')}</h1>

  {#if chapters.length === 0}
    <p class="banner">{$t('This page is for chapter chairs and secretaries. You are not currently serving as one.')}</p>
  {:else}
    <p class="muted" style="margin-top:-.75rem;">
      {$t('Member-cards are people in your chapter who cannot log in yet. You act on their behalf: mint their monthly contributions and certify their role cards. Value accrues to the card and is custodial until the person signs up and claims it.')}
    </p>

    <!-- Phase 1 officer playbook: what to actually do, in order -->
    <div class="card stack" style="gap:.55rem; border-left:3px solid var(--accent);">
      <h2 style="margin:0; font-size:1rem;">{$t('Your Phase 1 checklist')}</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {$t("We're seeding the community. As an officer, here's what gets your chapter live — work down the list.")}
      </p>
      <ol class="checklist">
        <li>{$t('Forge a card for each researcher in your chapter — fill in who they are and stage the skills they bring (form below).')}</li>
        <li>{@html $t("Claim your chapter's existing projects — open <a href='/projects'>Projects</a>, and on each one your chapter already runs use <strong>“Add a member directly”</strong> to seat your cards onto its roster (no application, no bond).")}</li>
        <li>{$t('Act as a card to declare its monthly contributions on the projects it joins — value accrues to the card until the person claims it.')}</li>
        <li>{$t('Review your roster below: every card you forged is listed, with its balance and staged skills.')}</li>
        <li>{$t('Clear your Approvals queue — over-capacity commitments from your chapter members wait for you there.')} <a href="/admin/approvals">{$t('Open Approvals →')}</a></li>
      </ol>
    </div>

    {#if error}<p style="color:var(--down);">{error}</p>{/if}
    {#if msg}<p class="pos" style="font-size:.85rem;">{msg}</p>{/if}

    <!-- forge a card: identity + skills in one action -->
    <div class="card stack" style="gap:.7rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Forge a card')}</h2>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {$t('A card is one researcher — their identity and their skill profile, forged together. Fill in who they are, then stage the skills they bring. The whole card goes to review as one batch.')}
      </p>
      <div class="row" style="align-items:flex-end; flex-wrap:wrap; gap:.5rem;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Full name')}</span>
          <input bind:value={cName} placeholder={$t('Full name')} />
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Email (to claim later)')}</span>
          <input bind:value={cEmail} placeholder="name@example.com" />
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Affiliation')}</span>
          <input bind:value={cAffil} placeholder={$t('Affiliation')} />
        </label>
        {#if chapters.length > 1}
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Chapter')}</span>
            <select bind:value={cUnit}>{#each chapters as c}<option value={c.unit_id}>{c.name}</option>{/each}</select>
          </label>
        {/if}
      </div>

      <!-- skill picker: stage the card's initial skills -->
      <div class="stack" style="gap:.3rem; border-top:1px solid var(--border-2); padding-top:.55rem;">
        <span class="muted" style="font-size:.78rem;">{$t('Stage their skills (optional) — click a level to add it; click again to remove.')}</span>
        {#if loading}
          <p class="muted" style="font-size:.82rem;">{$t('Loading…')}</p>
        {:else}
          <div class="talent">
            {#each domains as d}
              <div class="stack" style="gap:.3rem;">
                <h3 style="margin:0; font-size:.9rem;">{d.name}</h3>
                {#each leavesOf(d.id) as s}
                  {@const stg = levelRank(staged[s.id] ?? null)}
                  <div class="talent-row">
                    <span class="talent-name">{s.name}</span>
                    <div class="pips">
                      {#each LEVELS as lv, i}
                        <button
                          class="pip {stg === i ? 'staged' : ''}"
                          title={$t(LEVEL_LABEL[lv])}
                          onclick={() => stageAt(s.id, lv)}
                          aria-label={$t(LEVEL_LABEL[lv])}
                        ><span class="pip-dot"></span></button>
                      {/each}
                    </div>
                    <span class="talent-cur muted">{stg >= 0 ? $t(LEVEL_LABEL[LEVELS[stg]]) : '—'}</span>
                  </div>
                {/each}
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <div class="row" style="gap:.5rem; align-items:center; border-top:1px solid var(--border-2); padding-top:.6rem;">
        <button class="stake" disabled={!cName.trim() || !cEmail.trim() || busy === 'forge'} onclick={forgeCard}>
          {busy === 'forge' ? $t('Forging…') : (stagedCount > 0 ? $t('Forge card · {n} skill(s)', { n: stagedCount }) : $t('Forge card'))}</button>
        {#if stagedCount > 0}<button onclick={() => (staged = {})} disabled={busy === 'forge'}>{$t('Clear')}</button>{/if}
      </div>
    </div>

    <!-- roster -->
    <div class="card stack" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Cards')} {#if !loading}<span class="muted" style="font-weight:400;">· {cards.length}</span>{/if}</h2>
      {#if loading}
        <p class="muted">{$t('Loading…')}</p>
      {:else if cards.length === 0}
        <p class="muted">{$t('No cards yet. Forge one above.')}</p>
      {:else}
        <ul style="margin:0; padding:0; list-style:none;">
          {#each cards as c}
            <li class="stack" style="gap:.3rem; border-top:1px solid var(--border); padding:.6rem 0;">
              <div class="row" style="justify-content:space-between; align-items:center; flex-wrap:wrap; gap:.5rem;">
                <div>
                  <strong>{c.full_name}</strong>
                  <span class="muted" style="font-size:.8rem;">· {c.email}</span>
                  {#if chapters.length > 1}<span class="badge dim" style="font-size:.7rem; margin-left:.3rem;">{unitName(c.home_unit_id)}</span>{/if}
                  <span class="badge {c.status === 'active' ? 'pos' : 'warn'}" style="font-size:.7rem; margin-left:.3rem;">{$t(c.status)}</span>
                </div>
                <div class="row" style="gap:.5rem; align-items:center;">
                  <span class="chip"><span class="amt">{(balances[c.id] ?? 0).toLocaleString()}</span> STR</span>
                  <button onclick={() => actAs(c)}>{$t('Act as this card →')}</button>
                </div>
              </div>
              {#if (cardSkills[c.id] ?? []).length > 0}
                <div class="row" style="flex-wrap:wrap; gap:.3rem;">
                  {#each cardSkills[c.id] as s}
                    <span class="badge dim" style="font-size:.7rem;">{$t(s.skill?.name ?? '—')} · {$t((s.certified_level ?? '').charAt(0).toUpperCase() + (s.certified_level ?? '').slice(1))}</span>
                  {/each}
                </div>
              {/if}
            </li>
          {/each}
        </ul>
        <p class="muted" style="font-size:.8rem; margin:.2rem 0 0;">
          {$t('“Act as this card” lets you join projects, apply to needs, mint contributions and request role cards on the card’s behalf. Money moves on the card’s balance.')}
        </p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .checklist { margin: 0; padding-left: 1.2rem; display: flex; flex-direction: column; gap: .4rem; }
  .checklist li { font-size: .85rem; line-height: 1.45; }
  .talent {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: .9rem 1.4rem;
  }
  .talent-row { display: flex; align-items: center; gap: .5rem; padding: .15rem 0; }
  .talent-name { flex: 1; font-size: .85rem; }
  .talent-cur { font-size: .68rem; min-width: 64px; text-align: right; }
  .pips { display: flex; gap: .28rem; }
  .pip {
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: none; padding: 2px; cursor: pointer;
  }
  .pip-dot {
    width: 13px; height: 13px; border-radius: 50%;
    border: 1.5px solid var(--border); background: transparent; transition: all .12s;
  }
  .pip.staged .pip-dot { border-color: var(--accent); box-shadow: 0 0 0 2px var(--accent-soft); background: transparent; }
  .pip:not(.staged):hover .pip-dot { border-color: var(--accent); background: var(--accent-soft); }
</style>
