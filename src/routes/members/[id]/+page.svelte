<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import Medal from '$lib/Medal.svelte';

  // PUBLIC reputation page. By design this NEVER reads or shows liquid STR
  // balance or the ledger — only contribution (nominal), skills & projects.
  type Mem = {
    id: string; full_name: string; affiliation: string | null;
    avatar_url: string | null; bio: string | null; status: string; kind: string;
    links: Record<string, string> | null;
    member_position: { position: { name: string } | null }[];
  };
  type Skill = {
    skill_id: string; self_level: string; certified_level: string | null;
    skill: { name: string } | null;
    credit: number; endorsements: number;
  };
  type Proj = {
    id: string; name: string; status: string; role: string; nominal: number;
  };

  const id = $derived($page.params.id);

  let mem = $state<Mem | null>(null);
  let skills = $state<Skill[]>([]);
  let projects = $state<Proj[]>([]);
  let totalNominal = $state(0);
  let msVerified = $state(0);
  let loading = $state(true);
  let notFound = $state(false);

  const LINK_LABELS: Record<string, string> = {
    scholar: 'Google Scholar', hf: 'Hugging Face', github: 'GitHub', homepage: 'Homepage'
  };
  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }
  function levelClass(l: string) {
    return l === 'Expert' ? 'up' : l === 'Advanced' ? 'info' : l === 'Intermediate' ? '' : 'dim';
  }

  async function load(memberId: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; notFound = false;
    const { data: m } = await supabase.from('member')
      .select('id, full_name, affiliation, avatar_url, bio, status, kind, links, member_position(position(name))')
      .eq('id', memberId).maybeSingle();
    if (!m) { mem = null; notFound = true; loading = false; return; }
    mem = m as Mem;

    const [{ data: ms }, { data: cr }, { data: pm }, { data: nom }, { count: msc }] = await Promise.all([
      supabase.from('member_skill').select('skill_id, self_level, certified_level, skill(name)').eq('member_id', memberId),
      supabase.from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', memberId),
      supabase.from('project_member')
        .select('project_id, project_role(name), project:project_id(id, name, project_status!project_status_id_fkey(name))')
        .eq('member_id', memberId),
      supabase.from('stater_project_member_nominal').select('project_id, nominal').eq('member_id', memberId),
      supabase.from('project_milestone').select('id', { count: 'exact', head: true })
        .eq('claimed_by', memberId).eq('status', 'verified')
    ]);

    const creditBy: Record<string, { credit: number; endorsements: number }> = {};
    for (const c of (cr as any[]) ?? []) creditBy[c.skill_id] = { credit: Number(c.credit) || 0, endorsements: Number(c.endorsements) || 0 };
    skills = ((ms as any[]) ?? []).map((s) => ({
      skill_id: s.skill_id, self_level: s.self_level, certified_level: s.certified_level ?? null, skill: s.skill,
      credit: creditBy[s.skill_id]?.credit ?? 0, endorsements: creditBy[s.skill_id]?.endorsements ?? 0
    })).sort((a, b) => b.credit - a.credit || (a.skill?.name ?? '').localeCompare(b.skill?.name ?? ''));

    const nomBy: Record<string, number> = {};
    let tot = 0;
    for (const n of (nom as any[]) ?? []) { nomBy[n.project_id] = Number(n.nominal) || 0; tot += Number(n.nominal) || 0; }
    totalNominal = tot;

    projects = ((pm as any[]) ?? []).map((r) => ({
      id: r.project?.id, name: r.project?.name ?? 'Project',
      status: r.project?.project_status?.name ?? '—',
      role: r.project_role?.name ?? 'Contributor',
      nominal: nomBy[r.project_id] ?? 0
    })).filter((p) => p.id)
       .sort((a, b) => b.nominal - a.nominal);

    msVerified = msc ?? 0;
    loading = false;
  }

  // re-load whenever the [id] param changes (client-side nav between profiles)
  let lastId = '';
  $effect(() => {
    if (id && id !== lastId) { lastId = id; load(id); }
  });

  onMount(() => { if (id) { lastId = id; load(id); } });

  const totalEndorsers = $derived(skills.reduce((a, s) => a + s.endorsements, 0));
  const totalCredit = $derived(skills.reduce((a, s) => a + s.credit, 0));
  // certified role cards (medals) — guild-certified skills, ordered by rank
  const RANK: Record<string, number> = { apprentice: 0, journeyman: 1, craftsman: 2, master: 3 };
  const cards = $derived(
    skills.filter((s) => s.certified_level)
      .sort((a, b) => (RANK[b.certified_level!] ?? 0) - (RANK[a.certified_level!] ?? 0))
  );
</script>

<div class="stack">
  <p><a href="/members">← {$t('Leaderboard')}</a></p>

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if notFound || !mem}
    <div class="card"><p class="muted">{$t('No such member.')}</p></div>
  {:else}
    <!-- header -->
    <div class="card">
      <div class="row" style="gap:1rem; align-items:flex-start; flex-wrap:wrap;">
        <div class="pod-ava" style="width:64px; height:64px; font-size:1.4rem;">
          {#if mem.avatar_url}<img src={mem.avatar_url} alt={mem.full_name} style="width:100%; height:100%; object-fit:cover; border-radius:inherit;" />{:else}{initials(mem.full_name)}{/if}
        </div>
        <div style="flex:1; min-width:200px;">
          <div class="row" style="align-items:center; gap:.5rem;">
            <h1 style="margin:0;">{mem.full_name}</h1>
            {#if mem.kind === 'card'}<span class="badge dim" title={$t('A member-card: managed by a chapter officer; value is custodial until the person signs up and claims it.')}>{$t('card')}</span>{/if}
            {#if mem.status !== 'active'}<span class="badge dim">{mem.status}</span>{/if}
          </div>
          <p class="muted" style="margin:.2rem 0 0;">{mem.affiliation ?? '—'}</p>
          {#if mem.member_position?.length}
            <div class="row" style="gap:.35rem; margin-top:.4rem; flex-wrap:wrap;">
              {#each mem.member_position as p}{#if p.position?.name}<span class="badge">{p.position.name}</span>{/if}{/each}
            </div>
          {/if}
          {#if mem.links && Object.keys(mem.links).length}
            <div class="row" style="gap:.6rem; margin-top:.5rem; flex-wrap:wrap;">
              {#each Object.entries(mem.links) as [k, v]}
                {#if v}<a href={v} target="_blank" rel="noopener" style="font-size:.82rem;">{LINK_LABELS[k] ?? k} ↗</a>{/if}
              {/each}
            </div>
          {/if}
        </div>
      </div>
      {#if mem.bio}<p style="margin:.8rem 0 0;">{mem.bio}</p>{/if}
    </div>

    <!-- reputation stats (no liquid balance, by design) -->
    <div class="kpis">
      <div class="kpi">
        <span class="k-label">{$t('Contribution')}</span>
        <span class="k-value accent">{totalNominal.toLocaleString()}</span>
        <span class="k-sub">{$t('nominal STR minted through work')}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Reputation')}</span>
        <span class="k-value">{totalCredit.toLocaleString()}</span>
        <span class="k-sub">{$t('{n} endorsements across skills', { n: totalEndorsers })}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Milestones')}</span>
        <span class="k-value">{msVerified}</span>
        <span class="k-sub">{$t('verified outcomes claimed')}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Projects')}</span>
        <span class="k-value">{projects.length}</span>
        <span class="k-sub">{$t('collaborations on record')}</span>
      </div>
    </div>

    <!-- certified role cards (medals) -->
    {#if cards.length > 0}
      <div class="card stack">
        <h2 style="margin:0;">{$t('Role cards')}</h2>
        <div class="row" style="gap:.5rem; flex-wrap:wrap;">
          {#each cards as c}<Medal name={c.skill?.name ?? c.skill_id} level={c.certified_level!} />{/each}
        </div>
      </div>
    {/if}

    <!-- skills -->
    <div class="card stack">
      <h2 style="margin:0;">{$t('Skills & reputation')}</h2>
      {#if skills.length === 0}
        <p class="muted">{$t('No skills listed yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Skill')}</th><th>{$t('Self-rating')}</th><th class="num">{$t('Reputation')}</th><th class="num">{$t('Endorsers')}</th></tr></thead>
          <tbody>
            {#each skills as s}
              <tr>
                <td><strong>{s.skill?.name ?? s.skill_id}</strong></td>
                <td><span class="badge {levelClass(s.self_level)}">{s.self_level}</span></td>
                <td class="num mono">{s.credit.toLocaleString()}</td>
                <td class="num mono dim">{s.endorsements}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <!-- projects -->
    <div class="card stack">
      <h2 style="margin:0;">{$t('Projects')}</h2>
      {#if projects.length === 0}
        <p class="muted">{$t('Not on any project yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Project')}</th><th>{$t('Role')}</th><th>{$t('Status')}</th><th class="num">{$t('Contribution')}</th></tr></thead>
          <tbody>
            {#each projects as p}
              <tr>
                <td><a href={`/projects/${p.id}`}><strong>{p.name}</strong></a></td>
                <td><span class="badge dim">{p.role}</span></td>
                <td class="muted">{p.status}</td>
                <td class="num mono">{p.nominal > 0 ? p.nominal.toLocaleString() : '—'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  {/if}
</div>
