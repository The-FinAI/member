<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities } from '$lib/session';

  const id = $derived($page.params.id);

  type Project = {
    id: string; name: string; target_venue: string | null; summary: string | null;
    project_type: { name: string } | null; project_status: { name: string } | null;
  };
  type Participant = { member_id: string; member: { full_name: string } | null; project_role: { name: string; can_manage: boolean } | null };
  type Need = {
    id: string; description: string | null; headcount: number; min_level: string | null; status: string;
    project_role_id: string | null; project_role: { name: string } | null; skill: { name: string } | null;
  };
  type Application = { id: string; status: string; message: string | null; open_need_id: string; member: { full_name: string } | null };
  type Role = { id: string; name: string };
  type Skill = { id: string; name: string; parent_id: string | null };
  type ResType = { id: string; name: string };
  type ResRequest = { id: string; description: string | null; quantity: string | null; status: string; type_id: string | null; resource_type: { name: string } | null };
  type ResOffer = { id: string; status: string; message: string | null; request_id: string; member: { full_name: string } | null; resource: { name: string } | null };
  type OfferableResource = { id: string; name: string; scope: string };

  let project = $state<Project | null>(null);
  let participants = $state<Participant[]>([]);
  let needs = $state<Need[]>([]);
  let applications = $state<Application[]>([]);
  let roles = $state<Role[]>([]);
  let skills = $state<Skill[]>([]);
  let appliedNeedIds = $state<Set<string>>(new Set());
  let iManage = $state(false);
  let loading = $state(true);
  let error = $state('');

  // new-need form
  let nRole = $state(''); let nSkill = $state(''); let nLevel = $state(''); let nCount = $state(1); let nDesc = $state('');

  // resources
  let resTypes = $state<ResType[]>([]);
  let resRequests = $state<ResRequest[]>([]);
  let resOffers = $state<ResOffer[]>([]);
  let myResources = $state<OfferableResource[]>([]);
  let offeredRequestIds = $state<Set<string>>(new Set());
  // new resource-request form
  let rrType = $state(''); let rrQty = $state(''); let rrDesc = $state('');
  // offer form state, keyed by request id
  let offerResourceId = $state<Record<string, string>>({});
  let offerMessage = $state<Record<string, string>>({});

  const contributorRoleId = $derived(roles.find((r) => r.name === 'Contributor')?.id ?? roles[0]?.id ?? null);

  async function load() {
    if (!supabaseConfigured || !id) { loading = false; return; }
    loading = true;
    const [{ data: p }, { data: pm }, { data: nd }, { data: rl }, { data: sk }] = await Promise.all([
      supabase.from('project').select('id, name, target_venue, summary, project_type(name), project_status(name)').eq('id', id).maybeSingle(),
      supabase.from('project_member').select('member_id, member(full_name), project_role(name, can_manage)').eq('project_id', id),
      supabase.from('open_need').select('id, description, headcount, min_level, status, project_role_id, project_role(name), skill(name)').eq('project_id', id),
      supabase.from('project_role').select('id, name').order('name'),
      supabase.from('skill').select('id, name, parent_id').order('name')
    ]);
    project = (p as Project) ?? null;
    participants = (pm as Participant[]) ?? [];
    needs = (nd as Need[]) ?? [];
    roles = (rl as Role[]) ?? [];
    skills = (sk as Skill[]) ?? [];

    const me = $member?.id;
    iManage =
      $capabilities.has('edit_any_project') ||
      participants.some((x) => x.member_id === me && x.project_role?.can_manage);

    const needIds = needs.map((n) => n.id);
    if (me && needIds.length) {
      const { data: mine } = await supabase
        .from('need_application').select('open_need_id').eq('member_id', me).in('open_need_id', needIds);
      appliedNeedIds = new Set((mine ?? []).map((r: any) => r.open_need_id));
    }
    if (iManage && needIds.length) {
      const { data: apps } = await supabase
        .from('need_application').select('id, status, message, open_need_id, member(full_name)').in('open_need_id', needIds);
      applications = (apps as Application[]) ?? [];
    }

    // resources
    const [{ data: rt }, { data: rr }] = await Promise.all([
      supabase.from('resource_type').select('id, name').order('rank'),
      supabase.from('resource_request').select('id, description, quantity, status, type_id, resource_type(name)').eq('project_id', id).order('created_at')
    ]);
    resTypes = (rt as ResType[]) ?? [];
    resRequests = (rr as ResRequest[]) ?? [];

    if (me) {
      const { data: mine } = await supabase
        .from('resource').select('id, name, scope').eq('holder_member_id', me).order('name');
      myResources = (mine as OfferableResource[]) ?? [];
    }
    const reqIds = resRequests.map((r) => r.id);
    if (me && reqIds.length) {
      const { data: myOffers } = await supabase
        .from('resource_offer').select('request_id').eq('offered_by', me).in('request_id', reqIds);
      offeredRequestIds = new Set((myOffers ?? []).map((r: any) => r.request_id));
    }
    if (iManage && reqIds.length) {
      const { data: offers } = await supabase
        .from('resource_offer').select('id, status, message, request_id, member:offered_by(full_name), resource(name)').in('request_id', reqIds);
      resOffers = (offers as ResOffer[]) ?? [];
    }
    loading = false;
  }

  async function postResourceRequest() {
    error = '';
    const { error: err } = await supabase.from('resource_request').insert({
      project_id: id, type_id: rrType || null, quantity: rrQty || null, description: rrDesc || null
    });
    if (err) { error = err.message; return; }
    rrType = ''; rrQty = ''; rrDesc = '';
    await load();
  }

  async function offerResource(requestId: string) {
    error = '';
    if (!$member) return;
    const { error: err } = await supabase.from('resource_offer').insert({
      request_id: requestId,
      resource_id: offerResourceId[requestId] || null,
      offered_by: $member.id,
      message: offerMessage[requestId] || null
    });
    if (err) { error = err.message; return; }
    offeredRequestIds = new Set([...offeredRequestIds, requestId]);
  }

  async function acceptOffer(offerId: string) {
    error = '';
    if (!contributorRoleId) { error = 'No project role available to assign.'; return; }
    const { error: err } = await supabase.rpc('accept_resource_offer', { offer_id: offerId, role_id: contributorRoleId });
    if (err) { error = err.message; return; }
    await load();
  }

  async function declineOffer(offerId: string) {
    error = '';
    const { error: err } = await supabase.from('resource_offer').update({ status: 'declined' }).eq('id', offerId);
    if (err) { error = err.message; return; }
    await load();
  }

  function offersFor(requestId: string) {
    return resOffers.filter((o) => o.request_id === requestId);
  }

  onMount(load);

  async function apply(needId: string) {
    error = '';
    if (!$member) return;
    const { error: err } = await supabase.from('need_application').insert({ open_need_id: needId, member_id: $member.id });
    if (err) { error = err.message; return; }
    appliedNeedIds = new Set([...appliedNeedIds, needId]);
  }

  async function postNeed() {
    error = '';
    if (!nRole) { error = 'Pick a role.'; return; }
    const { error: err } = await supabase.from('open_need').insert({
      project_id: id, project_role_id: nRole, skill_id: nSkill || null,
      min_level: nLevel || null, headcount: nCount, description: nDesc || null
    });
    if (err) { error = err.message; return; }
    nRole = ''; nSkill = ''; nLevel = ''; nCount = 1; nDesc = '';
    await load();
  }

  async function accept(app: Application, roleId: string | null) {
    error = '';
    if (!roleId) { error = 'Need has no role to assign.'; return; }
    const { error: err } = await supabase.rpc('accept_application', { app_id: app.id, role_id: roleId });
    if (err) { error = err.message; return; }
    await load();
  }

  async function decline(appId: string) {
    error = '';
    const { error: err } = await supabase.from('need_application').update({ status: 'declined' }).eq('id', appId);
    if (err) { error = err.message; return; }
    await load();
  }

  function appsFor(needId: string) {
    return applications.filter((a) => a.open_need_id === needId);
  }
</script>

<div class="stack">
  <p><a href="/projects">← Projects</a></p>
  {#if error}<p style="color:#b91c1c;">{error}</p>{/if}

  {#if loading}
    <p class="muted">Loading…</p>
  {:else if !project}
    <p class="muted">Project not found.</p>
  {:else}
    <div class="row" style="justify-content:space-between;">
      <h1 style="margin:0;">{project.name}</h1>
      {#if iManage}<span class="badge">You manage this</span>{/if}
    </div>
    <div class="row muted" style="font-size:.85rem;">
      <span>{project.project_type?.name ?? '—'}</span>
      <span class="badge">{project.project_status?.name ?? '—'}</span>
      {#if project.target_venue}<span>Target: {project.target_venue}</span>{/if}
    </div>
    {#if project.summary}<p>{project.summary}</p>{/if}

    <div class="card">
      <h2>Participants</h2>
      {#if participants.length === 0}
        <p class="muted">No participants yet.</p>
      {:else}
        <table>
          <thead><tr><th>Name</th><th>Role</th></tr></thead>
          <tbody>
            {#each participants as pt}
              <tr><td>{pt.member?.full_name ?? '—'}</td><td>{pt.project_role?.name ?? '—'}</td></tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="card">
      <h2>Open needs</h2>
      {#if needs.length === 0}
        <p class="muted">No open needs.</p>
      {:else}
        <div class="stack">
          {#each needs as n}
            <div style="border:1px solid var(--border); border-radius:8px; padding:.75rem;">
              <div class="row" style="justify-content:space-between;">
                <strong>{n.project_role?.name ?? 'Contributor'}</strong>
                <span class="muted" style="font-size:.8rem;">{n.status} · {n.headcount} opening(s)</span>
              </div>
              {#if n.skill}<div class="muted" style="font-size:.82rem;">Skill: {n.skill.name}{n.min_level ? ` (≥ ${n.min_level})` : ''}</div>{/if}
              {#if n.description}<p style="margin:.4rem 0;">{n.description}</p>{/if}

              {#if !iManage}
                {#if appliedNeedIds.has(n.id)}
                  <span class="badge">Applied</span>
                {:else}
                  <button onclick={() => apply(n.id)}>I can help</button>
                {/if}
              {:else}
                <!-- manager: review applications -->
                {#if appsFor(n.id).length === 0}
                  <p class="muted" style="font-size:.82rem;">No applications yet.</p>
                {:else}
                  <table>
                    <thead><tr><th>Applicant</th><th>Status</th><th></th></tr></thead>
                    <tbody>
                      {#each appsFor(n.id) as a}
                        <tr>
                          <td>{a.member?.full_name ?? '—'}</td>
                          <td><span class="badge">{a.status}</span></td>
                          <td class="row">
                            {#if a.status === 'pending'}
                              <button class="ghost" onclick={() => accept(a, n.project_role_id)}>Accept</button>
                              <button class="danger" onclick={() => decline(a.id)}>Decline</button>
                            {/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                {/if}
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      {#if iManage}
        <div style="margin-top:1rem; border-top:1px dashed var(--border); padding-top:1rem;">
          <h3 style="margin:0 0 .5rem;">Post a need</h3>
          <div class="row" style="align-items:flex-end;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Role</span>
              <select bind:value={nRole}><option value="">—</option>{#each roles as r}<option value={r.id}>{r.name}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Skill (opt.)</span>
              <select bind:value={nSkill}><option value="">—</option>{#each skills as s}<option value={s.id}>{s.name}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Min level</span>
              <select bind:value={nLevel}><option value="">—</option><option>Beginner</option><option>Intermediate</option><option>Advanced</option><option>Expert</option></select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Count</span>
              <input type="number" min="1" bind:value={nCount} style="width:70px;" />
            </label>
            <button onclick={postNeed}>Post</button>
          </div>
          <input placeholder="Description (optional)" bind:value={nDesc} style="margin-top:.5rem; width:100%;" />
        </div>
      {/if}
    </div>

    <div class="card">
      <h2>Resource needs</h2>
      {#if resRequests.length === 0}
        <p class="muted">No resource requests.</p>
      {:else}
        <div class="stack">
          {#each resRequests as rr}
            <div style="border:1px solid var(--border); border-radius:8px; padding:.75rem;">
              <div class="row" style="justify-content:space-between;">
                <strong>{rr.resource_type?.name ?? 'Resource'}</strong>
                <span class="muted" style="font-size:.8rem;">{rr.status}{rr.quantity ? ` · ${rr.quantity}` : ''}</span>
              </div>
              {#if rr.description}<p style="margin:.4rem 0;">{rr.description}</p>{/if}

              {#if !iManage}
                {#if offeredRequestIds.has(rr.id)}
                  <span class="badge">Offered</span>
                {:else}
                  <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
                    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">Resource (optional)</span>
                      <select bind:value={offerResourceId[rr.id]}>
                        <option value="">— none / describe below —</option>
                        {#each myResources as mr}<option value={mr.id}>{mr.name}{mr.scope === 'community' ? ' (community)' : ''}</option>{/each}
                      </select>
                    </label>
                    <input placeholder="Message (optional)" bind:value={offerMessage[rr.id]} style="flex:1; min-width:160px;" />
                    <button onclick={() => offerResource(rr.id)}>I can provide</button>
                  </div>
                {/if}
              {:else}
                {#if offersFor(rr.id).length === 0}
                  <p class="muted" style="font-size:.82rem;">No offers yet.</p>
                {:else}
                  <table>
                    <thead><tr><th>From</th><th>Resource</th><th>Message</th><th>Status</th><th></th></tr></thead>
                    <tbody>
                      {#each offersFor(rr.id) as o}
                        <tr>
                          <td>{o.member?.full_name ?? '—'}</td>
                          <td>{o.resource?.name ?? '—'}</td>
                          <td>{o.message ?? '—'}</td>
                          <td><span class="badge">{o.status}</span></td>
                          <td class="row">
                            {#if o.status === 'pending'}
                              <button class="ghost" onclick={() => acceptOffer(o.id)}>Accept</button>
                              <button class="danger" onclick={() => declineOffer(o.id)}>Decline</button>
                            {/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                {/if}
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      {#if iManage}
        <div style="margin-top:1rem; border-top:1px dashed var(--border); padding-top:1rem;">
          <h3 style="margin:0 0 .5rem;">Ask for a resource</h3>
          <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Type</span>
              <select bind:value={rrType}><option value="">—</option>{#each resTypes as t}<option value={t.id}>{t.name}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Quantity</span>
              <input bind:value={rrQty} placeholder="e.g. 500 GPU-hrs" style="width:140px;" />
            </label>
            <button onclick={postResourceRequest}>Post</button>
          </div>
          <input placeholder="Description (optional)" bind:value={rrDesc} style="margin-top:.5rem; width:100%;" />
        </div>
      {/if}
    </div>
  {/if}
</div>
