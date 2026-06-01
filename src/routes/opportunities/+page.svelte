<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import Hint from '$lib/Hint.svelte';

  type Row = {
    id: string;
    description: string | null;
    headcount: number;
    min_level: string | null;
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

  const LEVELS = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  async function loadMine(memberId: string) {
    const [{ data: apps }, { data: pm }, { data: bal }] = await Promise.all([
      supabase.from('need_application').select('id, status, open_need_id').eq('member_id', memberId),
      supabase.from('project_member').select('project_id').eq('member_id', memberId),
      supabase.from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle()
    ]);
    const m: Record<string, { id: string; status: string }> = {};
    for (const a of (apps as any[]) ?? []) m[a.open_need_id] = { id: a.id, status: a.status };
    myApps = m;
    myProjectIds = new Set(((pm as any[]) ?? []).map((r) => r.project_id));
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
  }

  async function loadNeeds() {
    const { data } = await supabase
      .from('open_need')
      .select('id, description, headcount, min_level, status, contribution_kind, hours_per_month, project:project_id(id, name, project_type(join_stake)), project_role(name), skill(name)')
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

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    (async () => { await Promise.all([loadNeeds(), loadLeaderless()]); loading = false; })();
    const unsub = member.subscribe((m) => { if (m) loadMine(m.id); });
    return unsub;
  });

  function stakeOf(r: Row) { return Number(r.project?.project_type?.join_stake ?? 20); }

  async function apply(r: Row, msg: string) {
    error = '';
    if (!$member) return;
    busy = r.id;
    const { error: err } = await supabase.from('need_application').insert({
      open_need_id: r.id, member_id: $member.id, message: msg.trim() || null
    });
    busy = '';
    if (err) { error = err.message; return; }
    pitch[r.id] = '';
    await loadMine($member.id);
  }

  async function confirmJoin(r: Row) {
    error = '';
    const app = myApps[r.id];
    if (!app || !$member) return;
    if (!confirm(`Confirm joining ${r.project?.name ?? 'this project'}? This stakes ${stakeOf(r)} STR into the project escrow.`)) return;
    busy = r.id;
    const { error: err } = await supabase.rpc('confirm_join', { app_id: app.id });
    busy = '';
    if (err) { error = err.message; return; }
    await Promise.all([loadMine($member.id), loadNeeds()]);
  }

  async function claimLead(l: Lead) {
    error = '';
    if (!$member) return;
    if (l.leaderStake > myBalance) { error = `Leading ${l.name} stakes ${l.leaderStake} STR but you only have ${myBalance}.`; return; }
    if (!confirm(`Take the lead on ${l.name}? This stakes ${l.leaderStake} STR (the leader bond) into its escrow and makes you the managing leader.`)) return;
    busy = l.id;
    const { error: err } = await supabase.rpc('claim_leadership', { p: l.id });
    busy = '';
    if (err) { error = err.message; return; }
    await Promise.all([loadLeaderless(), loadNeeds(), $member ? loadMine($member.id) : Promise.resolve()]);
  }

  let pitch = $state<Record<string, string>>({});

  function kindLabel(k: string) {
    return k === 'labor' ? 'Labor' : k === 'resource' ? 'Resource' : 'Seat';
  }
  function kindClass(k: string) {
    return k === 'labor' ? 'info' : k === 'resource' ? 'dim' : '';
  }

  const roleNames = $derived([...new Set(rows.map((r) => r.project_role?.name).filter(Boolean) as string[])].sort());
  const skillNames = $derived([...new Set(rows.map((r) => r.skill?.name).filter(Boolean) as string[])].sort());

  // counts per kind for the chip row (over unfiltered open needs)
  const kindCounts = $derived.by(() => {
    const c: Record<string, number> = { seat: 0, labor: 0, resource: 0 };
    for (const r of rows) c[r.contribution_kind ?? 'seat'] = (c[r.contribution_kind ?? 'seat'] ?? 0) + 1;
    return c;
  });

  const filtered = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) =>
      (!kindFilter || (r.contribution_kind ?? 'seat') === kindFilter) &&
      (!roleFilter || r.project_role?.name === roleFilter) &&
      (!skillFilter || r.skill?.name === skillFilter) &&
      (!levelFilter || levelRank(r.min_level) <= levelRank(levelFilter)) &&
      (!needle ||
        (r.project?.name ?? '').toLowerCase().includes(needle) ||
        (r.description ?? '').toLowerCase().includes(needle) ||
        (r.skill?.name ?? '').toLowerCase().includes(needle) ||
        (r.project_role?.name ?? '').toLowerCase().includes(needle))
    );
  });
</script>

<div class="stack">
  <div>
    <h1 style="margin-bottom:.15rem;">Task Market <Hint term="need" text="Each row is a need — a typed request a project posts for a contribution (labor hours, a resource, or a seat). Apply to one that fits, then post the join bond to start." /></h1>
    <span class="muted" style="font-size:.85rem;">Open work across the community — claim a seat, commit monthly labor, lend a resource, or take the lead on a project.</span>
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  <!-- leaderless projects: anyone may stake the leader bond to take the lead -->
  {#if leaderless.length > 0}
    <div class="card stack" style="gap:.6rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">Lead a project <Hint term="bond" text="Leading means posting the 50 STR leader bond — real liquid STR escrowed into the project. It funds the pool and seeds your claim, but is slashable if you flake." /></h2>
        <span class="badge warn">{leaderless.length} leaderless</span>
      </div>
      <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
        These projects have no managing leader. Stake the leader bond to take the lead seat and start staffing it.
      </p>
      <div class="stack" style="gap:.4rem;">
        {#each leaderless as l}
          <div class="row" style="justify-content:space-between; align-items:center; gap:.6rem; padding:.5rem .2rem; border-top:1px solid var(--border-2);">
            <div>
              <a href={`/projects/${l.id}`} style="font-weight:600;">{l.name}</a>
              <span class="muted" style="font-size:.8rem;"> · {l.type} · {l.status} · {l.members} member{l.members === 1 ? '' : 's'}</span>
            </div>
            {#if $member}
              <button class="stake" onclick={() => claimLead(l)} disabled={busy === l.id || l.leaderStake > myBalance}>
                {#if busy === l.id}<span class="spin"></span> Claiming…{:else}Take the lead · {l.leaderStake} STR{/if}</button>
            {:else}
              <span class="muted" style="font-size:.8rem;">Sign in to lead</span>
            {/if}
          </div>
          {#if $member && l.leaderStake > myBalance}<span class="neg" style="font-size:.75rem; padding-left:.2rem;">Insufficient balance ({myBalance} STR) to lead {l.name}.</span>{/if}
        {/each}
      </div>
    </div>
  {/if}

  <!-- kind chips -->
  <div class="row" style="gap:.4rem;">
    <span class="chip toggle {kindFilter === '' ? 'on' : ''}" role="button" tabindex="0"
      onclick={() => (kindFilter = '')}
      onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') kindFilter = ''; }}
    >All <span class="ct">{rows.length}</span></span>
    {#each ['seat', 'labor', 'resource'] as k}
      <span class="chip toggle {kindFilter === k ? 'on' : ''}" role="button" tabindex="0"
        onclick={() => (kindFilter = kindFilter === k ? '' : k)}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') kindFilter = kindFilter === k ? '' : k; }}
      >{kindLabel(k)} <span class="ct">{kindCounts[k] ?? 0}</span></span>
    {/each}
  </div>

  <div class="row" style="gap:.6rem; flex-wrap:wrap;">
    <div class="search" style="flex:1; min-width:220px;">
      <span class="ico">⌕</span>
      <input placeholder="Search project, role, skill…" bind:value={q} style="width:100%;" />
    </div>
    <select bind:value={roleFilter}>
      <option value="">All roles</option>
      {#each roleNames as r}<option value={r}>{r}</option>{/each}
    </select>
    <select bind:value={skillFilter}>
      <option value="">All skills</option>
      {#each skillNames as s}<option value={s}>{s}</option>{/each}
    </select>
    <select bind:value={levelFilter} title="Show needs I'd qualify for at this level or below">
      <option value="">Any level</option>
      {#each LEVELS as l}<option value={l}>≤ {l}</option>{/each}
    </select>
    {#if q || kindFilter || roleFilter || skillFilter || levelFilter}
      <button class="ghost" onclick={() => { q = ''; kindFilter = ''; roleFilter = ''; skillFilter = ''; levelFilter = ''; }}>Reset</button>
    {/if}
  </div>

  {#if loading}
    <p class="muted">Loading…</p>
  {:else if filtered.length === 0}
    <div class="card"><p class="muted">No open opportunities match.</p></div>
  {:else}
    <div class="stack">
      {#each filtered as r}
        {@const mine = myApps[r.id]?.status}
        {@const member_already = r.project ? myProjectIds.has(r.project.id) : false}
        {@const kind = r.contribution_kind ?? 'seat'}
        <div class="card">
          <div class="row" style="justify-content:space-between; align-items:flex-start;">
            <div>
              <a href={`/projects/${r.project?.id}`}><h2 style="margin:0;">{r.project?.name ?? 'Project'}</h2></a>
              <div class="row muted" style="font-size:.82rem; margin-top:.2rem; flex-wrap:wrap;">
                {#if r.skill}<span>Skill: {r.skill.name}{r.min_level ? ` (≥ ${r.min_level})` : ''}</span>{/if}
                <span>· {r.headcount} opening(s)</span>
                {#if kind === 'labor'}
                  <span>· <strong class="mono">{r.hours_per_month ?? '—'}</strong> hrs/mo</span>
                {:else if kind === 'resource'}
                  <span>· lend a resource</span>
                {:else}
                  <span>· stakes <strong class="mono">{stakeOf(r)}</strong> STR</span>
                {/if}
              </div>
            </div>
            <div class="row" style="gap:.35rem;">
              <span class="badge {kindClass(kind)}">{kindLabel(kind)}</span>
              <span class="badge">{r.project_role?.name ?? 'Contributor'}</span>
            </div>
          </div>
          {#if r.description}<p class="muted" style="margin:.5rem 0 .2rem;">{r.description}</p>{/if}

          <div style="margin-top:.6rem;">
            {#if member_already}
              <span class="badge pos">You're on this project</span>
            {:else if mine === 'joined'}
              <span class="badge pos">Joined</span>
            {:else if mine === 'accepted'}
              <div class="stake-cta" style="padding:.55rem .8rem;">
                <div class="row" style="justify-content:space-between; align-items:center; gap:.6rem;">
                  <span style="font-size:.85rem;">You've been <strong>accepted</strong> — stake <strong class="mono" style="color:var(--accent);">{stakeOf(r)}</strong> STR to take your seat.</span>
                  <button class="stake" onclick={() => confirmJoin(r)} disabled={busy === r.id || stakeOf(r) > myBalance}>
                    {#if busy === r.id}<span class="spin"></span> Joining…{:else}Confirm join · {stakeOf(r)} STR{/if}</button>
                </div>
                {#if stakeOf(r) > myBalance}<span class="neg" style="font-size:.78rem;">Insufficient balance ({myBalance} STR).</span>{/if}
              </div>
            {:else if mine === 'declined'}
              <span class="badge neg">Application declined</span>
            {:else if mine === 'pending'}
              <span class="badge dim">Applied · pending review</span>
            {:else}
              <div class="row" style="gap:.5rem;">
                <input bind:value={pitch[r.id]} placeholder="Short pitch (optional)" style="flex:1; min-width:180px;" />
                <button onclick={() => apply(r, pitch[r.id] ?? '')} disabled={busy === r.id}>
                  {busy === r.id ? '…' : 'I can help'}</button>
              </div>
            {/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>
