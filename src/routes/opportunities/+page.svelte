<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type Row = {
    id: string;
    description: string | null;
    headcount: number;
    min_level: string | null;
    status: string;
    project: { id: string; name: string; project_type: { join_stake: number } | null } | null;
    project_role: { name: string } | null;
    skill: { name: string } | null;
  };

  let rows = $state<Row[]>([]);
  let myApps = $state<Record<string, { id: string; status: string }>>({}); // needId -> app
  let myProjectIds = $state<Set<string>>(new Set());
  let myBalance = $state(0);
  let loading = $state(true);
  let busy = $state('');
  let error = $state('');

  // filters
  let q = $state('');
  let roleFilter = $state('');
  let skillFilter = $state('');

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
      .select('id, description, headcount, min_level, status, project:project_id(id, name, project_type(join_stake)), project_role(name), skill(name)')
      .eq('status', 'open')
      .order('created_at', { ascending: false });
    rows = (data as Row[]) ?? [];
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    (async () => { await loadNeeds(); loading = false; })();
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

  let pitch = $state<Record<string, string>>({});

  const roleNames = $derived([...new Set(rows.map((r) => r.project_role?.name).filter(Boolean) as string[])].sort());
  const skillNames = $derived([...new Set(rows.map((r) => r.skill?.name).filter(Boolean) as string[])].sort());

  const filtered = $derived.by(() => {
    const needle = q.trim().toLowerCase();
    return rows.filter((r) =>
      (!roleFilter || r.project_role?.name === roleFilter) &&
      (!skillFilter || r.skill?.name === skillFilter) &&
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
    <h1 style="margin-bottom:.15rem;">Open Opportunities</h1>
    <span class="muted" style="font-size:.85rem;">Projects looking for collaborators. Apply, get accepted, then stake to join.</span>
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  <div class="row" style="gap:.6rem;">
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
    {#if q || roleFilter || skillFilter}
      <button class="ghost" onclick={() => { q = ''; roleFilter = ''; skillFilter = ''; }}>Reset</button>
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
        <div class="card">
          <div class="row" style="justify-content:space-between; align-items:flex-start;">
            <div>
              <a href={`/projects/${r.project?.id}`}><h2 style="margin:0;">{r.project?.name ?? 'Project'}</h2></a>
              <div class="row muted" style="font-size:.82rem; margin-top:.2rem;">
                {#if r.skill}<span>Skill: {r.skill.name}{r.min_level ? ` (≥ ${r.min_level})` : ''}</span>{/if}
                <span>· {r.headcount} opening(s)</span>
                <span>· stakes <strong class="mono">{stakeOf(r)}</strong> STR</span>
              </div>
            </div>
            <span class="badge">{r.project_role?.name ?? 'Contributor'}</span>
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
