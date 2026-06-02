<script lang="ts">
  import { onMount } from 'svelte';
  import { get } from 'svelte/store';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import EntityCard from '$lib/EntityCard.svelte';
  import CardDrawer from '$lib/CardDrawer.svelte';
  import CountUp from '$lib/CountUp.svelte';
  import MemberDetail from '$lib/MemberDetail.svelte';
  import UnitDetail from '$lib/UnitDetail.svelte';
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

  // top-level tab over the card families in the community
  type Tab = 'people' | 'chapters' | 'wgroups' | 'badges';
  let tab = $state<Tab>('people');

  const TABS: { key: Tab; label: string }[] = [
    { key: 'people', label: 'People' },
    { key: 'chapters', label: 'Chapters' },
    { key: 'wgroups', label: 'Working Groups' },
    { key: 'badges', label: 'Badges' }
  ];

  // ---- badge catalog (the former "Guild / crafts") ----
  // A certified skill IS a badge. The catalog lists every certifiable skill
  // (a leaf in the skill tree) as a badge type, with the members who hold it.
  type Skill = { id: string; name: string; parent_id: string | null };
  type Holder = { member_id: string; full_name: string; level: string };
  let skills = $state<Skill[]>([]);
  let holdersOf = $state<Record<string, Holder[]>>({});
  const RANK: Record<string, number> = { apprentice: 0, journeyman: 1, craftsman: 2, master: 3 };
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };

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

  onMount(async () => {
    const initial = $page.url.searchParams.get('tab');
    if (initial === 'chapters' || initial === 'wgroups' || initial === 'people' || initial === 'badges') tab = initial;
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

    // badge catalog data (skill tree + certified holders)
    const [{ data: sk }, { data: msk }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill')
        .select('skill_id, member_id, certified_level, member:member_id(full_name)')
        .not('certified_level', 'is', null)
    ]);
    skills = (sk as Skill[]) ?? [];
    const hmap: Record<string, Holder[]> = {};
    for (const r of (msk as { skill_id: string; member_id: string; certified_level: string; member: { full_name: string } | null }[]) ?? []) {
      (hmap[r.skill_id] ??= []).push({ member_id: r.member_id, full_name: r.member?.full_name ?? '—', level: r.certified_level });
    }
    holdersOf = hmap;
    const unsub = member.subscribe((m) => { if (m) { loadMyBalance(); loadMyUnits(); } });
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
  // units the current user serves as an officer of — pinned to the top of the
  // list and badged, so an officer lands on their own unit without hunting.
  const myUnitIds = $derived(new Set($officerUnits.map((o) => o.unit_id)));
  const unitFiltered = $derived(
    unitRanked
      .filter((u) => u.name.toLowerCase().includes(q.toLowerCase()) || u.code.toLowerCase().includes(q.toLowerCase()))
      .sort((a, b) => Number(myUnitIds.has(b.id)) - Number(myUnitIds.has(a.id)))
  );

  // ---- badge catalog ----
  type BadgeType = { id: string; name: string; domain: string; holders: Holder[]; top: string };
  const badgeCatalog = $derived.by<BadgeType[]>(() => {
    if (!skills.length) return [];
    const parentIds = new Set(skills.map((s) => s.parent_id).filter(Boolean));
    const nameOf = (id: string | null) => (id ? (skills.find((s) => s.id === id)?.name ?? '') : '');
    // a leaf (certifiable skill) is any skill that is nobody's parent
    return skills
      .filter((s) => !parentIds.has(s.id))
      .map((s) => {
        const holders = (holdersOf[s.id] ?? []).slice()
          .sort((a, b) => (RANK[b.level] ?? 0) - (RANK[a.level] ?? 0) || a.full_name.localeCompare(b.full_name));
        return { id: s.id, name: s.name, domain: nameOf(s.parent_id), holders, top: holders[0]?.level ?? '' };
      })
      .sort((a, b) => b.holders.length - a.holders.length || a.name.localeCompare(b.name));
  });
  const badgesFiltered = $derived(
    badgeCatalog.filter((c) =>
      c.name.toLowerCase().includes(q.toLowerCase()) || c.domain.toLowerCase().includes(q.toLowerCase()))
  );

  function onTab(tk: Tab) {
    tab = tk;
    q = '';
  }

  // ---- quick-view drawer ----
  type DrawerSel =
    | { kind: 'person'; row: Row }
    | { kind: 'unit'; unit: UnitRow; unitKind: 'chapter' | 'working_group' }
    | { kind: 'badge'; badge: BadgeType };
  let sel = $state<DrawerSel | null>(null);
  let drawerBusy = $state(false);
  let drawerErr = $state('');
  let drawerMsg = $state('');
  const drawerOpen = $derived(sel !== null);
  function openPerson(r: Row) { sel = { kind: 'person', row: r }; drawerErr = ''; drawerMsg = ''; }
  function openUnit(u: UnitRow) { sel = { kind: 'unit', unit: u, unitKind: tab === 'chapters' ? 'chapter' : 'working_group' }; drawerErr = ''; drawerMsg = ''; }
  function openBadge(c: BadgeType) { sel = { kind: 'badge', badge: c }; drawerErr = ''; drawerMsg = ''; }
  function closeDrawer() { sel = null; }

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
        {:else if tab === 'badges'}{$t('The badge catalog — every certifiable skill. Open one to see who holds it.')}
        {:else}{$t('The working groups driving the research agenda. Open one to apply to join.')}{/if}
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

  <!-- ============ BADGE CATALOG ============ -->
  {:else if tab === 'badges'}
    {#if badgesFiltered.length === 0}
      <div class="card"><p class="muted">{$t('No badges yet.')}</p></div>
    {:else}
      <div class="card-grid">
        {#each badgesFiltered as c (c.id)}
          <EntityCard
            type="Badge"
            title={c.name}
            subtitle={c.domain || '—'}
            status={c.holders.length ? $t('{n} holders', { n: c.holders.length }) : $t('No holders yet')}
            statusKind={c.holders.length ? 'pos' : 'dim'}
            stats={[
              { label: 'Holders', value: String(c.holders.length) },
              { label: 'Top level', value: c.top ? $t(LEVEL_LABEL[c.top]) : '—' }
            ]}
            onclick={() => openCardType(c)}
          />
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
            status={myUnitIds.has(u.id) ? $t('Your unit') : u.code}
            statusKind={myUnitIds.has(u.id) ? 'warn' : 'dim'}
            accent={myUnitIds.has(u.id)}
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
      <MemberDetail id={r.id} breadcrumbs={false} />
      {#snippet actions()}
        <a class="btn ghost" href={`/members/${r.id}`}>{$t('Open full page')} →</a>
      {/snippet}
    </CardDrawer>
  {:else if sel.kind === 'unit'}
    {@const u = sel.unit}
    <CardDrawer
      open={drawerOpen}
      type={sel.unitKind === 'chapter' ? 'Chapter' : 'Working Group'}
      title={u.name}
      subtitle={u.description ?? u.code}
      onClose={closeDrawer}
    >
      <UnitDetail id={u.id} breadcrumbs={false} />
      {#snippet actions()}
        <a class="btn ghost" href={`/units/${u.id}`}>{$t('Open full page')} →</a>
      {/snippet}
    </CardDrawer>
  {:else}
    {@const c = sel.badge}
    <CardDrawer
      open={drawerOpen}
      type="Badge"
      title={c.name}
      subtitle={c.domain || '—'}
      onClose={closeDrawer}
    >
      <div class="stack">
        <p class="muted" style="font-size:.85rem; margin:0;">
          {$t('A certified skill, ranked Apprentice → Journeyman → Craftsman → Master. In Phase 1, officers award badges to their members for review.')}
        </p>
        <h3 style="margin:.3rem 0 0;">{$t('Holders')}{#if c.holders.length}<span class="muted" style="font-weight:400;"> · {c.holders.length}</span>{/if}</h3>
        {#if c.holders.length === 0}
          <p class="muted" style="margin:0;">{$t('No holders yet.')}</p>
        {:else}
          <ul style="margin:0; padding:0; list-style:none;">
            {#each c.holders as h}
              <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.45rem 0;">
                <a href={`/members/${h.member_id}`} class="p-name">{h.full_name}</a>
                <Medal level={h.level} size="sm" />
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    </CardDrawer>
  {/if}
{/if}

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }
  .btn {
    display: inline-flex; align-items: center; gap: .3rem; padding: .5rem .9rem;
    background: var(--accent); color: #fff; border: 1px solid transparent; border-radius: 8px;
    text-decoration: none; font: inherit; font-weight: 600; cursor: pointer;
  }
  .btn:disabled { opacity: .55; cursor: not-allowed; }
  .btn.ghost { background: transparent; color: var(--accent); border-color: var(--border); }
  .search input { width: 100%; }
</style>
