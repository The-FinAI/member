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
  let loading = $state(true);

  async function load(memberId: string) {
    loading = true;
    const [{ data: mp }, { data: ma }, { count: oc }, { count: pc }] = await Promise.all([
      supabase.from('project_member')
        .select('project(id, name, project_status(name)), project_role(name)')
        .eq('member_id', memberId),
      supabase.from('need_application')
        .select('id, status, open_need(project(name))')
        .eq('member_id', memberId)
        .order('created_at', { ascending: false }),
      supabase.from('open_need').select('*', { count: 'exact', head: true }).eq('status', 'open'),
      supabase.from('project').select('*', { count: 'exact', head: true })
    ]);
    myProjects = (mp as MyProject[]) ?? [];
    myApps = (ma as MyApp[]) ?? [];
    openCount = oc ?? 0;
    projectCount = pc ?? 0;
    loading = false;
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    const unsub = member.subscribe((m) => { if (m) load(m.id); else loading = false; });
    return unsub;
  });
</script>

<div class="stack">
  <h1>Dashboard{$member ? ` · ${$member.full_name.split(' ')[0]}` : ''}</h1>

  <div class="row" style="align-items:stretch;">
    <div class="card" style="flex:1; min-width:160px;">
      <div class="muted" style="font-size:.78rem; text-transform:uppercase;">Active projects</div>
      <div style="font-size:1.8rem; font-family:Newsreader,serif; color:var(--navy);">{projectCount}</div>
    </div>
    <a class="card" href="/opportunities" style="flex:1; min-width:160px;">
      <div class="muted" style="font-size:.78rem; text-transform:uppercase;">Open opportunities</div>
      <div style="font-size:1.8rem; font-family:Newsreader,serif; color:var(--accent);">{openCount}</div>
    </a>
    <div class="card" style="flex:1; min-width:160px;">
      <div class="muted" style="font-size:.78rem; text-transform:uppercase;">My projects</div>
      <div style="font-size:1.8rem; font-family:Newsreader,serif; color:var(--navy);">{myProjects.length}</div>
    </div>
  </div>

  <div class="card">
    <h2>My projects</h2>
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if myProjects.length === 0}
      <p class="muted">You're not on any project yet. Browse <a href="/opportunities">Open Opportunities</a> to join one.</p>
    {:else}
      <table>
        <thead><tr><th>Project</th><th>Role</th><th>Status</th></tr></thead>
        <tbody>
          {#each myProjects as p}
            <tr>
              <td>{#if p.project}<a href={`/projects/${p.project.id}`}>{p.project.name}</a>{:else}—{/if}</td>
              <td>{p.project_role?.name ?? '—'}</td>
              <td><span class="badge">{p.project?.project_status?.name ?? '—'}</span></td>
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
      <p class="muted">No applications yet.</p>
    {:else}
      <table>
        <thead><tr><th>Project</th><th>Status</th></tr></thead>
        <tbody>
          {#each myApps as a}
            <tr>
              <td>{a.open_need?.project?.name ?? '—'}</td>
              <td><span class="badge">{a.status}</span></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
