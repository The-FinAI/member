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
  type Role = { id: string; name: string; payout_weight?: number };
  type Commitment = {
    id: string; member_id: string; commitment_type: string; status: string;
    token_amount: number; token_equivalent: number; hours_committed: number | null;
    member: { full_name: string } | null; skill: { name: string } | null;
  };
  type Settlement = { id: string; status: string; meeting_notes: string | null; submitted_by: string | null; review_window_ends_at: string | null; approved_at: string | null };
  type SettlementItem = { id: string; member_id: string; role: string | null; final_payout_weight: number; is_author: boolean; author_order: number | null; member?: { full_name: string } | null };
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
  let escrow = $state(0);
  let joinStake = $state(20);
  let finishing = $state(false);

  // stake commitments + settlement
  let commitments = $state<Commitment[]>([]);
  let settlement = $state<Settlement | null>(null);
  let settlementItems = $state<SettlementItem[]>([]);
  // settlement builder (manager): weights/authorship keyed by member_id
  let sWeight = $state<Record<string, number>>({});
  let sAuthor = $state<Record<string, boolean>>({});
  let sNotes = $state('');
  let submitting = $state(false);
  const canApprove = $derived($capabilities.has('manage_stater') || $capabilities.has('edit_any_project'));

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
      supabase.from('project_role').select('id, name, payout_weight').order('name'),
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

    const [{ data: esc }, { data: js }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('project_id', id).maybeSingle(),
      supabase.from('stater_policy').select('value').eq('key', 'join_stake_normal').maybeSingle()
    ]);
    escrow = Number((esc as { balance: number } | null)?.balance ?? 0);
    joinStake = Number((js as { value: number } | null)?.value ?? 20);

    // stake commitments
    const { data: cm } = await supabase
      .from('stater_project_stake_commitment')
      .select('id, member_id, commitment_type, status, token_amount, token_equivalent, hours_committed, member(full_name), skill(name)')
      .eq('project_id', id).order('created_at');
    commitments = (cm as Commitment[]) ?? [];

    // latest settlement + items
    const { data: stl } = await supabase
      .from('stater_settlement')
      .select('id, status, meeting_notes, submitted_by, review_window_ends_at, approved_at')
      .eq('project_id', id).order('created_at', { ascending: false }).limit(1).maybeSingle();
    settlement = (stl as Settlement) ?? null;
    if (settlement) {
      const { data: items } = await supabase
        .from('stater_settlement_item')
        .select('id, member_id, role, final_payout_weight, is_author, author_order, member(full_name)')
        .eq('settlement_id', settlement.id);
      settlementItems = (items as SettlementItem[]) ?? [];
    } else {
      settlementItems = [];
    }

    // seed the settlement builder defaults from participants (by role payout_weight)
    if (iManage && !settlement) {
      const w: Record<string, number> = {}; const a: Record<string, boolean> = {};
      for (const pt of participants) {
        const role = roles.find((r) => r.name === pt.project_role?.name);
        w[pt.member_id] = Number(role?.payout_weight ?? 1);
        a[pt.member_id] = true;
      }
      sWeight = w; sAuthor = a;
    }
    loading = false;
  }

  // mark Finished (opens settlement; no auto-payout under the Stater economy)
  async function finishProject() {
    if (!confirm('Mark this project Finished? This opens settlement — payout happens when a settlement is submitted and approved.')) return;
    error = ''; finishing = true;
    const { error: err } = await supabase.rpc('finish_project', { p: id });
    finishing = false;
    if (err) { error = err.message; return; }
    await load();
  }

  async function verifyCommitment(commitmentId: string) {
    error = '';
    const { error: err } = await supabase.rpc('verify_commitment', { commitment_id: commitmentId });
    if (err) { error = err.message; return; }
    await load();
  }

  async function submitSettlement() {
    error = ''; submitting = true;
    const items = participants.map((pt, i) => ({
      member_id: pt.member_id,
      role: pt.project_role?.name ?? null,
      final_payout_weight: Number(sWeight[pt.member_id] ?? 0),
      is_author: sAuthor[pt.member_id] ?? true,
      author_order: i + 1,
      notes: null
    }));
    const { error: err } = await supabase.rpc('submit_settlement', { p: id, notes: sNotes.trim() || null, items });
    submitting = false;
    if (err) { error = err.message; return; }
    sNotes = '';
    await load();
  }

  async function approveSettlement() {
    if (!settlement) return;
    if (!confirm('Approve this settlement? The finish bonus is minted and the whole escrow is distributed by payout weight. This cannot be undone.')) return;
    error = '';
    const { error: err } = await supabase.rpc('approve_settlement', { settlement_id: settlement.id });
    if (err) { error = err.message; return; }
    await load();
  }

  async function rejectSettlement() {
    if (!settlement) return;
    error = '';
    const { error: err } = await supabase.rpc('reject_settlement', { settlement_id: settlement.id, reason: 'rejected' });
    if (err) { error = err.message; return; }
    await load();
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
  {#if error}<p style="color:var(--down);">{error}</p>{/if}

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

    <div class="card row" style="justify-content:space-between; align-items:center;">
      <div>
        <span class="muted" style="font-size:.8rem;">Escrow</span>
        <strong style="font-size:1.2rem; margin-left:.4rem;">{escrow.toLocaleString()}</strong>
        <span class="muted" style="font-size:.8rem;"> STR · staked by leader + members ({joinStake}/join)</span>
      </div>
      {#if iManage && project.project_status?.name !== 'Finished'}
        <button onclick={finishProject} disabled={finishing}>{finishing ? 'Finishing…' : 'Mark Finished'}</button>
      {/if}
    </div>

    <div class="card">
      <h2>Stake commitments</h2>
      {#if commitments.length === 0}
        <p class="muted">No commitments yet.</p>
      {:else}
        <table>
          <thead><tr><th>Member</th><th>Type</th><th>Staked (STR)</th><th>Valuation</th><th>Status</th>{#if iManage}<th></th>{/if}</tr></thead>
          <tbody>
            {#each commitments as c}
              <tr>
                <td>{c.member?.full_name ?? '—'}</td>
                <td>{c.commitment_type.replace(/_/g, ' ')}{c.skill ? ` · ${c.skill.name}` : ''}{c.hours_committed ? ` · ${c.hours_committed}h` : ''}</td>
                <td>{c.token_amount > 0 ? c.token_amount.toLocaleString() : '—'}</td>
                <td>{c.token_equivalent > 0 ? `≈ ${c.token_equivalent.toLocaleString()}` : '—'}</td>
                <td><span class="badge">{c.status}</span></td>
                {#if iManage}
                  <td>{#if c.status === 'pledged'}<button class="ghost" onclick={() => verifyCommitment(c.id)}>Verify</button>{/if}</td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="card">
      <h2>Settlement</h2>
      {#if !settlement}
        {#if iManage}
          <p class="muted" style="font-size:.82rem;">
            Propose a settlement: assign each participant a payout weight (the escrow is split pro-rata)
            and confirm authorship. After submission, a Stater manager approves it to mint the finish
            bonus and distribute the escrow.
          </p>
          <table>
            <thead><tr><th>Member</th><th>Role</th><th>Payout weight</th><th>Author</th></tr></thead>
            <tbody>
              {#each participants as pt}
                <tr>
                  <td>{pt.member?.full_name ?? '—'}</td>
                  <td>{pt.project_role?.name ?? '—'}</td>
                  <td><input type="number" min="0" step="0.5" bind:value={sWeight[pt.member_id]} style="width:90px;" /></td>
                  <td><input type="checkbox" bind:checked={sAuthor[pt.member_id]} /></td>
                </tr>
              {/each}
            </tbody>
          </table>
          <label class="stack" style="gap:.2rem; margin-top:.5rem;"><span class="muted" style="font-size:.75rem;">Meeting notes (optional)</span>
            <textarea bind:value={sNotes} rows="2" placeholder="Rationale / meeting decision"></textarea></label>
          <div class="row"><button onclick={submitSettlement} disabled={submitting}>{submitting ? 'Submitting…' : 'Submit settlement'}</button></div>
        {:else}
          <p class="muted">No settlement submitted yet.</p>
        {/if}
      {:else}
        <div class="row" style="justify-content:space-between; align-items:center;">
          <span class="badge">{settlement.status}</span>
          {#if settlement.review_window_ends_at && settlement.status !== 'paid'}
            <span class="muted" style="font-size:.8rem;">Review window ends {new Date(settlement.review_window_ends_at).toLocaleString()}</span>
          {/if}
        </div>
        {#if settlement.meeting_notes}<p style="margin:.5rem 0;">{settlement.meeting_notes}</p>{/if}
        <table>
          <thead><tr><th>Member</th><th>Role</th><th>Weight</th><th>Author</th><th>Order</th></tr></thead>
          <tbody>
            {#each settlementItems as it}
              <tr>
                <td>{it.member?.full_name ?? '—'}</td>
                <td>{it.role ?? '—'}</td>
                <td>{it.final_payout_weight}</td>
                <td>{it.is_author ? '✓' : '—'}</td>
                <td>{it.author_order ?? '—'}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        {#if canApprove && (settlement.status === 'submitted' || settlement.status === 'under_review')}
          <div class="row" style="margin-top:.5rem;">
            <button onclick={approveSettlement}>Approve & pay out</button>
            <button class="danger" onclick={rejectSettlement}>Reject</button>
          </div>
        {/if}
      {/if}
    </div>

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
