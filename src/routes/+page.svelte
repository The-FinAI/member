<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { PHASE2 } from '$lib/phase';
  import CountUp from '$lib/CountUp.svelte';
  import Hint from '$lib/Hint.svelte';
  import GettingStarted from '$lib/GettingStarted.svelte';
  import Medal from '$lib/Medal.svelte';
  import EntityCard from '$lib/EntityCard.svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // ---- portfolio: positions, applications, economy snapshot ----
  type MyProject = { project: { id: string; name: string; project_status: { name: string } | null } | null; project_role: { name: string } | null };
  type MyApp = { id: string; status: string; open_need: { project: { id: string; name: string } | null } | null };

  let myProjects = $state<MyProject[]>([]);
  let myApps = $state<MyApp[]>([]);
  let openCount = $state(0);
  let projectCount = $state(0);
  let balance = $state(0);
  let staked = $state(0);
  let loading = $state(true);

  // ---- profile: certifications, resources, ledger, identity ----
  const GUILD_RANK = ['apprentice', 'journeyman', 'craftsman', 'master'];

  type Skill = { id: string; name: string; parent_id: string | null };
  type MySkill = { skill_id: string; certified_level: string | null };
  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };
  type ResType = { id: string; name: string; valuation_method: string };
  type GpuModel = { id: string; name: string; tflops: number };
  type ApiModel = { id: string; provider: string; name: string; usd_per_million: number };
  type MyResource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; approval_status: string; type_id: string | null;
    resource_type: { name: string; unit: string | null } | null;
    gpu_model: { name: string } | null;
    api_model: { provider: string; name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let saving = $state(false);
  let affiliation = $state('');
  let saved = $state(false);

  let skills = $state<Skill[]>([]);
  let mySkills = $state<MySkill[]>([]);
  let accountId = $state('');
  let totalNominal = $state(0);
  let ledger = $state<LedgerRow[]>([]);
  let skillsLoading = $state(true);
  let error = $state('');

  let resTypes = $state<ResType[]>([]);
  let myResources = $state<MyResource[]>([]);
  let gpuModels = $state<GpuModel[]>([]);
  let apiModels = $state<ApiModel[]>([]);
  let rName = $state('');
  let rType = $state('');
  let rCapacity = $state('');
  let rAvail = $state('available');
  let rGpuModel = $state('');
  let rApiModel = $state('');

  const rSelType = $derived(resTypes.find((t) => t.id === rType) ?? null);
  const rSelMethod = $derived(rSelType?.valuation_method ?? 'flat');
  let laborHours = $state('');
  let laborBusy = $state(false);

  $effect(() => { if ($member) affiliation = $member.affiliation ?? ''; });

  async function loadPortfolio(memberId: string) {
    loading = true;
    const [{ data: mp }, { data: ma }, { count: oc }, { count: pc }, { data: bal }, { data: cm }] = await Promise.all([
      supabase.from('project_member')
        .select('project(id, name, project_status!project_status_id_fkey(name)), project_role(name)')
        .eq('member_id', memberId),
      supabase.from('need_application')
        .select('id, status, open_need(project(id, name))')
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

  async function loadSkills(memberId: string) {
    skillsLoading = true;
    const [{ data: tree }, { data: ms }, { data: rt }, { data: mr }, { data: nom }, { data: gm }, { data: am }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', memberId),
      supabase.from('resource_type').select('id, name, valuation_method').order('rank'),
      supabase.from('resource')
        .select('id, name, description, capacity, availability, approval_status, type_id, resource_type(name, unit), gpu_model(name), api_model(provider, name)')
        .eq('scope', 'member').eq('holder_member_id', memberId).order('name'),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', memberId),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank')
    ]);
    skills = (tree as Skill[]) ?? [];
    mySkills = ((ms as MySkill[]) ?? []).sort(
      (a, b) => GUILD_RANK.indexOf(b.certified_level ?? '') - GUILD_RANK.indexOf(a.certified_level ?? '')
        || skillName(a.skill_id).localeCompare(skillName(b.skill_id))
    );
    resTypes = (rt as ResType[]) ?? [];
    myResources = (mr as MyResource[]) ?? [];
    gpuModels = (gm as GpuModel[]) ?? [];
    apiModels = (am as ApiModel[]) ?? [];
    totalNominal = ((nom as { nominal: number }[]) ?? []).reduce((a, n) => a + (Number(n.nominal) || 0), 0);

    const { data: bal } = await supabase.from('stater_balance').select('account_id').eq('owner_member_id', memberId).maybeSingle();
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    if (accountId) {
      const { data: lg } = await supabase
        .from('stater_ledger')
        .select('id, amount, entry_type, reason, from_account, to_account, created_at')
        .or(`from_account.eq.${accountId},to_account.eq.${accountId}`)
        .order('created_at', { ascending: false })
        .limit(12);
      ledger = (lg as LedgerRow[]) ?? [];
    }
    skillsLoading = false;
  }

  // --- labor: a member's time, stored as a Labor-typed resource (hrs/month) ---
  const laborTypeId = $derived(resTypes.find((t) => t.name === 'Labor')?.id ?? '');
  const myLabor = $derived(myResources.find((r) => r.resource_type?.name === 'Labor') ?? null);
  $effect(() => {
    const cap = myLabor?.capacity ?? '';
    const m = cap.match(/\d+/);
    if (m && laborHours === '') laborHours = m[0];
  });

  async function saveLabor() {
    error = '';
    if (!$member) return;
    const hrs = parseInt(laborHours, 10);
    if (!Number.isFinite(hrs) || hrs < 0) { error = get(t)('Enter hours per month (a number).'); return; }
    laborBusy = true;
    const capacity = `${hrs} hrs/mo`;
    let err;
    if (myLabor) {
      ({ error: err } = await supabase.from('resource').update({ capacity }).eq('id', myLabor.id));
    } else {
      ({ error: err } = await supabase.from('resource').insert({
        name: 'My time', type_id: laborTypeId || null, scope: 'member',
        holder_member_id: $member.id, capacity, availability: 'available'
      }));
    }
    laborBusy = false;
    if (err) { error = err.message; return; }
    await loadSkills($member.id);
  }

  async function addResource() {
    error = '';
    if (!rName.trim() || !$member) return;
    const { error: err } = await supabase.from('resource').insert({
      name: rName.trim(), type_id: rType || null, scope: 'member',
      holder_member_id: $member.id, capacity: rCapacity || null, availability: rAvail,
      gpu_model_id: rSelMethod === 'gpu' ? (rGpuModel || null) : null,
      api_model_id: rSelMethod === 'api' ? (rApiModel || null) : null
    });
    if (err) { error = err.message; return; }
    rName = ''; rType = ''; rCapacity = ''; rAvail = 'available'; rGpuModel = ''; rApiModel = '';
    await loadSkills($member.id);
  }

  async function removeResource(id: string) {
    if (!$member) return;
    const { error: err } = await supabase.from('resource').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await loadSkills($member.id);
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; skillsLoading = false; return; }
    const unsub = member.subscribe((m) => {
      if (m) { loadPortfolio(m.id); loadSkills(m.id); }
      else { loading = false; skillsLoading = false; }
    });
    return unsub;
  });

  function skillName(skillId: string) { return skills.find((s) => s.id === skillId)?.name ?? skillId; }
  function statusClass(name: string | null | undefined) {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold') return 'warn';
    return '';
  }
  function statusKindOf(name: string | null | undefined): 'pos' | 'warn' | 'dim' {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold' || name === 'Under review') return 'warn';
    return 'dim';
  }
  function appKind(status: string): 'pos' | 'warn' | 'down' | 'dim' {
    if (status === 'joined') return 'pos';
    if (status === 'accepted') return 'warn';
    if (status === 'declined') return 'down';
    return 'dim';
  }
  // the officer's home unit — prefer a chapter (where cards are forged) over a
  // working group, so the banner links straight to where the Phase 1 work is.
  const myUnit = $derived($officerUnits.find((u) => u.kind === 'chapter') ?? $officerUnits[0] ?? null);
  // community-wide stewards: anyone holding an admin/approval capability runs the
  // WHOLE community (not a single unit), so they get a banner that mirrors the
  // officer one but points at the community-wide admin & approval surfaces.
  const canAdmin = $derived(
    $capabilities.has('manage_taxonomy') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('edit_any_project')
  );
  const canApprove = $derived(
    $capabilities.has('manage_resources') ||
      $capabilities.has('manage_stater') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('review_skillcard')
  );
  const isSteward = $derived(canAdmin || canApprove);
  const certifiedCount = $derived(mySkills.filter((s) => s.certified_level).length);
  const myCards = $derived(mySkills.filter((s) => s.certified_level));
  const catalogResources = $derived(myResources.filter((r) => r.resource_type?.name !== 'Labor'));
  const catalogTypes = $derived(resTypes.filter((t) => t.name !== 'Labor'));

  async function save() {
    if (!supabaseConfigured || !$member) return;
    saving = true; saved = false;
    const { error: err } = await supabase.from('member').update({ affiliation }).eq('id', $member.id);
    saving = false;
    if (!err) { saved = true; member.update((m) => (m ? { ...m, affiliation } : m)); }
  }
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">{$t('Portfolio')}{$member ? ` · ${$member.full_name.split(' ')[0]}` : ''}</h1>
      <span class="muted" style="font-size:.85rem;">{$t('Your stake across the Stater research economy.')}</span>
    </div>
    <div class="row" style="gap:.5rem;">
      {#if $member}<a href={`/members/${$member.id}`}><button class="ghost">{$t('Public page →')}</button></a>{/if}
      <a href="/projects"><button>{$t('Start a project')}</button></a>
    </div>
  </div>

  {#if myUnit}
    <div class="card row" style="justify-content:space-between; align-items:center; gap:.75rem; border-left:3px solid var(--accent); flex-wrap:wrap;">
      <div class="stack" style="gap:.2rem;">
        <strong style="font-size:.95rem;">{$t("You're an officer of {unit}", { unit: myUnit.name })}</strong>
        <span class="muted" style="font-size:.82rem;">{$t('Phase 1: forge a card for each researcher, claim your existing projects, declare their monthly work, and clear your approvals.')}</span>
      </div>
      <div class="row" style="gap:.5rem; flex-wrap:wrap;">
        {#if myUnit.kind === 'chapter'}
          <a href={`/units/${myUnit.unit_id}#forge`}><button>{$t('Forge a member card →')}</button></a>
        {/if}
        <a href={`/units/${myUnit.unit_id}`}><button class="ghost">{$t('Open my unit →')}</button></a>
      </div>
    </div>
  {/if}

  {#if isSteward}
    <div class="card row" style="justify-content:space-between; align-items:center; gap:.75rem; border-left:3px solid var(--warn); flex-wrap:wrap;">
      <div class="stack" style="gap:.2rem;">
        <strong style="font-size:.95rem;">{$t('You help steward the whole community')}</strong>
        <span class="muted" style="font-size:.82rem;">{$t('Phase 1: invite officers, set up the chapters & working groups, and keep every approval queue clear across the community.')}</span>
      </div>
      <div class="row" style="gap:.5rem; flex-wrap:wrap;">
        {#if canApprove}
          <a href="/admin/approvals"><button>{$t('Review approvals →')}</button></a>
        {/if}
        {#if canAdmin}
          <a href="/admin"><button class="ghost">{$t('Admin dashboard →')}</button></a>
        {/if}
      </div>
    </div>
  {/if}

  {#if PHASE2 && $member}<GettingStarted memberId={$member.id} />{/if}

  <!-- economy snapshot -->
  <div class="row rise-stagger" style="align-items:stretch; flex-wrap:wrap;">
    <div class="tile" style="flex:1; min-width:150px;">
      <span class="label">{$t('STR balance')} <Hint term="liquid" text={$t('Liquid STR — your spendable wallet balance. Used to post bonds and pay role-card fees.')} /></span>
      <span class="value accent"><CountUp value={balance} /></span>
      <span class="sub"><a href="/wallet">{$t('open wallet →')}</a></span>
    </div>
    <div class="tile" style="flex:1; min-width:150px;">
      <span class="label">{$t('Staked')} <Hint term="nominal" text={$t("Nominal STR you've minted into project pools — locked until each project settles, then it converts to liquid STR.")} /></span>
      <span class="value"><CountUp value={staked} /></span>
      <span class="sub">{$t('bonded in projects')}</span>
    </div>
    <div class="tile" style="flex:1; min-width:150px;">
      <span class="label">{$t('Contribution')}</span>
      <span class="value"><CountUp value={totalNominal} /></span>
      <span class="sub">{$t('nominal STR minted through work')}</span>
    </div>
    <div class="tile" style="flex:1; min-width:150px;">
      <span class="label">{$t('Role cards')}</span>
      <span class="value">{certifiedCount}</span>
      <span class="sub">{$t(certifiedCount === 1 ? 'card earned' : 'cards earned')}</span>
    </div>
    <a class="tile" href="/projects?tab=needs" style="flex:1; min-width:150px;">
      <span class="label">{$t('Open needs')}</span>
      <span class="value">{openCount}</span>
      <span class="sub">{$t('across {n} projects', { n: projectCount })}</span>
    </a>
  </div>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <!-- positions: each seat I hold, as a project card -->
  <div class="card stack">
    <h2 style="margin:0;">{$t('My positions')}</h2>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if myProjects.length === 0}
      <p class="muted">{$t('No positions yet. Browse')} <a href="/projects?tab=needs">{$t('Open Opportunities')}</a> {$t('to stake into a project, or')} <a href="/guide">{$t('read how it works')}</a>{$t('first.')}</p>
    {:else}
      <div class="card-grid">
        {#each myProjects as p}
          <EntityCard
            type="Project"
            title={p.project?.name ?? '—'}
            status={p.project?.project_status?.name ?? ''}
            statusKind={statusKindOf(p.project?.project_status?.name)}
            stats={[{ label: 'Role', value: p.project_role?.name ?? '—' }]}
            onclick={() => p.project && goto(`/projects/${p.project.id}`)}
          />
        {/each}
      </div>
    {/if}
  </div>

  <!-- applications: open orders into projects, as cards -->
  <div class="card stack">
    <h2 style="margin:0;">{$t('My applications')}</h2>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if myApps.length === 0}
      <p class="muted">{$t('No open orders.')}</p>
    {:else}
      <div class="card-grid">
        {#each myApps as a}
          <EntityCard
            type="Application"
            title={a.open_need?.project?.name ?? '—'}
            status={a.status === 'accepted' ? $t('accepted · confirm to join →') : a.status}
            statusKind={appKind(a.status)}
            onclick={() => a.open_need?.project && goto(`/projects/${a.open_need.project.id}`)}
          />
        {/each}
      </div>
    {/if}
  </div>

  <!-- role cards: read-only. A certified skill IS a role card; reviewers mint them. -->
  <div class="card stack">
    <div class="row" style="justify-content:space-between; align-items:center;">
      <h2 style="margin:0;">{$t('Role cards')}</h2>
      <a href="/community?tab=cards"><button class="ghost">{$t('Card catalog →')}</button></a>
    </div>
    <p class="muted" style="font-size:.82rem; margin-top:-.35rem;">
      {@html $t("Skills aren't self-rated — they're <strong>earned</strong>. A reviewer certifies each role card, climbing Apprentice → Journeyman → Craftsman → Master.")}
    </p>
    {#if skillsLoading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if mySkills.length === 0}
      <p class="muted">{$t('No role cards yet — a reviewer certifies your cards as you demonstrate skill.')}</p>
    {:else}
      {#if myCards.length > 0}
        <div class="row" style="gap:.5rem; flex-wrap:wrap;">
          {#each myCards as s}<Medal name={skillName(s.skill_id)} level={s.certified_level!} />{/each}
        </div>
      {/if}
      {@const pending = mySkills.filter((s) => !s.certified_level)}
      {#if pending.length > 0}
        <div class="stack" style="gap:.35rem;">
          <span class="muted" style="font-size:.78rem;">{$t('Skills awaiting a card')}</span>
          <div class="row" style="gap:.35rem; flex-wrap:wrap;">
            {#each pending as s}<span class="badge dim">{skillName(s.skill_id)}</span>{/each}
          </div>
        </div>
      {/if}
    {/if}
  </div>

  <!-- resources: an offerable catalog (what I can bring), steward-gated -->
  <div class="card stack">
    <h2>{$t('What I can bring')}</h2>
    <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">{$t("Your offerable catalog — time, compute, funding, data. You pledge specific amounts to a project when you join it; this is just what's available.")}</p>

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
      <p class="muted" style="font-size:.75rem; margin:0;">{@html $t('Valued at the community’s monthly <code>labor rate</code> and minted into a project once you pledge the hours.')}</p>
    </div>

    <div class="res-pending-note">{$t('⏳ New resources are reviewed by a steward before they can be offered to projects.')}</div>
    {#if skillsLoading}
      <p class="muted">{$t('Loading…')}</p>
    {:else}
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
          <select bind:value={rType}><option value="">—</option>{#each catalogTypes as ct}<option value={ct.id}>{ct.name}</option>{/each}</select></label>
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
      {#if rSelMethod === 'gpu' || rSelMethod === 'api'}
        <p class="muted" style="font-size:.78rem; margin-top:-.4rem;">{$t('Pick the closest model — its built-in throughput/price sets the USD→STR conversion when you declare monthly usage on a project.')}</p>
      {/if}
    {/if}
  </div>

  <!-- recent STR activity -->
  {#if ledger.length > 0}
    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">{$t('Recent STR activity')}</h2>
        <a href="/wallet"><button class="ghost">{$t('Full ledger →')}</button></a>
      </div>
      <table>
        <thead><tr><th>{$t('When')}</th><th>{$t('Type')}</th><th>{$t('Reason')}</th><th class="num">{$t('Amount')}</th></tr></thead>
        <tbody>
          {#each ledger as l}
            {@const incoming = l.to_account === accountId}
            <tr>
              <td class="muted" style="font-size:.78rem;">{new Date(l.created_at).toLocaleDateString()}</td>
              <td><span class="badge dim">{l.entry_type}</span></td>
              <td class="muted" style="font-size:.82rem;">{l.reason ?? '—'}</td>
              <td class="num mono {incoming ? 'up' : 'down'}">{incoming ? '+' : '−'}{l.amount.toLocaleString()}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}

  <!-- identity + capabilities -->
  {#if $member}
    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:flex-start;">
        <div>
          <div><strong>{$member.full_name}</strong></div>
          <div class="muted">{$member.email}</div>
        </div>
      </div>
      <label class="stack" style="gap:.3rem;">
        <span class="muted" style="font-size:.8rem;">{$t('Affiliation')}</span>
        <input bind:value={affiliation} />
      </label>
      <div class="row">
        <button onclick={save} disabled={saving}>{saving ? $t('Saving…') : $t('Save')}</button>
        {#if saved}<span class="badge">{$t('Saved')}</span>{/if}
      </div>
      <div class="stack" style="gap:.3rem; border-top:1px solid var(--border); padding-top:.6rem;">
        <span class="muted" style="font-size:.8rem;">{$t('Capabilities')}</span>
        {#if $capabilities.size === 0}
          <p class="muted" style="margin:0;">{$t('Standard member — no admin capabilities.')}</p>
        {:else}
          <div class="row" style="flex-wrap:wrap; gap:.35rem;">{#each [...$capabilities] as c}<span class="badge">{c}</span>{/each}</div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }
</style>
