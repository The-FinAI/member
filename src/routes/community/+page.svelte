<script lang="ts">
  import { onMount } from 'svelte';
  import { get } from 'svelte/store';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { PHASE2 } from '$lib/phase';
  import EntityCard from '$lib/EntityCard.svelte';
  import CardDrawer from '$lib/CardDrawer.svelte';
  import CountUp from '$lib/CountUp.svelte';
  import Medal from '$lib/Medal.svelte';
  import { t } from '$lib/i18n';

  type Row = {
    id: string;
    full_name: string;
    affiliation: string | null;
    status: string;
    kind: string;
    home_unit_id: string | null;
    member_position: { position: { name: string } }[];
  };
  type OrgUnit = { id: string; code: string; name: string; kind: string; description: string | null };
  type Skill = { id: string; name: string; parent_id: string | null };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  let rows = $state<Row[]>([]);
  let balanceOf = $state<Record<string, number>>({});
  let nominalOf = $state<Record<string, number>>({});
  let orgUnits = $state<OrgUnit[]>([]);
  let projectNominalOf = $state<Record<string, number>>({}); // project_id -> Σ member nominal
  let projectUnitOf = $state<Record<string, string | null>>({}); // project_id -> org_unit_id
  let loading = $state(true);
  let q = $state('');
  let myBalance = $state(0);
  // current user's membership status per unit (org_unit_id -> 'active' | 'pending' | …)
  let myUnitStatus = $state<Record<string, string>>({});

  // ---- crafts (skill ladder catalog) ----
  let skills = $state<Skill[]>([]);
  let holders = $state<Record<string, number>>({}); // certified holders per skill
  let myCert = $state<Record<string, string>>({});   // my certified_level per skill
  let mintFee = $state(10);
  let updateFee = $state(5);

  // top-level tab over the card families in the community
  type Tab = 'people' | 'chapters' | 'wgroups' | 'crafts';
  let tab = $state<Tab>('people');

  const TABS: { key: Tab; label: string }[] = [
    { key: 'people', label: 'People' },
    { key: 'chapters', label: 'Chapters' },
    { key: 'wgroups', label: 'Working Groups' },
    { key: 'crafts', label: 'Crafts' }
  ];

  const netWorthOf = (id: string) => (balanceOf[id] ?? 0) + (nominalOf[id] ?? 0);

  async function loadMyBalance() {
    if (!$member) return;
    const { data: bal } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle();
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
  }

  async function loadMyUnits() {
    if (!$member) return;
    const { data } = await supabase.from('org_unit_member')
      .select('org_unit_id, status').eq('member_id', $member.id);
    const m: Record<string, string> = {};
    for (const r of (data as { org_unit_id: string; status: string }[]) ?? []) m[r.org_unit_id] = r.status;
    myUnitStatus = m;
  }

  async function loadCrafts() {
    const [{ data: sk }, { data: ms }, { data: pol }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').not('certified_level', 'is', null),
      supabase.from('stater_policy').select('key, value').in('key', ['skillcard_mint_fee', 'skillcard_update_fee'])
    ]);
    skills = ((sk as Skill[]) ?? []);
    const h: Record<string, number> = {};
    for (const r of (ms as { skill_id: string }[]) ?? []) h[r.skill_id] = (h[r.skill_id] ?? 0) + 1;
    holders = h;
    for (const p of (pol as { key: string; value: number }[]) ?? []) {
      if (p.key === 'skillcard_mint_fee') mintFee = Number(p.value);
      if (p.key === 'skillcard_update_fee') updateFee = Number(p.value);
    }
  }
  async function loadMyCert() {
    if (!$member) { myCert = {}; return; }
    const { data } = await supabase.from('member_skill')
      .select('skill_id, certified_level').eq('member_id', $member.id).not('certified_level', 'is', null);
    const c: Record<string, string> = {};
    for (const r of (data as { skill_id: string; certified_level: string }[]) ?? []) c[r.skill_id] = r.certified_level;
    myCert = c;
  }

  onMount(async () => {
    const initial = $page.url.searchParams.get('tab');
    if (initial === 'chapters' || initial === 'wgroups' || initial === 'people' || initial === 'crafts') tab = initial;
    if (!supabaseConfigured) { loading = false; return; }
    const [{ data }, { data: bals }, { data: nom }, { data: ou }, { data: prj }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, affiliation, status, kind, home_unit_id, member_position(position(name))')
        .order('full_name'),
      supabase.from('stater_balance').select('owner_member_id, balance').not('owner_member_id', 'is', null),
      supabase.from('stater_project_member_nominal').select('project_id, member_id, nominal'),
      supabase.from('org_unit').select('id, code, name, kind, description').order('rank'),
      supabase.from('project').select('id, org_unit_id')
    ]);
    loadCrafts();
    rows = (data as Row[]) ?? [];
    const bmap: Record<string, number> = {};
    for (const b of (bals as { owner_member_id: string; balance: number }[]) ?? [])
      bmap[b.owner_member_id] = Number(b.balance) || 0;
    balanceOf = bmap;
    const nmap: Record<string, number> = {};
    const pnmap: Record<string, number> = {};
    for (const n of (nom as { project_id: string; member_id: string; nominal: number }[]) ?? []) {
      nmap[n.member_id] = (nmap[n.member_id] ?? 0) + (Number(n.nominal) || 0);
      pnmap[n.project_id] = (pnmap[n.project_id] ?? 0) + (Number(n.nominal) || 0);
    }
    nominalOf = nmap;
    projectNominalOf = pnmap;
    orgUnits = (ou as OrgUnit[]) ?? [];
    const pumap: Record<string, string | null> = {};
    for (const p of (prj as { id: string; org_unit_id: string | null }[]) ?? []) pumap[p.id] = p.org_unit_id ?? null;
    projectUnitOf = pumap;
    loading = false;
    const unsub = member.subscribe((m) => { if (m) { loadMyBalance(); loadMyUnits(); loadMyCert(); } });
    return unsub;
  });

  // ---- people ----
  const peopleFiltered = $derived(
    [...rows]
      .sort((a, b) => netWorthOf(b.id) - netWorthOf(a.id) || a.full_name.localeCompare(b.full_name))
      .filter((r) => r.full_name.toLowerCase().includes(q.toLowerCase()))
  );
  function positionsOf(r: Row) {
    return r.member_position?.map((p) => p.position?.name).filter(Boolean).join(', ') || '';
  }

  // ---- units (chapters / working groups) ----
  type UnitRow = { id: string; code: string; name: string; description: string | null; total: number; count: number };
  const memberCountByUnit = $derived.by<Record<string, number>>(() => {
    const c: Record<string, number> = {};
    for (const r of rows) if (r.home_unit_id) c[r.home_unit_id] = (c[r.home_unit_id] ?? 0) + 1;
    return c;
  });
  const unitRanked = $derived.by<UnitRow[]>(() => {
    if (tab === 'chapters') {
      const chapters = orgUnits.filter((u) => u.kind === 'chapter');
      const total: Record<string, number> = {};
      for (const r of rows) {
        if (!r.home_unit_id) continue;
        total[r.home_unit_id] = (total[r.home_unit_id] ?? 0) + netWorthOf(r.id);
      }
      return chapters
        .map((u) => ({ id: u.id, code: u.code, name: u.name, description: u.description, total: total[u.id] ?? 0, count: memberCountByUnit[u.id] ?? 0 }))
        .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
    }
    if (tab === 'wgroups') {
      const wgs = orgUnits.filter((u) => u.kind === 'working_group');
      const total: Record<string, number> = {};
      const count: Record<string, number> = {};
      for (const [pid, str] of Object.entries(projectNominalOf)) {
        const uid = projectUnitOf[pid];
        if (uid) total[uid] = (total[uid] ?? 0) + str;
      }
      for (const [, uid] of Object.entries(projectUnitOf)) {
        if (uid) count[uid] = (count[uid] ?? 0) + 1;
      }
      return wgs
        .map((u) => ({ id: u.id, code: u.code, name: u.name, description: u.description, total: total[u.id] ?? 0, count: count[u.id] ?? 0 }))
        .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
    }
    return [];
  });
  const unitFiltered = $derived(
    unitRanked.filter((u) => u.name.toLowerCase().includes(q.toLowerCase()) || u.code.toLowerCase().includes(q.toLowerCase()))
  );

  function onTab(tk: Tab) {
    tab = tk;
    q = '';
  }

  // ---- crafts catalog: domains → leaf skills ----
  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills
      .filter((s) => s.parent_id === domainId && s.name.toLowerCase().includes(q.toLowerCase()))
      .sort((a, b) => a.name.localeCompare(b.name));
  }
  const certifiedCount = $derived(Object.keys(myCert).length);

  // ---- quick-view drawer ----
  type DrawerSel =
    | { kind: 'person'; row: Row }
    | { kind: 'unit'; unit: UnitRow; unitKind: 'chapter' | 'working_group' }
    | { kind: 'skill'; skill: Skill };
  let sel = $state<DrawerSel | null>(null);
  let drawerBusy = $state(false);
  let drawerErr = $state('');
  let drawerMsg = $state('');
  let cardLevel = $state('apprentice');
  const drawerOpen = $derived(sel !== null);
  function openPerson(r: Row) { sel = { kind: 'person', row: r }; drawerErr = ''; drawerMsg = ''; }
  function openUnit(u: UnitRow) { sel = { kind: 'unit', unit: u, unitKind: tab === 'chapters' ? 'chapter' : 'working_group' }; drawerErr = ''; drawerMsg = ''; }
  function openSkill(s: Skill) { sel = { kind: 'skill', skill: s }; drawerErr = ''; drawerMsg = ''; cardLevel = 'apprentice'; }
  function closeDrawer() { sel = null; }

  // mint when first certifying this skill, otherwise an update (level-up)
  const cardFeeFor = (skillId: string) => (myCert[skillId] ? updateFee : mintFee);
  async function requestCard(skillId: string) {
    drawerBusy = true; drawerErr = ''; drawerMsg = '';
    const { error: err } = await supabase.rpc('submit_skillcard_request', { p_skill: skillId, p_level: cardLevel, p_as: null });
    drawerBusy = false;
    if (err) { drawerErr = err.message; return; }
    drawerMsg = get(t)('Request sent — a reviewer will approve or reject it.');
    await Promise.all([loadCrafts(), loadMyCert(), loadMyBalance()]);
  }

  // ---- permission-aware actions ----
  const isMe = (id: string) => !!($member && id === $member.id);
  function isOfficerOf(unitId: string) {
    return $capabilities.has('manage_members') || $officerUnits.some((u) => u.unit_id === unitId);
  }
  function canManagePerson(r: Row) {
    return isMe(r.id) || $capabilities.has('manage_members') ||
      (!!r.home_unit_id && $officerUnits.some((u) => u.unit_id === r.home_unit_id));
  }
  async function applyUnit(unitId: string) {
    drawerBusy = true; drawerErr = ''; drawerMsg = '';
    const { error: err } = await supabase.rpc('apply_to_unit', { p_unit: unitId });
    drawerBusy = false;
    if (err) { drawerErr = err.message; return; }
    drawerMsg = get(t)('Application sent — an officer will review it.');
    await loadMyUnits();
  }
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">{$t('Community')}</h1>
      <span class="muted" style="font-size:.85rem;">
        {#if tab === 'people'}{$t('Everyone in the community — open a card to see their work, skills & standing.')}
        {:else if tab === 'chapters'}{$t('The three regional chapters. Open one to apply to join.')}
        {:else if tab === 'wgroups'}{$t('The working groups driving the research agenda. Open one to apply to join.')}
        {:else}{$t('The craft ladder — every certifiable skill. Open one to see who holds it and request a role card.')}{/if}
      </span>
    </div>
    {#if $member}<span class="chip"><span class="amt"><CountUp value={myBalance} /></span> STR</span>{/if}
  </div>

  <!-- top-level tabs -->
  <div class="row" style="gap:.4rem; flex-wrap:wrap;">
    {#each TABS as tb}
      <span class="chip toggle {tab === tb.key ? 'on' : ''}" role="button" tabindex="0"
        onclick={() => onTab(tb.key)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') onTab(tb.key); }}
      >{$t(tb.label)}</span>
    {/each}
  </div>

  <!-- controls: search -->
  <div class="row" style="gap:.6rem; flex-wrap:wrap; align-items:center;">
    <div class="search" style="flex:1; min-width:220px; max-width:340px;">
      <input placeholder={tab === 'people' ? $t('Search by name…') : $t('Search…')} bind:value={q} />
    </div>
  </div>

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>

  <!-- ============ PEOPLE ============ -->
  {:else if tab === 'people'}
    {#if peopleFiltered.length === 0}
      <div class="card"><p class="muted">{$t('No members.')}</p></div>
    {:else}
      <div class="card-grid">
        {#each peopleFiltered as r (r.id)}
          <EntityCard
            type={r.kind === 'card' ? 'Member card' : 'Member'}
            title={r.full_name}
            subtitle={r.affiliation ?? '—'}
            status={positionsOf(r) || ($member && r.id === $member.id ? 'you' : '')}
            statusKind={positionsOf(r) ? 'dim' : 'pos'}
            accent={!!($member && r.id === $member.id)}
            stats={[
              { label: 'Nominal', value: (nominalOf[r.id] ?? 0).toLocaleString() },
              { label: 'Net worth', value: netWorthOf(r.id).toLocaleString() }
            ]}
            onclick={() => openPerson(r)}
          />
        {/each}
      </div>
    {/if}

  <!-- ============ CRAFTS (skill ladder catalog) ============ -->
  {:else if tab === 'crafts'}
    {#if $member}
      <span class="muted" style="font-size:.82rem; margin-top:-.4rem;">{$t('{n} skills certified', { n: certifiedCount })}</span>
    {/if}
    {#if skills.length === 0}
      <div class="card"><p class="muted">{$t('No skills yet.')}</p></div>
    {:else}
      <div class="craft-grid">
        {#each domains as d}
          {@const leaves = leavesOf(d.id)}
          {#if leaves.length > 0}
            <div class="card stack" style="gap:.4rem;">
              <h3 style="margin:0; font-size:.95rem;">{d.name}</h3>
              <div class="stack" style="gap:.15rem;">
                {#each leaves as s}
                  <button class="tree-leaf" onclick={() => openSkill(s)}>
                    <span>{s.name}</span>
                    <span class="row" style="gap:.4rem; align-items:center;">
                      {#if myCert[s.id]}<Medal level={myCert[s.id]} size="sm" />{/if}
                      {#if holders[s.id]}<span class="muted" style="font-size:.72rem;">{holders[s.id]}⚒</span>{/if}
                    </span>
                  </button>
                {/each}
              </div>
            </div>
          {/if}
        {/each}
      </div>
    {/if}

  <!-- ============ CHAPTERS / WORKING GROUPS ============ -->
  {:else}
    {#if unitFiltered.length === 0}
      <div class="card"><p class="muted">{tab === 'chapters' ? $t('No chapters.') : $t('No working groups.')}</p></div>
    {:else}
      <div class="card-grid">
        {#each unitFiltered as u (u.id)}
          <EntityCard
            type={tab === 'chapters' ? 'Chapter' : 'Working Group'}
            title={u.name}
            subtitle={u.description ?? u.code}
            status={u.code}
            statusKind="dim"
            stats={tab === 'chapters'
              ? [{ label: 'Members', value: String(u.count) }, { label: 'Combined net worth', value: u.total.toLocaleString() }]
              : [{ label: 'Projects', value: String(u.count) }, { label: 'Staked STR', value: u.total.toLocaleString() }]}
            onclick={() => openUnit(u)}
          />
        {/each}
      </div>
    {/if}
  {/if}
</div>

<!-- quick-view drawer -->
{#if sel}
  {#if sel.kind === 'person'}
    {@const r = sel.row}
    <CardDrawer
      open={drawerOpen}
      type={r.kind === 'card' ? 'Member card' : 'Member'}
      title={r.full_name}
      subtitle={r.affiliation ?? '—'}
      onClose={closeDrawer}
    >
      <div class="dstats">
        <div class="dstat"><span class="dv">{(nominalOf[r.id] ?? 0).toLocaleString()}</span><span class="dl">{$t('Nominal')}</span></div>
        <div class="dstat"><span class="dv">{(balanceOf[r.id] ?? 0).toLocaleString()}</span><span class="dl">{$t('Liquid')}</span></div>
        <div class="dstat"><span class="dv accent">{netWorthOf(r.id).toLocaleString()}</span><span class="dl">{$t('Net worth')}</span></div>
      </div>
      {#if positionsOf(r)}
        <div><span class="dl">{$t('Position')}</span><div>{positionsOf(r)}</div></div>
      {/if}
      {#if r.kind === 'card'}
        <p class="muted" style="font-size:.8rem; margin:0;">{$t('A member-card: managed by a chapter officer; value is custodial until the person signs up.')}</p>
      {/if}
      {#snippet actions()}
        {#if isMe(r.id)}
          <a class="btn" href="/">{$t('Edit my profile')} →</a>
          <a class="btn ghost" href={`/members/${r.id}`}>{$t('Open full page')} →</a>
        {:else if canManagePerson(r)}
          <a class="btn" href={`/members/${r.id}`}>{$t('Manage')} →</a>
        {:else}
          <a class="btn" href={`/members/${r.id}`}>{$t('Open full page')} →</a>
        {/if}
      {/snippet}
    </CardDrawer>
  {:else if sel.kind === 'skill'}
    {@const s = sel.skill}
    {@const mine = myCert[s.id] ?? null}
    <CardDrawer
      open={drawerOpen}
      type={$t('Craft')}
      title={s.name}
      subtitle={mine ? $t(LEVEL_LABEL[mine]) : $t('Uncertified')}
      onClose={closeDrawer}
    >
      <div class="dstats">
        <div class="dstat"><span class="dv">{holders[s.id] ?? 0}</span><span class="dl">{$t('Certified holders')}</span></div>
        {#if mine}<div class="dstat"><span class="dv accent">{$t(LEVEL_LABEL[mine])}</span><span class="dl">{$t('Your level')}</span></div>{/if}
      </div>
      <p class="muted" style="font-size:.8rem; margin:0;">{$t('A certified skill is a role card — climb Apprentice → Journeyman → Craftsman → Master. A reviewer approves each request.')}</p>
      {#if PHASE2 && $member}
        <label class="stack" style="gap:.3rem;">
          <span class="dl">{$t('Request role card at')}</span>
          <select bind:value={cardLevel}>
            {#each LEVELS as lv}<option value={lv} disabled={levelRank(mine) >= levelRank(lv)}>{$t(LEVEL_LABEL[lv])}</option>{/each}
          </select>
        </label>
        <p class="muted" style="font-size:.74rem; margin:0;">
          {mine ? $t('Update fee {n} STR — escrowed and refunded if rejected.', { n: updateFee }) : $t('Mint fee {n} STR — escrowed and refunded if rejected.', { n: mintFee })}
        </p>
        {#if cardFeeFor(s.id) > myBalance}<span class="neg" style="font-size:.75rem;">{$t('Insufficient balance ({bal} STR).', { bal: myBalance })}</span>{/if}
      {:else if !PHASE2}
        <p class="muted" style="font-size:.78rem; margin:0;">{$t('In Phase 1, officers mint role cards onto their members. Self-service requests open in Phase 2.')}</p>
      {/if}
      {#if drawerErr}<p class="neg" style="font-size:.82rem; margin:0;">{drawerErr}</p>{/if}
      {#if drawerMsg}<p class="up" style="font-size:.82rem; margin:0;">{drawerMsg}</p>{/if}
      {#snippet actions()}
        {#if PHASE2 && $member}
          <button class="btn" onclick={() => requestCard(s.id)} disabled={drawerBusy || cardFeeFor(s.id) > myBalance}>
            {drawerBusy ? $t('Sending…') : $t('Request · {n} STR', { n: cardFeeFor(s.id) })}</button>
        {/if}
      {/snippet}
    </CardDrawer>
  {:else}
    {@const u = sel.unit}
    <CardDrawer
      open={drawerOpen}
      type={sel.unitKind === 'chapter' ? 'Chapter' : 'Working Group'}
      title={u.name}
      subtitle={u.description ?? u.code}
      onClose={closeDrawer}
    >
      <div class="dstats">
        {#if sel.unitKind === 'chapter'}
          <div class="dstat"><span class="dv">{u.count}</span><span class="dl">{$t('Members')}</span></div>
          <div class="dstat"><span class="dv accent">{u.total.toLocaleString()}</span><span class="dl">{$t('Combined net worth')}</span></div>
        {:else}
          <div class="dstat"><span class="dv">{u.count}</span><span class="dl">{$t('Projects')}</span></div>
          <div class="dstat"><span class="dv accent">{u.total.toLocaleString()}</span><span class="dl">{$t('Staked STR')}</span></div>
        {/if}
      </div>
      <div><span class="dl">{$t('Code')}</span><div class="mono">{u.code}</div></div>
      {#if isOfficerOf(u.id)}
        <p class="muted" style="font-size:.8rem; margin:0;">{$t('You serve here — manage members, applications & projects from the full page.')}</p>
      {:else if myUnitStatus[u.id] === 'active'}
        <span class="badge up" style="align-self:flex-start;">{$t('You are a member')}</span>
      {:else if myUnitStatus[u.id] === 'pending'}
        <span class="badge warn" style="align-self:flex-start;">{$t('Application pending')}</span>
      {/if}
      {#if drawerErr}<p class="neg" style="font-size:.82rem; margin:0;">{drawerErr}</p>{/if}
      {#if drawerMsg}<p class="up" style="font-size:.82rem; margin:0;">{drawerMsg}</p>{/if}
      {#snippet actions()}
        {#if isOfficerOf(u.id)}
          <a class="btn" href={`/units/${u.id}`}>{$t('Manage')} →</a>
        {:else if $member && !myUnitStatus[u.id]}
          <button class="btn" onclick={() => applyUnit(u.id)} disabled={drawerBusy}>
            {drawerBusy ? $t('Sending…') : $t('Apply to join')}</button>
          <a class="btn ghost" href={`/units/${u.id}`}>{$t('Open full page')} →</a>
        {:else}
          <a class="btn" href={`/units/${u.id}`}>{$t('Open full page')} →</a>
        {/if}
      {/snippet}
    </CardDrawer>
  {/if}
{/if}

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }
  .dstats { display: flex; flex-wrap: wrap; gap: 1.2rem; }
  .dstat { display: flex; flex-direction: column; gap: .1rem; }
  .dstat .dv { font-family: var(--font-mono); font-weight: 700; font-size: 1.1rem; }
  .dstat .dv.accent { color: var(--accent); }
  .dl { font-size: .7rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .btn {
    display: inline-flex; align-items: center; gap: .3rem; padding: .5rem .9rem;
    background: var(--accent); color: #fff; border: 1px solid transparent; border-radius: 8px;
    text-decoration: none; font: inherit; font-weight: 600; cursor: pointer;
  }
  .btn:disabled { opacity: .55; cursor: not-allowed; }
  .btn.ghost { background: transparent; color: var(--accent); border-color: var(--border); }
  .craft-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: .8rem; align-items: start; }
  .tree-leaf {
    display: flex; justify-content: space-between; align-items: center; gap: .5rem;
    width: 100%; text-align: left; padding: .35rem .55rem; border-radius: 6px;
    background: transparent; border: 1px solid transparent; color: inherit; cursor: pointer; font-size: .85rem;
  }
  .tree-leaf:hover { background: var(--card-2); }
  .search input { width: 100%; }
</style>
