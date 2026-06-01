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
  type Skill = { member_id: string; certified_level: string | null; skill: { name: string } | null };

  let cards = $state<Card[]>([]);
  let balances = $state<Record<string, number>>({});
  let cardSkills = $state<Record<string, Skill[]>>({});
  let loading = $state(true);
  let error = $state('');
  let msg = $state('');
  let busy = $state('');

  // create-card form
  let cName = $state(''); let cEmail = $state(''); let cAffil = $state(''); let cUnit = $state('');

  // chapters this user is a chair/secretary of (cards belong to chapters only)
  const chapters = $derived($officerUnits.filter((u) => u.kind === 'chapter'));
  const chapterIds = $derived(new Set(chapters.map((c) => c.unit_id)));

  function unitName(id: string) {
    return chapters.find((c) => c.unit_id === id)?.name ?? '';
  }

  async function load() {
    if (!supabaseConfigured || chapters.length === 0) { loading = false; return; }
    loading = true;
    const ids = chapters.map((c) => c.unit_id);
    const { data: cs, error: err } = await supabase
      .from('member')
      .select('id, full_name, email, affiliation, status, home_unit_id')
      .eq('kind', 'card')
      .in('home_unit_id', ids)
      .order('full_name');
    if (err) { error = err.message; loading = false; return; }
    cards = (cs as Card[]) ?? [];

    const cardIds = cards.map((c) => c.id);
    if (cardIds.length) {
      const [{ data: bal }, { data: sk }] = await Promise.all([
        supabase.from('stater_balance').select('owner_member_id, balance').in('owner_member_id', cardIds),
        supabase.from('member_skill').select('member_id, certified_level, skill(name)').in('member_id', cardIds).not('certified_level', 'is', null)
      ]);
      const b: Record<string, number> = {};
      for (const r of (bal as any[]) ?? []) b[r.owner_member_id] = Number(r.balance) || 0;
      balances = b;
      const m: Record<string, Skill[]> = {};
      for (const r of (sk as Skill[]) ?? []) (m[r.member_id] ??= []).push(r);
      cardSkills = m;
    } else {
      balances = {}; cardSkills = {};
    }
    loading = false;
  }

  onMount(() => {
    // default the create-card unit to the first chapter once known
    const c = get(officerUnits).filter((u) => u.kind === 'chapter');
    if (c.length) cUnit = c[0].unit_id;
    load();
  });

  async function createCard() {
    error = ''; msg = '';
    if (!cName.trim() || !cEmail.trim() || !cUnit) return;
    busy = 'create';
    const { error: err } = await supabase.rpc('create_card', {
      p_full_name: cName.trim(), p_email: cEmail.trim(), p_unit: cUnit,
      p_affiliation: cAffil.trim() || null
    });
    busy = '';
    if (err) { error = err.message; return; }
    msg = get(t)('Card created for {name}.', { name: cName.trim() });
    cName = ''; cEmail = ''; cAffil = '';
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

    {#if error}<p style="color:var(--down);">{error}</p>{/if}
    {#if msg}<p class="pos" style="font-size:.85rem;">{msg}</p>{/if}

    <!-- create a card -->
    <div class="card stack" style="gap:.6rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Add a member-card')}</h2>
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
        <button disabled={!cName.trim() || !cEmail.trim() || busy === 'create'} onclick={createCard}>{$t('Create card')}</button>
      </div>
    </div>

    <!-- roster -->
    <div class="card stack" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Cards')} {#if !loading}<span class="muted" style="font-weight:400;">· {cards.length}</span>{/if}</h2>
      {#if loading}
        <p class="muted">{$t('Loading…')}</p>
      {:else if cards.length === 0}
        <p class="muted">{$t('No cards yet. Add one above.')}</p>
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
