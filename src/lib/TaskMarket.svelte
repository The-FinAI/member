<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import Hint from '$lib/Hint.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // Embedded as the "Open needs" view of the Projects surface. A need is an open
  // slot on a project card — typed labor / resource / seat — plus the leaderless
  // projects anyone can take the lead on.
  let { showHeader = true }: { showHeader?: boolean } = $props();

  type Row = {
    id: string;
    description: string | null;
    headcount: number;
    min_guild_level: string | null;
    skill_id: string | null;
    status: string;
    contribution_kind: string;          // seat | labor | resource
    hours_per_month: number | null;
    project: { id: string; name: string; project_type: { join_stake: number } | null } | null;
    project_role: { name: string } | null;
    skill: { name: string } | null;
  };
  // a leaderless project anyone can take the lead on
  type Lead = {
    id: string; name: string; type: string; status: string;
    leaderStake: number; members: number;
  };

  let rows = $state<Row[]>([]);
  let leaderless = $state<Lead[]>([]);
  let myApps = $state<Record<string, { id: string; status: string }>>({}); // needId -> app
  let myProjectIds = $state<Set<string>>(new Set());
  let myBalance = $state(0);
  let loading = $state(true);
  let busy = $state('');
  let error = $state('');

  // filters
  let q = $state('');
  let kindFilter = $state('');   // '' | seat | labor | resource
  let roleFilter = $state('');
  let skillFilter = $state('');
  let levelFilter = $state('');

  const GUILD_LADDER = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const GUILD_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? GUILD_LADDER.indexOf(l) + 1 : 0);
  // my certified guild level per skill_id (drives "you qualify")
  let myCertified = $state<Record<string, string>>({});
  function qualifiesFor(r: Row) {
    if (!r.min_guild_level || !r.skill_id) return true;
    return levelRank(myCertified[r.skill_id]) >= levelRank(r.min_guild_level);
  }

  async function loadMine(memberId: string) {
    const [{ data: apps }, { data: pm }, { data: bal }, { data: cert }] = await Promise.all([
      supabase.from('need_application').select('id, status, open_need_id').eq('member_id', memberId),
      supabase.from('project_member').select('project_id').eq('member_id', memberId),
      supabase.from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', memberId).not('certified_level', 'is', null)
    ]);
    const m: Record<string, { id: string; status: string }> = {};
    for (const a of (apps as any[]) ?? []) m[a.open_need_id] = { id: a.id, status: a.status };
    myApps = m;
    myProjectIds = new Set(((pm as any[]) ?? []).map((r) => r.project_id));
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
    const cmap: Record<string, string> = {};
    for (const c of (cert as { skill_id: string; certified_level: string }[]) ?? []) cmap[c.skill_id] = c.certified_level;
    myCertified = cmap;
  }

  async function loadNeeds() {
    const { data } = await supabase
      .from('open_need')
      .select('id, description, headcount, min_guild_level, skill_id, status, contribution_kind, hours_per_month, project:project_id(id, name, project_type(join_stake)), project_role(name), skill(name)')
      .eq('status', 'open')
      .order('created_at', { ascending: false });
    rows = (data as Row[]) ?? [];
  }

  // leaderless = active project with no can_manage member; anyone may stake the leader bond
  async function loadLeaderless() {
    const [{ data: pr }, { data: pm }] = await Promise.all([
      supabase.from('project')
        .select('id, name, project_type(name, leader_stake), project_status!project_status_id_fkey(name)'),
      supabase.from('project_member').select('project_id, project_role(can_manage)')
    ]);
    const managed = new Set<string>();
    const memberCount: Record<string, number> = {};
    for (const r of (pm as any[]) ?? []) {
      memberCount[r.project_id] = (memberCount[r.project_id] ?? 0) + 1;
      if (r.project_role?.can_manage) managed.add(r.project_id);
    }
    leaderless = ((pr as any[]) ?? [])
      .filter((p) => !managed.has(p.id) && p.project_status?.name !== 'Finished')
      .map((p) => ({
        id: p.id,
        name: p.name,
        type: p.project_type?.name ?? '—',
        status: p.project_status?.name ?? '—',
        leaderStake: Number(p.project_type?.leader_stake ?? 50),
        members: memberCount[p.id] ?? 0
      }));
  }

  const effId = $derived($member?.id ?? null);
  const asArg = null;

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    (async () => { await Promise.all([loadNeeds(), loadLeaderless()]); loading = false; })();
  });
  // reload "my" state whenever the effective identity changes
  $effect(() => { if (effId) loadMine(effId); });

  function stakeOf(r: Row) { return Number(r.project?.project_type?.join_stake ?? 20); }

  async function apply(r: Row, msg: string) {
    error = '';
    if (!effId) return;
    busy = r.id;
    const { error: err } = await supabase.rpc('apply_to_need', {
      p_need: r.id, p_message: msg.trim() || null, p_as: asArg
    });
    busy = '';
    if (err) { error = err.message; return; }
    pitch[r.id] = '';
    await loadMine(effId);
  }

  async function confirmJoin(r: Row) {
    error = '';
    const app = myApps[r.id];
    if (!app || !effId) return;
    if (!confirm(get(t)('Confirm joining {name}? This stakes {n} STR into the project escrow.', { name: r.project?.name ?? get(t)('this project'), n: stakeOf(r) }))) return;
    busy = r.id;
    const { error: err } = await supabase.rpc('confirm_join', { app_id: app.id, p_as: asArg });
    busy = '';
    if (err) { error = err.message; return; }
    await Promise.all([loadMine(effId), loadNeeds()]);
  }

  async function claimLead(l: Lead) {
    error = '';
    if (!effId) return;
    if (l.leaderStake > myBalance) { error = get(t)('Leading {name} stakes {n} STR but you only have {bal}.', { name: l.name, n: l.leaderStake, bal: myBalance }); return; }
    if (!confirm(get(t)('Take the lead on {name}? This stakes {n} STR (the leader bond) into its escrow and makes you the managing leader.', { name: l.name, n: l.leaderStake }))) return;
    busy = l.id;
    const { error: err } = await supabase.rpc('claim_leadership', { p: l.id, p_as: asArg });
    busy = '';
    if (err) { error = err.message; return; }
    await Promise.all([loadLeaderless(), loadNeeds(), loadMine(effId)]);
  }

  let pitch = $state<Record<string, string>>({});

  function kindLabel(k: string) {
    return k === 'lead' ? 'Lead' : k === 'labor' ? 'Labor' : k === 'resource' ? 'Resource' : 'Seat';
  }
  function kindClass(k: string) {
    return k === 'lead' ? 'warn' : k === 'labor' ? 'info' : k === 'resource' ? 'dim' : '';
  }

  const roleNames = $derived([...new Set(rows.map((r) => r.project_role?.name).filter(Boolean) as string[])].sort());
  const skillNames = $derived([...new Set(rows.map((r) => r.skill?.name).filter(Boolean) as string[])].sort());

  // A unified market row: either an open need on a project, or a leaderless
  // project anyone may take the lead on. Both live in one list now.
  type Item = (Row & { _t: 'need' }) | (Lead & { _t: 'lead' });

  // counts per kind for the chip row (over the whole unfiltered market)
  const kindCounts = $derived.by(() => {
    const c: Record<string, number> = { lead: leaderless.length, seat: 0, labor: 0, resource: 0 };
    for (const r of rows) c[r.contribution_kind ?? 'seat'] = (c[r.contribution_kind ?? 'seat'] ?? 0) + 1;
    return c;
  });

  const filtered = $derived.by<Item[]>(() => {
    const needle = q.trim().toLowerCase();
    // leaderless projects are a "lead" need; they carry no role/skill/level,
    // so any of those filters naturally excludes them.
    const leads: Item[] = (roleFilter || skillFilter || levelFilter)
      ? []
      : leaderless
          .filter((l) => (!kindFilter || kindFilter === 'lead'))
          .filter((l) => !needle || l.name.toLowerCase().includes(needle) || l.type.toLowerCase().includes(needle))
          .map((l) => ({ ...l, _t: 'lead' as const }));
    const needs: Item[] = rows
      .filter((r) =>
        (!kindFilter || (r.contribution_kind ?? 'seat') === kindFilter) &&
        (!roleFilter || r.project_role?.name === roleFilter) &&
        (!skillFilter || r.skill?.name === skillFilter) &&
        (!levelFilter || levelRank(r.min_guild_level) <= levelRank(levelFilter)) &&
        (!needle ||
          (r.project?.name ?? '').toLowerCase().includes(needle) ||
          (r.description ?? '').toLowerCase().includes(needle) ||
          (r.skill?.name ?? '').toLowerCase().includes(needle) ||
          (r.project_role?.name ?? '').toLowerCase().includes(needle))
      )
      .map((r) => ({ ...r, _t: 'need' as const }));
    return [...leads, ...needs];
  });
</script>

<div class="stack">
  {#if showHeader}
    <div>
      <h1 style="margin-bottom:.15rem;">{$t('Task Market')} <Hint term="need" text={$t('Each row is a need — a typed request a project posts for a contribution (labor hours, a resource, or a seat). Apply to one that fits, then post the join bond to start.')} /></h1>
      <span class="muted" style="font-size:.85rem;">{$t('Open work across the community — claim a seat, commit monthly labor, lend a resource, or take the lead on a project.')}</span>
    </div>
  {:else}
    <span class="muted" style="font-size:.85rem;">{$t('Open work across the community — claim a seat, commit monthly labor, lend a resource, or take the lead on a project.')} <Hint term="need" text={$t('Each row is a need — a typed request a project posts for a contribution (labor hours, a resource, or a seat). Apply to one that fits, then post the join bond to start.')} /></span>
  {/if}

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  <!-- kind chips -->
  <div class="row" style="gap:.4rem;">
    <span class="chip toggle {kindFilter === '' ? 'on' : ''}" role="button" tabindex="0"
      onclick={() => (kindFilter = '')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') kindFilter = ''; }}
    >{$t('All')} <span class="ct">{rows.length}</span></span>
    {#each ['lead', 'seat', 'labor', 'resource'] as k}
      <span class="chip toggle {kindFilter === k ? 'on' : ''}" role="button" tabindex="0"
        onclick={() => (kindFilter = kindFilter === k ? '' : k)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') kindFilter = kindFilter === k ? '' : k; }}
      >{$t(kindLabel(k))} <span class="ct">{kindCounts[k] ?? 0}</span></span>
    {/each}
  </div>

  <div class="row" style="gap:.6rem; flex-wrap:wrap;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder={$t('Search project, role, skill…')} bind:value={q} style="width:100%;" />
    </div>
    <select bind:value={roleFilter}>
      <option value="">{$t('All roles')}</option>
      {#each roleNames as r}<option value={r}>{r}</option>{/each}
    </select>
    <select bind:value={skillFilter}>
      <option value="">{$t('All skills')}</option>
      {#each skillNames as s}<option value={s}>{s}</option>{/each}
    </select>
    <select bind:value={levelFilter} title={$t("Show needs I'd qualify for at this level or below")}>
      <option value="">{$t('Any level')}</option>
      {#each GUILD_LADDER as l}<option value={l}>≤ {$t(GUILD_LABEL[l])}</option>{/each}
    </select>
    {#if q || kindFilter || roleFilter || skillFilter || levelFilter}
      <button class="ghost" onclick={() => { q = ''; kindFilter = ''; roleFilter = ''; skillFilter = ''; levelFilter = ''; }}>{$t('Reset')}</button>
    {/if}
  </div>

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if filtered.length === 0}
    <div class="card"><p class="muted">{$t('No open opportunities match.')}</p></div>
  {:else}
    <div class="stack">
      {#each filtered as r (r._t + r.id)}
        {#if r._t === 'lead'}
          <!-- a leaderless project: take the lead by staking the leader bond -->
          <div class="card">
            <div class="row" style="justify-content:space-between; align-items:flex-start;">
              <div>
                <a href={`/projects/${r.id}`}><h2 style="margin:0;">{r.name}</h2></a>
                <div class="row muted" style="font-size:.82rem; margin-top:.2rem; flex-wrap:wrap;">
                  <span>{r.type}</span>
                  <span>· {$t(r.status)}</span>
                  <span>· {r.members} {r.members === 1 ? $t('member') : $t('members')}</span>
                  <span>· {$t('stakes')} <strong class="mono">{r.leaderStake}</strong> STR</span>
                </div>
              </div>
              <div class="row" style="gap:.35rem;">
                <span class="badge {kindClass('lead')}">{$t(kindLabel('lead'))}</span>
              </div>
            </div>
            <p class="muted" style="margin:.5rem 0 .2rem;">{$t('No managing leader yet. Stake the leader bond to take the lead seat and start staffing it.')}</p>

            <div style="margin-top:.6rem;">
              {#if myProjectIds.has(r.id)}
                <span class="badge pos">{$t("You're on this project")}</span>
              {:else if $member}
                <div class="row" style="gap:.5rem; align-items:center;">
                  <button class="stake" onclick={() => claimLead(r)} disabled={busy === r.id || r.leaderStake > myBalance}>
                    {#if busy === r.id}<span class="spin"></span> {$t('Claiming…')}{:else}{$t('Take the lead · {n} STR', { n: r.leaderStake })}{/if}</button>
                  {#if r.leaderStake > myBalance}<span class="neg" style="font-size:.78rem;">{$t('Insufficient balance ({bal} STR).', { bal: myBalance })}</span>{/if}
                </div>
              {:else}
                <span class="muted" style="font-size:.8rem;">{$t('Sign in to lead')}</span>
              {/if}
            </div>
          </div>
        {:else}
          {@const mine = myApps[r.id]?.status}
          {@const member_already = r.project ? myProjectIds.has(r.project.id) : false}
          {@const kind = r.contribution_kind ?? 'seat'}
          <div class="card">
            <div class="row" style="justify-content:space-between; align-items:flex-start;">
              <div>
                <a href={`/projects/${r.project?.id}`}><h2 style="margin:0;">{r.project?.name ?? $t('Project')}</h2></a>
                <div class="row muted" style="font-size:.82rem; margin-top:.2rem; flex-wrap:wrap;">
                  {#if r.skill}<span>{$t('Skill:')} {$t(r.skill.name)}{r.min_guild_level ? ` · ${$t('needs {lvl}', { lvl: $t(GUILD_LABEL[r.min_guild_level]) })}` : ''}</span>
                    {#if r.min_guild_level && $member}{#if qualifiesFor(r)}<span class="badge pos" style="font-size:.7rem;">{$t('You qualify')}</span>{:else}<span class="badge warn" style="font-size:.7rem;">{$t('Below required level')}</span>{/if}{/if}{/if}
                  <span>· {$t('{n} opening(s)', { n: r.headcount })}</span>
                  {#if kind === 'labor'}
                    <span>· <strong class="mono">{r.hours_per_month ?? '—'}</strong> {$t('hrs/mo')}</span>
                  {:else if kind === 'resource'}
                    <span>· {$t('lend a resource')}</span>
                  {:else}
                    <span>· {$t('stakes')} <strong class="mono">{stakeOf(r)}</strong> STR</span>
                  {/if}
                </div>
              </div>
              <div class="row" style="gap:.35rem;">
                <span class="badge {kindClass(kind)}">{$t(kindLabel(kind))}</span>
                <span class="badge">{r.project_role?.name ?? $t('Contributor')}</span>
              </div>
            </div>
            {#if r.description}<p class="muted" style="margin:.5rem 0 .2rem;">{r.description}</p>{/if}

            <div style="margin-top:.6rem;">
              {#if member_already}
                <span class="badge pos">{$t("You're on this project")}</span>
              {:else if mine === 'joined'}
                <span class="badge pos">{$t('Joined')}</span>
              {:else if mine === 'accepted'}
                <div class="stake-cta" style="padding:.55rem .8rem;">
                  <div class="row" style="justify-content:space-between; align-items:center; gap:.6rem;">
                    <span style="font-size:.85rem;">{@html $t("You've been <strong>accepted</strong> — stake <strong class='mono' style='color:var(--accent);'>{n}</strong> STR to take your seat.", { n: stakeOf(r) })}</span>
                    <button class="stake" onclick={() => confirmJoin(r)} disabled={busy === r.id || stakeOf(r) > myBalance}>
                      {#if busy === r.id}<span class="spin"></span> {$t('Joining…')}{:else}{$t('Confirm join · {n} STR', { n: stakeOf(r) })}{/if}</button>
                  </div>
                  {#if stakeOf(r) > myBalance}<span class="neg" style="font-size:.78rem;">{$t('Insufficient balance ({bal} STR).', { bal: myBalance })}</span>{/if}
                </div>
              {:else if mine === 'declined'}
                <span class="badge neg">{$t('Application declined')}</span>
              {:else if mine === 'pending'}
                <span class="badge dim">{$t('Applied · pending review')}</span>
              {:else}
                <div class="row" style="gap:.5rem;">
                  <input bind:value={pitch[r.id]} placeholder={$t('Short pitch (optional)')} style="flex:1; min-width:180px;" />
                  <button onclick={() => apply(r, pitch[r.id] ?? '')} disabled={busy === r.id}>
                    {busy === r.id ? '…' : $t('I can help')}</button>
                </div>
              {/if}
            </div>
          </div>
        {/if}
      {/each}
    </div>
  {/if}
</div>
