<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import SettlementForm from './SettlementForm.svelte';
  import InlineField from './InlineField.svelte';

  // The editable project card: media links (many), free-form history, and the
  // editable core fields (name / summary / venue / working group). All writes
  // go through the project_* RPCs, which enforce leader / WG-officer / admin
  // and auto-log each change to history. Read-only when the viewer can't edit.
  let { projectId, venues = [], workingGroups = [], statuses = [], onChanged }: {
    projectId: string;
    venues?: { id: string; name: string; kind: string; deadline: string | null }[];
    workingGroups?: { id: string; name: string }[];
    statuses?: { id: string; name: string; rank: number }[];
    onChanged?: () => void;
  } = $props();

  type Link = { id: string; kind: string; title: string | null; url: string; notes: string | null; created_at: string; member: { full_name: string } | null };
  type Meeting = { id: string; title: string; scheduled_at: string; ends_at: string | null; location: string | null; agenda: string | null; recurrence: string; member: { full_name: string } | null };
  type Event = { id: string; event_type: string; summary: string; created_at: string; member: { full_name: string } | null };
  type Proj = { id: string; name: string; summary: string | null; venue_id: string | null; org_unit_id: string | null; status_id: string | null; held_from_status_id: string | null; project_status: { name: string } | { name: string }[] | null };
  // the linear pipeline (Hold lives off to the side); Finished is the terminal
  // step, reachable only via the reviewed Mint-done flow from Under review.
  const pipeline = $derived(statuses.filter((s) => s.name !== 'Hold').sort((a, b) => a.rank - b.rank));
  const holdStatus = $derived(statuses.find((s) => s.name === 'Hold') ?? null);
  const curStatusName = $derived.by(() => {
    const ps = proj?.project_status;
    return (Array.isArray(ps) ? ps[0]?.name : ps?.name) ?? '';
  });
  const curRank = $derived(statuses.find((s) => s.id === proj?.status_id)?.rank ?? -1);
  const isHold = $derived(curStatusName === 'Hold');
  const isFinishedProj = $derived(curStatusName === 'Finished');
  const isUnderReview = $derived(curStatusName === 'Under review');
  // rank of "Under review" — the gate before completion can be minted
  const reviewRank = $derived(statuses.find((s) => s.name === 'Under review')?.rank ?? 999);

  const LINK_KINDS = ['proposal', 'overleaf', 'openreview', 'paper', 'repo', 'dataset', 'slides', 'drive', 'media', 'other'];
  const KIND_ICON: Record<string, string> = {
    proposal: '📄', overleaf: '✍', openreview: '🔎', paper: '📑', repo: '💻',
    dataset: '🗃', slides: '📊', drive: '📁', media: '🎞', other: '🔗'
  };

  let canEdit = $state(false);
  let proj = $state<Proj | null>(null);
  let links = $state<Link[]>([]);
  let meetings = $state<Meeting[]>([]);
  let events = $state<Event[]>([]);
  let catalog = $state<{ id: string; category: string; item: string; nominal_value: number; multiplier_bonus: number }[]>([]);
  let milestones = $state<{ id: string; status: string; nominal_value: number; multiplier_bonus: number; catalog: { item: string } | null }[]>([]);
  let mClaim = $state('');
  let settleStatus = $state<string | null>(null);
  const isSettled = $derived(settleStatus === 'approved' || settleStatus === 'submitted');
  let loading = $state(true);
  const MST_CLASS: Record<string, string> = { verified: 'pos', claimed: 'dim', under_review: 'warn', rejected: 'down', revoked: 'down', expired: 'dim' };
  const MST_LABEL: Record<string, string> = { verified: 'Verified', claimed: 'Claimed', under_review: 'Under review', rejected: 'Rejected', revoked: 'Revoked', expired: 'Expired' };
  let busy = $state(''); let err = $state(''); let msg = $state('');

  // per-field inline save helpers — each RPC is gated server-side & logs history
  async function rpcOrThrow(fn: string, args: Record<string, any>) {
    const { error: e } = await supabase.rpc(fn, args);
    if (e) throw new Error(e.message);
    await load(); onChanged?.();
  }
  const saveName = (v: string) => rpcOrThrow('project_rename', { p_project: projectId, p_name: v.trim() });
  const saveSummary = (v: string) => rpcOrThrow('project_set_summary', { p_project: projectId, p_summary: v.trim() || null });
  const saveVenue = (v: string) => rpcOrThrow('project_set_venue', { p_project: projectId, p_venue: v || null });
  const saveUnit = (v: string) => rpcOrThrow('project_set_org_unit', { p_project: projectId, p_unit: v || null });
  // add-link form
  let lKind = $state('paper'); let lTitle = $state(''); let lUrl = $state(''); let lNotes = $state('');
  let showAddLink = $state(false);
  // note box
  let note = $state('');
  // settlement form toggle
  let showSettle = $state(false);
  // add-meeting form
  let showAddMeeting = $state(false);
  let mTitle = $state(''); let mAt = $state(''); let mEnds = $state(''); let mLoc = $state(''); let mAgenda = $state(''); let mRecur = $state('none');
  const RECUR = ['none', 'weekly', 'biweekly', 'monthly'];
  const RECUR_LABEL: Record<string, string> = { none: 'One-off', weekly: 'Weekly', biweekly: 'Biweekly', monthly: 'Monthly' };

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = '';
    const [{ data: p }, { data: ce }, { data: lk }, { data: mt }, { data: ev }, { data: cat }, { data: pm }, { data: setl }] = await Promise.all([
      supabase.from('project').select('id, name, summary, venue_id, org_unit_id, status_id, held_from_status_id, project_status:status_id(name)').eq('id', projectId).maybeSingle(),
      supabase.rpc('can_edit_project', { p_project: projectId }),
      supabase.from('project_link').select('id, kind, title, url, notes, created_at, member:added_by(full_name)').eq('project_id', projectId).order('created_at', { ascending: false }),
      supabase.from('project_meeting').select('id, title, scheduled_at, ends_at, location, agenda, recurrence, member:created_by(full_name)').eq('project_id', projectId).order('scheduled_at', { ascending: false }),
      supabase.from('project_event').select('id, event_type, summary, created_at, member:actor_member_id(full_name)').eq('project_id', projectId).order('created_at', { ascending: false }).limit(40),
      supabase.from('milestone_catalog').select('id, category, item, nominal_value, multiplier_bonus').eq('is_active', true).order('rank'),
      supabase.from('project_milestone').select('id, status, nominal_value, multiplier_bonus, catalog:catalog_id(item)').eq('project_id', projectId).order('created_at', { ascending: false }),
      supabase.from('stater_settlement').select('status').eq('project_id', projectId).order('created_at', { ascending: false }).limit(1).maybeSingle()
    ]);
    proj = (p as Proj) ?? null;
    canEdit = ce === true;
    links = (lk as Link[]) ?? [];
    meetings = (mt as Meeting[]) ?? [];
    events = (ev as Event[]) ?? [];
    catalog = (cat as any[]) ?? [];
    milestones = (pm as any[]) ?? [];
    settleStatus = (setl as { status: string } | null)?.status ?? null;
    loading = false;
  }

  async function claimMilestone() {
    if (!mClaim) return;
    busy = 'milestone'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('forge_milestone', { p_project: projectId, p_catalog: mClaim });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Milestone claimed — pending verification.'); mClaim = '';
    await load(); onChanged?.();
  }

  async function setStatus(statusId: string) {
    if (!statusId || statusId === proj?.status_id) return;
    busy = 'status'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('project_set_status', { p_project: projectId, p_status: statusId });
    busy = '';
    if (e) { err = e.message; return; }
    await load(); onChanged?.();
  }

  async function hold() {
    if (holdStatus) await setStatus(holdStatus.id);
  }
  async function resume() {
    // back to where it was held from, else the first pipeline step
    const target = proj?.held_from_status_id ?? pipeline[0]?.id;
    if (target) await setStatus(target);
  }

  // completion is the reviewed path: submit a forge_request → review queue → settlement
  async function mintDone() {
    busy = 'done'; err = ''; msg = '';
    const { error: e } = await supabase.rpc('forge_project_done', { p_project: projectId });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Project finished — open settlement to split the pool.');
    await load(); onChanged?.();   // re-render to the Finished state (no reload needed)
  }

  async function addLink() {
    if (!lUrl.trim()) { err = get(t)('A URL is required.'); return; }
    busy = 'link'; err = '';
    const { error: e } = await supabase.rpc('project_link_add', {
      p_project: projectId, p_kind: lKind, p_title: lTitle.trim() || null, p_url: lUrl.trim(), p_notes: lNotes.trim() || null
    });
    busy = '';
    if (e) { err = e.message; return; }
    lTitle = ''; lUrl = ''; lNotes = ''; lKind = 'paper'; showAddLink = false;
    await load();
  }

  async function removeLink(id: string) {
    busy = id; err = '';
    const { error: e } = await supabase.rpc('project_link_remove', { p_link: id });
    busy = '';
    if (e) { err = e.message; return; }
    await load();
  }

  async function postNote() {
    if (!note.trim()) return;
    busy = 'note'; err = '';
    const { error: e } = await supabase.rpc('project_note', { p_project: projectId, p_text: note.trim() });
    busy = '';
    if (e) { err = e.message; return; }
    note = ''; await load();
  }

  async function addMeeting() {
    if (!mTitle.trim() || !mAt) { err = get(t)('Meeting title and time are required.'); return; }
    busy = 'meeting'; err = '';
    const { error: e } = await supabase.rpc('project_meeting_add', {
      p_project: projectId, p_title: mTitle.trim(),
      p_scheduled_at: new Date(mAt).toISOString(),
      p_ends_at: mEnds ? new Date(mEnds).toISOString() : null,
      p_location: mLoc.trim() || null, p_agenda: mAgenda.trim() || null, p_recurrence: mRecur
    });
    busy = '';
    if (e) { err = e.message; return; }
    mTitle = ''; mAt = ''; mEnds = ''; mLoc = ''; mAgenda = ''; mRecur = 'none'; showAddMeeting = false;
    await load();
  }

  async function removeMeeting(id: string) {
    busy = id; err = '';
    const { error: e } = await supabase.rpc('project_meeting_remove', { p_meeting: id });
    busy = '';
    if (e) { err = e.message; return; }
    await load();
  }

  function fmtWhen(iso: string, ends: string | null) {
    const d = new Date(iso);
    const day = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    const time = d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
    const endTime = ends ? new Date(ends).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' }) : '';
    return `${day} · ${time}${endTime ? '–' + endTime : ''}`;
  }
  const isPast = (iso: string) => new Date(iso).getTime() < Date.now();

  function host(u: string) { try { return new URL(u).host.replace(/^www\./, ''); } catch { return u; } }
  function rel(iso: string) {
    const d = Math.round((Date.now() - new Date(iso).getTime()) / 86400000);
    if (d <= 0) return get(t)('today');
    if (d === 1) return get(t)('yesterday');
    if (d < 30) return get(t)('{d}d ago', { d });
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }

  const venueName = $derived((id: string | null) => venues.find((v) => v.id === id)?.name ?? '');
  const curWgName = $derived(workingGroups.find((w) => w.id === proj?.org_unit_id)?.name ?? '');
  const curVenueName = $derived(venues.find((v) => v.id === proj?.venue_id)?.name ?? '');

  let last = '';
  $effect(() => { if (projectId && projectId !== last) { last = projectId; load(); } });
</script>

{#if !loading}
  {#if err}<p class="pcb-err">{err}</p>{/if}
  {#if msg}<p class="pcb-ok">{msg}</p>{/if}

  <!-- basic info — each field edits in place (✎ icon or double-click) -->
  <div class="pcb-basic">
    <InlineField label={$t('Summary')} type="textarea" {canEdit}
      value={proj?.summary ?? ''} placeholder={$t('One-line description')} onSave={saveSummary} />
    <div class="pcb-basic-grid">
      <InlineField label={$t('Target venue')} type="select" {canEdit}
        value={proj?.venue_id ?? ''} display={curVenueName}
        options={[{ value: '', label: get(t)('— none —') }, ...venues.map((v) => ({ value: v.id, label: v.name }))]}
        onSave={saveVenue} />
      <InlineField label={$t('Working Group')} type="select" {canEdit}
        value={proj?.org_unit_id ?? ''} display={curWgName}
        options={[{ value: '', label: get(t)('— unattributed —') }, ...workingGroups.map((w) => ({ value: w.id, label: w.name }))]}
        onSave={saveUnit} />
    </div>
    {#if canEdit}
      <InlineField label={$t('Name')} type="text" {canEdit}
        value={proj?.name ?? ''} placeholder={$t('Project / paper name')} onSave={saveName} />
    {/if}
  </div>

  <!-- status flow: a linear pipeline; completion only from Under review, via
       the reviewed Mint-done path; settlement opens once Finished. -->
  {#if pipeline.length}
    <div class="pcb-section pcb-status">
      <div class="pcb-h-row">
        <span class="pcb-h">{$t('Status')}</span>
        {#if canEdit && holdStatus && !isFinishedProj}
          {#if isHold}
            <button type="button" class="pcb-link" disabled={busy === 'status'} onclick={resume}>▶ {$t('Resume')}</button>
          {:else}
            <button type="button" class="pcb-link" disabled={busy === 'status'} onclick={hold}>⏸ {$t('Hold')}</button>
          {/if}
        {/if}
      </div>

      {#if isHold}
        <p class="pcb-hold">⏸ {$t('On hold')}{#if pipeline.find((s) => s.id === proj?.held_from_status_id)} · {$t('from')} {$t(pipeline.find((s) => s.id === proj?.held_from_status_id)?.name ?? '')}{/if}</p>
      {/if}

      <div class="pcb-steps" class:dim={isHold}>
        {#each pipeline as s, i (s.id)}
          {@const done = curRank > s.rank}
          {@const current = proj?.status_id === s.id}
          {@const terminal = s.name === 'Finished'}
          {@const clickable = canEdit && !isHold && !isFinishedProj && !current && !terminal}
          <button
            type="button"
            class="pcb-step"
            class:done class:current class:terminal
            disabled={!clickable || busy === 'status'}
            title={clickable ? $t('Set to {s}', { s: $t(s.name) }) : ''}
            onclick={() => clickable && setStatus(s.id)}
          >
            <span class="pcb-dotnum">{done ? '✓' : i + 1}</span>
            <span class="pcb-steplabel">{$t(s.name)}</span>
          </button>
          {#if i < pipeline.length - 1}<span class="pcb-steparrow" class:done={curRank > s.rank}>›</span>{/if}
        {/each}
      </div>

      <!-- the completion gate: only at Under review, and reviewed -->
      {#if canEdit && isUnderReview}
        <div class="pcb-status-row">
          <button type="button" class="pcb-done" disabled={busy === 'done'} onclick={mintDone}>
            {#if busy === 'done'}<span class="spin"></span>{/if}✓ {$t('Finish')}
          </button>
          <span class="pcb-hint">{$t('Submits completion to the review queue → settlement.')}</span>
        </div>
      {:else if canEdit && !isFinishedProj && !isHold && curRank < reviewRank}
        <span class="pcb-hint">{$t('Advance to Under review to submit completion.')}</span>
      {/if}

      <!-- settlement opens once the project is Finished -->
      {#if isFinishedProj && isSettled}
        <div class="pcb-settle pcb-settled">
          <span class="pcb-settle-h">✅ {$t('Settled — pool paid out')}</span>
          <span class="pcb-hint">{$t('This project is finished and its pool has been split into spendable STR for each contributor. See it on each wallet.')}</span>
        </div>
      {:else if isFinishedProj}
        <div class="pcb-settle">
          <span class="pcb-settle-h">💰 {$t('Settlement')}</span>
          <span class="pcb-hint">{$t('The project is finished — split its pool into liquid STR.')}</span>
          {#if canEdit && !showSettle}
            <button type="button" class="pcb-done" onclick={() => (showSettle = true)}>{$t('Open settlement')} →</button>
          {/if}
        </div>
        {#if canEdit && showSettle}
          <SettlementForm projectId={projectId}
            onSubmitted={() => { showSettle = false; msg = get(t)('Settlement submitted for review.'); load(); onChanged?.(); }}
            onCancel={() => (showSettle = false)} />
        {/if}
      {/if}
    </div>
  {/if}

  <!-- media links -->
  <div class="pcb-section">
    <div class="pcb-h-row">
      <span class="pcb-h">{$t('Draft & links')}{#if links.length}<span class="pcb-ct"> · {links.length}</span>{/if}</span>
      {#if canEdit}<button type="button" class="pcb-link" onclick={() => (showAddLink = !showAddLink)}>{showAddLink ? $t('Cancel') : '+ ' + $t('Add link')}</button>{/if}
    </div>

    {#if showAddLink && canEdit}
      <div class="pcb-form">
        <div class="pcb-row">
          <label class="pcb-field" style="flex:0 0 9rem;"><span>{$t('Kind')}</span>
            <select bind:value={lKind}>{#each LINK_KINDS as k}<option value={k}>{KIND_ICON[k]} {$t(k)}</option>{/each}</select>
          </label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Title')}</span><input bind:value={lTitle} placeholder={$t('optional')} /></label>
        </div>
        <label class="pcb-field"><span>{$t('URL')}</span><input bind:value={lUrl} placeholder="https://…" /></label>
        <label class="pcb-field"><span>{$t('Notes')}</span><input bind:value={lNotes} placeholder={$t('optional')} /></label>
        <button type="button" class="pcb-go" disabled={busy === 'link'} onclick={addLink}>
          {#if busy === 'link'}<span class="spin"></span>{/if}{$t('Add link')}
        </button>
      </div>
    {/if}

    {#if links.length === 0}
      <p class="pcb-muted">{$t('No links yet — add your Overleaf draft, repo, dataset or paper here. The writing stays in its own tool; this record tracks the work around it.')}</p>
    {:else}
      <ul class="pcb-links">
        {#each links as l (l.id)}
          <li class="pcb-link-row">
            <span class="pcb-kind" title={$t(l.kind)}>{KIND_ICON[l.kind] ?? '🔗'}</span>
            <a class="pcb-link-main" href={l.url} target="_blank" rel="noopener noreferrer">
              <span class="pcb-link-title">{l.title || host(l.url)}</span>
              <span class="pcb-link-host">{host(l.url)}{#if l.notes} · {l.notes}{/if}</span>
            </a>
            {#if canEdit}
              <button type="button" class="pcb-x" disabled={busy === l.id} title={$t('Remove')} aria-label={$t('Remove')} onclick={() => removeLink(l.id)}>✕</button>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- meetings -->
  <div class="pcb-section">
    <div class="pcb-h-row">
      <span class="pcb-h">{$t('Meetings')}{#if meetings.length}<span class="pcb-ct"> · {meetings.length}</span>{/if}</span>
      {#if canEdit}<button type="button" class="pcb-link" onclick={() => (showAddMeeting = !showAddMeeting)}>{showAddMeeting ? $t('Cancel') : '+ ' + $t('Schedule meeting')}</button>{/if}
    </div>

    {#if showAddMeeting && canEdit}
      <div class="pcb-form">
        <label class="pcb-field"><span>{$t('Title')}</span><input bind:value={mTitle} placeholder={$t('Kickoff, weekly sync…')} /></label>
        <div class="pcb-row">
          <label class="pcb-field" style="flex:1;"><span>{$t('Starts')}</span><input type="datetime-local" bind:value={mAt} /></label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Ends')}</span><input type="datetime-local" bind:value={mEnds} /></label>
        </div>
        <div class="pcb-row">
          <label class="pcb-field" style="flex:0 0 9rem;"><span>{$t('Repeats')}</span>
            <select bind:value={mRecur}>{#each RECUR as rc}<option value={rc}>{$t(RECUR_LABEL[rc])}</option>{/each}</select>
          </label>
          <label class="pcb-field" style="flex:1;"><span>{$t('Location')}</span><input bind:value={mLoc} placeholder={$t('Zoom link or room')} /></label>
        </div>
        <label class="pcb-field"><span>{$t('Agenda')}</span><input bind:value={mAgenda} placeholder={$t('optional')} /></label>
        <button type="button" class="pcb-go" disabled={busy === 'meeting'} onclick={addMeeting}>
          {#if busy === 'meeting'}<span class="spin"></span>{/if}{$t('Schedule meeting')}
        </button>
      </div>
    {/if}

    {#if meetings.length === 0}
      <p class="pcb-muted">{$t('No meetings scheduled.')}</p>
    {:else}
      <ul class="pcb-links">
        {#each meetings as m (m.id)}
          {@const recurring = m.recurrence && m.recurrence !== 'none'}
          <li class="pcb-link-row" class:past={!recurring && isPast(m.scheduled_at)}>
            <span class="pcb-kind">{recurring ? '↻' : isPast(m.scheduled_at) ? '✓' : '📅'}</span>
            <div class="pcb-link-main">
              <span class="pcb-link-title">{m.title}{#if recurring}<span class="pcb-recur">{$t(RECUR_LABEL[m.recurrence])}</span>{/if}</span>
              <span class="pcb-link-host">{fmtWhen(m.scheduled_at, m.ends_at)}{#if m.location} · {m.location}{/if}{#if m.agenda} · {m.agenda}{/if}</span>
            </div>
            {#if canEdit}
              <button type="button" class="pcb-x" disabled={busy === m.id} title={$t('Remove')} aria-label={$t('Remove')} onclick={() => removeMeeting(m.id)}>✕</button>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <!-- milestones (output axis: grow the pool + lift the multiplier) -->
  <div class="pcb-section">
    <span class="pcb-h">{$t('Milestones')}</span>
    {#if milestones.length}
      <ul class="pcb-mst">
        {#each milestones as m (m.id)}
          <li>
            <span class="mst-item">{$t(m.catalog?.item ?? '—')}</span>
            <span class="mst-val">+{m.nominal_value} {$t('accruing')} · ×{(1 + Number(m.multiplier_bonus)).toFixed(3)}</span>
            <span class="badge {MST_CLASS[m.status] ?? 'dim'}">{$t(MST_LABEL[m.status] ?? m.status)}</span>
          </li>
        {/each}
      </ul>
    {:else}
      <p class="pcb-muted">{$t('No milestones claimed yet.')}</p>
    {/if}
    {#if canEdit && !isFinishedProj}
      <div class="pcb-mst-claim">
        <select bind:value={mClaim}>
          <option value="">{$t('Claim a milestone…')}</option>
          {#each catalog as c (c.id)}<option value={c.id}>{c.item} (+{c.nominal_value} · ×{(1 + Number(c.multiplier_bonus)).toFixed(3)})</option>{/each}
        </select>
        <button type="button" class="pcb-link" disabled={busy === 'milestone' || !mClaim} onclick={claimMilestone}>{$t('Claim')}</button>
      </div>
    {/if}
  </div>

  <!-- history -->
  <div class="pcb-section">
    <span class="pcb-h">{$t('History')}</span>
    {#if canEdit}
      <div class="pcb-note">
        <input bind:value={note} placeholder={$t('Add a note to the history…')} onkeydown={(e) => { if (e.key === 'Enter') postNote(); }} />
        <button type="button" class="pcb-go" disabled={busy === 'note' || !note.trim()} onclick={postNote}>{$t('Post')}</button>
      </div>
    {/if}
    {#if events.length === 0}
      <p class="pcb-muted">{$t('No activity yet.')}</p>
    {:else}
      <ul class="pcb-timeline">
        {#each events as ev (ev.id)}
          <li class="pcb-ev">
            <span class="pcb-dot"></span>
            <div class="pcb-ev-body">
              <span class="pcb-ev-text">{ev.summary}</span>
              <span class="pcb-ev-meta">{ev.member?.full_name ?? '—'} · {rel(ev.created_at)}</span>
            </div>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
{/if}

<style>
  .pcb-err { font-size: .82rem; color: var(--down); margin: 0 0 .5rem; }
  .pcb-ok { font-size: .82rem; color: var(--accent); margin: 0 0 .5rem; }
  .pcb-done {
    display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .7rem;
    border-radius: 8px; border: 1px solid var(--up); background: color-mix(in srgb, var(--up) 12%, transparent);
    color: var(--up); font: inherit; font-weight: 600; font-size: .82rem; cursor: pointer;
  }
  .pcb-done:disabled { opacity: .55; cursor: not-allowed; }
  .pcb-section { display: flex; flex-direction: column; gap: .5rem; padding-top: .8rem; border-top: 1px solid var(--border); }
  .pcb-h-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
  .pcb-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .pcb-ct { color: var(--text-dim); }
  .pcb-steps { display: flex; align-items: center; gap: .15rem; flex-wrap: wrap; }
  .pcb-steps.dim { opacity: .5; }
  .pcb-step {
    display: inline-flex; align-items: center; gap: .35rem; padding: .3rem .55rem;
    border: 1px solid var(--border); border-radius: 999px; background: var(--card);
    color: var(--text-dim); font: inherit; font-size: .8rem; cursor: pointer;
  }
  .pcb-step:disabled { cursor: default; }
  .pcb-step.done { color: var(--up); border-color: color-mix(in srgb, var(--up) 35%, transparent); }
  .pcb-step.current { color: #fff; background: var(--accent); border-color: var(--accent); font-weight: 600; }
  .pcb-step.terminal { color: var(--muted); border-style: dashed; }
  .pcb-step:not(:disabled):hover { border-color: var(--accent); color: var(--accent); }
  .pcb-dotnum {
    display: inline-flex; align-items: center; justify-content: center; width: 1.15rem; height: 1.15rem;
    border-radius: 50%; background: color-mix(in srgb, currentColor 16%, transparent); font-size: .7rem; font-weight: 700;
  }
  .pcb-step.current .pcb-dotnum { background: rgba(255,255,255,.25); }
  .pcb-steparrow { color: var(--border-2, var(--border)); font-size: .9rem; }
  .pcb-steparrow.done { color: var(--up); }
  .pcb-hold { margin: 0; font-size: .82rem; color: var(--accent); }
  .pcb-settle {
    display: flex; flex-wrap: wrap; align-items: center; gap: .5rem;
    padding: .6rem .7rem; border: 1px solid color-mix(in srgb, var(--up) 30%, transparent);
    border-radius: 10px; background: color-mix(in srgb, var(--up) 8%, transparent); margin-top: .3rem;
  }
  .pcb-settle-h { font-weight: 600; color: var(--text); }
  .pcb-basic { display: flex; flex-direction: column; gap: .6rem; }
  .pcb-basic-grid { display: flex; flex-wrap: wrap; gap: .6rem 1.2rem; }
  .pcb-basic-grid > :global(.if-row) { flex: 1; min-width: 9rem; }
  .pcb-status-row { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
  .pcb-hint { font-size: .72rem; color: var(--muted); }
  .pcb-link { background: transparent; border: 0; color: var(--accent); font: inherit; font-size: .8rem; cursor: pointer; padding: 0; }
  .pcb-link:hover { text-decoration: underline; }
  .pcb-muted { font-size: .82rem; color: var(--muted); margin: 0; }
  .pcb-mst { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .35rem; }
  .pcb-mst li { display: flex; align-items: center; gap: .6rem; padding: .4rem .6rem; border: 1px solid var(--border); border-radius: 8px; background: var(--card); }
  .mst-item { flex: 1; font-size: .86rem; color: var(--text); font-weight: 500; }
  .mst-val { font-size: .76rem; color: var(--muted); font-variant-numeric: tabular-nums; }
  .pcb-mst-claim { display: flex; gap: .4rem; align-items: center; margin-top: .2rem; }
  .pcb-mst-claim select { flex: 1; padding: .4rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .85rem; }

  .pcb-form { display: flex; flex-direction: column; gap: .5rem; padding: .2rem 0 .2rem; }
  .pcb-row { display: flex; gap: .5rem; flex-wrap: wrap; }
  .pcb-field { display: flex; flex-direction: column; gap: .25rem; font-size: .76rem; color: var(--muted); }
  .pcb-field input, .pcb-field select {
    padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem; font-family: inherit;
  }
  .pcb-go {
    align-self: flex-start; padding: .45rem .85rem; border-radius: 8px; border: 1px solid transparent;
    background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .pcb-go:disabled { opacity: .55; cursor: not-allowed; }

  .pcb-links { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .35rem; }
  .pcb-link-row { display: flex; align-items: center; gap: .55rem; padding: .4rem .5rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); }
  .pcb-link-row.past { opacity: .6; }
  .pcb-kind { flex: none; font-size: .95rem; }
  .pcb-link-main { display: flex; flex-direction: column; gap: .05rem; text-decoration: none; color: inherit; min-width: 0; flex: 1; }
  .pcb-link-title { font-size: .86rem; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pcb-link-title:hover { color: var(--accent); }
  .pcb-recur {
    margin-left: .4rem; font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em;
    color: var(--accent); background: var(--accent-soft); border-radius: 999px; padding: .05rem .4rem; vertical-align: middle;
  }
  .pcb-link-host { font-size: .72rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pcb-x { flex: none; background: transparent; border: 0; color: var(--muted); cursor: pointer; font-size: .85rem; padding: .2rem .35rem; }
  .pcb-x:hover { color: var(--down); }

  .pcb-note { display: flex; gap: .4rem; }
  .pcb-note input { flex: 1; padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .86rem; }
  .pcb-timeline { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .5rem; max-height: 240px; overflow-y: auto; }
  .pcb-ev { display: flex; gap: .55rem; }
  .pcb-dot { flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--accent); margin-top: .42rem; }
  .pcb-ev-body { display: flex; flex-direction: column; gap: .1rem; }
  .pcb-ev-text { font-size: .84rem; color: var(--text); }
  .pcb-ev-meta { font-size: .72rem; color: var(--muted); }
</style>
