<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type MyProject = { project: { id: string; name: string; project_status: { name: string } | null } | null; project_role: { name: string } | null };
  type MyApp = { id: string; status: string; open_need: { project: { name: string } | null } | null };

  let myProjects = $state<MyProject[]>([]);
  let myApps = $state<MyApp[]>([]);
  let openCount = $state(0);
  let projectCount = $state(0);
  let balance = $state(0);
  let staked = $state(0);
  let loading = $state(true);

  async function load(memberId: string) {
    loading = true;
    const [{ data: mp }, { data: ma }, { count: oc }, { count: pc }, { data: bal }, { data: cm }] = await Promise.all([
      supabase.from('project_member')
        .select('project(id, name, project_status(name)), project_role(name)')
        .eq('member_id', memberId),
      supabase.from('need_application')
        .select('id, status, open_need(project(name))')
        .eq('member_id', memberId)
        .order('created_at', { ascending: false }),
      supabase.from('open_need').select('*', { count: 'exact', head: true }).eq('status', 'open'),
      supabase.from('project').select('*', { count: 'exact', head: true }),
      supabase.from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_project_stake_commitment')
        .select('token_amount, status').eq('member_id', memberId)
    ]);
    myProjects = (mp as MyProject[]) ?? [];
    myApps = (ma as MyApp[]) ?? [];
    openCount = oc ?? 0;
    projectCount = pc ?? 0;
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    staked = ((cm as { token_amount: number; status: string }[]) ?? [])
      .filter((c) => ['pledged', 'accepted', 'verified'].includes(c.status))
      .reduce((a, c) => a + Number(c.token_amount), 0);
    loading = false;
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    const unsub = member.subscribe((m) => { if (m) load(m.id); else loading = false; });
    return unsub;
  });

  function statusClass(name: string | null | undefined) {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold') return 'warn';
    return '';
  }
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">Portfolio{$member ? ` · ${$member.full_name.split(' ')[0]}` : ''}</h1>
      <span class="muted" style="font-size:.85rem;">Your stake across the Stater research economy.</span>
    </div>
    <a href="/projects"><button>Start a project</button></a>
  </div>

  <div class="row" style="align-items:stretch;">
    <div class="tile" style="flex:1; min-width:170px;">
      <span class="label">STR balance</span>
      <span class="value accent">{balance.toLocaleString()}</span>
      <span class="sub">liquid, spendable</span>
    </div>
    <div class="tile" style="flex:1; min-width:170px;">
      <span class="label">Staked</span>
      <span class="value">{staked.toLocaleString()}</span>
      <span class="sub">bonded in projects</span>
    </div>
    <a class="tile" href="/projects" style="flex:1; min-width:170px;">
      <span class="label">My projects</span>
      <span class="value">{myProjects.length}</span>
      <span class="sub">projects joined</span>
    </a>
    <a class="tile" href="/opportunities" style="flex:1; min-width:170px;">
      <span class="label">Open needs</span>
      <span class="value">{openCount}</span>
      <span class="sub">across {projectCount} projects</span>
    </a>
  </div>

  <div class="card">
    <h2>My positions</h2>
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if myProjects.length === 0}
      <p class="muted">No positions yet. Browse <a href="/opportunities">Open Opportunities</a> to stake into a project.</p>
    {:else}
      <table>
        <thead><tr><th>Project</th><th>Role</th><th>Status</th></tr></thead>
        <tbody>
          {#each myProjects as p}
            <tr>
              <td>{#if p.project}<a href={`/projects/${p.project.id}`}>{p.project.name}</a>{:else}—{/if}</td>
              <td class="dim">{p.project_role?.name ?? '—'}</td>
              <td><span class="badge {statusClass(p.project?.project_status?.name)}">{p.project?.project_status?.name ?? '—'}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <div class="card">
    <h2>My applications</h2>
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if myApps.length === 0}
      <p class="muted">No open orders.</p>
    {:else}
      <table>
        <thead><tr><th>Project</th><th>Status</th></tr></thead>
        <tbody>
          {#each myApps as a}
            <tr>
              <td>{a.open_need?.project?.name ?? '—'}</td>
              <td><span class="badge {a.status === 'accepted' ? 'pos' : a.status === 'declined' ? 'neg' : 'dim'}">{a.status}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
