<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, actingAs } from '$lib/session';
  import CountUp from '$lib/CountUp.svelte';
  import Hint from '$lib/Hint.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  const id = $derived($page.params.id);

  type Project = {
    id: string; name: string; target_venue: string | null; summary: string | null;
    status_id: string | null; held_from_status_id: string | null; venue_id: string | null;
    project_type: { name: string; join_stake: number; leader_stake: number } | null; project_status: { id: string; name: string; rank: number } | null;
    venue: { name: string; kind: string; url: string | null; deadline: string | null } | null;
  };
  type VenueOpt = { id: string; name: string; kind: string; deadline: string | null };
  type PStatus = { id: string; name: string; rank: number };
  type Participant = { member_id: string; member: { full_name: string } | null; project_role: { name: string; can_manage: boolean } | null };
  type Need = {
    id: string; description: string | null; headcount: number; min_level: string | null;
    min_guild_level: string | null; skill_id: string | null; status: string;
    contribution_kind: string; hours_per_month: number | null;
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
  type ResType = { id: string; name: string; valuation_method: string; unit: string | null; usd_per_unit: number | null };
  type ResRequest = { id: string; description: string | null; quantity: string | null; status: string; type_id: string | null; resource_type: { name: string } | null };
  type ResOffer = { id: string; status: string; message: string | null; request_id: string; member: { full_name: string } | null; resource: { name: string } | null };
  type OfferableResource = { id: string; name: string; scope: string;
    unit?: string | null; usd_per_unit?: number | null;
    resource_type?: { valuation_method: string | null; unit: string | null; usd_per_unit: number | null } | null;
    gpu_model?: { name: string; tflops: number } | null;
    api_model?: { name: string; usd_per_million: number } | null };
  type MyResourceRow = { resource_id: string; resource: string; unit: string; ym: string; qty: number; equiv: number };
  type MCatalog = { id: string; category: string; item: string; nominal_value: number; multiplier_bonus: number };
  type PMilestone = {
    id: string; catalog_id: string | null; title: string | null; status: string;
    claimed_by: string | null; verified_by: string | null; verified_at: string | null;
    milestone_catalog: { category: string; item: string; nominal_value: number; multiplier_bonus: number } | null;
  };
  type MyLaborRow = { skill_id: string; skill: string; ym: string; hours: number; equiv: number };
  type MyWritingRow = { ym: string; hours: number; equiv: number };

  let project = $state<Project | null>(null);
  let participants = $state<Participant[]>([]);
  let needs = $state<Need[]>([]);
  let applications = $state<Application[]>([]);
  let roles = $state<Role[]>([]);
  let skills = $state<Skill[]>([]);
  let statuses = $state<PStatus[]>([]);
  let venueOpts = $state<VenueOpt[]>([]);
  let editingVenue = $state(false);
  let vSel = $state('');
  let savingVenue = $state(false);
  let transitioning = $state(false);
  // my application per need: needId -> { id, status }
  let myApps = $state<Record<string, { id: string; status: string }>>({});
  let applyMsg = $state<Record<string, string>>({});
  let confirming = $state('');
  let iManage = $state(false);
  let loading = $state(true);
  let error = $state('');
  let escrow = $state(0);
  let joinStake = $state(20);
  let leaderStake = $state(50);
  let myBalance = $state(0);
  let claiming = $state(false);

  // contribution model: nominal pool, multiplier, milestones, my labor
  let nominalPool = $state(0);
  let multiplier = $state(1);
  let memberNominal = $state<Record<string, number>>({});
  let catalog = $state<MCatalog[]>([]);
  let milestones = $state<PMilestone[]>([]);
  let myLabor = $state<MyLaborRow[]>([]);
  // my-contribution (set next month's labor)
  let clSkill = $state(''); let clHours = $state(0); let clMonth = $state(currentMonth());
  let settingLabor = $state(false);
  // leader first-author writing duty (20h/month)
  let myWriting = $state<MyWritingRow[]>([]);
  let writeHours = $state(20); let writeMonth = $state(currentMonth());
  let settingWriting = $state(false);
  const writingRequired = 20;
  // milestone claim form
  let msCatalog = $state(''); let msTitle = $state(''); let claimingMs = $state(false);

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
  let nKind = $state('seat'); let nHours = $state(20);

  // leader skill gate (mirrors the server-side hard gate)
  type LeaderReq = { skill_id: string; skill_name: string; min_level: string; have: string | null };
  let leaderMissing = $state<LeaderReq[]>([]);
  const leaderReady = $derived(leaderMissing.length === 0);
  const GUILD_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };
  const GUILD_LADDER = ['apprentice', 'journeyman', 'craftsman', 'master'];
  function guildRank(g: string | null | undefined) { return g ? GUILD_LADDER.indexOf(g) + 1 : 0; }
  // my certified guild level per skill_id (drives "you qualify" on needs)
  let myCertified = $state<Record<string, string>>({});
  // does the current member meet a recruiting need's guild-skill bar?
  function qualifiesFor(n: Need) {
    if (!n.min_guild_level || !n.skill_id) return true;
    return guildRank(myCertified[n.skill_id]) >= guildRank(n.min_guild_level);
  }

  // ---- records / meetings / history ----
  type Link = { id: string; kind: string; title: string; url: string; notes: string | null; created_at: string; member: { full_name: string } | null };
  type Meeting = { id: string; title: string; scheduled_at: string; ends_at: string | null; location: string | null; agenda: string | null; member: { full_name: string } | null };
  type Event = { id: string; event_type: string; summary: string; created_at: string; member: { full_name: string } | null };

  let links = $state<Link[]>([]);
  let meetings = $state<Meeting[]>([]);
  let events = $state<Event[]>([]);
  const iParticipate = $derived(participants.some((x) => x.member_id === $member?.id));
  const canContribute = $derived(iManage || iParticipate);
  const hasLeader = $derived(participants.some((x) => x.project_role?.can_manage));

  const LINK_KINDS = ['proposal', 'overleaf', 'openreview', 'paper', 'repo', 'dataset', 'slides', 'drive', 'media', 'other'];
  // add-link form
  let lKind = $state('proposal'); let lTitle = $state(''); let lUrl = $state(''); let lNotes = $state('');
  let addingLink = $state(false);
  // add-meeting form
  let mTitle = $state(''); let mAt = $state(''); let mEnds = $state(''); let mLoc = $state(''); let mAgenda = $state('');
  let addingMeeting = $state(false);
  // manual note
  let noteText = $state('');

  // resources
  let resTypes = $state<ResType[]>([]);
  let resRequests = $state<ResRequest[]>([]);
  let resOffers = $state<ResOffer[]>([]);
  let myResources = $state<OfferableResource[]>([]);
  let offeredRequestIds = $state<Set<string>>(new Set());
  // rolling monthly resource contribution (declare = mint)
  let myResCommits = $state<MyResourceRow[]>([]);
  let rcRes = $state(''); let rcQty = $state(0); let rcMonth = $state(currentMonth());
  let settingRes = $state(false);
  let strPerUsd = $state(0.24); let usdPerTflopHour = $state(0.005);
  // new resource-request form
  let rrType = $state(''); let rrQty = $state(''); let rrDesc = $state('');
  const rrSelected = $derived(resTypes.find((r) => r.id === rrType) ?? null);
  const rrUnit = $derived(rrSelected?.unit ?? '');
  // est. STR for the request, when the type prices a flat USD/unit and qty is numeric
  const rrEstStr = $derived.by(() => {
    const t = rrSelected;
    if (!t || !(t.valuation_method === 'flat' || t.valuation_method === 'usd') || t.usd_per_unit == null) return null;
    const qty = parseFloat(String(rrQty).replace(/[^0-9.]/g, ''));
    if (!isFinite(qty) || qty <= 0) return null;
    return Math.round(qty * Number(t.usd_per_unit) * strPerUsd);
  });
  // offer form state, keyed by request id
  let offerResourceId = $state<Record<string, string>>({});
  let offerMessage = $state<Record<string, string>>({});

  const contributorRoleId = $derived(roles.find((r) => r.name === 'Contributor')?.id ?? roles[0]?.id ?? null);

  async function load() {
    if (!supabaseConfigured || !id) { loading = false; return; }
    loading = true;
    const [{ data: p }, { data: pm }, { data: nd }, { data: rl }, { data: sk }, { data: ps }] = await Promise.all([
      supabase.from('project').select('id, name, target_venue, summary, status_id, held_from_status_id, venue_id, project_type(name, join_stake, leader_stake), project_status!project_status_id_fkey(id, name, rank), venue:venue_id(name, kind, url, deadline)').eq('id', id).maybeSingle(),
      supabase.from('project_member').select('member_id, member(full_name), project_role(name, can_manage)').eq('project_id', id),
      supabase.from('open_need').select('id, description, headcount, min_level, min_guild_level, skill_id, status, contribution_kind, hours_per_month, project_role_id, project_role(name), skill(name)').eq('project_id', id),
      supabase.from('project_role').select('id, name, payout_weight').order('name'),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('project_status').select('id, name, rank').order('rank')
    ]);
    project = (p as Project) ?? null;
    participants = (pm as Participant[]) ?? [];
    needs = (nd as Need[]) ?? [];
    roles = (rl as Role[]) ?? [];
    skills = (sk as Skill[]) ?? [];
    statuses = (ps as PStatus[]) ?? [];

    if (!venueOpts.length) {
      const { data: vn } = await supabase.from('venue').select('id, name, kind, deadline').eq('is_active', true).order('rank');
      venueOpts = (vn as VenueOpt[]) ?? [];
    }

    // act on behalf of a card (officer proxy) when one is selected
    const me = $actingAs?.id ?? $member?.id;
    iManage =
      $capabilities.has('edit_any_project') ||
      participants.some((x) => x.member_id === me && x.project_role?.can_manage);

    joinStake = Number(project?.project_type?.join_stake ?? joinStake);
    leaderStake = Number(project?.project_type?.leader_stake ?? leaderStake);

    if (me) {
      const { data: bal } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle();
      myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
      if (!hasLeader) {
        const { data: lm } = await supabase.rpc('leader_reqs_missing', { mid: me });
        leaderMissing = (lm as LeaderReq[]) ?? [];
      }
      const { data: cert } = await supabase
        .from('member_skill').select('skill_id, certified_level').eq('member_id', me).not('certified_level', 'is', null);
      const cmap: Record<string, string> = {};
      for (const r of (cert as { skill_id: string; certified_level: string }[]) ?? []) cmap[r.skill_id] = r.certified_level;
      myCertified = cmap;
    }

    const needIds = needs.map((n) => n.id);
    if (me && needIds.length) {
      const { data: mine } = await supabase
        .from('need_application').select('id, status, open_need_id').eq('member_id', me).in('open_need_id', needIds);
      const map: Record<string, { id: string; status: string }> = {};
      for (const r of (mine as any[]) ?? []) map[r.open_need_id] = { id: r.id, status: r.status };
      myApps = map;
    } else {
      myApps = {};
    }
    if (iManage && needIds.length) {
      const { data: apps } = await supabase
        .from('need_application').select('id, status, message, open_need_id, member(full_name)').in('open_need_id', needIds);
      applications = (apps as Application[]) ?? [];
    }

    // resources
    const [{ data: rt }, { data: rr }, { data: pol }] = await Promise.all([
      supabase.from('resource_type').select('id, name, valuation_method, unit, usd_per_unit').order('rank'),
      supabase.from('resource_request').select('id, description, quantity, status, type_id, resource_type(name)').eq('project_id', id).order('created_at'),
      supabase.from('stater_policy').select('key, value').in('key', ['str_per_usd', 'usd_per_tflop_hour'])
    ]);
    resTypes = (rt as ResType[]) ?? [];
    resRequests = (rr as ResRequest[]) ?? [];
    for (const p of (pol as { key: string; value: number }[]) ?? []) {
      if (p.key === 'str_per_usd') strPerUsd = Number(p.value);
      if (p.key === 'usd_per_tflop_hour') usdPerTflopHour = Number(p.value);
    }

    if (me) {
      const { data: mine } = await supabase
        .from('resource')
        .select('id, name, scope, unit, usd_per_unit, resource_type(valuation_method, unit, usd_per_unit), gpu_model:gpu_model_id(name, tflops), api_model:api_model_id(name, usd_per_million)')
        .or(`holder_member_id.eq.${me},scope.eq.community`)
        .eq('approval_status', 'approved').order('name');
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

    // contribution model: nominal pool + multiplier + per-member nominal + milestones
    const [{ data: np }, { data: mu }, { data: mn }, { data: cat }, { data: ms }] = await Promise.all([
      supabase.rpc('stater_project_nominal_pool', { p: id }),
      supabase.rpc('stater_milestone_mult', { p: id }),
      supabase.from('stater_project_member_nominal').select('member_id, nominal').eq('project_id', id),
      supabase.from('milestone_catalog').select('id, category, item, nominal_value, multiplier_bonus').order('rank'),
      supabase.from('project_milestone')
        .select('id, catalog_id, title, status, claimed_by, verified_by, verified_at, milestone_catalog(category, item, nominal_value, multiplier_bonus)')
        .eq('project_id', id).order('created_at', { ascending: false })
    ]);
    nominalPool = Number((np as number | null) ?? 0);
    multiplier = Number((mu as number | null) ?? 1);
    const nmap: Record<string, number> = {};
    for (const r of (mn as any[]) ?? []) nmap[r.member_id] = Number(r.nominal);
    memberNominal = nmap;
    catalog = (cat as MCatalog[]) ?? [];
    milestones = (ms as PMilestone[]) ?? [];

    // my standing labor commitments on this project, with monthly periods
    if (me) {
      const { data: mine } = await supabase
        .from('stater_project_stake_commitment')
        .select('id, skill_id, skill(name), stater_commitment_period(year_month, committed_amount, token_equivalent)')
        .eq('project_id', id).eq('member_id', me).eq('commitment_type', 'labor');
      const rows: MyLaborRow[] = [];
      for (const c of (mine as any[]) ?? [])
        for (const p of c.stater_commitment_period ?? [])
          rows.push({ skill_id: c.skill_id, skill: c.skill?.name ?? '—', ym: p.year_month,
                      hours: Number(p.committed_amount), equiv: Number(p.token_equivalent) });
      rows.sort((a, b) => b.ym.localeCompare(a.ym) || a.skill.localeCompare(b.skill));
      myLabor = rows;
    } else {
      myLabor = [];
    }

    // my standing first-author writing duty on this project (leaders)
    if (me) {
      const { data: fw } = await supabase
        .from('stater_project_stake_commitment')
        .select('id, stater_commitment_period(year_month, committed_amount, token_equivalent)')
        .eq('project_id', id).eq('member_id', me).eq('commitment_type', 'first_author_writing');
      const wrows: MyWritingRow[] = [];
      for (const c of (fw as any[]) ?? [])
        for (const p of c.stater_commitment_period ?? [])
          wrows.push({ ym: p.year_month, hours: Number(p.committed_amount), equiv: Number(p.token_equivalent) });
      wrows.sort((a, b) => b.ym.localeCompare(a.ym));
      myWriting = wrows;
    } else {
      myWriting = [];
    }

    // my standing resource contributions on this project, with monthly periods
    if (me) {
      const { data: mres } = await supabase
        .from('stater_project_stake_commitment')
        .select('id, resource_id, resource(name, unit, str_per_unit, resource_type(unit, str_per_unit)), stater_commitment_period(year_month, committed_amount, token_equivalent)')
        .eq('project_id', id).eq('member_id', me).eq('commitment_type', 'resource').not('resource_id', 'is', null);
      const rrows: MyResourceRow[] = [];
      for (const c of (mres as any[]) ?? []) {
        const u = c.resource?.unit || c.resource?.resource_type?.unit || 'unit';
        for (const p of c.stater_commitment_period ?? [])
          rrows.push({ resource_id: c.resource_id, resource: c.resource?.name ?? '—', unit: u,
                       ym: p.year_month, qty: Number(p.committed_amount), equiv: Number(p.token_equivalent) });
      }
      rrows.sort((a, b) => b.ym.localeCompare(a.ym) || a.resource.localeCompare(b.resource));
      myResCommits = rrows;
    } else {
      myResCommits = [];
    }

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

    // records / meetings / history
    const [{ data: lk }, { data: mt }, { data: ev }] = await Promise.all([
      supabase.from('project_link')
        .select('id, kind, title, url, notes, created_at, member:added_by(full_name)')
        .eq('project_id', id).order('created_at', { ascending: false }),
      supabase.from('project_meeting')
        .select('id, title, scheduled_at, ends_at, location, agenda, member:created_by(full_name)')
        .eq('project_id', id).order('scheduled_at', { ascending: false }),
      supabase.from('project_event')
        .select('id, event_type, summary, created_at, member:actor_member_id(full_name)')
        .eq('project_id', id).order('created_at', { ascending: false }).limit(100)
    ]);
    links = (lk as Link[]) ?? [];
    meetings = (mt as Meeting[]) ?? [];
    events = (ev as Event[]) ?? [];

    // seed the settlement builder defaults from participants (by role payout_weight)
    if (iManage && !settlement) {
      const w: Record<string, number> = {}; const a: Record<string, boolean> = {};
      for (const pt of participants) {
        const role = roles.find((r) => r.name === pt.project_role?.name);
        // pre-fill from accrued nominal (bonds + labor + resources); fall back to role weight
        w[pt.member_id] = Number(memberNominal[pt.member_id]) || Number(role?.payout_weight ?? 1);
        a[pt.member_id] = true;
      }
      sWeight = w; sAuthor = a;
    }
    loading = false;
  }

  // ---- controlled status pipeline ----
  const pipeline = $derived([...statuses].filter((s) => s.name !== 'Hold').sort((a, b) => a.rank - b.rank));
  const holdStatus = $derived(statuses.find((s) => s.name === 'Hold') ?? null);
  const isHold = $derived(project?.project_status?.name === 'Hold');
  const curIdx = $derived(pipeline.findIndex((s) => s.id === project?.status_id));
  const nextStatus = $derived(!isHold && curIdx >= 0 && curIdx < pipeline.length - 1 ? pipeline[curIdx + 1] : null);
  const prevStatus = $derived(!isHold && curIdx > 0 ? pipeline[curIdx - 1] : null);
  const resumeStatus = $derived(isHold ? (statuses.find((s) => s.id === project?.held_from_status_id) ?? pipeline[0] ?? null) : null);

  function statusClass(name: string | null | undefined) {
    switch (name) {
      case 'Proposal': return 'st-proposal';
      case 'Data Collecting': return 'st-data';
      case 'Work in progress': return 'st-wip';
      case 'Under review': return 'st-review';
      case 'Finished': return 'st-finished';
      case 'Hold': return 'st-hold';
      default: return 'st-proposal';
    }
  }
  function fmtDay(d: string | null | undefined) {
    if (!d) return '';
    return new Date(d + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }
  function ddlClass(d: string | null | undefined) {
    if (!d) return 'muted';
    const days = (new Date(d + 'T00:00:00').getTime() - Date.now()) / 86400000;
    if (days < 0) return 'neg';
    if (days < 14) return 'warn';
    return 'dim';
  }

  async function transitionStatus(targetId: string | undefined, label: string) {
    if (!targetId) return;
    if (label === 'Finished' && !confirm(get(t)('Advance to Finished? This opens settlement — payout happens when a settlement is submitted and approved.'))) return;
    error = ''; transitioning = true;
    const { error: err } = await supabase.rpc('transition_project_status', { p: id, target: targetId });
    transitioning = false;
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
    if (!confirm(get(t)('Co-sign & approve? The pool mints to {n} STR (nominal ×{m}) and is distributed by the drafted weights. This cannot be undone.', { n: Math.floor(nominalPool * multiplier).toLocaleString(), m: multiplier }))) return;
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
    if (!contributorRoleId) { error = get(t)('No project role available to assign.'); return; }
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

  async function addLink() {
    error = '';
    if (!lTitle.trim() || !lUrl.trim()) { error = get(t)('Title and URL are required.'); return; }
    let url = lUrl.trim();
    if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
    addingLink = true;
    const { error: err } = await supabase.from('project_link').insert({
      project_id: id, kind: lKind, title: lTitle.trim(), url, notes: lNotes.trim() || null
    });
    addingLink = false;
    if (err) { error = err.message; return; }
    lTitle = ''; lUrl = ''; lNotes = ''; lKind = 'proposal';
    await load();
  }

  async function deleteLink(linkId: string) {
    error = '';
    const { error: err } = await supabase.from('project_link').delete().eq('id', linkId);
    if (err) { error = err.message; return; }
    await load();
  }

  async function addMeeting() {
    error = '';
    if (!mTitle.trim() || !mAt) { error = get(t)('Meeting title and time are required.'); return; }
    addingMeeting = true;
    const { error: err } = await supabase.from('project_meeting').insert({
      project_id: id, title: mTitle.trim(), scheduled_at: new Date(mAt).toISOString(),
      ends_at: mEnds ? new Date(mEnds).toISOString() : null,
      location: mLoc.trim() || null, agenda: mAgenda.trim() || null
    });
    addingMeeting = false;
    if (err) { error = err.message; return; }
    mTitle = ''; mAt = ''; mEnds = ''; mLoc = ''; mAgenda = '';
    await load();
  }

  async function deleteMeeting(meetingId: string) {
    error = '';
    const { error: err } = await supabase.from('project_meeting').delete().eq('id', meetingId);
    if (err) { error = err.message; return; }
    await load();
  }

  function openVenueEdit() {
    vSel = project?.venue_id ?? '';
    editingVenue = true;
  }
  async function changeVenue() {
    if (!project) return;
    error = '';
    const newId = vSel || null;
    if (newId === (project.venue_id ?? null)) { editingVenue = false; return; }
    savingVenue = true;
    const { error: err } = await supabase.from('project').update({ venue_id: newId }).eq('id', id);
    if (err) { savingVenue = false; error = err.message; return; }
    if ($member) {
      const target = venueOpts.find((v) => v.id === newId);
      await supabase.from('project_event').insert({
        project_id: id, actor_member_id: $member.id, event_type: 'note',
        summary: `Target venue changed to ${target ? target.name : 'none'}`
      });
    }
    savingVenue = false;
    editingVenue = false;
    await load();
  }

  async function postNote() {
    error = '';
    if (!noteText.trim() || !$member) return;
    const { error: err } = await supabase.from('project_event').insert({
      project_id: id, actor_member_id: $member.id, event_type: 'note', summary: noteText.trim()
    });
    if (err) { error = err.message; return; }
    noteText = '';
    await load();
  }

  function linkHost(u: string) {
    try { return new URL(u).hostname.replace(/^www\./, ''); } catch { return u; }
  }
  function fmt(ts: string) { return new Date(ts).toLocaleString(); }
  function isUpcoming(ts: string) { return new Date(ts).getTime() > Date.now(); }

  const EVENT_ICON: Record<string, string> = {
    project_created: '◆', status_changed: '⇄', member_joined: '＋', need_posted: '⊕',
    application_accepted: '✓', stake_committed: '◇', record_added: '🔗', meeting_scheduled: '◷',
    note: '✎'
  };
  function eventIcon(t: string) {
    if (t.startsWith('settlement_')) return '⚖';
    return EVENT_ICON[t] ?? '•';
  }

  onMount(load);

  // p_as for member-scoped RPCs; reload me-relative state when the acting card changes
  const asArg = $derived($actingAs?.id ?? null);
  let actingMounted = false;
  $effect(() => {
    const _ = $actingAs?.id; // track
    if (actingMounted) load();
    actingMounted = true;
  });

  function currentMonth() { return new Date().toISOString().slice(0, 7); }
  function fmtMonth(ym: string) {
    const [y, m] = ym.split('-').map(Number);
    return new Date(y, m - 1, 1).toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
  }
  const leafSkills = $derived(skills.filter((s) => s.parent_id));
  const writingThisMonth = $derived(myWriting.find((w) => w.ym === currentMonth())?.hours ?? 0);
  const writingMet = $derived(writingThisMonth >= writingRequired);
  const totalNominal = $derived(Object.values(memberNominal).reduce((a, b) => a + b, 0));
  const canVerifyMs = $derived(iManage || $capabilities.has('manage_stater') || $capabilities.has('manage_resources'));
  const verifiedBonus = $derived(
    milestones.filter((m) => m.status === 'verified')
      .reduce((a, m) => a + Number(m.milestone_catalog?.multiplier_bonus ?? 0), 0)
  );

  async function setLabor() {
    error = '';
    if (!clSkill) { error = get(t)('Pick a skill for your labor.'); return; }
    if (!/^\d{4}-\d{2}$/.test(clMonth)) { error = get(t)('Month must be YYYY-MM.'); return; }
    settingLabor = true;
    const { error: err } = await supabase.rpc('set_labor_commitment',
      { p: id, sk: clSkill, ym: clMonth, hours: Number(clHours), p_as: asArg });
    settingLabor = false;
    if (err) { error = err.message; return; }
    await load();
  }

  async function setWriting() {
    error = '';
    if (!/^\d{4}-\d{2}$/.test(writeMonth)) { error = get(t)('Month must be YYYY-MM.'); return; }
    settingWriting = true;
    const { error: err } = await supabase.rpc('set_first_author_writing',
      { p: id, ym: writeMonth, hours: Number(writeHours) });
    settingWriting = false;
    if (err) { error = err.message; return; }
    await load();
  }

  function resMethod(r: OfferableResource) { return r.resource_type?.valuation_method ?? 'flat'; }
  function resUnit(r: OfferableResource) {
    return r.unit || r.resource_type?.unit ||
      ({ gpu: 'GPU-hour', api: '1M tokens', usd: 'USD' } as Record<string, string>)[resMethod(r)] || 'unit';
  }
  function resValueUsd(r: OfferableResource, qty: number) {
    switch (resMethod(r)) {
      case 'gpu': return Number(r.gpu_model?.tflops ?? 0) * qty * usdPerTflopHour;
      case 'api': return Number(r.api_model?.usd_per_million ?? 0) * qty;
      case 'usd': return qty;
      default: return Number(r.usd_per_unit ?? r.resource_type?.usd_per_unit ?? 0) * qty;
    }
  }
  function resValueStr(r: OfferableResource, qty: number) { return Math.ceil(resValueUsd(r, qty) * strPerUsd); }
  function resRateHint(r: OfferableResource) {
    switch (resMethod(r)) {
      case 'gpu': return r.gpu_model ? `${r.gpu_model.name} · ${r.gpu_model.tflops} TFLOPs` : 'GPU';
      case 'api': return r.api_model ? `${r.api_model.name} · $${r.api_model.usd_per_million}/M` : 'API';
      case 'usd': return `$ → STR`;
      default: return `$${Number(r.usd_per_unit ?? r.resource_type?.usd_per_unit ?? 0)}/${resUnit(r)}`;
    }
  }
  const rcSelected = $derived(myResources.find((r) => r.id === rcRes) ?? null);
  const rcPreview = $derived(rcSelected ? resValueStr(rcSelected, Number(rcQty) || 0) : 0);

  async function setResource() {
    error = '';
    if (!rcRes) { error = get(t)('Pick a resource to contribute.'); return; }
    if (!/^\d{4}-\d{2}$/.test(rcMonth)) { error = get(t)('Month must be YYYY-MM.'); return; }
    settingRes = true;
    const { error: err } = await supabase.rpc('set_resource_commitment',
      { p: id, res: rcRes, ym: rcMonth, qty: Number(rcQty), p_as: asArg });
    settingRes = false;
    if (err) { error = err.message; return; }
    await load();
  }

  async function claimMilestone() {
    error = '';
    if (!msCatalog) { error = get(t)('Pick a milestone.'); return; }
    claimingMs = true;
    const { error: err } = await supabase.rpc('claim_milestone',
      { p: id, p_catalog_id: msCatalog, p_title: msTitle.trim() || null });
    claimingMs = false;
    if (err) { error = err.message; return; }
    msCatalog = ''; msTitle = '';
    await load();
  }
  async function verifyMilestone(mid: string) {
    error = '';
    const { error: err } = await supabase.rpc('verify_milestone', { milestone_id: mid });
    if (err) { error = err.message; return; }
    await load();
  }
  async function rejectMilestone(mid: string) {
    error = '';
    const { error: err } = await supabase.rpc('reject_milestone', { milestone_id: mid });
    if (err) { error = err.message; return; }
    await load();
  }

  async function apply(needId: string) {
    error = '';
    if (!$member && !$actingAs) return;
    const { error: err } = await supabase.rpc('apply_to_need', {
      p_need: needId, p_message: applyMsg[needId]?.trim() || null, p_as: asArg
    });
    if (err) { error = err.message; return; }
    applyMsg[needId] = '';
    await load();
  }

  async function confirmJoin(needId: string) {
    error = '';
    const app = myApps[needId];
    if (!app) return;
    if (!confirm(get(t)('Confirm joining this project? This stakes {n} STR from your balance into the project escrow.', { n: joinStake }))) return;
    confirming = needId;
    const { error: err } = await supabase.rpc('confirm_join', { app_id: app.id, p_as: asArg });
    confirming = '';
    if (err) { error = err.message; return; }
    await load();
  }

  async function claimLeadership() {
    error = '';
    if (!$member && !$actingAs) return;
    if (!leaderReady) { error = get(t)('You don’t yet meet the leader skill requirements.'); return; }
    if (!confirm(get(t)('Take the lead on this project? This stakes {n} STR from your balance into the project escrow and seats you as Leader.', { n: leaderStake }))) return;
    claiming = true;
    const { error: err } = await supabase.rpc('claim_leadership', { p: id, p_as: asArg });
    claiming = false;
    if (err) { error = err.message; return; }
    await load();
  }

  async function closeNeed(needId: string) {
    error = '';
    const { error: err } = await supabase.from('open_need').update({ status: 'closed' }).eq('id', needId);
    if (err) { error = err.message; return; }
    await load();
  }

  async function postNeed() {
    error = '';
    if (!nRole) { error = get(t)('Pick a role.'); return; }
    const { error: err } = await supabase.from('open_need').insert({
      project_id: id, project_role_id: nRole, skill_id: nSkill || null,
      min_guild_level: nSkill && nLevel ? nLevel : null, headcount: nCount, description: nDesc || null,
      contribution_kind: nKind, hours_per_month: nKind === 'labor' ? Number(nHours) : null
    });
    if (err) { error = err.message; return; }
    nRole = ''; nSkill = ''; nLevel = ''; nCount = 1; nDesc = ''; nKind = 'seat'; nHours = 20;
    await load();
  }

  async function accept(app: Application, roleId: string | null) {
    error = '';
    if (!roleId) { error = get(t)('Need has no role to assign.'); return; }
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
  <p><a href="/projects">← {$t('Projects')}</a></p>
  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if !project}
    <p class="muted">{$t('Project not found.')}</p>
  {:else}
    <div class="row" style="justify-content:space-between;">
      <h1 style="margin:0;">{project.name}</h1>
      {#if iManage}<span class="badge">{$t('You manage this')}</span>{/if}
    </div>
    <div class="row muted" style="font-size:.85rem;">
      <span>{$t(project.project_type?.name ?? '—')}</span>
      {#if editingVenue}
        <span class="row" style="gap:.4rem;">
          <span>{$t('Target:')}</span>
          <select bind:value={vSel}>
            <option value="">{$t('— none —')}</option>
            {#each venueOpts as v}<option value={v.id}>{v.name}{v.deadline ? ` · DDL ${fmtDay(v.deadline)}` : ''}</option>{/each}
          </select>
          <button onclick={changeVenue} disabled={savingVenue}>{savingVenue ? $t('Saving…') : $t('Save')}</button>
          <button class="ghost" onclick={() => (editingVenue = false)} disabled={savingVenue}>{$t('Cancel')}</button>
        </span>
      {:else}
        {#if project.venue}
          <span>{$t('Target:')}
            {#if project.venue.url}<a href={project.venue.url} target="_blank" rel="noopener">{project.venue.name}</a>{:else}{project.venue.name}{/if}
            <span class="badge dim" style="text-transform:capitalize;">{project.venue.kind}</span>
          </span>
          {#if project.venue.deadline}<span class="mono {ddlClass(project.venue.deadline)}">DDL {fmtDay(project.venue.deadline)}</span>{/if}
        {:else if project.target_venue}<span>{$t('Target:')} {project.target_venue}</span>
        {:else}<span>{$t('No target venue')}</span>{/if}
        {#if iManage}<button class="ghost" style="padding:.15rem .5rem; font-size:.78rem;" onclick={openVenueEdit}>{$t('Change')}</button>{/if}
      {/if}
    </div>
    {#if project.summary}<p>{project.summary}</p>{/if}

    <!-- STATUS PIPELINE -->
    <div class="card">
      <div class="row" style="justify-content:space-between; align-items:center; gap:1rem;">
        <div class="row" style="gap:.5rem; flex-wrap:wrap;">
          {#each pipeline as s, i}
            <span class="status {statusClass(s.name)}" style="opacity:{project.status_id === s.id ? 1 : (i <= curIdx && !isHold ? .85 : .4)};">
              <span class="sdot" style="background:currentColor;"></span>{$t(s.name)}
            </span>
            {#if i < pipeline.length - 1}<span class="muted" style="opacity:.5;">→</span>{/if}
          {/each}
          {#if isHold}<span class="status st-hold" style="margin-left:.4rem;"><span class="sdot" style="background:currentColor;"></span>{$t('On hold')}</span>{/if}
        </div>
        {#if iManage}
          <div class="row" style="gap:.4rem;">
            {#if isHold}
              <button onclick={() => transitionStatus(resumeStatus?.id, resumeStatus?.name ?? '')} disabled={transitioning}>
                {$t('Resume →')} {$t(resumeStatus?.name ?? 'Proposal')}</button>
            {:else}
              {#if prevStatus}<button class="ghost" onclick={() => transitionStatus(prevStatus?.id, prevStatus?.name ?? '')} disabled={transitioning}>← {$t(prevStatus.name)}</button>{/if}
              {#if nextStatus}<button onclick={() => transitionStatus(nextStatus?.id, nextStatus?.name ?? '')} disabled={transitioning}>{$t(nextStatus.name)} →</button>{/if}
              {#if holdStatus && project.project_status?.name !== 'Finished'}<button class="ghost" onclick={() => transitionStatus(holdStatus?.id, 'Hold')} disabled={transitioning}>{$t('Hold')}</button>{/if}
            {/if}
          </div>
        {/if}
      </div>
    </div>

    <div class="card stack" style="gap:.7rem;">
      <div class="row" style="justify-content:space-between; align-items:flex-start; flex-wrap:wrap; gap:1rem;">
        <div>
          <span class="muted" style="font-size:.78rem;">{$t('Nominal pool')} <Hint term="nominal" text={$t("The sum of everyone's nominal stake in this project — bonds + minted labor/resources + verified milestone value. Provisional until settlement, when it's split into liquid STR.")} /></span>
          <div><strong class="mono" style="font-size:1.5rem; color:var(--accent);"><CountUp value={nominalPool} /></strong>
            <span class="muted" style="font-size:.8rem;"> {$t('STR (provisional, mints at settlement)')}</span></div>
        </div>
        <div style="text-align:right;">
          <span class="muted" style="font-size:.78rem;">{$t('Mint multiplier')} <Hint term="milestone" text={$t('Verified milestones raise this multiplier (capped ×3). At settlement the nominal pool is multiplied by it before converting to liquid STR.')} /></span>
          <div><strong class="mono" style="font-size:1.5rem; color:{multiplier > 1 ? 'var(--up)' : 'var(--text)'};">×{multiplier.toFixed(3).replace(/0+$/,'').replace(/\.$/,'')}</strong></div>
        </div>
      </div>
      <div class="escrow-meter"><i style="width:{Math.min(100, nominalPool > 0 ? 100 : 0)}%"></i></div>
      <div class="row" style="justify-content:space-between; flex-wrap:wrap; gap:.6rem; font-size:.8rem;">
        <span class="muted">{$t('Real escrow (bonds):')} <strong class="mono" style="color:var(--text);">{escrow.toLocaleString()}</strong> STR</span>
        <span class="muted">{$t('Projected settlement pool:')} <strong class="mono" style="color:var(--accent);">{Math.floor(nominalPool * multiplier).toLocaleString()}</strong> STR</span>
        <span class="muted">{$t('{n} contributor(s) · {s}/join bond', { n: participants.length, s: joinStake })}</span>
      </div>
    </div>

    {#if !hasLeader && $member}
      <div class="stake-cta rise">
        <div class="row" style="justify-content:space-between; align-items:center; gap:.8rem; flex-wrap:wrap;">
          <div>
            <strong>{$t('This project has no leader.')}</strong>
            <div class="muted" style="font-size:.84rem; margin-top:.15rem;">
              {@html $t("Stake <strong class='mono' style='color:var(--accent);'>{n}</strong> STR to take the lead — you'll post needs, accept applicants, and steer the project.", { n: leaderStake })}
            </div>
          </div>
          <div class="stack" style="gap:.2rem; align-items:flex-end;">
            <button class="stake" onclick={claimLeadership} disabled={claiming || leaderStake > myBalance || !leaderReady}>
              {#if claiming}<span class="spin"></span> {$t('Staking…')}{:else}{$t('Claim leadership · {n} STR', { n: leaderStake })}{/if}</button>
            {#if !leaderReady}<span class="neg" style="font-size:.78rem;">{$t('Leader skill requirements not met.')}</span>
            {:else if leaderStake > myBalance}<span class="neg" style="font-size:.78rem;">{$t('Insufficient balance ({n} STR).', { n: myBalance })}</span>{/if}
          </div>
        </div>
        {#if !leaderReady}
          <div class="row" style="flex-wrap:wrap; gap:.4rem; margin-top:.6rem;">
            <span class="muted" style="font-size:.78rem;">{$t('Leading requires:')}</span>
            {#each leaderMissing as r}
              <span class="badge warn" title={$t('You have {have}', { have: r.have ? $t(GUILD_LABEL[r.have]) : $t('none') })}>
                {$t(r.skill_name)} · {$t('needs {lvl}', { lvl: $t(GUILD_LABEL[r.min_level]) })}
              </span>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- MY CONTRIBUTION (rolling monthly labor; declare = mint) -->
    {#if canContribute}
      <div class="card stack">
        <div class="row" style="justify-content:space-between; align-items:baseline;">
          <h2 style="margin:0;">{$t('My contribution')}</h2>
          <span class="muted" style="font-size:.8rem;">{$t('Accrued nominal:')}
            <strong class="mono" style="color:var(--accent);">{Number(memberNominal[$member?.id ?? ''] ?? 0).toLocaleString()}</strong> STR</span>
        </div>
        <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
          {@html $t("Each month set the hours you'll put in. <strong>Declaring mints immediately</strong> into the pool as nominal STR (hours × your skill rate) — adjust up when free, down to 0 when busy.")}
        </p>
        {#if myLabor.length}
          <table>
            <thead><tr><th>{$t('Month')}</th><th>{$t('Skill')}</th><th>{$t('Hours')}</th><th>{$t('Minted (nominal)')}</th></tr></thead>
            <tbody>
              {#each myLabor as l}
                <tr>
                  <td>{fmtMonth(l.ym)}{l.ym === currentMonth() ? $t(' · now') : ''}</td>
                  <td>{l.skill}</td>
                  <td class="mono">{l.hours}h</td>
                  <td class="mono" style="color:var(--accent);">≈ {l.equiv.toLocaleString()}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted">{$t('No labor declared yet on this project.')}</p>
        {/if}
        <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.7rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Skill')}</span>
            <select bind:value={clSkill}><option value="">{$t('— pick —')}</option>{#each leafSkills as s}<option value={s.id}>{s.name}</option>{/each}</select>
          </label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Month')}</span>
            <input type="month" bind:value={clMonth} /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Hours / month')}</span>
            <input type="number" min="0" step="1" bind:value={clHours} style="width:110px;" /></label>
          <button onclick={setLabor} disabled={settingLabor}>{settingLabor ? $t('Minting…') : $t('Set & mint')}</button>
        </div>
      </div>
    {/if}

    <!-- MY RESOURCES (rolling monthly resource quantity; declare = mint) -->
    {#if canContribute}
      <div class="card stack">
        <div class="row" style="justify-content:space-between; align-items:baseline;">
          <h2 style="margin:0;">{$t('My resources')}</h2>
          <span class="muted" style="font-size:.8rem;">{$t('Valued by unit rate')}</span>
        </div>
        <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
          {@html $t("Each month declare how much of a resource you put in — GPU-hours, dollars, API credits. <strong>Declaring mints immediately</strong> into the pool as nominal STR (quantity × the resource's STR-per-unit rate).")}
        </p>
        {#if myResCommits.length}
          <table>
            <thead><tr><th>{$t('Month')}</th><th>{$t('Resource')}</th><th>{$t('Quantity')}</th><th>{$t('Minted (nominal)')}</th></tr></thead>
            <tbody>
              {#each myResCommits as r}
                <tr>
                  <td>{fmtMonth(r.ym)}{r.ym === currentMonth() ? $t(' · now') : ''}</td>
                  <td>{r.resource}</td>
                  <td class="mono">{r.qty} {r.unit}</td>
                  <td class="mono" style="color:var(--accent);">≈ {r.equiv.toLocaleString()}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted">{$t('No resources declared yet on this project.')}</p>
        {/if}
        {#if myResources.length}
          <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.7rem;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Resource')}</span>
              <select bind:value={rcRes}><option value="">{$t('— pick —')}</option>
                {#each myResources as mr}<option value={mr.id}>{mr.name}{mr.scope === 'community' ? $t(' (community)') : ''} · {resRateHint(mr)}</option>{/each}
              </select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Month')}</span>
              <input type="month" bind:value={rcMonth} /></label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{rcSelected ? $t('Quantity ({u}) / month', { u: resUnit(rcSelected) }) : $t('Quantity / month')}</span>
              <input type="number" min="0" step="1" bind:value={rcQty} style="width:130px;" /></label>
            <button onclick={setResource} disabled={settingRes}>{settingRes ? $t('Minting…') : $t('Set & mint')}</button>
            {#if rcSelected && Number(rcQty) > 0}
              <span class="muted" style="font-size:.82rem; padding-bottom:.4rem;">{@html $t('mints <strong style="color:var(--accent);">≈ {n} STR</strong>', { n: rcPreview.toLocaleString() })}</span>
            {/if}
          </div>
        {:else}
          <p class="muted" style="font-size:.8rem;">{@html $t('You have no approved resources yet. Add one under <a href="/">your portfolio</a>, or use a community resource.')}</p>
        {/if}
      </div>
    {/if}

    <!-- LEADER FIRST-AUTHOR WRITING DUTY (20h / month) -->
    {#if iManage}
      <div class="card stack">
        <div class="row" style="justify-content:space-between; align-items:baseline;">
          <h2 style="margin:0;">{$t('First-author writing')}</h2>
          <span class="badge {writingMet ? 'pos' : 'neg'}">
            {writingMet ? $t('On track') : $t('Behind')} · {writingThisMonth}/{writingRequired}h
          </span>
        </div>
        <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
          {@html $t('As leader you owe <strong>{n}h of first-author writing every month</strong>. Declare the hours to mint them into the pool — falling short flags you on the admin compliance board.', { n: writingRequired })}
        </p>
        {#if myWriting.length}
          <table>
            <thead><tr><th>{$t('Month')}</th><th>{$t('Hours')}</th><th>{$t('Required')}</th><th>{$t('Minted (nominal)')}</th></tr></thead>
            <tbody>
              {#each myWriting as w}
                <tr>
                  <td>{fmtMonth(w.ym)}{w.ym === currentMonth() ? $t(' · now') : ''}</td>
                  <td class="mono">{w.hours}h</td>
                  <td class="mono"><span class="badge {w.hours >= writingRequired ? 'pos' : 'neg'}">{writingRequired}h</span></td>
                  <td class="mono" style="color:var(--accent);">≈ {w.equiv.toLocaleString()}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        {:else}
          <p class="muted">{$t('No first-author writing declared yet.')}</p>
        {/if}
        <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.7rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Month')}</span>
            <input type="month" bind:value={writeMonth} /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Hours / month')}</span>
            <input type="number" min="0" step="1" bind:value={writeHours} style="width:110px;" /></label>
          <button onclick={setWriting} disabled={settingWriting}>{settingWriting ? $t('Minting…') : $t('Declare & mint')}</button>
        </div>
      </div>
    {/if}

    <!-- MILESTONES (outcome minting: nominal + multiplier) -->
    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:baseline;">
        <h2 style="margin:0;">{$t('Milestones')}</h2>
        <span class="muted" style="font-size:.8rem;">{$t('Verified bonus:')} <strong class="mono" style="color:var(--up);">+{verifiedBonus.toFixed(3).replace(/0+$/,'').replace(/\.$/,'')}</strong> {$t('to ×mult')}</span>
      </div>
      <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
        {@html $t('Verified outcomes both <strong>add nominal STR</strong> to the pool and <strong>raise the settlement multiplier</strong> (capped ×3). Only verified milestones count.')}
      </p>
      {#if milestones.length === 0}
        <p class="muted">{$t('No milestones claimed yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Milestone')}</th><th>{$t('Nominal')}</th><th>{$t('+Mult')}</th><th>{$t('Status')}</th>{#if canVerifyMs}<th></th>{/if}</tr></thead>
          <tbody>
            {#each milestones as m}
              <tr>
                <td><strong>{m.milestone_catalog?.item ?? m.title ?? '—'}</strong>
                  {#if m.title && m.milestone_catalog}<div class="muted" style="font-size:.78rem;">{m.title}</div>{/if}
                  <div class="muted" style="font-size:.74rem; text-transform:capitalize;">{m.milestone_catalog?.category ?? ''}</div></td>
                <td class="mono">{m.milestone_catalog?.nominal_value ?? 0}</td>
                <td class="mono">+{Number(m.milestone_catalog?.multiplier_bonus ?? 0)}</td>
                <td><span class="badge {m.status === 'verified' ? 'pos' : m.status === 'rejected' ? 'neg' : 'dim'}">{$t(m.status)}</span></td>
                {#if canVerifyMs}
                  <td class="row">
                    {#if m.status === 'claimed' || m.status === 'under_review'}
                      <button class="ghost" onclick={() => verifyMilestone(m.id)}>{$t('Verify')}</button>
                      <button class="danger" onclick={() => rejectMilestone(m.id)}>{$t('Reject')}</button>
                    {/if}
                  </td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
      {#if canContribute}
        <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.7rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Milestone')}</span>
            <select bind:value={msCatalog}><option value="">{$t('— pick —')}</option>
              {#each catalog as c}<option value={c.id}>{c.item} (+{c.nominal_value} / +{c.multiplier_bonus}×)</option>{/each}
            </select>
          </label>
          <label class="stack" style="gap:.2rem; flex:1; min-width:160px;"><span class="muted" style="font-size:.72rem;">{$t('Note / evidence (opt.)')}</span>
            <input bind:value={msTitle} placeholder={$t('link or detail')} /></label>
          <button onclick={claimMilestone} disabled={claimingMs}>{claimingMs ? $t('Claiming…') : $t('Claim milestone')}</button>
        </div>
      {/if}
    </div>

    <div class="row" style="align-items:stretch; gap:1rem;">
      <!-- RECORDS / LINKS -->
      <div class="card stack" style="flex:1; min-width:320px;">
        <h2 style="margin:0;">{$t('Records & links')}</h2>
        <p class="muted" style="font-size:.8rem; margin:0;">{$t('Proposal PDF, Overleaf, OpenReview, repo, datasets — anything with a URL.')}</p>
        {#if links.length === 0}
          <p class="muted">{$t('No records yet.')}</p>
        {:else}
          <div class="stack" style="gap:.5rem;">
            {#each links as l}
              <div class="row" style="justify-content:space-between; align-items:flex-start; border:1px solid var(--border); border-radius:8px; padding:.55rem .7rem;">
                <div style="min-width:0;">
                  <div class="row" style="gap:.4rem;">
                    <span class="badge dim" style="text-transform:capitalize;">{l.kind}</span>
                    <a href={l.url} target="_blank" rel="noopener" style="font-weight:500;">{l.title}</a>
                  </div>
                  <div class="muted" style="font-size:.74rem; margin-top:.15rem;">
                    {linkHost(l.url)}{l.member ? ` · ${l.member.full_name}` : ''}
                  </div>
                  {#if l.notes}<div class="dim" style="font-size:.8rem; margin-top:.2rem;">{l.notes}</div>{/if}
                </div>
                {#if canContribute}<button class="ghost" style="padding:.2rem .5rem;" onclick={() => deleteLink(l.id)} title={$t('Remove')}>✕</button>{/if}
              </div>
            {/each}
          </div>
        {/if}
        {#if canContribute}
          <div class="stack" style="gap:.4rem; border-top:1px dashed var(--border); padding-top:.7rem;">
            <div class="row" style="gap:.4rem;">
              <select bind:value={lKind} style="text-transform:capitalize;">
                {#each LINK_KINDS as k}<option value={k}>{k}</option>{/each}
              </select>
              <input bind:value={lTitle} placeholder={$t('Title')} style="flex:1; min-width:120px;" />
            </div>
            <input bind:value={lUrl} placeholder="https://…" />
            <input bind:value={lNotes} placeholder={$t('Note (optional)')} />
            <div class="row"><button onclick={addLink} disabled={addingLink}>{addingLink ? $t('Adding…') : $t('Add record')}</button></div>
          </div>
        {/if}
      </div>

      <!-- MEETINGS -->
      <div class="card stack" style="flex:1; min-width:320px;">
        <h2 style="margin:0;">{$t('Meetings')}</h2>
        <p class="muted" style="font-size:.8rem; margin:0;">{$t('Scheduled syncs with a join link.')}</p>
        {#if meetings.length === 0}
          <p class="muted">{$t('No meetings scheduled.')}</p>
        {:else}
          <div class="stack" style="gap:.5rem;">
            {#each meetings as m}
              <div class="row" style="justify-content:space-between; align-items:flex-start; border:1px solid var(--border); border-radius:8px; padding:.55rem .7rem;">
                <div style="min-width:0;">
                  <div class="row" style="gap:.4rem;">
                    <strong>{m.title}</strong>
                    {#if isUpcoming(m.scheduled_at)}<span class="badge info">{$t('upcoming')}</span>{:else}<span class="badge dim">{$t('past')}</span>{/if}
                  </div>
                  <div class="muted mono" style="font-size:.76rem; margin-top:.15rem;">{fmt(m.scheduled_at)}</div>
                  {#if m.location}
                    {#if /^https?:\/\//i.test(m.location)}
                      <a href={m.location} target="_blank" rel="noopener" style="font-size:.82rem;">{$t('Join link ↗')}</a>
                    {:else}<span class="dim" style="font-size:.82rem;">{m.location}</span>{/if}
                  {/if}
                  {#if m.agenda}<div class="dim" style="font-size:.8rem; margin-top:.2rem;">{m.agenda}</div>{/if}
                </div>
                {#if canContribute}<button class="ghost" style="padding:.2rem .5rem;" onclick={() => deleteMeeting(m.id)} title={$t('Remove')}>✕</button>{/if}
              </div>
            {/each}
          </div>
        {/if}
        {#if canContribute}
          <div class="stack" style="gap:.4rem; border-top:1px dashed var(--border); padding-top:.7rem;">
            <input bind:value={mTitle} placeholder={$t('Meeting title')} />
            <div class="row" style="gap:.4rem;">
              <label class="stack" style="gap:.15rem; flex:1;"><span class="muted" style="font-size:.7rem;">{$t('Starts')}</span>
                <input type="datetime-local" bind:value={mAt} /></label>
              <label class="stack" style="gap:.15rem; flex:1;"><span class="muted" style="font-size:.7rem;">{$t('Ends (opt.)')}</span>
                <input type="datetime-local" bind:value={mEnds} /></label>
            </div>
            <input bind:value={mLoc} placeholder={$t('Zoom/Meet link or place')} />
            <input bind:value={mAgenda} placeholder={$t('Agenda (optional)')} />
            <div class="row"><button onclick={addMeeting} disabled={addingMeeting}>{addingMeeting ? $t('Adding…') : $t('Schedule meeting')}</button></div>
          </div>
        {/if}
      </div>
    </div>

    <div class="card">
      <h2>{$t('Stake commitments')}</h2>
      {#if commitments.length === 0}
        <p class="muted">{$t('No commitments yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Member')}</th><th>{$t('Type')}</th><th>{$t('Staked (STR)')}</th><th>{$t('Valuation')}</th><th>{$t('Status')}</th>{#if iManage}<th></th>{/if}</tr></thead>
          <tbody>
            {#each commitments as c}
              <tr>
                <td>{c.member?.full_name ?? '—'}</td>
                <td>{c.commitment_type.replace(/_/g, ' ')}{c.skill ? ` · ${c.skill.name}` : ''}{c.hours_committed ? ` · ${c.hours_committed}h` : ''}</td>
                <td>{c.token_amount > 0 ? c.token_amount.toLocaleString() : '—'}</td>
                <td>{c.token_equivalent > 0 ? `≈ ${c.token_equivalent.toLocaleString()}` : '—'}</td>
                <td><span class="badge">{$t(c.status)}</span></td>
                {#if iManage}
                  <td>{#if c.status === 'pledged'}<button class="ghost" onclick={() => verifyCommitment(c.id)}>{$t('Verify')}</button>{/if}</td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="card">
      <h2>{$t('Settlement')}</h2>
      {#if !settlement}
        {#if iManage}
          <p class="muted" style="font-size:.82rem;">
            {@html $t("Draft the split. Weights are <strong>pre-filled from each member's accrued nominal</strong> (bonds + labor + resources) — adjust down anyone who declared but didn't deliver. On approval the pool mints to <strong class='mono' style='color:var(--accent);'>{n}</strong> STR (nominal ×{m}) and splits by these weights. <strong>Both you and a Stater manager must sign</strong> (you submit; they approve).", { n: Math.floor(nominalPool * multiplier).toLocaleString(), m: multiplier.toFixed(3).replace(/0+$/,'').replace(/\.$/,'') })}
          </p>
          <table>
            <thead><tr><th>{$t('Member')}</th><th>{$t('Role')}</th><th>{$t('Payout weight')}</th><th>{$t('Author')}</th></tr></thead>
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
          <label class="stack" style="gap:.2rem; margin-top:.5rem;"><span class="muted" style="font-size:.75rem;">{$t('Meeting notes (optional)')}</span>
            <textarea bind:value={sNotes} rows="2" placeholder={$t('Rationale / meeting decision')}></textarea></label>
          <div class="row"><button onclick={submitSettlement} disabled={submitting}>{submitting ? $t('Submitting…') : $t('Submit settlement')}</button></div>
        {:else}
          <p class="muted">{$t('No settlement submitted yet.')}</p>
        {/if}
      {:else}
        <div class="row" style="justify-content:space-between; align-items:center;">
          <span class="badge">{$t(settlement.status)}</span>
          {#if settlement.review_window_ends_at && settlement.status !== 'paid'}
            <span class="muted" style="font-size:.8rem;">{$t('Review window ends {d}', { d: new Date(settlement.review_window_ends_at).toLocaleString() })}</span>
          {/if}
        </div>
        {#if settlement.meeting_notes}<p style="margin:.5rem 0;">{settlement.meeting_notes}</p>{/if}
        <table>
          <thead><tr><th>{$t('Member')}</th><th>{$t('Role')}</th><th>{$t('Weight')}</th><th>{$t('Author')}</th><th>{$t('Order')}</th></tr></thead>
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
            <button onclick={approveSettlement}>{$t('Approve & pay out')}</button>
            <button class="danger" onclick={rejectSettlement}>{$t('Reject')}</button>
          </div>
        {/if}
      {/if}
    </div>

    <div class="card">
      <h2>{$t('Roster')}</h2>
      <p class="muted" style="font-size:.8rem; margin-top:-.4rem;">{$t("Share % is each member's accrued nominal (bonds + labor + resources) over the member total — milestone nominal is added to everyone at settlement.")}</p>
      {#if participants.length === 0}
        <p class="muted">{$t('No participants yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Name')}</th><th>{$t('Role')}</th><th>{$t('Accrued (nominal)')}</th><th>{$t('Share')}</th></tr></thead>
          <tbody>
            {#each participants as pt}
              {@const nom = Number(memberNominal[pt.member_id] ?? 0)}
              <tr>
                <td><a href={`/members/${pt.member_id}`}>{pt.member?.full_name ?? '—'}</a></td>
                <td>{pt.project_role?.name ?? '—'}</td>
                <td class="mono" style="color:var(--accent);">{nom.toLocaleString()}</td>
                <td class="mono">{totalNominal > 0 ? (100 * nom / totalNominal).toFixed(1) : '0.0'}%</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="card">
      <h2>{$t('Open needs')}</h2>
      {#if needs.length === 0}
        <p class="muted">{$t('No open needs.')}</p>
      {:else}
        <div class="stack">
          {#each needs as n}
            <div style="border:1px solid var(--border); border-radius:8px; padding:.75rem;">
              <div class="row" style="justify-content:space-between; align-items:flex-start;">
                <span class="row" style="gap:.4rem; align-items:baseline;">
                  <strong>{$t(n.project_role?.name ?? 'Contributor')}</strong>
                  {#if n.contribution_kind === 'labor'}<span class="badge info">{$t('⚒ Labor')}{n.hours_per_month ? $t(' · {n} hrs/mo', { n: n.hours_per_month }) : ''}</span>
                  {:else if n.contribution_kind === 'resource'}<span class="badge info">{$t('⛁ Resource')}</span>{/if}
                </span>
                <span class="row" style="gap:.4rem;">
                  <span class="badge {n.status === 'open' ? 'info' : 'dim'}" style="text-transform:capitalize;">{$t(n.status)}</span>
                  <span class="muted" style="font-size:.8rem;">{$t('{n} opening(s)', { n: n.headcount })}</span>
                  {#if iManage && n.status === 'open'}
                    <button class="ghost" style="padding:.15rem .5rem; font-size:.76rem;" onclick={() => closeNeed(n.id)}>{$t('Close')}</button>
                  {/if}
                </span>
              </div>
              {#if n.skill}
                <div class="row" style="gap:.4rem; align-items:center; font-size:.82rem;">
                  <span class="muted">{$t('Skill:')} {$t(n.skill.name)}{n.min_guild_level ? ` · ${$t('needs {lvl}', { lvl: $t(GUILD_LABEL[n.min_guild_level]) })}` : ''}</span>
                  {#if n.min_guild_level && $member && !iManage && !iParticipate}
                    {#if qualifiesFor(n)}<span class="badge pos">{$t('You qualify')}</span>
                    {:else}<span class="badge warn" title={$t('You have {have}', { have: myCertified[n.skill_id ?? ''] ? $t(GUILD_LABEL[myCertified[n.skill_id ?? '']]) : $t('none') })}>{$t('Below required level')}</span>{/if}
                  {/if}
                </div>
              {/if}
              <div class="muted" style="font-size:.78rem;">{@html $t('Joining stakes <strong class="mono">{n}</strong> STR into escrow.', { n: joinStake })}</div>
              {#if n.description}<p style="margin:.4rem 0;">{n.description}</p>{/if}

              {#if !iManage}
                {#if iParticipate}
                  <span class="badge pos">{$t("You're on this project")}</span>
                {:else if myApps[n.id]?.status === 'joined'}
                  <span class="badge pos">{$t('Joined')}</span>
                {:else if myApps[n.id]?.status === 'accepted'}
                  <div class="stake-cta" style="padding:.6rem .8rem;">
                    <div class="row" style="justify-content:space-between; align-items:center; gap:.6rem;">
                      <span style="font-size:.85rem;">{@html $t("You've been <strong>accepted</strong>. Stake <strong class='mono' style='color:var(--accent);'>{n}</strong> STR to take your seat.", { n: joinStake })}</span>
                      <button class="stake" onclick={() => confirmJoin(n.id)} disabled={confirming === n.id}>
                        {#if confirming === n.id}<span class="spin"></span> {$t('Joining…')}{:else}{$t('Confirm join · {n} STR', { n: joinStake })}{/if}</button>
                    </div>
                  </div>
                {:else if myApps[n.id]?.status === 'declined'}
                  <span class="badge neg">{$t('Application declined')}</span>
                {:else if myApps[n.id]?.status === 'pending'}
                  <span class="badge dim">{$t('Applied · pending review')}</span>
                {:else if n.status === 'open'}
                  <div class="row" style="gap:.5rem;">
                    <input bind:value={applyMsg[n.id]} placeholder={$t('Short pitch (optional)')} style="flex:1;" />
                    <button onclick={() => apply(n.id)}>{$t('I can help')}</button>
                  </div>
                {:else}
                  <span class="muted" style="font-size:.82rem;">{$t('This need is {s}.', { s: $t(n.status) })}</span>
                {/if}
              {:else}
                <!-- manager: review applications -->
                {#if appsFor(n.id).length === 0}
                  <p class="muted" style="font-size:.82rem;">{$t('No applications yet.')}</p>
                {:else}
                  <table>
                    <thead><tr><th>{$t('Applicant')}</th><th>{$t('Pitch')}</th><th>{$t('Status')}</th><th></th></tr></thead>
                    <tbody>
                      {#each appsFor(n.id) as a}
                        <tr>
                          <td>{a.member?.full_name ?? '—'}</td>
                          <td class="dim" style="font-size:.82rem;">{a.message ?? '—'}</td>
                          <td>
                            <span class="badge {a.status === 'joined' ? 'pos' : a.status === 'accepted' ? 'info' : a.status === 'declined' ? 'neg' : 'dim'}">
                              {a.status === 'accepted' ? $t('accepted · awaiting confirm') : $t(a.status)}
                            </span>
                          </td>
                          <td class="row">
                            {#if a.status === 'pending'}
                              <button class="ghost" onclick={() => accept(a, n.project_role_id)}>{$t('Accept')}</button>
                              <button class="danger" onclick={() => decline(a.id)}>{$t('Decline')}</button>
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
          <h3 style="margin:0 0 .5rem;">{$t('Post a need')}</h3>
          <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Kind')}</span>
              <select bind:value={nKind}><option value="seat">{$t('Seat')}</option><option value="labor">{$t('Labor (hrs/mo)')}</option><option value="resource">{$t('Resource')}</option></select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Role')}</span>
              <select bind:value={nRole}><option value="">—</option>{#each roles as r}<option value={r.id}>{r.name}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Skill (opt.)')}</span>
              <select bind:value={nSkill}><option value="">—</option>{#each skills as s}<option value={s.id}>{s.name}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Min guild level')}</span>
              <select bind:value={nLevel} disabled={!nSkill}>
                <option value="">{$t('— any —')}</option>
                {#each GUILD_LADDER as g}<option value={g}>{$t(GUILD_LABEL[g])}</option>{/each}
              </select>
            </label>
            {#if nKind === 'labor'}
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Hrs / mo')}</span>
                <input type="number" min="1" bind:value={nHours} style="width:80px;" />
              </label>
            {/if}
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Count')}</span>
              <input type="number" min="1" bind:value={nCount} style="width:70px;" />
            </label>
            <button onclick={postNeed}>{$t('Post')}</button>
          </div>
          <input placeholder={$t('Description (optional)')} bind:value={nDesc} style="margin-top:.5rem; width:100%;" />
        </div>
      {/if}
    </div>

    <div class="card">
      <h2>{$t('Resource needs')}</h2>
      {#if resRequests.length === 0}
        <p class="muted">{$t('No resource requests.')}</p>
      {:else}
        <div class="stack">
          {#each resRequests as rr}
            <div style="border:1px solid var(--border); border-radius:8px; padding:.75rem;">
              <div class="row" style="justify-content:space-between;">
                <strong>{rr.resource_type?.name ?? $t('Resource')}</strong>
                <span class="muted" style="font-size:.8rem;">{$t(rr.status)}{rr.quantity ? ` · ${rr.quantity}` : ''}</span>
              </div>
              {#if rr.description}<p style="margin:.4rem 0;">{rr.description}</p>{/if}

              {#if !iManage}
                {#if offeredRequestIds.has(rr.id)}
                  <span class="badge">{$t('Offered')}</span>
                {:else}
                  <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
                    <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Resource (optional)')}</span>
                      <select bind:value={offerResourceId[rr.id]}>
                        <option value="">{$t('— none / describe below —')}</option>
                        {#each myResources as mr}<option value={mr.id}>{mr.name}{mr.scope === 'community' ? $t(' (community)') : ''}</option>{/each}
                      </select>
                    </label>
                    <input placeholder={$t('Message (optional)')} bind:value={offerMessage[rr.id]} style="flex:1; min-width:160px;" />
                    <button onclick={() => offerResource(rr.id)}>{$t('I can provide')}</button>
                  </div>
                {/if}
              {:else}
                {#if offersFor(rr.id).length === 0}
                  <p class="muted" style="font-size:.82rem;">{$t('No offers yet.')}</p>
                {:else}
                  <table>
                    <thead><tr><th>{$t('From')}</th><th>{$t('Resource')}</th><th>{$t('Message')}</th><th>{$t('Status')}</th><th></th></tr></thead>
                    <tbody>
                      {#each offersFor(rr.id) as o}
                        <tr>
                          <td>{o.member?.full_name ?? '—'}</td>
                          <td>{o.resource?.name ?? '—'}</td>
                          <td>{o.message ?? '—'}</td>
                          <td><span class="badge">{$t(o.status)}</span></td>
                          <td class="row">
                            {#if o.status === 'pending'}
                              <button class="ghost" onclick={() => acceptOffer(o.id)}>{$t('Accept')}</button>
                              <button class="danger" onclick={() => declineOffer(o.id)}>{$t('Decline')}</button>
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
          <h3 style="margin:0 0 .5rem;">{$t('Ask for a resource')}</h3>
          <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type')}</span>
              <select bind:value={rrType}><option value="">—</option>{#each resTypes as rt}<option value={rt.id}>{$t(rt.name)}{rt.unit ? ` · ${rt.unit}` : ''}</option>{/each}</select>
            </label>
            <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{rrUnit ? $t('Quantity ({u})', { u: rrUnit }) : $t('Quantity')}</span>
              <input bind:value={rrQty} placeholder={rrUnit ? $t('e.g. 500 {u}', { u: rrUnit }) : $t('e.g. 500 GPU-hrs')} style="width:140px;" />
            </label>
            <button onclick={postResourceRequest}>{$t('Post')}</button>
          </div>
          {#if rrEstStr != null}
            <p class="muted" style="font-size:.78rem; margin:.4rem 0 0;">
              {@html $t('At the current anchor this is worth <strong style="color:var(--accent);">≈ {n} STR</strong> when contributed.', { n: rrEstStr.toLocaleString() })}
            </p>
          {/if}
          <input placeholder={$t('Description (optional)')} bind:value={rrDesc} style="margin-top:.5rem; width:100%;" />
        </div>
      {/if}
    </div>

    <!-- HISTORY -->
    <div class="card">
      <h2>{$t('History')}</h2>
      {#if canContribute}
        <div class="row" style="gap:.4rem; margin-bottom:.8rem;">
          <input bind:value={noteText} placeholder={$t('Add a note to the timeline…')} style="flex:1;"
            onkeydown={(e) => { if (e.key === 'Enter') postNote(); }} />
          <button onclick={postNote} disabled={!noteText.trim()}>{$t('Note')}</button>
        </div>
      {/if}
      {#if events.length === 0}
        <p class="muted">{$t('No activity yet.')}</p>
      {:else}
        <div class="timeline">
          {#each events as ev}
            <div class="tl-item">
              <span class="tl-dot" title={ev.event_type}>{eventIcon(ev.event_type)}</span>
              <div class="tl-body">
                <span class="tl-text">{ev.summary}</span>
                <span class="tl-meta">{ev.member?.full_name ?? $t('System')} · {fmt(ev.created_at)}</span>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>
