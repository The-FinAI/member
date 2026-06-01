<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import CountUp from '$lib/CountUp.svelte';
  import Medal from '$lib/Medal.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }

  type Row = {
    id: string;
    full_name: string;
    affiliation: string | null;
    status: string;
    kind: string;
    member_position: { position: { name: string } }[];
  };
  type MemberSkill = { skill_id: string; self_level: string; certified_level: string | null; skill: { name: string } | null };
  type Credit = { skill_id: string; credit: number; endorsements: number };

  let rows = $state<Row[]>([]);
  let balanceOf = $state<Record<string, number>>({});
  let nominalOf = $state<Record<string, number>>({});
  let creditOf = $state<Record<string, number>>({});
  let loading = $state(true);
  let q = $state('');
  let myBalance = $state(0);
  let endorseMin = $state(1);

  // multi-board: each board is a different way to rank the same members
  type Board = 'contribution' | 'networth' | 'wealth' | 'masters';
  let board = $state<Board>('contribution');
  const BOARDS: { key: Board; label: string; blurb: string }[] = [
    { key: 'contribution', label: 'Contribution', blurb: 'Lifetime nominal STR minted through declared work & verified milestones.' },
    { key: 'networth', label: 'Net worth', blurb: 'Liquid STR plus nominal STR still accruing in live projects.' },
    { key: 'wealth', label: 'Wealth', blurb: 'Liquid, spendable STR held right now.' },
    { key: 'masters', label: 'Masters', blurb: 'Peer-endorsed skill reputation across the guild.' }
  ];
  const netWorthOf = (id: string) => (balanceOf[id] ?? 0) + (nominalOf[id] ?? 0);
  function metricOf(id: string): number {
    switch (board) {
      case 'contribution': return nominalOf[id] ?? 0;
      case 'networth': return netWorthOf(id);
      case 'wealth': return balanceOf[id] ?? 0;
      case 'masters': return creditOf[id] ?? 0;
    }
  }
  const metricUnit = $derived(board === 'masters' ? 'rep' : 'STR');

  // expanded member endorse panel
  let openId = $state('');
  let openSkills = $state<MemberSkill[]>([]);
  let openCredit = $state<Record<string, Credit>>({});
  let panelLoading = $state(false);
  let amounts = $state<Record<string, number>>({});
  let notes = $state<Record<string, string>>({});
  let error = $state('');
  let busy = $state('');

  async function loadMyBalance() {
    if (!$member) return;
    const [{ data: bal }, { data: pol }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle(),
      supabase.from('stater_policy').select('value').eq('key', 'endorse_min').maybeSingle()
    ]);
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
    endorseMin = Number((pol as { value: number } | null)?.value ?? 1);
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [{ data }, { data: bals }, { data: cr }, { data: nom }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, affiliation, status, kind, member_position(position(name))')
        .order('full_name'),
      supabase.from('stater_balance').select('owner_member_id, balance').not('owner_member_id', 'is', null),
      supabase.from('stater_skill_credit').select('member_id, credit'),
      supabase.from('stater_project_member_nominal').select('member_id, nominal')
    ]);
    rows = (data as Row[]) ?? [];
    const bmap: Record<string, number> = {};
    for (const b of (bals as { owner_member_id: string; balance: number }[]) ?? [])
      bmap[b.owner_member_id] = Number(b.balance) || 0;
    balanceOf = bmap;
    const cmap: Record<string, number> = {};
    for (const c of (cr as { member_id: string; credit: number }[]) ?? [])
      cmap[c.member_id] = (cmap[c.member_id] ?? 0) + (Number(c.credit) || 0);
    creditOf = cmap;
    const nmap: Record<string, number> = {};
    for (const n of (nom as { member_id: string; nominal: number }[]) ?? [])
      nmap[n.member_id] = (nmap[n.member_id] ?? 0) + (Number(n.nominal) || 0);
    nominalOf = nmap;
    loading = false;
    const unsub = member.subscribe((m) => { if (m) loadMyBalance(); });
    return unsub;
  });

  async function toggle(id: string) {
    error = '';
    if (openId === id) { openId = ''; return; }
    openId = id;
    panelLoading = true;
    const [{ data: ms }, { data: cr }] = await Promise.all([
      supabase.from('member_skill').select('skill_id, self_level, certified_level, skill(name)').eq('member_id', id),
      supabase.from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', id)
    ]);
    openSkills = (ms as MemberSkill[]) ?? [];
    const map: Record<string, Credit> = {};
    for (const c of (cr as Credit[]) ?? []) map[c.skill_id] = c;
    openCredit = map;
    panelLoading = false;
  }

  async function endorse(target: string, skillId: string) {
    error = '';
    const amt = Number(amounts[skillId] ?? endorseMin);
    if (amt < endorseMin) { error = get(t)('Minimum is {n} STR.', { n: endorseMin }); return; }
    if (amt > myBalance) { error = get(t)('You only have {n} STR.', { n: myBalance }); return; }
    busy = skillId;
    const { error: err } = await supabase.rpc('endorse_skill', {
      target, sk: skillId, amt, note: notes[skillId]?.trim() || null
    });
    busy = '';
    if (err) { error = err.message; return; }
    amounts[skillId] = endorseMin; notes[skillId] = '';
    await Promise.all([loadMyBalance(), toggleReload(target)]);
  }

  async function toggleReload(id: string) {
    const { data: cr } = await supabase
      .from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', id);
    const map: Record<string, Credit> = {};
    for (const c of (cr as Credit[]) ?? []) map[c.skill_id] = c;
    openCredit = map;
  }

  // leaderboard: rank by the active board's metric (desc), tiebreak by net worth then name
  const ranked = $derived(
    [...rows].sort((a, b) =>
      metricOf(b.id) - metricOf(a.id) ||
      netWorthOf(b.id) - netWorthOf(a.id) ||
      a.full_name.localeCompare(b.full_name)
    )
  );
  // rank number is assigned on the full ranking, then we filter for display
  const filtered = $derived(
    ranked
      .map((r, i) => ({ row: r, rank: i + 1 }))
      .filter(({ row }) => row.full_name.toLowerCase().includes(q.toLowerCase()))
  );

  const maxMetric = $derived(Math.max(1, ...ranked.map((r) => metricOf(r.id))));
  // podium order: 2nd · 1st · 3rd
  const podium = $derived(
    ranked.length >= 3
      ? [{ r: ranked[1], rank: 2, cls: 'p2' }, { r: ranked[0], rank: 1, cls: 'p1' }, { r: ranked[2], rank: 3, cls: 'p3' }]
      : []
  );
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
          <div class="pod-ava">{initials(p.r.full_name)}</div>
          <div class="pod-name">{p.r.full_name}{#if $member && p.r.id === $member.id}<span class="badge dim" style="margin-left:.3rem;">{$t('you')}</span>{/if}</div>
          <div class="pod-sub">{p.r.affiliation ?? '—'}</div>
          <div class="pod-str"><CountUp value={metricOf(p.r.id)} /><span class="u">{$t(metricUnit)}</span></div>
        </div>
      {/each}
    </div>
  {/if}

  <input placeholder={$t('Search by name…')} bind:value={q} style="max-width:320px;" />
  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card" style="padding:0; overflow-x:auto;">
    {#if loading}
      <p class="muted" style="padding:1rem;">{$t('Loading…')}</p>
    {:else if filtered.length === 0}
      <p class="muted" style="padding:1rem;">{$t('No members.')}</p>
    {:else}
      <table>
        <thead><tr>
          <th class="num">#</th><th>{$t('Member')}</th><th>{$t('Position')}</th><th style="min-width:90px;">{$t('Share')}</th>
          <th class="num" class:accent={board === 'wealth'}>{$t('Liquid')}</th>
          <th class="num" class:accent={board === 'contribution'}>{$t('Nominal')}</th>
          <th class="num" class:accent={board === 'networth'}>{$t('Net worth')}</th>
          <th class="num" class:accent={board === 'masters'}>{$t('Rep')}</th>
          <th></th>
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
              <td class="num mono" class:accent={board === 'masters'} style={board === 'masters' ? 'color:var(--accent);' : ''}>{(creditOf[r.id] ?? 0).toLocaleString()}</td>
              <td>
                {#if $member && r.id !== $member.id}
                  <button onclick={() => toggle(r.id)}>{openId === r.id ? $t('Close') : $t('Endorse')}</button>
                {/if}
              </td>
            </tr>
            {#if openId === r.id}
              <tr>
                <td colspan="9" style="background:var(--card-2);">
                  {#if panelLoading}
                    <p class="muted">{$t('Loading skills…')}</p>
                  {:else if openSkills.length === 0}
                    <p class="muted">{$t('{name} has no skills listed yet.', { name: r.full_name })}</p>
                  {:else}
                    <div class="stack" style="gap:.5rem; padding:.25rem 0;">
                      <p class="muted" style="font-size:.82rem; margin:0;">
                        {$t('Endorse a skill by transferring your own STR — scarce credit means it carries signal.')}
                      </p>
                      {#each openSkills as s}
                        <div class="row" style="align-items:center; flex-wrap:wrap; gap:.5rem;">
                          <strong style="min-width:160px;">{s.skill?.name ?? s.skill_id}</strong>
                          {#if s.certified_level}<Medal level={s.certified_level} size="sm" />{:else}<span class="badge">{s.self_level}</span>{/if}
                          <span class="muted" style="font-size:.8rem;">
                            {$t('credit {c} · {n} endorsers', { c: openCredit[s.skill_id]?.credit ?? 0, n: openCredit[s.skill_id]?.endorsements ?? 0 })}
                          </span>
                          <input type="number" min={endorseMin} bind:value={amounts[s.skill_id]} placeholder={String(endorseMin)} style="width:70px;" />
                          <input bind:value={notes[s.skill_id]} placeholder={$t('note (optional)')} style="width:180px;" />
                          <button disabled={busy === s.skill_id} onclick={() => endorse(r.id, s.skill_id)}>
                            {busy === s.skill_id ? '…' : $t('Endorse')}
                          </button>
                        </div>
                      {/each}
                    </div>
                  {/if}
                </td>
              </tr>
            {/if}
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
