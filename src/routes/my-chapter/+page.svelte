<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import EntityCard from '$lib/EntityCard.svelte';
  import CardDrawer from '$lib/CardDrawer.svelte';
  import Medal from '$lib/Medal.svelte';

  type Card = {
    id: string; full_name: string; email: string; affiliation: string | null;
    status: string; home_unit_id: string;
  };
  type Skill = { id: string; name: string; parent_id: string | null };
  type CardSkill = { member_id: string; certified_level: string | null; skill_id: string; skill: { name: string } | null };
  type ResType = { id: string; name: string; unit: string | null };
  type StagedRes = { typeId: string; capacity: string };

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

  // forge-card form: identity + staged skills + resources
  let cName = $state(''); let cEmail = $state(''); let cAffil = $state(''); let cUnit = $state('');
  let staged = $state<Record<string, string>>({}); // skillId -> level
  let cHours = $state(''); // monthly labor hours for this card
  let resTypes = $state<ResType[]>([]);
  let stagedRes = $state<StagedRes[]>([]); // non-labor resources to attach
  let rType = $state(''); let rCap = $state('');
  const laborType = $derived(resTypes.find((r) => r.name === 'Labor') ?? null);
  const offerTypes = $derived(resTypes.filter((r) => r.name !== 'Labor'));
  function resTypeName(id: string) { return resTypes.find((r) => r.id === id)?.name ?? '—'; }
  function addStagedRes() {
    if (!rType) return;
    stagedRes = [...stagedRes, { typeId: rType, capacity: rCap.trim() }];
    rType = ''; rCap = '';
  }
  function removeStagedRes(i: number) { stagedRes = stagedRes.filter((_, j) => j !== i); }

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
    const [{ data: cs, error: err }, { data: sk }, { data: rt }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, email, affiliation, status, home_unit_id')
        .eq('kind', 'card').in('home_unit_id', ids).order('full_name'),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('resource_type').select('id, name, unit').order('rank')
    ]);
    skills = ((sk as any[]) ?? []).map((s) => ({ id: s.id, name: s.name, parent_id: s.parent_id }));
    resTypes = ((rt as any[]) ?? []).map((r) => ({ id: r.id, name: r.name, unit: r.unit }));
    if (err) { error = err.message; loading = false; return; }
    cards = (cs as Card[]) ?? [];

    const cardIds = cards.map((c) => c.id);
    if (cardIds.length) {
      const [{ data: bal }, { data: ms }] = await Promise.all([
        supabase.from('stater_balance').select('owner_member_id, balance').in('owner_member_id', cardIds),
        supabase.from('member_skill').select('member_id, certified_level, skill_id, skill(name)').in('member_id', cardIds).not('certified_level', 'is', null)
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
    // a person is forged once: catch the obvious duplicate before the round-trip
    const dup = cards.find((c) => c.email.toLowerCase() === cEmail.trim().toLowerCase());
    if (dup) { error = get(t)('{name} is already a card — each person is forged only once.', { name: dup.full_name }); return; }
    busy = 'forge';
    const items = Object.entries(staged).map(([skill, level]) => ({ skill, level }));
    const { data: newId, error: err } = await supabase.rpc('forge_card', {
      p_full_name: cName.trim(), p_email: cEmail.trim(), p_unit: cUnit,
      p_affiliation: cAffil.trim() || null, p_items: items
    });
    if (err) { busy = ''; error = err.message; return; }

    // attach resources to the new card (steward review applies, same as members)
    const rows: any[] = [];
    const hrs = parseInt(cHours, 10);
    if (Number.isFinite(hrs) && hrs > 0 && laborType) {
      rows.push({ name: get(t)('Monthly time'), type_id: laborType.id, scope: 'member',
        holder_member_id: newId, capacity: `${hrs} hrs/mo`, availability: 'available' });
    }
    for (const r of stagedRes) {
      rows.push({ name: resTypeName(r.typeId), type_id: r.typeId, scope: 'member',
        holder_member_id: newId, capacity: r.capacity || null, availability: 'available' });
    }
    if (rows.length) {
      const { error: rErr } = await supabase.from('resource').insert(rows);
      if (rErr) { busy = ''; error = rErr.message; await load(); return; }
    }
    busy = '';
    msg = get(t)('Card forged for {name} — {s} skill(s), {r} resource(s) staged for review.',
      { name: cName.trim(), s: items.length, r: rows.length });
    cName = ''; cEmail = ''; cAffil = ''; staged = {}; cHours = ''; stagedRes = [];
    await load();
  }

  // ── card drawer: the one place to inspect & directly edit a person-card ──
  type DrawerRes = { id: string; name: string; capacity: string | null; availability: string; approval_status: string; type_id: string | null; resource_type: { name: string } | null };
  type DrawerProj = { project: { id: string; name: string; project_status: { name: string } | null } | null; project_role: { name: string } | null };
  type CommitPeriod = { year_month: string; committed_amount: number; token_equivalent: number; status: string; approval: string };
  type CommitRow = {
    id: string; project_id: string; commitment_type: string;
    skill_id: string | null; resource_id: string | null;
    skill: { name: string } | null; resource: { name: string } | null;
    stater_commitment_period: CommitPeriod[];
  };
  let selected = $state<Card | null>(null);
  let selRes = $state<DrawerRes[]>([]);
  let selProjects = $state<DrawerProj[]>([]);
  let selCommits = $state<Record<string, CommitRow[]>>({}); // project_id -> this card's commitments
  let selLoading = $state(false);
  let dMsg = $state(''); let dErr = $state(''); let dBusy = $state('');

  // drawer edit fields
  let dHours = $state('');
  let dResType = $state(''); let dResCap = $state('');
  let dStaged = $state<Record<string, string>>({}); // skillId -> level (new role cards to mint)
  let dNewSkill = $state(''); let dNewLevel = $state('apprentice');
  function skillNameOf(sid: string) { return skills.find((s) => s.id === sid)?.name ?? '—'; }

  // per-project monthly contributions (labor + resource), declared for the card
  function currentMonth() { return new Date().toISOString().slice(0, 7); }
  let dMonth = $state(currentMonth());
  let dpSkill = $state<Record<string, string>>({});  // project_id -> skill_id
  let dpHours = $state<Record<string, string>>({});  // project_id -> hours
  let dpRes = $state<Record<string, string>>({});    // project_id -> resource_id
  let dpQty = $state<Record<string, string>>({});    // project_id -> qty
  // approved, non-labor resources this card holds — committable to a project
  const committableRes = $derived(selRes.filter((r) => r.approval_status === 'approved' && r.resource_type?.name !== 'Labor'));
  // the card's certified skills — the only ones a labor commitment can use
  const cardCertSkills = $derived(selected ? (cardSkills[selected.id] ?? []) : []);
  function periodFor(rows: CommitRow[] | undefined, ym: string) {
    const out: { label: string; amount: number; str: number; approval: string }[] = [];
    for (const r of rows ?? []) {
      const p = r.stater_commitment_period.find((x) => x.year_month === ym);
      if (!p) continue;
      out.push({
        label: r.commitment_type === 'labor' ? (r.skill?.name ?? '—') : (r.resource?.name ?? '—'),
        amount: Number(p.committed_amount), str: Number(p.token_equivalent), approval: p.approval
      });
    }
    return out;
  }

  async function saveLabor(pid: string) {
    if (!selected) return;
    const sk = dpSkill[pid]; const hours = dpHours[pid];
    if (!sk || hours === undefined || hours === '') return;
    dErr = ''; dMsg = ''; dBusy = 'labor:' + pid;
    const { error: err } = await supabase.rpc('set_labor_commitment',
      { p: pid, sk, ym: dMonth, hours: Number(hours), p_as: selected.id });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dpHours = { ...dpHours, [pid]: '' };
    dMsg = get(t)('Monthly contribution recorded.');
    await refreshSel(selected);
  }
  async function saveResCommit(pid: string) {
    if (!selected) return;
    const res = dpRes[pid]; const qty = dpQty[pid];
    if (!res || qty === undefined || qty === '') return;
    dErr = ''; dMsg = ''; dBusy = 'rescommit:' + pid;
    const { error: err } = await supabase.rpc('set_resource_commitment',
      { p: pid, res, ym: dMonth, qty: Number(qty), p_as: selected.id });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dpQty = { ...dpQty, [pid]: '' };
    dMsg = get(t)('Monthly contribution recorded.');
    await refreshSel(selected);
  }

  const laborRes = $derived(selRes.find((r) => r.resource_type?.name === 'Labor') ?? null);
  const dStagedCount = $derived(Object.keys(dStaged).length);
  function dStageAt(skillId: string, level: string) {
    if (dStaged[skillId] === level) { const { [skillId]: _, ...rest } = dStaged; dStaged = rest; }
    else dStaged = { ...dStaged, [skillId]: level };
  }

  async function refreshSel(c: Card) {
    const [{ data: rs }, { data: pm }, { data: cm }] = await Promise.all([
      supabase.from('resource')
        .select('id, name, capacity, availability, approval_status, type_id, resource_type(name)')
        .eq('scope', 'member').eq('holder_member_id', c.id).order('name'),
      supabase.from('project_member')
        .select('project(id, name, project_status!project_status_id_fkey(name)), project_role(name)')
        .eq('member_id', c.id),
      supabase.from('stater_project_stake_commitment')
        .select('id, project_id, commitment_type, skill_id, resource_id, skill(name), resource(name), stater_commitment_period(year_month, committed_amount, token_equivalent, status, approval)')
        .eq('member_id', c.id)
    ]);
    selRes = (rs as DrawerRes[]) ?? [];
    selProjects = (pm as DrawerProj[]) ?? [];
    const byProj: Record<string, CommitRow[]> = {};
    for (const r of (cm as CommitRow[]) ?? []) (byProj[r.project_id] ??= []).push(r);
    selCommits = byProj;
  }

  async function openCard(c: Card) {
    selected = c; selLoading = true; selRes = []; selProjects = []; selCommits = {};
    dMsg = ''; dErr = ''; dStaged = {}; dResType = ''; dResCap = '';
    dMonth = currentMonth(); dpSkill = {}; dpHours = {}; dpRes = {}; dpQty = {};
    await refreshSel(c);
    // seed monthly-hours editor from the card's Labor resource
    const m = (laborRes?.capacity ?? '').match(/\d+/);
    dHours = m ? m[0] : '';
    selLoading = false;
  }
  function closeCard() { selected = null; }
  const cap = (s: string | null) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : '');

  // save monthly hours: update the card's Labor resource, or create it
  async function saveHours() {
    if (!selected) return;
    dErr = ''; dMsg = ''; dBusy = 'hours';
    const hrs = parseInt(dHours, 10);
    const capacity = Number.isFinite(hrs) && hrs > 0 ? `${hrs} hrs/mo` : null;
    let err;
    if (laborRes) {
      ({ error: err } = await supabase.from('resource').update({ capacity }).eq('id', laborRes.id));
    } else if (laborType && capacity) {
      ({ error: err } = await supabase.from('resource').insert({
        name: get(t)('Monthly time'), type_id: laborType.id, scope: 'member',
        holder_member_id: selected.id, capacity, availability: 'available'
      }));
    }
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dMsg = get(t)('Monthly hours updated.');
    await refreshSel(selected);
  }

  // add / remove a resource directly on the card (steward review applies)
  async function addResource() {
    if (!selected || !dResType) return;
    dErr = ''; dMsg = ''; dBusy = 'res';
    const { error: err } = await supabase.from('resource').insert({
      name: resTypeName(dResType), type_id: dResType, scope: 'member',
      holder_member_id: selected.id, capacity: dResCap.trim() || null, availability: 'available'
    });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dResType = ''; dResCap = '';
    dMsg = get(t)('Resource added — staged for review.');
    await refreshSel(selected);
  }
  async function removeResource(resId: string) {
    if (!selected) return;
    dErr = ''; dMsg = ''; dBusy = 'res:' + resId;
    const { error: err } = await supabase.from('resource').delete().eq('id', resId);
    dBusy = '';
    if (err) { dErr = err.message; return; }
    await refreshSel(selected);
  }

  // mint additional role cards onto the card (officer mint, no fee, goes to review)
  async function submitRoleCards() {
    if (!selected || dStagedCount === 0) return;
    dErr = ''; dMsg = ''; dBusy = 'cards';
    const items = Object.entries(dStaged).map(([skill, level]) => ({ skill, level }));
    const { error: err } = await supabase.rpc('mint_skillcard_batch', { p_member: selected.id, p_items: items });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dMsg = get(t)('{n} role-card request(s) staged for review.', { n: items.length });
    dStaged = {};
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
        {$t("Phase 1 is officers only — ordinary researchers aren't invited yet. Your job is to bring in the people who work under you as cards, then claim your projects. Work down the list.")}
      </p>
      <ol class="checklist">
        <li>{$t('Forge a card for each person who works under you — fill in who they are, stage the skills they bring and the resources they offer (compute, API, funding, data) and their monthly hours. Each person is forged only once.')}</li>
        <li>{@html $t("Claim your chapter's existing projects — open <a href='/projects'>Projects</a>, and on each one your chapter already runs use <strong>“Add a member directly”</strong> to seat your cards onto its roster (no application, no bond).")}</li>
        <li>{$t('Click any card below to open it and edit directly — adjust its monthly hours, mint role cards, stage resources, and declare its monthly contributions on each project it has joined. No mode-switching; the drawer is the card.')}</li>
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
        {$t('A card is one person who works under you — their identity, skills and resources, forged together. Each person is forged only once; the email is how they later claim the card. The whole card goes to review as one batch.')}
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
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Monthly hours')}</span>
          <input bind:value={cHours} type="number" min="0" placeholder="40" style="width:6rem;" />
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

      <!-- resource picker: stage the card's offerable resources -->
      <div class="stack" style="gap:.4rem; border-top:1px solid var(--border-2); padding-top:.55rem;">
        <span class="muted" style="font-size:.78rem;">{$t('Stage their resources (optional) — compute, API, funding, data… each goes to a steward for review.')}</span>
        {#if stagedRes.length > 0}
          <div class="row" style="flex-wrap:wrap; gap:.3rem;">
            {#each stagedRes as r, i}
              <span class="badge dim" style="font-size:.74rem;">
                {$t(resTypeName(r.typeId))}{#if r.capacity} · {r.capacity}{/if}
                <button class="x" onclick={() => removeStagedRes(i)} aria-label={$t('Remove')}>×</button>
              </span>
            {/each}
          </div>
        {/if}
        <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Resource type')}</span>
            <select bind:value={rType}>
              <option value="">{$t('Pick a type…')}</option>
              {#each offerTypes as ot}<option value={ot.id}>{$t(ot.name)}</option>{/each}
            </select>
          </label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Capacity / detail')}</span>
            <input bind:value={rCap} placeholder={$t('e.g. 4× A100, $5k, 2 datasets')} />
          </label>
          <button onclick={addStagedRes} disabled={!rType}>{$t('Add resource')}</button>
        </div>
      </div>

      <div class="row" style="gap:.5rem; align-items:center; border-top:1px solid var(--border-2); padding-top:.6rem;">
        <button class="stake" disabled={!cName.trim() || !cEmail.trim() || busy === 'forge'} onclick={forgeCard}>
          {busy === 'forge' ? $t('Forging…') : $t('Forge card')}</button>
        {#if stagedCount > 0 || stagedRes.length > 0 || cHours}
          <span class="muted" style="font-size:.78rem;">
            {$t('{s} skill(s), {r} resource(s) staged', { s: stagedCount, r: stagedRes.length + (cHours ? 1 : 0) })}</span>
          <button onclick={() => { staged = {}; stagedRes = []; cHours = ''; }} disabled={busy === 'forge'}>{$t('Clear')}</button>
        {/if}
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
        <div class="card-grid">
          {#each cards as c}
            <EntityCard
              type="Person"
              title={c.full_name}
              subtitle={c.email}
              status={cap(c.status)}
              statusKind={c.status === 'active' ? 'pos' : 'warn'}
              stats={[{ label: 'STR', value: (balances[c.id] ?? 0).toLocaleString() }]}
              onclick={() => openCard(c)}
            >
              {#snippet badges()}
                {#each (cardSkills[c.id] ?? []) as s}
                  <Medal name={$t(s.skill?.name ?? '—')} level={s.certified_level ?? 'apprentice'} size="sm" />
                {/each}
              {/snippet}
            </EntityCard>
          {/each}
        </div>
        <p class="muted" style="font-size:.8rem; margin:.2rem 0 0;">
          {$t('Click a card to open it and edit directly — its monthly hours, role cards and resources. Money moves on the card’s balance.')}
        </p>
      {/if}
    </div>
  {/if}
</div>

<!-- person-card drawer: the one place to inspect and act on a card -->
<CardDrawer
  open={selected !== null}
  type="Person"
  title={selected?.full_name ?? ''}
  subtitle={selected?.email ?? ''}
  onClose={closeCard}
>
  {#if selected}
    {#if dErr}<p style="color:var(--down); font-size:.82rem; margin:0;">{dErr}</p>{/if}
    {#if dMsg}<p class="pos" style="font-size:.82rem; margin:0;">{dMsg}</p>{/if}

    <section class="dsec">
      <h3>{$t('Identity')}</h3>
      <dl class="kv">
        <dt>{$t('Status')}</dt><dd><span class="badge {selected.status === 'active' ? 'pos' : 'warn'}">{$t(cap(selected.status))}</span></dd>
        {#if selected.affiliation}<dt>{$t('Affiliation')}</dt><dd>{selected.affiliation}</dd>{/if}
        {#if chapters.length > 1}<dt>{$t('Chapter')}</dt><dd>{unitName(selected.home_unit_id)}</dd>{/if}
        <dt>{$t('Balance')}</dt><dd><span class="chip"><span class="amt">{(balances[selected.id] ?? 0).toLocaleString()}</span> STR</span></dd>
      </dl>
    </section>

    <!-- monthly hours: edit the card's Labor resource directly -->
    <section class="dsec">
      <h3>{$t('Monthly hours')}</h3>
      <div class="row" style="gap:.4rem; align-items:flex-end;">
        <input type="number" min="0" bind:value={dHours} placeholder="40" style="width:6rem;" />
        <button onclick={saveHours} disabled={dBusy === 'hours'}>{dBusy === 'hours' ? $t('Saving…') : $t('Save')}</button>
      </div>
    </section>

    <!-- role cards: mint additional ones directly onto the card -->
    <section class="dsec">
      <h3>{$t('Role cards')}</h3>
      {#if (cardSkills[selected.id] ?? []).length > 0}
        <div class="row" style="flex-wrap:wrap; gap:.3rem;">
          {#each cardSkills[selected.id] as s}
            <Medal name={$t(s.skill?.name ?? '—')} level={s.certified_level ?? 'apprentice'} size="sm" />
          {/each}
        </div>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('No role cards yet.')}</p>
      {/if}
      <div class="row" style="gap:.4rem; align-items:flex-end; flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem; flex:1; min-width:120px;"><span class="muted" style="font-size:.72rem;">{$t('Skill')}</span>
          <select bind:value={dNewSkill}>
            <option value="">{$t('Pick a skill…')}</option>
            {#each domains as d}
              <optgroup label={d.name}>
                {#each leavesOf(d.id) as s}<option value={s.id}>{s.name}</option>{/each}
              </optgroup>
            {/each}
          </select>
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Level')}</span>
          <select bind:value={dNewLevel}>{#each LEVELS as lv}<option value={lv}>{$t(LEVEL_LABEL[lv])}</option>{/each}</select>
        </label>
        <button onclick={() => { if (dNewSkill) { dStageAt(dNewSkill, dNewLevel); dNewSkill = ''; } }} disabled={!dNewSkill}>{$t('Stage')}</button>
      </div>
      {#if dStagedCount > 0}
        <div class="row" style="flex-wrap:wrap; gap:.3rem; align-items:center;">
          {#each Object.entries(dStaged) as [sid, lv]}
            <span class="badge dim" style="font-size:.72rem;">{skillNameOf(sid)} · {$t(LEVEL_LABEL[lv])}
              <button class="x" onclick={() => dStageAt(sid, lv)} aria-label={$t('Remove')}>×</button></span>
          {/each}
          <button class="stake" onclick={submitRoleCards} disabled={dBusy === 'cards'}>{dBusy === 'cards' ? $t('Submitting…') : $t('Submit for review')}</button>
        </div>
      {/if}
    </section>

    <!-- resources: add / remove directly on the card -->
    <section class="dsec">
      <h3>{$t('Resources')}</h3>
      {#if selLoading}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Loading…')}</p>
      {:else if selRes.filter((r) => r.resource_type?.name !== 'Labor').length > 0}
        <ul class="dlist">
          {#each selRes.filter((r) => r.resource_type?.name !== 'Labor') as r}
            <li>
              <span>{$t(r.resource_type?.name ?? r.name)}{#if r.capacity} · {r.capacity}{/if}</span>
              <span class="row" style="gap:.4rem; align-items:center;">
                <span class="badge {r.approval_status === 'approved' ? 'pos' : r.approval_status === 'rejected' ? 'down' : 'warn'}" style="font-size:.68rem;">{$t(cap(r.approval_status))}</span>
                <button class="x" onclick={() => removeResource(r.id)} disabled={dBusy === 'res:' + r.id} aria-label={$t('Remove')}>×</button>
              </span>
            </li>
          {/each}
        </ul>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('No resources staged yet.')}</p>
      {/if}
      <div class="row" style="gap:.4rem; align-items:flex-end; flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem; flex:1; min-width:120px;"><span class="muted" style="font-size:.72rem;">{$t('Resource type')}</span>
          <select bind:value={dResType}>
            <option value="">{$t('Pick a type…')}</option>
            {#each offerTypes as ot}<option value={ot.id}>{$t(ot.name)}</option>{/each}
          </select>
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Capacity / detail')}</span>
          <input bind:value={dResCap} placeholder={$t('e.g. 4× A100, $5k')} style="width:9rem;" />
        </label>
        <button onclick={addResource} disabled={!dResType || dBusy === 'res'}>{$t('Add')}</button>
      </div>
    </section>

    <section class="dsec">
      <div class="row" style="justify-content:space-between; align-items:center; gap:.5rem;">
        <h3 style="margin:0;">{$t('Projects')}</h3>
        {#if selProjects.length > 0}
          <label class="row" style="gap:.3rem; align-items:center;"><span class="muted" style="font-size:.72rem;">{$t('Month')}</span>
            <input type="month" bind:value={dMonth} style="font-size:.78rem;" />
          </label>
        {/if}
      </div>
      {#if selLoading}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Loading…')}</p>
      {:else if selProjects.length > 0}
        <p class="muted" style="font-size:.74rem; margin:0;">{$t('Declare this card’s monthly contributions per project. STR accrues to the card; over-capacity months go to an officer for review.')}</p>
        <div class="pcommit-list">
          {#each selProjects as p}
            {@const pid = p.project?.id ?? ''}
            {@const declared = periodFor(selCommits[pid], dMonth)}
            <div class="pcommit">
              <div class="row" style="justify-content:space-between; align-items:baseline; gap:.5rem;">
                <a href={`/projects/${pid}`}>{p.project?.name}</a>
                <span class="muted" style="font-size:.7rem;">{$t(p.project_role?.name ?? '')} · {$t(p.project?.project_status?.name ?? '')}</span>
              </div>
              {#if declared.length > 0}
                <div class="row" style="flex-wrap:wrap; gap:.3rem;">
                  {#each declared as d}
                    <span class="badge {d.approval === 'needs_review' ? 'warn' : 'pos'}" style="font-size:.68rem;">
                      {$t(d.label)} · {d.amount} · {d.str} STR{#if d.approval === 'needs_review'} · {$t('review')}{/if}
                    </span>
                  {/each}
                </div>
              {/if}
              <!-- labor commitment: pick one of the card's certified skills + hours -->
              {#if cardCertSkills.length > 0}
                <div class="row" style="gap:.3rem; align-items:flex-end; flex-wrap:wrap;">
                  <select bind:value={dpSkill[pid]} style="font-size:.78rem; flex:1; min-width:110px;">
                    <option value="">{$t('Skill (labor)…')}</option>
                    {#each cardCertSkills as s}<option value={s.skill_id}>{$t(s.skill?.name ?? '—')}</option>{/each}
                  </select>
                  <input type="number" min="0" bind:value={dpHours[pid]} placeholder={$t('hrs')} style="width:4.5rem; font-size:.78rem;" />
                  <button onclick={() => saveLabor(pid)} disabled={!dpSkill[pid] || dpHours[pid] === undefined || dpHours[pid] === '' || dBusy === 'labor:' + pid}>{dBusy === 'labor:' + pid ? $t('Saving…') : $t('Mint')}</button>
                </div>
              {/if}
              <!-- resource commitment: pick one of the card's approved resources + qty -->
              {#if committableRes.length > 0}
                <div class="row" style="gap:.3rem; align-items:flex-end; flex-wrap:wrap;">
                  <select bind:value={dpRes[pid]} style="font-size:.78rem; flex:1; min-width:110px;">
                    <option value="">{$t('Resource…')}</option>
                    {#each committableRes as r}<option value={r.id}>{$t(r.resource_type?.name ?? r.name)}{#if r.capacity} · {r.capacity}{/if}</option>{/each}
                  </select>
                  <input type="number" min="0" bind:value={dpQty[pid]} placeholder={$t('qty')} style="width:4.5rem; font-size:.78rem;" />
                  <button onclick={() => saveResCommit(pid)} disabled={!dpRes[pid] || dpQty[pid] === undefined || dpQty[pid] === '' || dBusy === 'rescommit:' + pid}>{dBusy === 'rescommit:' + pid ? $t('Saving…') : $t('Mint')}</button>
                </div>
              {/if}
              {#if cardCertSkills.length === 0 && committableRes.length === 0}
                <p class="muted" style="font-size:.72rem; margin:0;">{$t('Add a role card or an approved resource above to mint contributions here.')}</p>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Not on any project yet. Seat this card onto a project from its Projects page.')}</p>
      {/if}
    </section>
  {/if}
</CardDrawer>

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }
  .dsec { display: flex; flex-direction: column; gap: .4rem; }
  .dsec h3 { margin: 0; font-size: .82rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .kv { display: grid; grid-template-columns: max-content 1fr; gap: .3rem .8rem; margin: 0; }
  .kv dt { color: var(--muted); font-size: .82rem; }
  .kv dd { margin: 0; font-size: .85rem; }
  .dlist { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: .4rem; }
  .dlist li { display: flex; align-items: center; justify-content: space-between; gap: .5rem; font-size: .85rem; }
  .dlist a { color: var(--accent); text-decoration: none; }
  .pcommit-list { display: flex; flex-direction: column; gap: .6rem; }
  .pcommit {
    display: flex; flex-direction: column; gap: .35rem;
    border: 1px solid var(--border); border-radius: 10px; padding: .55rem .6rem;
  }
  .pcommit a { color: var(--accent); text-decoration: none; font-size: .85rem; }
  .checklist { margin: 0; padding-left: 1.2rem; display: flex; flex-direction: column; gap: .4rem; }
  .checklist li { font-size: .85rem; line-height: 1.45; }
  .badge .x {
    background: transparent; border: none; cursor: pointer; color: inherit;
    font-size: .9rem; line-height: 1; padding: 0 0 0 .25rem; opacity: .65;
  }
  .badge .x:hover { opacity: 1; }
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
