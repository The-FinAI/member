<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits, member } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import { type Slot } from './ProjectSlotCard.svelte';
  import ProjectTeam from '$lib/people/ProjectTeam.svelte';
  import ProjectCardBody from './ProjectCardBody.svelte';
  import TaskBoard from '$lib/record/TaskBoard.svelte';

  // Shared body for a single project — used by the /projects/[id] page and the
  // projects-grid quick-view drawer, so the page mirrors the drawer (like
  // MemberDetail). Self-loading: pass a projectId. showHeader for the standalone
  // page (the drawer already shows the title in its chrome).
  let { projectId, showHeader = true, onChanged }: {
    projectId: string;
    showHeader?: boolean;
    onChanged?: () => void;
  } = $props();

  type G = {
    id: string; name: string; type: string; status: string;
    venue: string; venueKind: string; deadline: string | null;
    wg: string; wgUnitId: string | null; leader: string;
    seatsFilled: number; seatsTotal: number; openNeeds: number; pool: number;
    summary: string | null; finished: boolean; claimable: boolean;
    mult: number; milestoneNominal: number; leaderId: string | null; settleStatus: string | null;
  };
  let g = $state<G | null>(null);
  let slots = $state<Slot[]>([]);
  let showPostNeed = $state(false);
  let venues = $state<{ id: string; name: string; kind: string; deadline: string | null }[]>([]);
  let workingGroups = $state<{ id: string; name: string }[]>([]);
  let statuses = $state<{ id: string; name: string; rank: number }[]>([]);
  let loading = $state(true);
  let notFound = $state(false);

  const canSeat = $derived(
    $capabilities.has('manage_members') || $capabilities.has('edit_any_project') || $officerUnits.length > 0
  );
  const canManage = $derived.by(() => {
    if (!g) return false;
    if ($capabilities.has('edit_any_project')) return true;
    return !!g.wgUnitId && $officerUnits.some((u) => u.unit_id === g.wgUnitId);
  });
  // a WG officer OR the project's leader (first author) may post needs
  const canPostNeed = $derived(canManage || (!!g?.leaderId && $member?.id === g.leaderId));

  // STR pipeline: nominal accrues → finish → settle → liquid payout
  const projectedPayout = $derived(g ? Math.round(g.pool * g.mult) : 0);
  const stage = $derived.by(() => {
    if (!g) return 'accruing';
    if (g.settleStatus === 'approved') return 'settled';
    if (g.settleStatus === 'submitted' || g.settleStatus === 'under_review') return 'settling';
    if (g.finished) return 'ready';
    return 'accruing';
  });
  const STAGES = ['accruing', 'ready', 'settling', 'settled'];
  const STAGE_LABEL: Record<string, string> = {
    accruing: 'Accruing', ready: 'Ready to settle', settling: 'Settling', settled: 'Settled'
  };
  const stageIdx = $derived(STAGES.indexOf(stage));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; notFound = false;
    const [{ data: p }, { data: ou }, { data: vn }, { data: st }, { data: wg }] = await Promise.all([
      supabase.from('project')
        .select('id, name, target_venue, deadline, summary, org_unit_id, venue:venue_id(name, kind, deadline), project_type(name), project_status!project_status_id_fkey(name, is_active)')
        .eq('id', projectId).maybeSingle(),
      supabase.from('org_unit').select('id, name'),
      supabase.from('venue').select('id, name, kind, deadline').eq('is_active', true).order('rank'),
      supabase.from('project_status').select('id, name, rank').order('rank'),
      supabase.from('org_unit').select('id, name').eq('kind', 'working_group').order('rank')
    ]);
    if (!p) { notFound = true; loading = false; return; }
    venues = (vn as any[]) ?? [];
    statuses = (st as any[]) ?? [];
    workingGroups = (wg as any[]) ?? [];
    const unitName: Record<string, string> = {};
    for (const u of (ou as { id: string; name: string }[]) ?? []) unitName[u.id] = u.name;

    const { data: sl } = await supabase.from('project_slot')
      .select('id, slot_kind, req_access, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name)')
      .eq('project_id', projectId);
    const rawSlots = (sl as any[]) ?? [];
    const memMap: Record<string, { id: string; name: string; amount: number; unit: string }[]> = {};
    // pool = Σ nominal_str over the WHOLE project (by project_id), so legacy
    // commitments migrated with a null slot_id still count — matching how a
    // member's nominal is summed. Per-slot member lists still key on slot_id.
    let pool = 0;
    const { data: wc } = await supabase.from('work_commitment')
      .select('slot_id, member_id, monthly_amount, nominal_str, member:member_id(full_name), resource:resource_id(unit)')
      .eq('project_id', projectId);
    for (const w of (wc as any[]) ?? []) {
      pool += Number(w.nominal_str) || 0;
      if (!w.slot_id) continue;
      const arr = (memMap[w.slot_id] ??= []);
      if (arr.some((m) => m.id === w.member_id)) continue;
      arr.push({ id: w.member_id, name: w.member?.full_name ?? '—', amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h' });
    }
    // output axis: verified milestones add to the pool and lift the settlement
    // multiplier (capped ×3). nominal pool = work nominal + Σ milestone nominal.
    const { data: setl } = await supabase.from('stater_settlement')
      .select('status').eq('project_id', projectId).order('created_at', { ascending: false }).limit(1).maybeSingle();
    const settleStatus = (setl as { status: string } | null)?.status ?? null;

    const { data: vms } = await supabase.from('project_milestone')
      .select('nominal_value, multiplier_bonus').eq('project_id', projectId).eq('status', 'verified');
    let mNominal = 0, mBonus = 0;
    for (const m of (vms as any[]) ?? []) { mNominal += Number(m.nominal_value) || 0; mBonus += Number(m.multiplier_bonus) || 0; }
    pool += mNominal;
    const mult = Math.min(1 + mBonus, 3);
    let seatsTotal = 0, seatsFilled = 0, openNeeds = 0, hasLeader = false, leader = '', leaderId: string | null = null;
    const slotList: Slot[] = [];
    for (const s of rawSlots) {
      const members = memMap[s.id] ?? [];
      slotList.push({ id: s.id, slot_kind: s.slot_kind, skill_name: s.skill?.name ?? null,
        resource_type_name: s.resource_type?.name ?? null, req_access: s.req_access,
        quota: s.quota, headcount: s.headcount ?? 1, status: s.status, members });
      const head = s.headcount ?? 1;
      seatsTotal += head; seatsFilled += Math.min(members.length, head);
      if (members.length < head) openNeeds++;
      if (s.slot_kind === 'leader' && members.length) { hasLeader = true; leader = members[0].name; leaderId = members[0].id; }
    }
    slots = slotList;

    const statusName = (p.project_status?.name ?? '—').trim();
    const finished = statusName.toLowerCase() === 'finished';
    g = {
      id: p.id, name: p.name, type: p.project_type?.name ?? '—', status: statusName,
      venue: p.venue?.name ?? p.target_venue ?? '', venueKind: p.venue?.kind ?? '',
      deadline: p.deadline ?? p.venue?.deadline ?? null,
      wg: (p.org_unit_id && unitName[p.org_unit_id]) || '', wgUnitId: p.org_unit_id ?? null,
      leader, leaderId, seatsFilled, seatsTotal, openNeeds, pool, summary: p.summary ?? null,
      finished, claimable: !hasLeader && !finished, mult, milestoneNominal: mNominal, settleStatus
    };
    loading = false;
  }
  function reload() { load(); onChanged?.(); }

  let releasing = $state(false);
  async function releaseClaim() {
    if (!g) return;
    releasing = true;
    const { error } = await supabase.rpc('release_claim', { p_project: g.id });
    releasing = false;
    if (!error) reload();
  }

  function fmtDate(d: string | null) {
    if (!d) return '';
    return new Date(d + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
  function relDays(d: string | null) {
    if (!d) return '';
    const days = Math.round((new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000);
    if (days === 0) return get(t)('today');
    if (days > 0) return get(t)('in {d}d', { d: days });
    return get(t)('{d}d overdue', { d: -days });
  }
  function ddlClass(d: string | null) {
    if (!d) return 'dim';
    const days = (new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000;
    if (days < 0) return 'neg';
    if (days < 14) return 'warn';
    return 'dim';
  }

  let last = '';
  $effect(() => { if (projectId && projectId !== last) { last = projectId; load(); } });
</script>

{#if loading}
  <p class="muted" style="padding:1rem 0;">{$t('Loading…')}</p>
{:else if notFound || !g}
  <div class="card"><p class="muted" style="padding:1rem;">{$t('No such project.')}</p></div>
{:else}
  <div class="pdrawer">
    {#if showHeader}
      <div class="pd-header">
        <a href="/projects" class="pd-back">← {$t('Projects')}</a>
        <h1 class="pd-title">{g.name}</h1>
        {#if g.wg || g.venue}<p class="pd-subtitle">{[g.wg, g.venue].filter(Boolean).join(' · ')}</p>{/if}
      </div>
    {/if}

    <div class="pd-meta">
      <div class="pd-meta-chips">
        {#if g.claimable}<span class="pd-chip pd-chip-seat" title={$t('The first-author seat is an open need — match someone into it like any other role.')}>✍ {$t('1st-author seat: open')}</span>{/if}
        <span class="pd-chip">{$t(g.type)}</span>
        {#if g.deadline}<span class="pd-chip {ddlClass(g.deadline)}">⏱ {fmtDate(g.deadline)} · {relDays(g.deadline)}</span>{/if}
      </div>
    </div>

    <!-- The credit economy is FIRST-CLASS and operation-linked: committed work
         mints nominal STR into the project's pool; finishing settles it into
         spendable (actual) STR. Shown where the work happens. -->
    <div class="pd-str">
      <div class="pd-str-top">
        <span class="pd-str-pool"><b>{g.pool.toLocaleString()}</b> {$t('STR')}</span>
        <span class="pd-str-label">{$t('in the pool · nominal, accruing from committed work')}</span>
        {#if g.mult > 1}<span class="pd-str-mult">×{g.mult} {$t('milestones')} → {projectedPayout.toLocaleString()} {$t('projected')}</span>{/if}
      </div>
      <div class="pdc-pipe">
        {#each STAGES as s, i}
          <span class="pdc-step" class:done={i < stageIdx} class:on={i === stageIdx}>{$t(STAGE_LABEL[s])}</span>
          {#if i < STAGES.length - 1}<span class="pdc-arr">→</span>{/if}
        {/each}
      </div>
      <p class="pd-str-note">{$t('Nominal STR is locked while the project runs. When it finishes and settles, each contributor is paid their share as settled (spendable) STR.')}</p>
    </div>
    {#if g.finished && stage === 'ready' && canPostNeed}
      <p class="pd-settle-nudge">{$t('This project is finished — draft the settlement below to split the credit.')}</p>
    {/if}

    <!-- the living record is the heartbeat — task board + team lead, the deeper
         project admin (status pipeline · links · meetings · milestones · history
         · settlement) follows. -->
    <div class="pd-section">
      <TaskBoard projectId={g.id} canEdit={canManage || canPostNeed} onChanged={onChanged} />
    </div>

    <div class="pd-section">
      <ProjectTeam projectId={g.id} canManage={canPostNeed} finished={g.finished} />
    </div>

    <ProjectCardBody projectId={g.id} {venues} {workingGroups} {statuses} onChanged={reload} />

    {#if !g.wg}
      <p class="muted" style="font-size:.82rem; margin:0;">{$t('This project isn’t attributed to a working group yet.')}</p>
    {/if}

    {#if g.wgUnitId}
      <div class="row" style="gap:.5rem; flex-wrap:wrap; align-items:center;">
        {#if canManage}
          <button type="button" class="pd-release" disabled={releasing} onclick={releaseClaim}>
            {releasing ? $t('Releasing…') : $t('Release claim')}
          </button>
        {/if}
      </div>
    {/if}
  </div>
{/if}

<style>
  /* credit economy panel — gold is STR's alone (design system v2) */
  .pd-str { border: 1px solid var(--border); border-top: 2px solid var(--gold); border-radius: var(--r-md); padding: .7rem .85rem; background: var(--gold-soft); }
  .pd-str-top { display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
  .pd-str-pool { font-family: var(--font-mono); font-variant-numeric: tabular-nums; font-size: 1.25rem; color: var(--gold); }
  .pd-str-pool b { font-weight: 700; }
  .pd-str-label { font-size: .8rem; color: var(--text-dim); }
  .pd-str-mult { font-size: .76rem; color: var(--gold); font-weight: 600; margin-left: auto; }
  .pdc-pipe { display: flex; flex-direction: row; align-items: center; gap: .4rem; flex-wrap: wrap; margin-top: .5rem; }
  .pdc-step { font-size: .72rem; font-weight: 700; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); }
  .pdc-step.done { color: var(--text-dim); }
  .pdc-step.on { color: var(--gold); border-bottom: 2px solid var(--gold); }
  .pdc-arr { color: var(--border-2); font-size: .8rem; }
  .pd-str-note { font-size: .76rem; color: var(--muted); margin: .45rem 0 0; }
  .pd-settle-nudge { font-size:.9rem; color: var(--gold); background: var(--gold-soft); border:1px solid var(--gold); border-radius: var(--r-sm); padding:.5rem .7rem; }
  .pdrawer { display: flex; flex-direction: column; gap: 1rem; }
  .pd-header { display: flex; flex-direction: column; gap: .15rem; }
  .pd-back { font-size: .82rem; color: var(--muted); text-decoration: none; }
  .pd-back:hover { color: var(--accent); }
  .pd-title { margin: .2rem 0 0; font-size: 1.5rem; }
  .pd-subtitle { margin: 0; font-size: .85rem; color: var(--text-dim); }
  .pd-meta { display: flex; gap: .5rem; align-items: flex-start; }
  .pd-meta-chips { display: flex; flex-wrap: wrap; gap: .4rem; align-items: center; }
  .pd-chip { display: inline-flex; align-items: center; gap: .3rem; font-size: .76rem; color: var(--text-dim); background: var(--card-2); border: 1px solid var(--border); border-radius: var(--r-full); padding: .15rem .55rem; }
  .pd-chip.warn { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 35%, transparent); }
  .pd-chip-seat { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 30%, transparent); background: var(--accent-soft); }
  .pd-chip.neg { color: var(--down); border-color: color-mix(in srgb, var(--down) 35%, transparent); }
  .pd-stats { display: flex; flex-wrap: wrap; gap: .3rem 1.4rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card); }
  .pd-stat { display: flex; flex-direction: column; gap: .1rem; }
  .pd-v { font-weight: 700; font-size: 1rem; color: var(--text); }
  .pd-l { font-size: .68rem; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .pd-section { display: flex; flex-direction: column; gap: .45rem; }
  .pd-h { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .pd-btn { align-self: flex-start; display: inline-flex; align-items: center; gap: .3rem; padding: .5rem .9rem; background: var(--accent); color: #fff; border: 1px solid transparent; border-radius: var(--r-sm); text-decoration: none; font-weight: 600; }
  .pd-btn.ghost { background: transparent; color: var(--accent); border-color: var(--border); }
  .pd-postneed-toggle { align-self: flex-start; background: transparent; border: 0; padding: 0; cursor: pointer; font: inherit; color: var(--accent); font-weight: 600; }
  .pd-postneed-toggle:hover { text-decoration: underline; }
  .pd-release { padding: .5rem .9rem; border-radius: var(--r-sm); border: 1px solid var(--border); background: transparent; color: var(--down); font: inherit; font-weight: 600; cursor: pointer; }
  .pd-release:hover { border-color: var(--down); }
  .pd-release:disabled { opacity: .55; cursor: not-allowed; }
</style>
