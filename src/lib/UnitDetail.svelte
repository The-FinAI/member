<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, officerUnits, capabilities } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import SectionNav from '$lib/SectionNav.svelte';
  import Breadcrumbs from '$lib/Breadcrumbs.svelte';
  import CardDrawer from '$lib/CardDrawer.svelte';
  import Medal from '$lib/Medal.svelte';

  // Shared body for the unit (chapter / working-group) page. Used by the
  // /units/[id] route and by the unit quick-view drawer in Community, so the
  // drawer mirrors the full page. Pass `breadcrumbs={false}` inside a drawer.
  let { id, breadcrumbs = true }: { id: string; breadcrumbs?: boolean } = $props();

  type Unit = { id: string; code: string; name: string; kind: string; description: string | null };
  type Person = { id: string; full_name: string; affiliation: string | null; kind?: string; email?: string | null; status?: string };
  type Officer = { member_id: string; role: string; member: Person | null };
  type UnitMember = { member_id: string; status: string; applied_on: string; member: Person | null };
  type Proj = { id: string; name: string; status: string; org_unit_id: string | null };
  type Skill = { id: string; name: string; parent_id: string | null };
  type CardSkill = { member_id: string; certified_level: string | null; skill_id: string; skill: { name: string } | null };
  type ResType = { id: string; name: string; unit: string | null };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  let unit = $state<Unit | null>(null);
  let officers = $state<Officer[]>([]);
  let members = $state<UnitMember[]>([]);
  let pending = $state<UnitMember[]>([]);
  let projects = $state<Proj[]>([]);
  let myStatus = $state<string | null>(null); // pending | active | rejected | left | null
  let allMembers = $state<Person[]>([]); // for the officer "add member" picker
  let allProjects = $state<Proj[]>([]); // for the WG "add project" picker
  let addQ = $state('');
  let projQ = $state('');
  let loading = $state(true);
  let notFound = $state(false);
  let error = $state('');
  let msg = $state('');
  let busy = $state('');

  // editing info
  let editing = $state(false);
  let eName = $state(''); let eDesc = $state('');
  // forge card (chapters)
  let fName = $state(''); let fEmail = $state(''); let fAffil = $state('');

  // card management data (for the rich per-card drawer)
  let skills = $state<Skill[]>([]);
  let resTypes = $state<ResType[]>([]);
  let balances = $state<Record<string, number>>({});       // card member_id -> STR balance
  let cardSkills = $state<Record<string, CardSkill[]>>({}); // card member_id -> certified skills
  const laborType = $derived(resTypes.find((r) => r.name === 'Labor') ?? null);
  const offerTypes = $derived(resTypes.filter((r) => r.name !== 'Labor'));
  function resTypeName(rid: string) { return resTypes.find((r) => r.id === rid)?.name ?? '—'; }
  function skillNameOf(sid: string) { return skills.find((s) => s.id === sid)?.name ?? '—'; }
  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name));
  }

  const isChapter = $derived(unit?.kind === 'chapter');
  const isOfficer = $derived(
    !!unit && ($capabilities.has('manage_members') || $officerUnits.some((u) => u.unit_id === unit!.id))
  );
  const ROLE_LABEL: Record<string, string> = { chair: 'Chair', secretary: 'Secretary', leader: 'Leader' };
  function initials(name: string) {
    return name.split(' ').filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('') || '?';
  }

  async function load(unitId: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; notFound = false; error = '';
    const { data: u } = await supabase.from('org_unit')
      .select('id, code, name, kind, description').eq('id', unitId).maybeSingle();
    if (!u) { unit = null; notFound = true; loading = false; return; }
    unit = u as Unit;
    eName = unit.name; eDesc = unit.description ?? '';

    const isWG = unit.kind === 'working_group';
    const [{ data: off }, { data: oum }, { data: prj }, { data: am }, { data: sk }, { data: rt }] = await Promise.all([
      supabase.from('org_unit_officer')
        .select('member_id, role, member:member_id(id, full_name, affiliation)')
        .eq('org_unit_id', unitId).is('ended_on', null),
      supabase.from('org_unit_member')
        .select('member_id, status, applied_on, member:member_id(id, full_name, affiliation, kind, email, status)')
        .eq('org_unit_id', unitId),
      isWG
        ? supabase.from('project').select('id, name, org_unit_id, project_status!project_status_id_fkey(name)').order('name')
        : Promise.resolve({ data: [] as any[] }),
      supabase.from('member').select('id, full_name, affiliation, kind').order('full_name'),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('resource_type').select('id, name, unit').order('rank')
    ]);
    allMembers = (am as Person[]) ?? [];
    skills = ((sk as Skill[]) ?? []);
    resTypes = ((rt as any[]) ?? []).map((r) => ({ id: r.id, name: r.name, unit: r.unit }));

    officers = ((off as any[]) ?? []).sort((a, b) => a.role.localeCompare(b.role));
    const all = (oum as UnitMember[]) ?? [];
    members = all.filter((m) => m.status === 'active')
      .sort((a, b) => (a.member?.full_name ?? '').localeCompare(b.member?.full_name ?? ''));
    pending = all.filter((m) => m.status === 'pending')
      .sort((a, b) => a.applied_on.localeCompare(b.applied_on));
    allProjects = ((prj as any[]) ?? []).map((p) => ({
      id: p.id, name: p.name, org_unit_id: p.org_unit_id ?? null, status: p.project_status?.name ?? '—'
    }));
    projects = allProjects.filter((p) => p.org_unit_id === unitId);

    const mine = $member ? all.find((m) => m.member_id === $member!.id) : null;
    myStatus = mine?.status ?? null;
    loading = false;
    loadCardData();
  }

  // balances + certified skills for the card-kind members in this unit's roster,
  // used by the per-card management drawer
  async function loadCardData() {
    const cardIds = members.filter((m) => m.member?.kind === 'card').map((m) => m.member_id);
    if (cardIds.length === 0) { balances = {}; cardSkills = {}; return; }
    const [{ data: bal }, { data: ms }] = await Promise.all([
      supabase.from('stater_balance').select('owner_member_id, balance').in('owner_member_id', cardIds),
      supabase.from('member_skill').select('member_id, certified_level, skill_id, skill(name)').in('member_id', cardIds).not('certified_level', 'is', null)
    ]);
    const b: Record<string, number> = {};
    for (const r of (bal as any[]) ?? []) b[r.owner_member_id] = Number(r.balance) || 0;
    balances = b;
    const m: Record<string, CardSkill[]> = {};
    for (const r of (ms as CardSkill[]) ?? []) (m[r.member_id] ??= []).push(r);
    cardSkills = m;
  }

  let lastId = '';
  $effect(() => { if (id && id !== lastId) { lastId = id; load(id); } });

  async function apply() {
    if (!unit) return;
    busy = 'apply'; error = ''; msg = '';
    const { error: err } = await supabase.rpc('apply_to_unit', { p_unit: unit.id });
    busy = '';
    if (err) { error = err.message; return; }
    msg = get(t)('Application sent — an officer will review it.');
    await load(unit.id);
  }
  async function leave() {
    if (!unit) return;
    busy = 'leave'; error = ''; msg = '';
    const { error: err } = await supabase.rpc('leave_unit', { p_unit: unit.id });
    busy = '';
    if (err) { error = err.message; return; }
    await load(unit.id);
  }
  async function decide(memberId: string, approve: boolean) {
    if (!unit) return;
    busy = memberId; error = '';
    const { error: err } = await supabase.rpc('decide_unit_member', {
      p_unit: unit.id, p_member: memberId, p_approve: approve
    });
    busy = '';
    if (err) { error = err.message; return; }
    await load(unit.id);
  }
  async function removeMember(memberId: string) {
    if (!unit) return;
    busy = memberId; error = '';
    // an officer removing someone = reject their membership
    const { error: err } = await supabase.rpc('decide_unit_member', {
      p_unit: unit.id, p_member: memberId, p_approve: false
    });
    busy = '';
    if (err) { error = err.message; return; }
    await load(unit.id);
  }
  async function saveInfo() {
    if (!unit) return;
    busy = 'info'; error = '';
    const { error: err } = await supabase.rpc('update_org_unit', {
      p_unit: unit.id, p_name: eName.trim(), p_description: eDesc.trim()
    });
    busy = '';
    if (err) { error = err.message; return; }
    editing = false;
    await load(unit.id);
  }
  async function forge() {
    if (!unit || !fName.trim() || !fEmail.trim()) return;
    busy = 'forge'; error = ''; msg = '';
    const { error: err } = await supabase.rpc('forge_card', {
      p_full_name: fName.trim(), p_email: fEmail.trim(), p_unit: unit.id,
      p_affiliation: fAffil.trim() || null, p_items: []
    });
    busy = '';
    if (err) { error = err.message; return; }
    msg = get(t)('Card forged for {name}.', { name: fName.trim() });
    fName = ''; fEmail = ''; fAffil = '';
    await load(unit.id);
  }

  async function addExisting(memberId: string) {
    if (!unit) return;
    busy = 'add:' + memberId; error = '';
    const { error: err } = await supabase.rpc('officer_add_unit_member', {
      p_unit: unit.id, p_member: memberId
    });
    busy = '';
    if (err) { error = err.message; return; }
    addQ = '';
    await load(unit.id);
  }

  async function attachProject(projectId: string) {
    if (!unit) return;
    busy = 'attach:' + projectId; error = '';
    const { error: err } = await supabase.rpc('attach_project_to_unit', { p_project: projectId, p_unit: unit.id });
    busy = '';
    if (err) { error = err.message; return; }
    projQ = '';
    await load(unit.id);
  }
  async function detachProject(projectId: string) {
    if (!unit) return;
    busy = 'detach:' + projectId; error = '';
    const { error: err } = await supabase.rpc('detach_project_from_unit', { p_project: projectId });
    busy = '';
    if (err) { error = err.message; return; }
    await load(unit.id);
  }

  // ── per-card management drawer: inspect & directly edit a member-card ──
  type DrawerRes = { id: string; name: string; capacity: string | null; availability: string; approval_status: string; type_id: string | null; resource_type: { name: string } | null };
  type DrawerProj = { project: { id: string; name: string; project_status: { name: string } | null } | null; project_role: { name: string } | null };
  type CommitPeriod = { year_month: string; committed_amount: number; token_equivalent: number; status: string; approval: string };
  type CommitRow = {
    id: string; project_id: string; commitment_type: string;
    skill_id: string | null; resource_id: string | null;
    skill: { name: string } | null; resource: { name: string } | null;
    stater_commitment_period: CommitPeriod[];
  };
  let selected = $state<Person | null>(null);
  let selRes = $state<DrawerRes[]>([]);
  let selProjects = $state<DrawerProj[]>([]);
  let selCommits = $state<Record<string, CommitRow[]>>({});
  let selLoading = $state(false);
  let dMsg = $state(''); let dErr = $state(''); let dBusy = $state('');

  // drawer edit fields
  let dHours = $state('');
  let dResType = $state(''); let dResCap = $state('');
  let dStaged = $state<Record<string, string>>({}); // skillId -> level (new role cards to mint)
  let dNewSkill = $state(''); let dNewLevel = $state('apprentice');

  // per-project monthly contributions (labor + resource), declared for the card
  function currentMonth() { return new Date().toISOString().slice(0, 7); }
  let dMonth = $state(currentMonth());
  let dpSkill = $state<Record<string, string>>({});
  let dpHours = $state<Record<string, string>>({});
  let dpRes = $state<Record<string, string>>({});
  let dpQty = $state<Record<string, string>>({});
  const committableRes = $derived(selRes.filter((r) => r.approval_status === 'approved' && r.resource_type?.name !== 'Labor'));
  const cardCertSkills = $derived(selected ? (cardSkills[selected.id] ?? []) : []);
  const laborRes = $derived(selRes.find((r) => r.resource_type?.name === 'Labor') ?? null);
  const dStagedCount = $derived(Object.keys(dStaged).length);
  const cap = (s: string | null | undefined) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : '');
  function dStageAt(skillId: string, level: string) {
    if (dStaged[skillId] === level) { const { [skillId]: _, ...rest } = dStaged; dStaged = rest; }
    else dStaged = { ...dStaged, [skillId]: level };
  }
  function periodFor(rows: CommitRow[] | undefined, ym: string) {
    const out: { label: string; amount: number; str: number; approval: string }[] = [];
    for (const r of rows ?? []) {
      const p = r.stater_commitment_period.find((x) => x.year_month === ym);
      if (!p) continue;
      out.push({
        label: r.commitment_type === 'labor' ? (r.skill?.name ?? '—') : (r.resource?.name ?? '—'),
        amount: Number(p.committed_amount), str: Number(p.token_equivalent), approval: p.approval
      });
    }
    return out;
  }

  async function refreshSel(c: Person) {
    const [{ data: rs }, { data: pm }, { data: cm }] = await Promise.all([
      supabase.from('resource')
        .select('id, name, capacity, availability, approval_status, type_id, resource_type(name)')
        .eq('scope', 'member').eq('holder_member_id', c.id).order('name'),
      supabase.from('project_member')
        .select('project(id, name, project_status!project_status_id_fkey(name)), project_role(name)')
        .eq('member_id', c.id),
      supabase.from('stater_project_stake_commitment')
        .select('id, project_id, commitment_type, skill_id, resource_id, skill(name), resource(name), stater_commitment_period(year_month, committed_amount, token_equivalent, status, approval)')
        .eq('member_id', c.id)
    ]);
    selRes = (rs as DrawerRes[]) ?? [];
    selProjects = (pm as DrawerProj[]) ?? [];
    const byProj: Record<string, CommitRow[]> = {};
    for (const r of (cm as CommitRow[]) ?? []) (byProj[r.project_id] ??= []).push(r);
    selCommits = byProj;
  }

  async function openCard(c: Person) {
    selected = c; selLoading = true; selRes = []; selProjects = []; selCommits = {};
    dMsg = ''; dErr = ''; dStaged = {}; dResType = ''; dResCap = '';
    dMonth = currentMonth(); dpSkill = {}; dpHours = {}; dpRes = {}; dpQty = {};
    await refreshSel(c);
    const m = (laborRes?.capacity ?? '').match(/\d+/);
    dHours = m ? m[0] : '';
    selLoading = false;
  }
  function closeCard() { selected = null; }

  async function saveHours() {
    if (!selected) return;
    dErr = ''; dMsg = ''; dBusy = 'hours';
    const hrs = parseInt(dHours, 10);
    const capacity = Number.isFinite(hrs) && hrs > 0 ? `${hrs} hrs/mo` : null;
    let err;
    if (laborRes) {
      ({ error: err } = await supabase.from('resource').update({ capacity }).eq('id', laborRes.id));
    } else if (laborType && capacity) {
      ({ error: err } = await supabase.from('resource').insert({
        name: get(t)('Monthly time'), type_id: laborType.id, scope: 'member',
        holder_member_id: selected.id, capacity, availability: 'available'
      }));
    }
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dMsg = get(t)('Monthly hours updated.');
    await refreshSel(selected);
  }

  async function addResource() {
    if (!selected || !dResType) return;
    dErr = ''; dMsg = ''; dBusy = 'res';
    const { error: err } = await supabase.from('resource').insert({
      name: resTypeName(dResType), type_id: dResType, scope: 'member',
      holder_member_id: selected.id, capacity: dResCap.trim() || null, availability: 'available'
    });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dResType = ''; dResCap = '';
    dMsg = get(t)('Resource added — staged for review.');
    await refreshSel(selected);
  }
  async function removeResource(resId: string) {
    if (!selected) return;
    dErr = ''; dMsg = ''; dBusy = 'res:' + resId;
    const { error: err } = await supabase.from('resource').delete().eq('id', resId);
    dBusy = '';
    if (err) { dErr = err.message; return; }
    await refreshSel(selected);
  }

  async function submitRoleCards() {
    if (!selected || dStagedCount === 0) return;
    dErr = ''; dMsg = ''; dBusy = 'cards';
    const items = Object.entries(dStaged).map(([skill, level]) => ({ skill, level }));
    const { error: err } = await supabase.rpc('mint_skillcard_batch', { p_member: selected.id, p_items: items });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dMsg = get(t)('{n} role-card request(s) staged for review.', { n: items.length });
    dStaged = {};
    await loadCardData();
  }

  async function saveLabor(pid: string) {
    if (!selected) return;
    const sk = dpSkill[pid]; const hours = dpHours[pid];
    if (!sk || hours === undefined || hours === '') return;
    dErr = ''; dMsg = ''; dBusy = 'labor:' + pid;
    const { error: err } = await supabase.rpc('set_labor_commitment',
      { p: pid, sk, ym: dMonth, hours: Number(hours), p_as: selected.id });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dpHours = { ...dpHours, [pid]: '' };
    dMsg = get(t)('Monthly contribution recorded.');
    await refreshSel(selected);
  }
  async function saveResCommit(pid: string) {
    if (!selected) return;
    const res = dpRes[pid]; const qty = dpQty[pid];
    if (!res || qty === undefined || qty === '') return;
    dErr = ''; dMsg = ''; dBusy = 'rescommit:' + pid;
    const { error: err } = await supabase.rpc('set_resource_commitment',
      { p: pid, res, ym: dMonth, qty: Number(qty), p_as: selected.id });
    dBusy = '';
    if (err) { dErr = err.message; return; }
    dpQty = { ...dpQty, [pid]: '' };
    dMsg = get(t)('Monthly contribution recorded.');
    await refreshSel(selected);
  }

  function officersByRole(role: string) { return officers.filter((o) => o.role === role); }
  const roleOrder = $derived(isChapter ? ['chair', 'secretary'] : ['leader']);
  const officerIds = $derived(new Set(officers.map((o) => o.member_id)));
  // members who already belong (active) — exclude from the add picker
  const activeIds = $derived(new Set(members.map((m) => m.member_id)));
  const candidates = $derived(
    !addQ.trim() ? []
      : allMembers
          .filter((m) => !activeIds.has(m.id))
          .filter((m) => (m.full_name + ' ' + (m.affiliation ?? '')).toLowerCase().includes(addQ.trim().toLowerCase()))
          .slice(0, 8)
  );
  // projects not yet in this group, for the WG "add project" picker
  const projCandidates = $derived(
    !projQ.trim() ? []
      : allProjects
          .filter((p) => p.org_unit_id !== unit?.id)
          .filter((p) => p.name.toLowerCase().includes(projQ.trim().toLowerCase()))
          .slice(0, 8)
  );

  // in-page section nav (only the sections actually rendered, in DOM order)
  const sections = $derived([
    { id: 'officers', label: 'Officers' },
    ...(isOfficer && pending.length > 0 ? [{ id: 'applications', label: 'Applications' }] : []),
    { id: 'members', label: 'Members' },
    ...(isOfficer ? [{ id: 'add-member', label: 'Add an existing member' }] : []),
    ...(isOfficer && isChapter ? [{ id: 'forge', label: 'Forge a member card' }] : []),
    ...(!isChapter ? [{ id: 'projects', label: 'Projects' }] : [])
  ]);
</script>

<div class="stack">
  {#if breadcrumbs}
    <Breadcrumbs items={[{ label: 'Community', href: '/community?tab=chapters' }, { label: unit?.name ?? 'Unit' }]} />
  {/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if notFound || !unit}
    <div class="card"><p class="muted">{$t('No such unit.')}</p></div>
  {:else}
    <!-- header -->
    <div class="card stack" style="gap:.6rem;">
      <div class="row" style="justify-content:space-between; align-items:flex-start; gap:1rem; flex-wrap:wrap;">
        <div>
          <div class="row" style="align-items:center; gap:.5rem;">
            <h1 style="margin:0;">{unit.name}</h1>
            <span class="badge dim">{unit.code}</span>
            <span class="badge">{isChapter ? $t('Chapter') : $t('Working Group')}</span>
          </div>
          {#if unit.description && !editing}<p style="margin:.5rem 0 0; max-width:60ch;">{unit.description}</p>{/if}
        </div>
        <div class="row" style="gap:.5rem; align-items:center;">
          {#if isOfficer && !editing}
            <button onclick={() => { editing = true; eName = unit!.name; eDesc = unit!.description ?? ''; }}>{$t('Edit info')}</button>
          {/if}
          {#if $member && !isOfficer}
            {#if myStatus === 'active'}
              <span class="badge pos">{$t('Member')}</span>
              <button onclick={leave} disabled={busy === 'leave'}>{$t('Leave')}</button>
            {:else if myStatus === 'pending'}
              <span class="badge warn">{$t('Application pending')}</span>
              <button onclick={leave} disabled={busy === 'leave'}>{$t('Withdraw')}</button>
            {:else}
              <button class="stake" onclick={apply} disabled={busy === 'apply'}>
                {busy === 'apply' ? $t('Sending…') : $t('Apply to join')}</button>
            {/if}
          {/if}
        </div>
      </div>

      {#if editing}
        <div class="stack" style="gap:.5rem; border-top:1px solid var(--border-2); padding-top:.6rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Name')}</span>
            <input bind:value={eName} /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Description')}</span>
            <textarea bind:value={eDesc} rows="3" placeholder={$t('What this unit is about…')}></textarea></label>
          <div class="row" style="gap:.5rem;">
            <button class="stake" onclick={saveInfo} disabled={busy === 'info' || !eName.trim()}>{$t('Save')}</button>
            <button onclick={() => (editing = false)}>{$t('Cancel')}</button>
          </div>
        </div>
      {/if}

      {#if error}<p style="color:var(--down); margin:0;">{error}</p>{/if}
      {#if msg}<p class="pos" style="font-size:.85rem; margin:0;">{msg}</p>{/if}
      {#if isOfficer && $capabilities.has('manage_members')}
        <p class="muted" style="font-size:.78rem; margin:0;">{$t('To appoint officers, use the')} <a href="/admin/org-units">{$t('Admin · org units')}</a> {$t('page.')}</p>
      {/if}
    </div>

    <div class="detail">
      <SectionNav {sections} />
      <div class="detail-body">
    <!-- officers -->
    <div class="card stack" id="officers" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Officers')}</h2>
      {#if officers.length === 0}
        <p class="muted" style="margin:0;">{$t('No officers appointed yet.')}</p>
      {:else}
        {#each roleOrder as role}
          {#if officersByRole(role).length}
            <div class="stack" style="gap:.3rem;">
              <span class="muted" style="font-size:.72rem; text-transform:uppercase; letter-spacing:.03em;">{$t(ROLE_LABEL[role])}</span>
              <div class="row" style="gap:.6rem; flex-wrap:wrap;">
                {#each officersByRole(role) as o}
                  {#if o.member}
                    <a href={`/members/${o.member.id}`} class="person">
                      <span class="p-ava">{initials(o.member.full_name)}</span>
                      <span class="stack" style="gap:0;">
                        <span class="p-name">{o.member.full_name}</span>
                        <span class="p-sub">{o.member.affiliation ?? '—'}</span>
                      </span>
                    </a>
                  {/if}
                {/each}
              </div>
            </div>
          {/if}
        {/each}
      {/if}
    </div>

    <!-- pending applications (officers only) -->
    {#if isOfficer && pending.length > 0}
      <div class="card stack" id="applications" style="gap:.5rem;">
        <h2 style="margin:0; font-size:1rem;">{$t('Applications')} <span class="muted" style="font-weight:400;">· {pending.length}</span></h2>
        <ul style="margin:0; padding:0; list-style:none;">
          {#each pending as p}
            <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.55rem 0;">
              <a href={`/members/${p.member?.id}`} class="person">
                <span class="p-ava">{initials(p.member?.full_name ?? '?')}</span>
                <span class="stack" style="gap:0;">
                  <span class="p-name">{p.member?.full_name}</span>
                  <span class="p-sub">{p.member?.affiliation ?? '—'}</span>
                </span>
              </a>
              <div class="row" style="gap:.4rem;">
                <button class="stake" onclick={() => decide(p.member_id, true)} disabled={busy === p.member_id}>{$t('Approve')}</button>
                <button onclick={() => decide(p.member_id, false)} disabled={busy === p.member_id}>{$t('Reject')}</button>
              </div>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <!-- members roster -->
    <div class="card stack" id="members" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Members')} {#if members.length}<span class="muted" style="font-weight:400;">· {members.length}</span>{/if}</h2>
      {#if members.length === 0}
        <p class="muted" style="margin:0;">{$t('No members yet.')}</p>
      {:else}
        <ul style="margin:0; padding:0; list-style:none;">
          {#each members as m}
            {@const isCard = m.member?.kind === 'card'}
            {@const manageable = isOfficer && isCard && !!m.member}
            <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.5rem 0;">
              {#if manageable}
                <button type="button" class="person as-link" onclick={() => openCard(m.member!)}>
                  <span class="p-ava">{initials(m.member!.full_name)}</span>
                  <span class="stack" style="gap:0;">
                    <span class="p-name">{m.member!.full_name}<span class="badge dim" style="margin-left:.35rem; font-size:.68rem;">{$t('card')}</span></span>
                    <span class="p-sub">{m.member!.affiliation ?? '—'}</span>
                  </span>
                </button>
              {:else}
                <a href={`/members/${m.member?.id}`} class="person">
                  <span class="p-ava">{initials(m.member?.full_name ?? '?')}</span>
                  <span class="stack" style="gap:0;">
                    <span class="p-name">{m.member?.full_name}{#if isCard}<span class="badge dim" style="margin-left:.35rem; font-size:.68rem;">{$t('card')}</span>{/if}</span>
                    <span class="p-sub">{m.member?.affiliation ?? '—'}</span>
                  </span>
                </a>
              {/if}
              <div class="row" style="gap:.45rem; align-items:center; flex-wrap:wrap; justify-content:flex-end;">
                {#if manageable}
                  {#each (cardSkills[m.member_id] ?? []) as s}
                    <Medal name={$t(s.skill?.name ?? '—')} level={s.certified_level ?? 'apprentice'} size="sm" />
                  {/each}
                {/if}
                {#if isOfficer && officerIds.has(m.member_id)}
                  <span class="badge dim" title={$t('Serves as an officer of this unit.')}>{$t('Officer')}</span>
                {:else if manageable}
                  <button class="stake" onclick={() => openCard(m.member!)}>{$t('Manage')}</button>
                  <button onclick={() => removeMember(m.member_id)} disabled={busy === m.member_id}>{$t('Remove')}</button>
                {:else if isOfficer}
                  <button onclick={() => removeMember(m.member_id)} disabled={busy === m.member_id}>{$t('Remove')}</button>
                {/if}
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </div>

    <!-- add an existing member (officers / admins) -->
    {#if isOfficer}
      <div class="card stack" id="add-member" style="gap:.5rem;">
        <h2 style="margin:0; font-size:1rem;">{$t('Add an existing member')}</h2>
        <p class="muted" style="font-size:.82rem; margin:0;">
          {$t('Search anyone in the community and add them to this unit directly — no application needed.')}
        </p>
        <input placeholder={$t('Search by name…')} bind:value={addQ} style="max-width:340px;" />
        {#if candidates.length}
          <ul style="margin:0; padding:0; list-style:none;">
            {#each candidates as c}
              <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.45rem 0;">
                <span class="person">
                  <span class="p-ava">{initials(c.full_name)}</span>
                  <span class="stack" style="gap:0;">
                    <span class="p-name">{c.full_name}{#if c.kind === 'card'}<span class="badge dim" style="margin-left:.35rem; font-size:.68rem;">{$t('card')}</span>{/if}</span>
                    <span class="p-sub">{c.affiliation ?? '—'}</span>
                  </span>
                </span>
                <button class="stake" onclick={() => addExisting(c.id)} disabled={busy === 'add:' + c.id}>{$t('Add')}</button>
              </li>
            {/each}
          </ul>
        {:else if addQ.trim()}
          <p class="muted" style="font-size:.82rem; margin:0;">{$t('No matching members.')}</p>
        {/if}
      </div>
    {/if}

    <!-- forge a card (chapter officers) -->
    {#if isOfficer && isChapter}
      <div class="card stack" id="forge" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1rem;">{$t('Forge a member card')}</h2>
        <p class="muted" style="font-size:.82rem; margin:0;">
          {$t('Add someone in this chapter who cannot log in yet. They become a card you act for; value is custodial until they sign up and claim it.')}
        </p>
        <div class="row" style="align-items:flex-end; flex-wrap:wrap; gap:.5rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Full name')}</span>
            <input bind:value={fName} placeholder={$t('Full name')} /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Email (to claim later)')}</span>
            <input bind:value={fEmail} placeholder="name@example.com" /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Affiliation')}</span>
            <input bind:value={fAffil} placeholder={$t('Affiliation')} /></label>
          <button class="stake" onclick={forge} disabled={!fName.trim() || !fEmail.trim() || busy === 'forge'}>
            {busy === 'forge' ? $t('Forging…') : $t('Forge card')}</button>
        </div>
        <p class="muted" style="font-size:.76rem; margin:0;">{$t('Forge the identity here, then open the card from the roster above to mint role cards, set monthly hours and resources, and declare its work.')}</p>
      </div>
    {/if}

    <!-- projects (working groups) -->
    {#if !isChapter}
      <div class="card stack" id="projects" style="gap:.5rem;">
        <h2 style="margin:0; font-size:1rem;">{$t('Projects')} {#if projects.length}<span class="muted" style="font-weight:400;">· {projects.length}</span>{/if}</h2>
        {#if projects.length === 0}
          <p class="muted" style="margin:0;">{$t('No projects attributed to this group yet.')}</p>
        {:else}
          <table>
            <thead><tr><th>{$t('Project')}</th><th>{$t('Status')}</th>{#if isOfficer}<th></th>{/if}</tr></thead>
            <tbody>
              {#each projects as p}
                <tr>
                  <td><a href={`/projects/${p.id}`}><strong>{p.name}</strong></a></td>
                  <td class="muted">{p.status}</td>
                  {#if isOfficer}<td class="num"><button onclick={() => detachProject(p.id)} disabled={busy === 'detach:' + p.id}>{$t('Remove')}</button></td>{/if}
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}

        {#if isOfficer}
          <div class="stack" style="gap:.4rem; border-top:1px solid var(--border-2); padding-top:.6rem;">
            <span class="muted" style="font-size:.8rem;">{$t('Attach an existing project to this group.')}</span>
            <input placeholder={$t('Search projects…')} bind:value={projQ} style="max-width:340px;" />
            {#if projCandidates.length}
              <ul style="margin:0; padding:0; list-style:none;">
                {#each projCandidates as p}
                  <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.45rem 0;">
                    <span class="stack" style="gap:0;">
                      <a href={`/projects/${p.id}`} class="p-name">{p.name}</a>
                      <span class="p-sub">{p.status}{#if p.org_unit_id} · {$t('in another group')}{/if}</span>
                    </span>
                    <button class="stake" onclick={() => attachProject(p.id)} disabled={busy === 'attach:' + p.id}>{$t('Attach')}</button>
                  </li>
                {/each}
              </ul>
            {:else if projQ.trim()}
              <p class="muted" style="font-size:.82rem; margin:0;">{$t('No matching projects.')}</p>
            {/if}
          </div>
        {/if}
      </div>
    {/if}
      </div>
    </div>
  {/if}
</div>

<!-- per-card management drawer: inspect and act on a member-card -->
<CardDrawer
  open={selected !== null}
  type="Person"
  title={selected?.full_name ?? ''}
  subtitle={selected?.email ?? ''}
  onClose={closeCard}
>
  {#if selected}
    {#if dErr}<p style="color:var(--down); font-size:.82rem; margin:0;">{dErr}</p>{/if}
    {#if dMsg}<p class="pos" style="font-size:.82rem; margin:0;">{dMsg}</p>{/if}

    <section class="dsec">
      <h3>{$t('Identity')}</h3>
      <dl class="kv">
        <dt>{$t('Status')}</dt><dd><span class="badge {selected.status === 'active' ? 'pos' : 'warn'}">{$t(cap(selected.status))}</span></dd>
        {#if selected.affiliation}<dt>{$t('Affiliation')}</dt><dd>{selected.affiliation}</dd>{/if}
        <dt>{$t('Balance')}</dt><dd><span class="chip"><span class="amt">{(balances[selected.id] ?? 0).toLocaleString()}</span> STR</span></dd>
      </dl>
    </section>

    <!-- monthly hours: edit the card's Labor resource directly -->
    <section class="dsec">
      <h3>{$t('Monthly hours')}</h3>
      <div class="row" style="gap:.4rem; align-items:flex-end;">
        <input type="number" min="0" bind:value={dHours} placeholder="40" style="width:6rem;" />
        <button onclick={saveHours} disabled={dBusy === 'hours'}>{dBusy === 'hours' ? $t('Saving…') : $t('Save')}</button>
      </div>
    </section>

    <!-- role cards: mint additional ones directly onto the card -->
    <section class="dsec">
      <h3>{$t('Role cards')}</h3>
      {#if (cardSkills[selected.id] ?? []).length > 0}
        <div class="row" style="flex-wrap:wrap; gap:.3rem;">
          {#each cardSkills[selected.id] as s}
            <Medal name={$t(s.skill?.name ?? '—')} level={s.certified_level ?? 'apprentice'} size="sm" />
          {/each}
        </div>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('No role cards yet.')}</p>
      {/if}
      <div class="row" style="gap:.4rem; align-items:flex-end; flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem; flex:1; min-width:120px;"><span class="muted" style="font-size:.72rem;">{$t('Skill')}</span>
          <select bind:value={dNewSkill}>
            <option value="">{$t('Pick a skill…')}</option>
            {#each domains as d}
              <optgroup label={d.name}>
                {#each leavesOf(d.id) as s}<option value={s.id}>{s.name}</option>{/each}
              </optgroup>
            {/each}
          </select>
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Level')}</span>
          <select bind:value={dNewLevel}>{#each LEVELS as lv}<option value={lv}>{$t(LEVEL_LABEL[lv])}</option>{/each}</select>
        </label>
        <button onclick={() => { if (dNewSkill) { dStageAt(dNewSkill, dNewLevel); dNewSkill = ''; } }} disabled={!dNewSkill}>{$t('Stage')}</button>
      </div>
      {#if dStagedCount > 0}
        <div class="row" style="flex-wrap:wrap; gap:.3rem; align-items:center;">
          {#each Object.entries(dStaged) as [sid, lv]}
            <span class="badge dim" style="font-size:.72rem;">{skillNameOf(sid)} · {$t(LEVEL_LABEL[lv])}
              <button class="x" onclick={() => dStageAt(sid, lv)} aria-label={$t('Remove')}>×</button></span>
          {/each}
          <button class="stake" onclick={submitRoleCards} disabled={dBusy === 'cards'}>{dBusy === 'cards' ? $t('Submitting…') : $t('Submit for review')}</button>
        </div>
      {/if}
    </section>

    <!-- resources: add / remove directly on the card -->
    <section class="dsec">
      <h3>{$t('Resources')}</h3>
      {#if selLoading}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Loading…')}</p>
      {:else if selRes.filter((r) => r.resource_type?.name !== 'Labor').length > 0}
        <ul class="dlist">
          {#each selRes.filter((r) => r.resource_type?.name !== 'Labor') as r}
            <li>
              <span>{$t(r.resource_type?.name ?? r.name)}{#if r.capacity} · {r.capacity}{/if}</span>
              <span class="row" style="gap:.4rem; align-items:center;">
                <span class="badge {r.approval_status === 'approved' ? 'pos' : r.approval_status === 'rejected' ? 'down' : 'warn'}" style="font-size:.68rem;">{$t(cap(r.approval_status))}</span>
                <button class="x" onclick={() => removeResource(r.id)} disabled={dBusy === 'res:' + r.id} aria-label={$t('Remove')}>×</button>
              </span>
            </li>
          {/each}
        </ul>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('No resources staged yet.')}</p>
      {/if}
      <div class="row" style="gap:.4rem; align-items:flex-end; flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem; flex:1; min-width:120px;"><span class="muted" style="font-size:.72rem;">{$t('Resource type')}</span>
          <select bind:value={dResType}>
            <option value="">{$t('Pick a type…')}</option>
            {#each offerTypes as ot}<option value={ot.id}>{$t(ot.name)}</option>{/each}
          </select>
        </label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Capacity / detail')}</span>
          <input bind:value={dResCap} placeholder={$t('e.g. 4× A100, $5k')} style="width:9rem;" />
        </label>
        <button onclick={addResource} disabled={!dResType || dBusy === 'res'}>{$t('Add')}</button>
      </div>
    </section>

    <section class="dsec">
      <div class="row" style="justify-content:space-between; align-items:center; gap:.5rem;">
        <h3 style="margin:0;">{$t('Projects')}</h3>
        {#if selProjects.length > 0}
          <label class="row" style="gap:.3rem; align-items:center;"><span class="muted" style="font-size:.72rem;">{$t('Month')}</span>
            <input type="month" bind:value={dMonth} style="font-size:.78rem;" />
          </label>
        {/if}
      </div>
      {#if selLoading}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Loading…')}</p>
      {:else if selProjects.length > 0}
        <p class="muted" style="font-size:.74rem; margin:0;">{$t('Declare this card’s monthly contributions per project. STR accrues to the card; over-capacity months go to an officer for review.')}</p>
        <div class="pcommit-list">
          {#each selProjects as p}
            {@const pid = p.project?.id ?? ''}
            {@const declared = periodFor(selCommits[pid], dMonth)}
            <div class="pcommit">
              <div class="row" style="justify-content:space-between; align-items:baseline; gap:.5rem;">
                <a href={`/projects/${pid}`}>{p.project?.name}</a>
                <span class="muted" style="font-size:.7rem;">{$t(p.project_role?.name ?? '')} · {$t(p.project?.project_status?.name ?? '')}</span>
              </div>
              {#if declared.length > 0}
                <div class="row" style="flex-wrap:wrap; gap:.3rem;">
                  {#each declared as d}
                    <span class="badge {d.approval === 'needs_review' ? 'warn' : 'pos'}" style="font-size:.68rem;">
                      {$t(d.label)} · {d.amount} · {d.str} STR{#if d.approval === 'needs_review'} · {$t('review')}{/if}
                    </span>
                  {/each}
                </div>
              {/if}
              {#if cardCertSkills.length > 0}
                <div class="row" style="gap:.3rem; align-items:flex-end; flex-wrap:wrap;">
                  <select bind:value={dpSkill[pid]} style="font-size:.78rem; flex:1; min-width:110px;">
                    <option value="">{$t('Skill (labor)…')}</option>
                    {#each cardCertSkills as s}<option value={s.skill_id}>{$t(s.skill?.name ?? '—')}</option>{/each}
                  </select>
                  <input type="number" min="0" bind:value={dpHours[pid]} placeholder={$t('hrs')} style="width:4.5rem; font-size:.78rem;" />
                  <button onclick={() => saveLabor(pid)} disabled={!dpSkill[pid] || dpHours[pid] === undefined || dpHours[pid] === '' || dBusy === 'labor:' + pid}>{dBusy === 'labor:' + pid ? $t('Saving…') : $t('Mint')}</button>
                </div>
              {/if}
              {#if committableRes.length > 0}
                <div class="row" style="gap:.3rem; align-items:flex-end; flex-wrap:wrap;">
                  <select bind:value={dpRes[pid]} style="font-size:.78rem; flex:1; min-width:110px;">
                    <option value="">{$t('Resource…')}</option>
                    {#each committableRes as r}<option value={r.id}>{$t(r.resource_type?.name ?? r.name)}{#if r.capacity} · {r.capacity}{/if}</option>{/each}
                  </select>
                  <input type="number" min="0" bind:value={dpQty[pid]} placeholder={$t('qty')} style="width:4.5rem; font-size:.78rem;" />
                  <button onclick={() => saveResCommit(pid)} disabled={!dpRes[pid] || dpQty[pid] === undefined || dpQty[pid] === '' || dBusy === 'rescommit:' + pid}>{dBusy === 'rescommit:' + pid ? $t('Saving…') : $t('Mint')}</button>
                </div>
              {/if}
              {#if cardCertSkills.length === 0 && committableRes.length === 0}
                <p class="muted" style="font-size:.72rem; margin:0;">{$t('Add a role card or an approved resource above to mint contributions here.')}</p>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <p class="muted" style="font-size:.82rem; margin:0;">{$t('Not on any project yet. Seat this card onto a project from its Projects page.')}</p>
      {/if}
    </section>
  {/if}
</CardDrawer>

<style>
  .person { display: inline-flex; align-items: center; gap: .5rem; text-decoration: none; color: inherit; }
  .as-link { background: transparent; border: none; cursor: pointer; padding: 0; text-align: left; }
  .dsec { display: flex; flex-direction: column; gap: .4rem; }
  .dsec h3 { margin: 0; font-size: .82rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .kv { display: grid; grid-template-columns: max-content 1fr; gap: .3rem .8rem; margin: 0; }
  .kv dt { color: var(--muted); font-size: .82rem; }
  .kv dd { margin: 0; font-size: .85rem; }
  .dlist { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: .4rem; }
  .dlist li { display: flex; align-items: center; justify-content: space-between; gap: .5rem; font-size: .85rem; }
  .pcommit-list { display: flex; flex-direction: column; gap: .6rem; }
  .pcommit {
    display: flex; flex-direction: column; gap: .35rem;
    border: 1px solid var(--border); border-radius: 10px; padding: .55rem .6rem;
  }
  .pcommit a { color: var(--accent); text-decoration: none; font-size: .85rem; }
  .badge .x {
    background: transparent; border: none; cursor: pointer; color: inherit;
    font-size: .9rem; line-height: 1; padding: 0 0 0 .25rem; opacity: .65;
  }
  .badge .x:hover { opacity: 1; }
  .p-ava {
    width: 34px; height: 34px; border-radius: 50%; flex-shrink: 0;
    display: inline-flex; align-items: center; justify-content: center;
    background: var(--accent-soft); color: var(--accent); font-size: .78rem; font-weight: 600;
  }
  .p-name { font-size: .9rem; font-weight: 600; }
  .person:hover .p-name { color: var(--accent); }
  .p-sub { font-size: .74rem; color: var(--muted); }
</style>
