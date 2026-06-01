<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, officerUnits, capabilities } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Unit = { id: string; code: string; name: string; kind: string; description: string | null };
  type Person = { id: string; full_name: string; affiliation: string | null; kind?: string };
  type Officer = { member_id: string; role: string; member: Person | null };
  type UnitMember = { member_id: string; status: string; applied_on: string; member: Person | null };
  type Proj = { id: string; name: string; status: string };

  const id = $derived($page.params.id);

  let unit = $state<Unit | null>(null);
  let officers = $state<Officer[]>([]);
  let members = $state<UnitMember[]>([]);
  let pending = $state<UnitMember[]>([]);
  let projects = $state<Proj[]>([]);
  let myStatus = $state<string | null>(null); // pending | active | rejected | left | null
  let allMembers = $state<Person[]>([]); // for the officer "add member" picker
  let addQ = $state('');
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

    const [{ data: off }, { data: oum }, { data: prj }, { data: am }] = await Promise.all([
      supabase.from('org_unit_officer')
        .select('member_id, role, member:member_id(id, full_name, affiliation)')
        .eq('org_unit_id', unitId).is('ended_on', null),
      supabase.from('org_unit_member')
        .select('member_id, status, applied_on, member:member_id(id, full_name, affiliation, kind)')
        .eq('org_unit_id', unitId),
      unit.kind === 'working_group'
        ? supabase.from('project').select('id, name, project_status!project_status_id_fkey(name)').eq('org_unit_id', unitId)
        : Promise.resolve({ data: [] as any[] }),
      supabase.from('member').select('id, full_name, affiliation, kind').order('full_name')
    ]);
    allMembers = (am as Person[]) ?? [];

    officers = ((off as any[]) ?? []).sort((a, b) => a.role.localeCompare(b.role));
    const all = (oum as UnitMember[]) ?? [];
    members = all.filter((m) => m.status === 'active')
      .sort((a, b) => (a.member?.full_name ?? '').localeCompare(b.member?.full_name ?? ''));
    pending = all.filter((m) => m.status === 'pending')
      .sort((a, b) => a.applied_on.localeCompare(b.applied_on));
    projects = ((prj as any[]) ?? []).map((p) => ({
      id: p.id, name: p.name, status: p.project_status?.name ?? '—'
    }));

    const mine = $member ? all.find((m) => m.member_id === $member!.id) : null;
    myStatus = mine?.status ?? null;
    loading = false;
  }

  let lastId = '';
  $effect(() => { if (id && id !== lastId) { lastId = id; load(id); } });
  onMount(() => { if (id) { lastId = id; load(id); } });

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
</script>

<div class="stack">
  <p><a href="/units">← {$t('Chapters & Working Groups')}</a></p>

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

    <!-- officers -->
    <div class="card stack" style="gap:.5rem;">
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
      <div class="card stack" style="gap:.5rem;">
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
    <div class="card stack" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Members')} {#if members.length}<span class="muted" style="font-weight:400;">· {members.length}</span>{/if}</h2>
      {#if members.length === 0}
        <p class="muted" style="margin:0;">{$t('No members yet.')}</p>
      {:else}
        <ul style="margin:0; padding:0; list-style:none;">
          {#each members as m}
            <li class="row" style="justify-content:space-between; align-items:center; gap:.5rem; border-top:1px solid var(--border); padding:.5rem 0;">
              <a href={`/members/${m.member?.id}`} class="person">
                <span class="p-ava">{initials(m.member?.full_name ?? '?')}</span>
                <span class="stack" style="gap:0;">
                  <span class="p-name">{m.member?.full_name}{#if m.member?.kind === 'card'}<span class="badge dim" style="margin-left:.35rem; font-size:.68rem;">{$t('card')}</span>{/if}</span>
                  <span class="p-sub">{m.member?.affiliation ?? '—'}</span>
                </span>
              </a>
              {#if isOfficer && officerIds.has(m.member_id)}
                <span class="badge dim" title={$t('Serves as an officer of this unit.')}>{$t('Officer')}</span>
              {:else if isOfficer}
                <button onclick={() => removeMember(m.member_id)} disabled={busy === m.member_id}>{$t('Remove')}</button>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </div>

    <!-- add an existing member (officers / admins) -->
    {#if isOfficer}
      <div class="card stack" style="gap:.5rem;">
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
      <div class="card stack" style="gap:.6rem;">
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
        <p class="muted" style="font-size:.76rem; margin:0;">{$t('For staging skills too, use the')} <a href="/my-chapter">{$t('My Chapter')}</a> {$t('page.')}</p>
      </div>
    {/if}

    <!-- projects (working groups) -->
    {#if !isChapter}
      <div class="card stack" style="gap:.5rem;">
        <h2 style="margin:0; font-size:1rem;">{$t('Projects')} {#if projects.length}<span class="muted" style="font-weight:400;">· {projects.length}</span>{/if}</h2>
        {#if projects.length === 0}
          <p class="muted" style="margin:0;">{$t('No projects attributed to this group yet.')}</p>
        {:else}
          <table>
            <thead><tr><th>{$t('Project')}</th><th>{$t('Status')}</th></tr></thead>
            <tbody>
              {#each projects as p}
                <tr><td><a href={`/projects/${p.id}`}><strong>{p.name}</strong></a></td><td class="muted">{p.status}</td></tr>
              {/each}
            </tbody>
          </table>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<style>
  .person { display: inline-flex; align-items: center; gap: .5rem; text-decoration: none; color: inherit; }
  .p-ava {
    width: 34px; height: 34px; border-radius: 50%; flex-shrink: 0;
    display: inline-flex; align-items: center; justify-content: center;
    background: var(--accent-soft); color: var(--accent); font-size: .78rem; font-weight: 600;
  }
  .p-name { font-size: .9rem; font-weight: 600; }
  .person:hover .p-name { color: var(--accent); }
  .p-sub { font-size: .74rem; color: var(--muted); }
</style>
