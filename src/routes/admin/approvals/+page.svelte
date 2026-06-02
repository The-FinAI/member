<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';

  // Consolidated approval portal: every queue that wants an officer's eyes,
  // in one place. Each section is gated by the capability (or officer role)
  // that owns it, and ALWAYS renders when the reviewer has access — even when
  // empty — so the page reads as a complete map of what they're responsible
  // for, not just whatever happens to be pending right now.
  type Resrc = {
    id: string; name: string; capacity: string | null;
    resource_type: { name: string } | null; member: { full_name: string } | null;
  };
  type Card = {
    id: string; target_level: number; kind: string; fee: number;
    member: { full_name: string } | null; skill: { name: string } | null;
  };
  type UnitApp = {
    org_unit_id: string; member_id: string; applied_on: string;
    member: { full_name: string } | null; org_unit: { name: string } | null;
  };
  type Commit = {
    period_id: string; year_month: string; committed_amount: number;
    token_equivalent: number; commitment_type: string;
    project_id: string; project_name: string; member_name: string;
    skill_name: string | null; resource_name: string | null;
    capacity: number | null; month_total: number | null;
  };
  type Mstone = {
    id: string; title: string | null; status: string;
    project: { id: string; name: string } | null;
    milestone_catalog: { item: string; nominal_value: number; multiplier_bonus: number } | null;
    member: { full_name: string } | null;
  };

  const canResources = $derived($capabilities.has('manage_resources'));
  const canCards = $derived($capabilities.has('review_skillcard'));
  // commitment review is open to capability holders AND to officers of the
  // member's unit — the queue view itself filters each officer to their own
  // members, so showing the section for any officer is safe.
  const canCommitCap = $derived(
    $capabilities.has('manage_stater') ||
      $capabilities.has('manage_resources') ||
      $capabilities.has('manage_members')
  );
  const canCommit = $derived(canCommitCap || $officerUnits.length > 0);
  const canMilestone = $derived(
    $capabilities.has('manage_stater') ||
      $capabilities.has('manage_resources') ||
      $capabilities.has('edit_any_project')
  );
  const isOfficer = $derived($officerUnits.length > 0);
  const hasAnyQueue = $derived(canResources || canCards || canCommit || canMilestone || isOfficer);

  let resources = $state<Resrc[]>([]);
  let cards = $state<Card[]>([]);
  let unitApps = $state<UnitApp[]>([]);
  let commits = $state<Commit[]>([]);
  let milestones = $state<Mstone[]>([]);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; error = '';
    const officerIds = $officerUnits.map((u) => u.unit_id);
    const [r, c, u, k, ms] = await Promise.all([
      canResources
        ? supabase.from('resource')
            .select('id, name, capacity, resource_type(name), member:holder_member_id(full_name)')
            .eq('approval_status', 'pending').order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as any[] }),
      canCards
        ? supabase.from('skillcard_request')
            .select('id, target_level, kind, fee, member:member_id(full_name), skill:skill_id(name)')
            .eq('status', 'submitted').order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as any[] }),
      isOfficer && officerIds.length
        ? supabase.from('org_unit_member')
            .select('org_unit_id, member_id, applied_on, member:member_id(full_name), org_unit:org_unit_id(name)')
            .eq('status', 'pending').in('org_unit_id', officerIds).order('applied_on')
        : Promise.resolve({ data: [] as any[] }),
      canCommit
        ? supabase.from('commitment_review_queue')
            .select('*').order('year_month', { ascending: false })
        : Promise.resolve({ data: [] as any[] }),
      canMilestone
        ? supabase.from('project_milestone')
            .select('id, title, status, project:project_id(id, name), milestone_catalog(item, nominal_value, multiplier_bonus), member:claimed_by(full_name)')
            .in('status', ['claimed', 'under_review']).order('created_at', { ascending: false })
        : Promise.resolve({ data: [] as any[] })
    ]);
    resources = (r.data as Resrc[]) ?? [];
    cards = (c.data as Card[]) ?? [];
    unitApps = (u.data as UnitApp[]) ?? [];
    commits = (k.data as Commit[]) ?? [];
    milestones = (ms.data as Mstone[]) ?? [];
    loading = false;
  }

  onMount(load);

  async function reviewResource(id: string, ok: boolean) {
    busy = id; error = '';
    const { error: err } = await supabase.from('resource')
      .update({ approval_status: ok ? 'approved' : 'rejected' }).eq('id', id);
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function reviewCard(id: string, ok: boolean) {
    busy = id; error = '';
    const { error: err } = await supabase.rpc('review_skillcard_request', {
      p_request: id, p_approve: ok, p_note: null
    });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function reviewUnit(a: UnitApp, ok: boolean) {
    busy = a.member_id + a.org_unit_id; error = '';
    const { error: err } = await supabase.rpc('decide_unit_member', {
      p_unit: a.org_unit_id, p_member: a.member_id, p_approve: ok
    });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function reviewCommit(id: string, ok: boolean) {
    busy = id; error = '';
    const { error: err } = await supabase.rpc('review_commitment_period', {
      p_period: id, p_approve: ok
    });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function reviewMilestone(id: string, ok: boolean) {
    busy = id; error = '';
    const { error: err } = await supabase.rpc(ok ? 'verify_milestone' : 'reject_milestone', { milestone_id: id });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Approvals')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Every request waiting on a decision, in one place — member resources, role cards, project milestones, chapter & working-group applications, and over-capacity monthly commitments.')}
  </p>

  {#if error}<p class="banner err">{error}</p>{/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if !hasAnyQueue}
    <div class="card"><p class="muted" style="margin:0;">{$t('You have no queues to review.')}</p></div>
  {/if}

  {#if !loading}
    <!-- Over-capacity monthly commitments -->
    {#if canCommit}
      <div class="card stack" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1.05rem;">
          {$t('Over-capacity commitments')}
          {#if commits.length}<span class="badge warn">{commits.length}</span>{/if}
        </h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t("A member's monthly total across projects exceeds the capacity they declared. Minting still happened — approve to keep it, or reject to discount it out of the pool.")}
        </p>
        {#if commits.length}
          <table>
            <thead><tr>
              <th>{$t('Member')}</th><th>{$t('What')}</th><th>{$t('Month')}</th>
              <th>{$t('Project')}</th><th class="num">{$t('This row')}</th>
              <th class="num">{$t('Month total')}</th><th class="num">{$t('Capacity')}</th><th></th>
            </tr></thead>
            <tbody>
              {#each commits as k (k.period_id)}
                <tr>
                  <td>{k.member_name}</td>
                  <td>{k.commitment_type === 'labor' ? (k.skill_name ?? $t('Labor')) : (k.resource_name ?? $t('Resource'))}</td>
                  <td>{k.year_month}</td>
                  <td><a href={`/projects/${k.project_id}`}>{k.project_name}</a></td>
                  <td class="num">{k.committed_amount}</td>
                  <td class="num"><strong>{k.month_total}</strong></td>
                  <td class="num">{k.capacity ?? '—'}</td>
                  <td class="row" style="gap:.35rem; justify-content:flex-end;">
                    <button disabled={busy === k.period_id} onclick={() => reviewCommit(k.period_id, true)}>{$t('Approve')}</button>
                    <button class="danger" disabled={busy === k.period_id} onclick={() => reviewCommit(k.period_id, false)}>{$t('Reject')}</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted" style="margin:0;">{$t('Nothing pending. ✓')}</p>
        {/if}
      </div>
    {/if}

    <!-- Project milestones -->
    {#if canMilestone}
      <div class="card stack" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1.05rem;">
          {$t('Project milestones')}
          {#if milestones.length}<span class="badge warn">{milestones.length}</span>{/if}
        </h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t('Milestones members claimed. Verifying adds its nominal value to the pool and bumps the settlement multiplier.')}
        </p>
        {#if milestones.length}
          <table>
            <thead><tr>
              <th>{$t('Project')}</th><th>{$t('Milestone')}</th><th>{$t('Claimed by')}</th>
              <th class="num">{$t('Nominal')}</th><th class="num">{$t('+Mult')}</th><th></th>
            </tr></thead>
            <tbody>
              {#each milestones as m (m.id)}
                <tr>
                  <td>{#if m.project}<a href={`/projects/${m.project.id}`}>{m.project.name}</a>{:else}—{/if}</td>
                  <td><strong>{m.milestone_catalog?.item ?? m.title ?? '—'}</strong>
                    {#if m.title && m.milestone_catalog}<div class="muted" style="font-size:.76rem;">{m.title}</div>{/if}</td>
                  <td>{m.member?.full_name ?? '—'}</td>
                  <td class="num">{m.milestone_catalog?.nominal_value ?? 0}</td>
                  <td class="num">+{Number(m.milestone_catalog?.multiplier_bonus ?? 0)}</td>
                  <td class="row" style="gap:.35rem; justify-content:flex-end;">
                    <button disabled={busy === m.id} onclick={() => reviewMilestone(m.id, true)}>{$t('Verify')}</button>
                    <button class="danger" disabled={busy === m.id} onclick={() => reviewMilestone(m.id, false)}>{$t('Reject')}</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted" style="margin:0;">{$t('Nothing pending. ✓')}</p>
        {/if}
      </div>
    {/if}

    <!-- Member resources -->
    {#if canResources}
      <div class="card stack" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1.05rem;">
          {$t('Member resources')}
          {#if resources.length}<span class="badge warn">{resources.length}</span>{/if}
        </h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t("Member-submitted resources can't be offered to projects until a steward approves them.")}
        </p>
        {#if resources.length}
          <table>
            <thead><tr>
              <th>{$t('Resource')}</th><th>{$t('Type')}</th><th>{$t('Holder')}</th>
              <th>{$t('Capacity')}</th><th></th>
            </tr></thead>
            <tbody>
              {#each resources as r (r.id)}
                <tr>
                  <td>{r.name}</td>
                  <td>{r.resource_type?.name ?? '—'}</td>
                  <td>{r.member?.full_name ?? '—'}</td>
                  <td>{r.capacity ?? '—'}</td>
                  <td class="row" style="gap:.35rem; justify-content:flex-end;">
                    <button disabled={busy === r.id} onclick={() => reviewResource(r.id, true)}>{$t('Approve')}</button>
                    <button class="danger" disabled={busy === r.id} onclick={() => reviewResource(r.id, false)}>{$t('Reject')}</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted" style="margin:0;">{$t('Nothing pending. ✓')}</p>
        {/if}
      </div>
    {/if}

    <!-- Role cards -->
    {#if canCards}
      <div class="card stack" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1.05rem;">
          {$t('Role cards')}
          {#if cards.length}<span class="badge warn">{cards.length}</span>{/if}
        </h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t('Members requesting a skill certification. Approving mints the card; rejecting refunds the fee.')}
        </p>
        {#if cards.length}
          <table>
            <thead><tr>
              <th>{$t('Member')}</th><th>{$t('Skill')}</th><th class="num">{$t('Level')}</th>
              <th class="num">{$t('Fee')}</th><th></th>
            </tr></thead>
            <tbody>
              {#each cards as c (c.id)}
                <tr>
                  <td>{c.member?.full_name ?? '—'}</td>
                  <td>{c.skill?.name ?? '—'}</td>
                  <td class="num">{c.target_level}</td>
                  <td class="num">{c.fee}</td>
                  <td class="row" style="gap:.35rem; justify-content:flex-end;">
                    <button disabled={busy === c.id} onclick={() => reviewCard(c.id, true)}>{$t('Approve')}</button>
                    <button class="danger" disabled={busy === c.id} onclick={() => reviewCard(c.id, false)}>{$t('Reject')}</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted" style="margin:0;">{$t('Nothing pending. ✓')}</p>
        {/if}
      </div>
    {/if}

    <!-- Chapter / working-group applications -->
    {#if isOfficer}
      <div class="card stack" style="gap:.6rem;">
        <h2 style="margin:0; font-size:1.05rem;">
          {$t('Chapter & working-group applications')}
          {#if unitApps.length}<span class="badge warn">{unitApps.length}</span>{/if}
        </h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t('People asking to join a chapter or working group you serve.')}
        </p>
        {#if unitApps.length}
          <table>
            <thead><tr>
              <th>{$t('Applicant')}</th><th>{$t('Unit')}</th><th>{$t('Applied')}</th><th></th>
            </tr></thead>
            <tbody>
              {#each unitApps as a (a.member_id + a.org_unit_id)}
                <tr>
                  <td>{a.member?.full_name ?? '—'}</td>
                  <td>{a.org_unit?.name ?? '—'}</td>
                  <td>{a.applied_on}</td>
                  <td class="row" style="gap:.35rem; justify-content:flex-end;">
                    <button disabled={busy === a.member_id + a.org_unit_id} onclick={() => reviewUnit(a, true)}>{$t('Approve')}</button>
                    <button class="danger" disabled={busy === a.member_id + a.org_unit_id} onclick={() => reviewUnit(a, false)}>{$t('Reject')}</button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted" style="margin:0;">{$t('Nothing pending. ✓')}</p>
        {/if}
      </div>
    {/if}
  {/if}
</div>
