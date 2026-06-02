<script lang="ts">
  import { get } from 'svelte/store';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';
  import { t } from '$lib/i18n';
  import Medal from '$lib/Medal.svelte';
  import SectionNav from '$lib/SectionNav.svelte';
  import Breadcrumbs from '$lib/Breadcrumbs.svelte';

  // Shared body for the public member/card page. Used both by the
  // /members/[id] route and by the person quick-view drawer, so the drawer
  // mirrors the full page exactly. Pass `breadcrumbs={false}` inside a drawer
  // (the drawer already has its own header chrome).
  let { id, breadcrumbs = true }: { id: string; breadcrumbs?: boolean } = $props();

  // PUBLIC reputation page. By design this NEVER reads or shows liquid STR
  // balance or the ledger — only contribution (nominal), skills & projects.
  type Mem = {
    id: string; full_name: string; affiliation: string | null;
    avatar_url: string | null; bio: string | null; status: string; kind: string;
    links: Record<string, string> | null;
    member_position: { position: { name: string } | null }[];
  };
  type Skill = {
    skill_id: string; certified_level: string | null;
    skill: { name: string } | null;
  };
  type Proj = {
    id: string; name: string; status: string; role: string; nominal: number;
  };

  let mem = $state<Mem | null>(null);
  let skills = $state<Skill[]>([]);
  let projects = $state<Proj[]>([]);
  let totalNominal = $state(0);
  let msVerified = $state(0);
  let loading = $state(true);
  let notFound = $state(false);

  // --- editable offerable catalog (only for managers of this card) ---
  type ResType = { id: string; name: string; valuation_method: string };
  type GpuModel = { id: string; name: string; tflops: number };
  type ApiModel = { id: string; provider: string; name: string; usd_per_million: number };
  type CardResource = {
    id: string; name: string; capacity: string | null; availability: string;
    approval_status: string; type_id: string | null;
    resource_type: { name: string; unit: string | null } | null;
    gpu_model: { name: string } | null;
    api_model: { provider: string; name: string } | null;
  };
  const AVAIL = ['available', 'limited', 'committed'];

  let canEdit = $state(false);          // officer manages this member-card's catalog
  let canEditCatalog = $state(false);   // canEdit OR it's my own profile
  // viewer is looking at their own profile → inline self-edit controls
  const isMe = $derived(!!($member && mem && $member.id === mem.id));

  // self-profile editor (only when isMe)
  let pAffiliation = $state('');
  let pBio = $state('');
  let profileSaving = $state(false);
  let profileSaved = $state(false);
  let profileErr = $state('');

  async function saveProfile() {
    if (!mem) return;
    profileErr = ''; profileSaving = true; profileSaved = false;
    const { error: err } = await supabase.from('member')
      .update({ affiliation: pAffiliation || null, bio: pBio || null }).eq('id', mem.id);
    profileSaving = false;
    if (err) { profileErr = err.message; return; }
    profileSaved = true;
    mem = { ...mem, affiliation: pAffiliation || null, bio: pBio || null };
    member.update((m) => (m ? { ...m, affiliation: pAffiliation || null } : m));
  }

  let resTypes = $state<ResType[]>([]);
  let cardResources = $state<CardResource[]>([]);
  let gpuModels = $state<GpuModel[]>([]);
  let apiModels = $state<ApiModel[]>([]);
  let catError = $state('');
  let laborHours = $state('');
  let laborBusy = $state(false);
  let rName = $state(''); let rType = $state(''); let rCapacity = $state('');
  let rAvail = $state('available'); let rGpuModel = $state(''); let rApiModel = $state('');

  const laborTypeId = $derived(resTypes.find((rt) => rt.name === 'Labor')?.id ?? '');
  const myLabor = $derived(cardResources.find((r) => r.resource_type?.name === 'Labor') ?? null);
  const catalogResources = $derived(cardResources.filter((r) => r.resource_type?.name !== 'Labor'));
  const rSelType = $derived(resTypes.find((rt) => rt.id === rType) ?? null);
  const rSelMethod = $derived(rSelType?.valuation_method ?? 'flat');

  async function loadCatalog(cardId: string) {
    const [{ data: rt }, { data: mr }, { data: gm }, { data: am }] = await Promise.all([
      supabase.from('resource_type').select('id, name, valuation_method').order('rank'),
      supabase.from('resource')
        .select('id, name, capacity, availability, approval_status, type_id, resource_type(name, unit), gpu_model(name), api_model(provider, name)')
        .eq('scope', 'member').eq('holder_member_id', cardId).order('name'),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank')
    ]);
    resTypes = (rt as ResType[]) ?? [];
    cardResources = (mr as CardResource[]) ?? [];
    gpuModels = (gm as GpuModel[]) ?? [];
    apiModels = (am as ApiModel[]) ?? [];
    const cap = cardResources.find((r) => r.resource_type?.name === 'Labor')?.capacity ?? '';
    const m = cap?.match(/\d+/);
    laborHours = m ? m[0] : '';
  }

  async function saveLabor() {
    catError = '';
    const hrs = parseInt(laborHours, 10);
    if (!Number.isFinite(hrs) || hrs < 0) { catError = get(t)('Enter hours per month (a number).'); return; }
    laborBusy = true;
    const capacity = `${hrs} hrs/mo`;
    let err;
    if (myLabor) {
      ({ error: err } = await supabase.from('resource').update({ capacity }).eq('id', myLabor.id));
    } else {
      ({ error: err } = await supabase.from('resource').insert({
        name: 'My time', type_id: laborTypeId || null, scope: 'member',
        holder_member_id: id, capacity, availability: 'available'
      }));
    }
    laborBusy = false;
    if (err) { catError = err.message; return; }
    await loadCatalog(id);
  }

  async function addResource() {
    catError = '';
    if (!rName.trim()) return;
    const { error: err } = await supabase.from('resource').insert({
      name: rName.trim(), type_id: rType || null, scope: 'member',
      holder_member_id: id, capacity: rCapacity || null, availability: rAvail,
      gpu_model_id: rSelMethod === 'gpu' ? (rGpuModel || null) : null,
      api_model_id: rSelMethod === 'api' ? (rApiModel || null) : null
    });
    if (err) { catError = err.message; return; }
    rName = ''; rType = ''; rCapacity = ''; rAvail = 'available'; rGpuModel = ''; rApiModel = '';
    await loadCatalog(id);
  }

  async function removeResource(rid: string) {
    catError = '';
    const { error: err } = await supabase.from('resource').delete().eq('id', rid);
    if (err) { catError = err.message; return; }
    await loadCatalog(id);
  }

  const LINK_LABELS: Record<string, string> = {
    scholar: 'Google Scholar', hf: 'Hugging Face', github: 'GitHub', homepage: 'Homepage'
  };
  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }

  async function load(memberId: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; notFound = false; canEdit = false; canEditCatalog = false; cardResources = []; catError = '';
    profileSaved = false; profileErr = '';
    const { data: m } = await supabase.from('member')
      .select('id, full_name, affiliation, avatar_url, bio, status, kind, links, member_position(position(name))')
      .eq('id', memberId).maybeSingle();
    if (!m) { mem = null; notFound = true; loading = false; return; }
    mem = m as Mem;

    // is the viewer the owner of this profile?
    const me = get(member);
    const mineSelf = !!(me && me.id === memberId);
    if (mineSelf) { pAffiliation = (m as Mem).affiliation ?? ''; pBio = (m as Mem).bio ?? ''; }

    // can the viewer edit this profile's offerable catalog?
    // officers manage a member-card's catalog; everyone manages their own.
    if ((m as Mem).kind === 'card') {
      const { data: ce } = await supabase.rpc('manages_card', { p_card: memberId });
      canEdit = !!ce;
    }
    canEditCatalog = canEdit || mineSelf;
    if (canEditCatalog) await loadCatalog(memberId);

    const [{ data: ms }, { data: pm }, { data: nom }, { count: msc }] = await Promise.all([
      supabase.from('member_skill').select('skill_id, certified_level, skill(name)').eq('member_id', memberId),
      supabase.from('project_member')
        .select('project_id, project_role(name), project:project_id(id, name, project_status!project_status_id_fkey(name))')
        .eq('member_id', memberId),
      supabase.from('stater_project_member_nominal').select('project_id, nominal').eq('member_id', memberId),
      supabase.from('project_milestone').select('id', { count: 'exact', head: true })
        .eq('claimed_by', memberId).eq('status', 'verified')
    ]);

    skills = ((ms as any[]) ?? []).map((s) => ({
      skill_id: s.skill_id, certified_level: s.certified_level ?? null, skill: s.skill
    })).sort((a, b) => (RANK[b.certified_level ?? ''] ?? -1) - (RANK[a.certified_level ?? ''] ?? -1)
      || (a.skill?.name ?? '').localeCompare(b.skill?.name ?? ''));

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

  // re-load whenever the id prop changes (route nav or drawer subject swap)
  let lastId = '';
  $effect(() => {
    if (id && id !== lastId) { lastId = id; load(id); }
  });

  // certified role cards (medals) — guild-certified skills, ordered by rank
  const RANK: Record<string, number> = { apprentice: 0, journeyman: 1, craftsman: 2, master: 3 };
  const cards = $derived(
    skills.filter((s) => s.certified_level)
      .sort((a, b) => (RANK[b.certified_level!] ?? 0) - (RANK[a.certified_level!] ?? 0))
  );

  // in-page section nav (only the sections actually rendered, in DOM order)
  const sections = $derived([
    ...(canEditCatalog ? [{ id: 'catalog', label: isMe ? 'What I can bring' : 'What this card can bring' }] : []),
    { id: 'stats', label: 'Overview' },
    { id: 'role-cards', label: 'Role cards' },
    { id: 'projects', label: 'Projects' }
  ]);
</script>

<div class="stack">
  {#if breadcrumbs}
    <Breadcrumbs items={[{ label: 'Community', href: '/community' }, { label: mem?.full_name ?? 'Member' }]} />
  {/if}

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

      {#if isMe}
        <div class="self-edit stack" style="gap:.5rem; margin-top:.9rem; border-top:1px solid var(--border); padding-top:.8rem;">
          <span class="muted" style="font-size:.78rem;">{$t('This is your profile — edit how others see you.')}</span>
          <label class="stack" style="gap:.25rem;">
            <span class="muted" style="font-size:.75rem;">{$t('Affiliation')}</span>
            <input bind:value={pAffiliation} placeholder={$t('e.g. The Fin AI')} />
          </label>
          <label class="stack" style="gap:.25rem;">
            <span class="muted" style="font-size:.75rem;">{$t('Bio')}</span>
            <textarea bind:value={pBio} rows="3" placeholder={$t('A short bio shown on your public profile.')}></textarea>
          </label>
          <div class="row" style="gap:.5rem; align-items:center;">
            <button onclick={saveProfile} disabled={profileSaving}>{profileSaving ? $t('Saving…') : $t('Save')}</button>
            {#if profileSaved}<span class="badge">{$t('Saved')}</span>{/if}
            {#if profileErr}<span class="neg" style="font-size:.8rem;">{profileErr}</span>{/if}
          </div>
        </div>
      {/if}
    </div>

    <div class="detail">
      <SectionNav {sections} />
      <div class="detail-body">
    <!-- editable offerable catalog — only for officers/admins who manage this card -->
    {#if canEditCatalog}
      <div class="card stack" id="catalog">
        <h2 style="margin:0;">{isMe ? $t('What I can bring') : $t('What this card can bring')}</h2>
        <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">{isMe ? $t('Your offerable catalog — your monthly time and resources. New entries go to a steward for review.') : $t("This card’s offerable catalog — its monthly time and resources. You’re editing it as an officer; new entries go to a steward for review.")}</p>
        {#if catError}<p class="neg" style="font-size:.85rem;">{catError}</p>{/if}

        <!-- labor / time -->
        <div class="stack" style="gap:.4rem; border:1px solid var(--border); border-radius:8px; padding:.6rem .75rem;">
          <div class="row" style="justify-content:space-between; align-items:center;">
            <strong style="font-size:.9rem;">⏱ {$t('Time I can commit')}</strong>
            {#if myLabor}<span class="badge {myLabor.approval_status}">{myLabor.approval_status === 'approved' ? $t('✓ approved') : myLabor.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span>{/if}
          </div>
          <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Hours per month')}</span>
              <input type="number" min="0" bind:value={laborHours} placeholder={$t('e.g. 40')} style="width:120px;" /></label>
            <button onclick={saveLabor} disabled={laborBusy}>{laborBusy ? $t('Saving…') : myLabor ? $t('Update time') : $t('Set time')}</button>
          </div>
        </div>

        <div class="res-pending-note">{$t('⏳ New resources are reviewed by a steward before they can be offered to projects.')}</div>
        {#if catalogResources.length === 0}
          <p class="muted">{$t('No other resources added yet.')}</p>
        {:else}
          <table>
            <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Capacity')}</th><th>{$t('Availability')}</th><th>{$t('Review')}</th><th></th></tr></thead>
            <tbody>
              {#each catalogResources as r}
                <tr>
                  <td>{r.name}{#if r.gpu_model || r.api_model}<div class="muted" style="font-size:.75rem;">{r.gpu_model?.name ?? `${r.api_model?.provider} ${r.api_model?.name}`}</div>{/if}</td>
                  <td>{r.resource_type?.name ?? '—'}</td>
                  <td>{r.capacity ?? '—'}{#if r.capacity && r.resource_type?.unit}<span class="muted" style="font-size:.75rem;"> {r.resource_type.unit}</span>{/if}</td>
                  <td><span class="badge dim">{$t(r.availability)}</span></td>
                  <td><span class="badge {r.approval_status}">{r.approval_status === 'approved' ? $t('✓ approved') : r.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span></td>
                  <td><button class="danger" onclick={() => removeResource(r.id)}>{$t('Remove')}</button></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}

        <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.75rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Name')}</span>
            <input bind:value={rName} placeholder={$t('e.g. RTX 4090 ×2')} /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type')}</span>
            <select bind:value={rType}><option value="">—</option>{#each resTypes.filter((rt) => rt.name !== 'Labor') as ct}<option value={ct.id}>{ct.name}</option>{/each}</select></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Capacity')}</span>
            <input bind:value={rCapacity} placeholder={$t('optional')} style="width:120px;" /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Availability')}</span>
            <select bind:value={rAvail}>{#each AVAIL as a}<option value={a}>{$t(a)}</option>{/each}</select></label>
          {#if rSelMethod === 'gpu'}
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('GPU model')}</span>
              <select bind:value={rGpuModel}><option value="">{$t('— pick —')}</option>{#each gpuModels as g}<option value={g.id}>{g.name} · {g.tflops} TFLOPs</option>{/each}</select></label>
          {:else if rSelMethod === 'api'}
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('API model')}</span>
              <select bind:value={rApiModel}><option value="">{$t('— pick —')}</option>{#each apiModels as a}<option value={a.id}>{a.provider} {a.name} · ${a.usd_per_million}/M</option>{/each}</select></label>
          {/if}
          <button onclick={addResource}>{$t('Add resource')}</button>
        </div>
      </div>
    {/if}

    <!-- reputation stats (no liquid balance, by design) -->
    <div class="kpis" id="stats">
      <div class="kpi">
        <span class="k-label">{$t('Contribution')}</span>
        <span class="k-value accent">{totalNominal.toLocaleString()}</span>
        <span class="k-sub">{$t('nominal STR minted through work')}</span>
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

    <!-- role cards: a certified skill IS a role card (medal); uncertified skills
         are listed as awaiting a card. One section, no duplicate skills table. -->
    <div class="card stack" id="role-cards">
      <h2 style="margin:0;">{$t('Role cards')}</h2>
      {#if skills.length === 0}
        <p class="muted">{$t('No skills listed yet.')}</p>
      {:else}
        {#if cards.length > 0}
          <div class="row" style="gap:.5rem; flex-wrap:wrap;">
            {#each cards as c}<Medal name={c.skill?.name ?? c.skill_id} level={c.certified_level!} />{/each}
          </div>
        {/if}
        {@const pending = skills.filter((s) => !s.certified_level)}
        {#if pending.length > 0}
          <div class="stack" style="gap:.35rem;">
            <span class="muted" style="font-size:.78rem;">{$t('Skills awaiting a card')}</span>
            <div class="row" style="gap:.35rem; flex-wrap:wrap;">
              {#each pending as s}<span class="badge dim">{s.skill?.name ?? s.skill_id}</span>{/each}
            </div>
          </div>
        {/if}
      {/if}
    </div>

    <!-- projects -->
    <div class="card stack" id="projects">
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
      </div>
    </div>
  {/if}
</div>
