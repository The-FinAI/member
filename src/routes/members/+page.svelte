<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import CountUp from '$lib/CountUp.svelte';
  import { t } from '$lib/i18n';

  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }

  type Row = {
    id: string;
    full_name: string;
    affiliation: string | null;
    status: string;
    kind: string;
    home_unit_id: string | null;
    member_position: { position: { name: string } }[];
  };
  type OrgUnit = { id: string; code: string; name: string; kind: string };

  let rows = $state<Row[]>([]);
  let balanceOf = $state<Record<string, number>>({});
  let nominalOf = $state<Record<string, number>>({});
  let orgUnits = $state<OrgUnit[]>([]);
  let projectNominalOf = $state<Record<string, number>>({}); // project_id -> Σ member nominal
  let projectUnitOf = $state<Record<string, string | null>>({}); // project_id -> org_unit_id
  let loading = $state(true);
  let q = $state('');
  let myBalance = $state(0);

  // multi-board: member boards rank people; unit boards rank chapters / working groups
  type Board = 'contribution' | 'networth' | 'wealth' | 'chapters' | 'wgroups';
  let board = $state<Board>('contribution');
  const BOARDS: { key: Board; label: string; blurb: string }[] = [
    { key: 'contribution', label: 'Contribution', blurb: 'Lifetime nominal STR minted through declared work & verified milestones.' },
    { key: 'networth', label: 'Net worth', blurb: 'Liquid STR plus nominal STR still accruing in live projects.' },
    { key: 'wealth', label: 'Wealth', blurb: 'Liquid, spendable STR held right now.' },
    { key: 'chapters', label: 'Chapters', blurb: 'Chapters ranked by the combined net worth of their members.' },
    { key: 'wgroups', label: 'Working Groups', blurb: 'Working Groups ranked by the STR staked across their projects.' }
  ];
  const isUnitBoard = $derived(board === 'chapters' || board === 'wgroups');

  const netWorthOf = (id: string) => (balanceOf[id] ?? 0) + (nominalOf[id] ?? 0);
  function metricOf(id: string): number {
    switch (board) {
      case 'contribution': return nominalOf[id] ?? 0;
      case 'networth': return netWorthOf(id);
      case 'wealth': return balanceOf[id] ?? 0;
      default: return 0;
    }
  }

  async function loadMyBalance() {
    if (!$member) return;
    const { data: bal } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle();
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [{ data }, { data: bals }, { data: nom }, { data: ou }, { data: prj }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, affiliation, status, kind, home_unit_id, member_position(position(name))')
        .order('full_name'),
      supabase.from('stater_balance').select('owner_member_id, balance').not('owner_member_id', 'is', null),
      supabase.from('stater_project_member_nominal').select('project_id, member_id, nominal'),
      supabase.from('org_unit').select('id, code, name, kind').order('rank'),
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
    const unsub = member.subscribe((m) => { if (m) loadMyBalance(); });
    return unsub;
  });

  // ---- member boards ----
  const ranked = $derived(
    [...rows].sort((a, b) =>
      metricOf(b.id) - metricOf(a.id) ||
      netWorthOf(b.id) - netWorthOf(a.id) ||
      a.full_name.localeCompare(b.full_name)
    )
  );
  const filtered = $derived(
    ranked
      .map((r, i) => ({ row: r, rank: i + 1 }))
      .filter(({ row }) => row.full_name.toLowerCase().includes(q.toLowerCase()))
  );
  const maxMetric = $derived(Math.max(1, ...ranked.map((r) => metricOf(r.id))));

  // ---- unit boards (chapters / working groups) ----
  type UnitRow = { id: string; code: string; name: string; total: number; count: number };
  const unitRanked = $derived.by<UnitRow[]>(() => {
    if (board === 'chapters') {
      const chapters = orgUnits.filter((u) => u.kind === 'chapter');
      const total: Record<string, number> = {};
      const count: Record<string, number> = {};
      for (const r of rows) {
        if (!r.home_unit_id) continue;
        total[r.home_unit_id] = (total[r.home_unit_id] ?? 0) + netWorthOf(r.id);
        count[r.home_unit_id] = (count[r.home_unit_id] ?? 0) + 1;
      }
      return chapters
        .map((u) => ({ id: u.id, code: u.code, name: u.name, total: total[u.id] ?? 0, count: count[u.id] ?? 0 }))
        .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
    }
    if (board === 'wgroups') {
      const wgs = orgUnits.filter((u) => u.kind === 'working_group');
      const total: Record<string, number> = {};
      const count: Record<string, number> = {};
      for (const [pid, str] of Object.entries(projectNominalOf)) {
        const uid = projectUnitOf[pid];
        if (!uid) continue;
        total[uid] = (total[uid] ?? 0) + str;
      }
      for (const [pid, uid] of Object.entries(projectUnitOf)) {
        if (!uid) continue;
        count[uid] = (count[uid] ?? 0) + 1;
      }
      return wgs
        .map((u) => ({ id: u.id, code: u.code, name: u.name, total: total[u.id] ?? 0, count: count[u.id] ?? 0 }))
        .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name));
    }
    return [];
  });
  const unitFiltered = $derived(
    unitRanked
      .map((u, i) => ({ unit: u, rank: i + 1 }))
      .filter(({ unit }) => unit.name.toLowerCase().includes(q.toLowerCase()) || unit.code.toLowerCase().includes(q.toLowerCase()))
  );
  const maxUnitMetric = $derived(Math.max(1, ...unitRanked.map((u) => u.total)));

  // podium order: 2nd · 1st · 3rd — works for both member and unit boards
  const podium = $derived.by(() => {
    if (isUnitBoard) {
      if (unitRanked.length < 3) return [];
      const noun = board === 'chapters' ? '{n} members' : '{n} projects';
      const mkU = (u: UnitRow, rank: number, cls: string) => ({
        id: u.id, name: u.name, sub: $t(noun, { n: u.count }), metric: u.total, rank, cls, me: false
      });
      return [mkU(unitRanked[1], 2, 'p2'), mkU(unitRanked[0], 1, 'p1'), mkU(unitRanked[2], 3, 'p3')];
    }
    if (ranked.length < 3) return [];
    const mk = (r: Row, rank: number, cls: string) => ({
      id: r.id, name: r.full_name, sub: r.affiliation ?? '—', metric: metricOf(r.id), rank, cls,
      me: !!($member && r.id === $member.id)
    });
    return [mk(ranked[1], 2, 'p2'), mk(ranked[0], 1, 'p1'), mk(ranked[2], 3, 'p3')];
  });
  const MEDAL = ['🥇', '🥈', '🥉'];
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">{$t('Leaderboard')}</h1>
      <span class="muted" style="font-size:.85rem;">{$t(BOARDS.find((b) => b.key === board)?.blurb ?? '')}</span>
    </div>
    {#if $member}<span class="chip"><span class="amt"><CountUp value={myBalance} /></span> STR</span>{/if}
  </div>

  <!-- board tabs -->
  <div class="row" style="gap:.4rem; flex-wrap:wrap;">
    {#each BOARDS as b}
      <span class="chip toggle {board === b.key ? 'on' : ''}" role="button" tabindex="0"
        onclick={() => (board = b.key)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') board = b.key; }}
      >{$t(b.label)}</span>
    {/each}
  </div>

  {#if !loading && podium.length === 3 && !q}
    <div class="podium">
      {#each podium as p}
        <div class="pod {p.cls}">
          <div class="medal">{MEDAL[p.rank - 1]}</div>
          <div class="pod-ava">{initials(p.name)}</div>
          <div class="pod-name">{p.name}{#if p.me}<span class="badge dim" style="margin-left:.3rem;">{$t('you')}</span>{/if}</div>
          <div class="pod-sub">{p.sub}</div>
          <div class="pod-str"><CountUp value={p.metric} /><span class="u">{$t('STR')}</span></div>
        </div>
      {/each}
    </div>
  {/if}

  <input placeholder={isUnitBoard ? $t('Search…') : $t('Search by name…')} bind:value={q} style="max-width:320px;" />

  <div class="card" style="padding:0; overflow-x:auto;">
    {#if loading}
      <p class="muted" style="padding:1rem;">{$t('Loading…')}</p>
    {:else if isUnitBoard}
      {#if unitFiltered.length === 0}
        <p class="muted" style="padding:1rem;">{board === 'chapters' ? $t('No chapters.') : $t('No working groups.')}</p>
      {:else}
        <table>
          <thead><tr>
            <th class="num">#</th>
            <th>{board === 'chapters' ? $t('Chapter') : $t('Working Group')}</th>
            <th class="num">{board === 'chapters' ? $t('Members') : $t('Projects')}</th>
            <th style="min-width:90px;">{$t('Share')}</th>
            <th class="num accent">{board === 'chapters' ? $t('Combined net worth') : $t('Staked STR')}</th>
          </tr></thead>
          <tbody>
            {#each unitFiltered as { unit: u, rank } (u.id)}
              <tr>
                <td class="num"><span class="rank {rank <= 3 ? 'r' + rank : ''}">{rank}</span></td>
                <td>
                  <span class="pname">{u.name}</span>
                  <span class="psub">{u.code}</span>
                </td>
                <td class="num dim">{u.count}</td>
                <td><span class="lb-bar"><i style="width:{Math.max(3, (u.total / maxUnitMetric) * 100)}%"></i></span></td>
                <td class="num mono accent" style="color:var(--accent);">{u.total.toLocaleString()}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    {:else if filtered.length === 0}
      <p class="muted" style="padding:1rem;">{$t('No members.')}</p>
    {:else}
      <table>
        <thead><tr>
          <th class="num">#</th><th>{$t('Member')}</th><th>{$t('Position')}</th><th style="min-width:90px;">{$t('Share')}</th>
          <th class="num" class:accent={board === 'wealth'}>{$t('Liquid')}</th>
          <th class="num" class:accent={board === 'contribution'}>{$t('Nominal')}</th>
          <th class="num" class:accent={board === 'networth'}>{$t('Net worth')}</th>
        </tr></thead>
        <tbody>
          {#each filtered as { row: r, rank } (r.id)}
            <tr class={$member && r.id === $member.id ? 'me-row' : ''}>
              <td class="num"><span class="rank {rank <= 3 ? 'r' + rank : ''}">{rank}</span></td>
              <td>
                <a href={`/members/${r.id}`} class="proj">
                  <span class="pname">{r.full_name}{#if $member && r.id === $member.id}<span class="badge dim" style="margin-left:.4rem;">{$t('you')}</span>{/if}{#if r.kind === 'card'}<span class="badge dim" style="margin-left:.4rem;" title={$t('A member-card: managed by a chapter officer; value is custodial until the person signs up.')}>{$t('card')}</span>{/if}</span>
                  <span class="psub">{r.affiliation ?? '—'}</span>
                </a>
              </td>
              <td class="dim">{r.member_position?.map((p) => p.position?.name).filter(Boolean).join(', ') || '—'}</td>
              <td><span class="lb-bar"><i style="width:{Math.max(3, (metricOf(r.id) / maxMetric) * 100)}%"></i></span></td>
              <td class="num mono" class:accent={board === 'wealth'} style={board === 'wealth' ? 'color:var(--accent);' : ''}>{(balanceOf[r.id] ?? 0).toLocaleString()}</td>
              <td class="num mono" class:accent={board === 'contribution'} style={board === 'contribution' ? 'color:var(--accent);' : ''}>{(nominalOf[r.id] ?? 0).toLocaleString()}</td>
              <td class="num mono" class:accent={board === 'networth'} style={board === 'networth' ? 'color:var(--accent);' : ''}>{netWorthOf(r.id).toLocaleString()}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
