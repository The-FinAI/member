<script lang="ts">
  import { get } from 'svelte/store';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities } from '$lib/session';
  import { t } from '$lib/i18n';
  import Medal from '$lib/Medal.svelte';
  import BadgeTree from '$lib/cards/BadgeTree.svelte';
  import SkillCapacity from '$lib/people/SkillCapacity.svelte';
  import SectionNav from '$lib/SectionNav.svelte';
  import Breadcrumbs from '$lib/Breadcrumbs.svelte';
  import ResourceForgeForm from '$lib/resources/ResourceForgeForm.svelte';

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
  type Badge = {
    skill_id: string; level: string;
    skill: { name: string } | null;
  };
  type Proj = {
    id: string; name: string; status: string; role: string; nominal: number;
  };

  let mem = $state<Mem | null>(null);
  let badges = $state<Badge[]>([]);
  // managers (manages_card / manage_members / mint_skillcard) can award badges
  // via the talent-tree editor below.
  // owners may claim their own badges (staged → review); officers/admins award others'
  const canAward = $derived(isMe || canEdit || $capabilities.has('manage_members') || $capabilities.has('mint_skillcard'));
  let projects = $state<Proj[]>([]);
  let totalNominal = $state(0);
  let loading = $state(true);
  let notFound = $state(false);

  // --- editable offerable catalog (only for managers of this card) ---
  type ResType = { id: string; name: string; valuation_method: string };
  type GpuModel = { id: string; name: string; tflops: number };
  type ApiModel = { id: string; provider: string; name: string; usd_per_million: number };
  type CardResource = {
    id: string; name: string; capacity: string | null; availability: string;
    approval_status: string; type_id: string | null; scope: string;
    monthly_quota: number | null; unit: string | null;
    resource_type: { name: string; unit: string | null } | null;
    gpu_model: { name: string } | null;
    api_model: { provider: string; name: string } | null;
  };
  const AVAIL = ['available', 'limited', 'committed'];

  let editResId = $state('');           // resource currently being edited (re-review)
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
  // the editor only governs this card's OWN (member-scope) catalog…
  const ownResources = $derived(cardResources.filter((r) => r.scope === 'member'));
  const myLabor = $derived(ownResources.find((r) => r.resource_type?.name === 'Labor') ?? null);
  const catalogResources = $derived(ownResources);
  // …while community resources this person STEWARDS (holds for the community)
  // are shown read-only on their page too.
  const stewarded = $derived(cardResources.filter((r) => r.scope === 'community'));
  // read-only view (for visitors who can't edit): only show approved offerings
  const approvedLabor = $derived(myLabor && myLabor.approval_status === 'approved' ? myLabor : null);
  const approvedResources = $derived(catalogResources.filter((r) => r.resource_type?.name !== 'Labor' && r.approval_status === 'approved'));
  const hasPublicResources = $derived(!!approvedLabor || approvedResources.length > 0 || stewarded.length > 0);
  const resourceCount = $derived(
    (approvedLabor ? 1 : 0) + approvedResources.length + stewarded.length
  );
  const rSelType = $derived(resTypes.find((rt) => rt.id === rType) ?? null);
  const rSelMethod = $derived(rSelType?.valuation_method ?? 'flat');

  async function loadCatalog(cardId: string) {
    const [{ data: rt }, { data: mr }, { data: gm }, { data: am }] = await Promise.all([
      supabase.from('resource_type').select('id, name, valuation_method').order('rank'),
      supabase.from('resource')
        .select('id, name, capacity, availability, approval_status, type_id, scope, monthly_quota, unit, resource_type(name, unit), gpu_model(name), api_model(provider, name)')
        .eq('holder_member_id', cardId).order('name'),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank')
    ]);
    resTypes = (rt as ResType[]) ?? [];
    cardResources = (mr as CardResource[]) ?? [];
    gpuModels = (gm as GpuModel[]) ?? [];
    apiModels = (am as ApiModel[]) ?? [];
    const lab = cardResources.find((r) => r.scope === 'member' && r.resource_type?.name === 'Labor');
    laborHours = lab?.monthly_quota != null ? String(lab.monthly_quota) : '';
  }

  async function saveLabor() {
    catError = '';
    const hrs = parseInt(laborHours, 10);
    if (!Number.isFinite(hrs) || hrs < 0) { catError = get(t)('Enter hours per month (a number).'); return; }
    laborBusy = true;
    let err;
    if (myLabor) {
      // editing an existing pledge — update the quota in place (if it's still
      // pending it stays in the forge queue; a steward re-reviews if approved)
      ({ error: err } = await supabase.from('resource').update({ monthly_quota: hrs }).eq('id', myLabor.id));
    } else {
      // first-time pledge → forge_resource, which raises a forge_request so the
      // submission actually appears in the officer's mint/forge queue.
      ({ error: err } = await supabase.rpc('forge_resource', {
        p_type: laborTypeId || null, p_name: 'My time', p_holder: id, p_scope: 'member',
        p_monthly_quota: hrs, p_unit: 'hour'
      }));
    }
    laborBusy = false;
    if (err) { catError = err.message; return; }
    await loadCatalog(id);
  }

  async function addResource() {
    catError = '';
    if (!rName.trim()) return;
    // forge_resource raises a forge_request → the resource shows up in the
    // officer's mint/forge queue for review (a raw insert never would).
    const { error: err } = await supabase.rpc('forge_resource', {
      p_type: rType || null, p_name: rName.trim(), p_holder: id, p_scope: 'member',
      p_monthly_quota: Number(rCapacity) || 0,
      p_gpu_model: rSelMethod === 'gpu' ? (rGpuModel || null) : null,
      p_api_model: rSelMethod === 'api' ? (rApiModel || null) : null
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
    // owners edit their own; chapter officers manage a card; admins with
    // manage_members / manage_resources can edit any member's catalog.
    canEditCatalog = canEdit || mineSelf
      || $capabilities.has('manage_members') || $capabilities.has('manage_resources');
    // load the catalog for EVERYONE — visitors see a read-only "Resources" tab
    // (what this card can bring); editors get the full editor below.
    await loadCatalog(memberId);

    // new model: badges live in `badge`; contribution & project roster come from
    // work_commitment (nominal_str + the slot kind → role).
    const [{ data: bg }, { data: wc }] = await Promise.all([
      supabase.from('badge').select('skill_id, level, skill:skill_id(name)').eq('member_id', memberId),
      supabase.from('work_commitment')
        .select('project_id, nominal_str, slot:slot_id(slot_kind), project:project_id(id, name, project_status!project_status_id_fkey(name))')
        .eq('member_id', memberId)
    ]);

    badges = ((bg as any[]) ?? []).map((b) => ({ skill_id: b.skill_id, level: b.level, skill: b.skill }))
      .sort((a, b) => (RANK[b.level] ?? 0) - (RANK[a.level] ?? 0) || (a.skill?.name ?? '').localeCompare(b.skill?.name ?? ''));

    // aggregate per project: Σ nominal_str, and the strongest role (leader > resource > contributor)
    const byP: Record<string, Proj> = {};
    let tot = 0;
    for (const w of (wc as any[]) ?? []) {
      const pid = w.project_id; if (!pid) continue;
      const nom = Number(w.nominal_str) || 0; tot += nom;
      const kind = w.slot?.slot_kind as string | undefined;
      const role = kind === 'leader' ? 'Leader' : kind === 'work_resource' ? 'Resource' : 'Contributor';
      const cur = byP[pid];
      if (!cur) {
        byP[pid] = { id: w.project?.id ?? pid, name: w.project?.name ?? 'Project',
          status: w.project?.project_status?.name ?? '—', role, nominal: nom };
      } else {
        cur.nominal += nom;
        if (role === 'Leader' || (role === 'Resource' && cur.role === 'Contributor')) cur.role = role;
      }
    }
    totalNominal = tot;
    projects = Object.values(byP).filter((p) => p.id).sort((a, b) => b.nominal - a.nominal);
    loading = false;
  }

  // re-load whenever the id prop changes (route nav or drawer subject swap)
  let lastId = '';
  $effect(() => {
    if (id && id !== lastId) { lastId = id; load(id); }
  });

  const RANK: Record<string, number> = { apprentice: 0, journeyman: 1, craftsman: 2, master: 3 };

  // in-page section nav (only the sections actually rendered, in DOM order)
  const sections = $derived([
    { id: 'stats', label: 'Overview' },
    { id: 'skills', label: 'Skills' },
    { id: 'projects', label: 'Projects' },
    { id: 'resources', label: 'Resources' }
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
            {#if mem.status !== 'active'}<span class="badge dim">{mem.kind === 'card' && mem.status === 'invited' ? $t('unclaimed') : $t(mem.status)}</span>{/if}
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
    <!-- Resources: own offerable catalog + community resources this card stewards -->
    <div class="stack" id="resources">
    {#if canEditCatalog}
      <div class="card stack">
        <h2 style="margin:0;">{isMe ? $t('What I can bring') : $t('What this card can bring')}</h2>
        <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">{isMe ? $t('Your offerable catalog — your monthly time and resources. New entries go to a steward for review.') : $t("This card’s offerable catalog — its monthly time and resources. You’re editing it as an officer; new entries go to a steward for review.")}</p>
        {#if catError}<p class="neg" style="font-size:.85rem;">{catError}</p>{/if}

        <!-- unified resource-forge form (same as the community console);
             labour = your "My time" hours, declared as a Labor resource.
             editResId set → the form edits that resource (re-enters review). -->
        <ResourceForgeForm holder={id} scope="member" editId={editResId}
          onForged={() => { editResId = ''; loadCatalog(id); }} />
        {#if editResId}<button class="link" style="align-self:flex-start;" onclick={() => (editResId = '')}>{$t('Cancel edit')}</button>{/if}

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
                  <td>{r.monthly_quota != null ? r.monthly_quota.toLocaleString() : (r.capacity ?? '—')}{#if r.resource_type?.unit}<span class="muted" style="font-size:.75rem;"> {r.resource_type.unit}/mo</span>{/if}</td>
                  <td><span class="badge dim">{$t(r.availability)}</span></td>
                  <td><span class="badge {r.approval_status}">{r.approval_status === 'approved' ? $t('✓ approved') : r.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span></td>
                  <td style="white-space:nowrap;"><button onclick={() => (editResId = r.id)}>{$t('Edit')}</button> <button class="danger" onclick={() => removeResource(r.id)}>{$t('Remove')}</button></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    {:else}
      <!-- read-only catalog for visitors: what this card can bring -->
      <div class="card stack">
        <h2 style="margin:0;">{$t('What this card can bring')}</h2>
        <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">{$t('Approved offerings — the monthly time and resources this card can commit to projects.')}</p>
        {#if !hasPublicResources}<p class="muted">{$t('No resources offered yet.')}</p>{/if}
        {#if approvedLabor}
          <div class="row" style="justify-content:space-between; align-items:center; border:1px solid var(--border); border-radius:8px; padding:.5rem .75rem;">
            <strong style="font-size:.9rem;">⏱ {$t('Time')}</strong>
            <span class="mono">{approvedLabor.monthly_quota != null ? `${approvedLabor.monthly_quota} hrs/mo` : (approvedLabor.capacity ?? '—')}</span>
          </div>
        {/if}
        {#if approvedResources.length}
          <table>
            <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Capacity')}</th><th>{$t('Availability')}</th></tr></thead>
            <tbody>
              {#each approvedResources as r}
                <tr>
                  <td>{r.name}{#if r.gpu_model || r.api_model}<div class="muted" style="font-size:.75rem;">{r.gpu_model?.name ?? `${r.api_model?.provider} ${r.api_model?.name}`}</div>{/if}</td>
                  <td>{r.resource_type?.name ?? '—'}</td>
                  <td>{r.monthly_quota != null ? r.monthly_quota.toLocaleString() : (r.capacity ?? '—')}{#if r.resource_type?.unit}<span class="muted" style="font-size:.75rem;"> {r.resource_type.unit}/mo</span>{/if}</td>
                  <td><span class="badge dim">{$t(r.availability)}</span></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    {/if}

    {#if stewarded.length}
      <div class="card stack">
        <h2 style="margin:0;">{$t('Stewarded for the community')}</h2>
        <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">{$t('Community-owned resources this person holds in custody (the steward, not the owner).')}</p>
        <table>
          <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Monthly quota')}</th><th>{$t('Review')}</th></tr></thead>
          <tbody>
            {#each stewarded as r}
              <tr>
                <td>{r.name}{#if r.gpu_model || r.api_model}<div class="muted" style="font-size:.75rem;">{r.gpu_model?.name ?? `${r.api_model?.provider} ${r.api_model?.name}`}</div>{/if}</td>
                <td>{r.resource_type?.name ?? '—'}</td>
                <td class="mono">{r.monthly_quota != null ? r.monthly_quota.toLocaleString() : (r.capacity ?? '—')}{#if r.unit}<span class="muted" style="font-size:.75rem;"> {r.unit}</span>{/if}</td>
                <td><span class="badge {r.approval_status}">{r.approval_status === 'approved' ? $t('✓ approved') : r.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
    </div>

    <!-- reputation stats (no liquid balance, by design) -->
    <div class="kpis" id="stats">
      <div class="kpi">
        <span class="k-label">{$t('Contribution')}</span>
        <span class="k-value accent">{totalNominal.toLocaleString()}</span>
        <span class="k-sub">{$t('nominal STR minted through work')}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Badges')}</span>
        <span class="k-value">{badges.length}</span>
        <span class="k-sub">{$t('certified skills')}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Projects')}</span>
        <span class="k-value">{projects.length}</span>
        <span class="k-sub">{$t('collaborations on record')}</span>
      </div>
      <div class="kpi">
        <span class="k-label">{$t('Resources')}</span>
        <span class="k-value">{resourceCount}</span>
        <span class="k-sub">{$t('time & resources on offer')}</span>
      </div>
    </div>

    <!-- badges: a certified skill IS a badge (medal); uncertified skills
         are listed as awaiting a badge. One section, no duplicate skills table. -->
    <div class="card stack" id="skills">
      <SkillCapacity memberId={id} canEdit={canEditCatalog} />
    </div>

    <!-- Skills now live in the card above (SkillCapacity). The old badge tree is
         demoted to a collapsed, secondary block — kept (not deleted) so badge
         granting still works until person_skill is confirmed authoritative. -->
    <details class="card stack legacy" id="badges">
      <summary class="legacy-sum">{$t('Certified badges')} <span class="muted">· {$t('legacy — skills are set above')}</span></summary>
      {#if canAward}
        <p class="muted" style="font-size:.8rem; margin:.3rem 0 0;">{$t('Click ranks to stage raises across skills, then submit the batch for review.')}</p>
        <BadgeTree memberId={id} canEdit={true} onSubmitted={() => load(id)} />
      {:else if badges.length === 0}
        <p class="muted">{$t('No badges yet.')}</p>
      {:else}
        <div class="row" style="gap:.5rem; flex-wrap:wrap; margin-top:.4rem;">
          {#each badges as b}<Medal name={b.skill?.name ?? b.skill_id} level={b.level} />{/each}
        </div>
      {/if}
    </details>

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
