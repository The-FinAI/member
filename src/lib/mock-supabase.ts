// DEV-ONLY mock Supabase client for local UI screenshot review (PUBLIC_MOCK=1).
// Never shipped: supabase.ts only uses this when the env flag is set. It serves
// a tiny seeded world through a loose chainable query-builder + rpc + auth so the
// rebuilt pages render populated. It does NOT test backend logic.
/* eslint-disable @typescript-eslint/no-explicit-any */

const U_CHAP = 'u-chap', U_WG = 'u-wg';
const M_ME = 'm-me', M_LI = 'm-li', M_WANG = 'm-wang', M_ZHAO = 'm-zhao';
const P1 = 'p-ml';
const SK_ANN = 'sk-ann', SK_WRI = 'sk-wri', SK_OCR = 'sk-ocr', DOM = 'sk-dom';
const RT_LABOR = 'rt-labor', RT_GPU = 'rt-gpu';

// capabilities the President position grants — embedded into member_position so
// loadProfile's nested select (position → position_capability → capability_key)
// resolves and the admin's Settings consoles actually appear.
const PRES_CAPS = [
  { capability_key: 'manage_members' }, { capability_key: 'invite_members' },
  { capability_key: 'edit_any_project' }, { capability_key: 'manage_taxonomy' },
  { capability_key: 'manage_guild' }, { capability_key: 'manage_resources' },
  { capability_key: 'manage_stater' }, { capability_key: 'review_skillcard' }
];

const seed: Record<string, any[]> = {
  org_unit: [
    { id: U_CHAP, code: 'BJ', name: 'Beijing Chapter', kind: 'chapter', description: 'People in Beijing', rank: 1 },
    { id: U_WG, code: 'MM', name: 'Multilingual & Multimodal', kind: 'working_group', description: 'M&M research', rank: 1 }
  ],
  member: [
    { id: M_ME, full_name: 'Chen Wei', email: 'chen@test', affiliation: 'The Fin AI', kind: 'member', status: 'active', home_unit_id: U_CHAP, auth_user_id: 'mock-uid', monthly_hours: 20, bio: 'Chapter & WG officer.', links: {}, member_position: [{ position: { name: 'President' } }] },
    { id: M_LI, full_name: 'Li Hua', email: 'li@test', affiliation: 'PKU', kind: 'member', status: 'active', home_unit_id: U_CHAP, auth_user_id: 'uid-member', monthly_hours: 10, bio: 'Researcher — no officer role.', links: {}, member_position: [], is_release_reviewer: true },
    { id: M_WANG, full_name: 'Wang Fang', email: 'wang@test', affiliation: 'THU', kind: 'card', status: 'active', home_unit_id: U_CHAP, auth_user_id: null, monthly_hours: 30, member_position: [], is_release_reviewer: true },
    { id: M_ZHAO, full_name: 'Zhao Lei', email: 'zhao@test', affiliation: 'SJTU', kind: 'card', status: 'active', home_unit_id: U_CHAP, auth_user_id: null, monthly_hours: 8, member_position: [] },
    { id: 'm-wg', full_name: 'Wu Jing', email: 'wu@test', affiliation: 'The Fin AI', kind: 'member', status: 'active', home_unit_id: U_WG, auth_user_id: 'uid-wg', monthly_hours: 20, bio: 'Working-group officer.', links: {}, member_position: [] },
    { id: 'm-chap', full_name: 'Chan Min', email: 'chan@test', affiliation: 'The Fin AI', kind: 'member', status: 'active', home_unit_id: U_CHAP, auth_user_id: 'uid-chap', monthly_hours: 20, bio: 'Chapter officer.', links: {}, member_position: [] },
    { id: 'm-admin', full_name: 'Sai Tan', email: 'admin@test', affiliation: 'The Fin AI', kind: 'member', status: 'active', home_unit_id: U_CHAP, auth_user_id: 'uid-admin', monthly_hours: 0, bio: 'Community administrator.', links: {}, member_position: [{ position: { name: 'President' } }] }
  ],
  org_unit_officer: [
    { member_id: M_ME, org_unit_id: U_CHAP, role: 'officer', ended_on: null, org_unit: { id: U_CHAP, code: 'BJ', name: 'Beijing Chapter', kind: 'chapter' } },
    { member_id: M_ME, org_unit_id: U_WG, role: 'officer', ended_on: null, org_unit: { id: U_WG, code: 'MM', name: 'Multilingual & Multimodal', kind: 'working_group' } },
    { member_id: 'm-wg', org_unit_id: U_WG, role: 'officer', ended_on: null, org_unit: { id: U_WG, code: 'MM', name: 'Multilingual & Multimodal', kind: 'working_group' } },
    { member_id: 'm-chap', org_unit_id: U_CHAP, role: 'officer', ended_on: null, org_unit: { id: U_CHAP, code: 'BJ', name: 'Beijing Chapter', kind: 'chapter' } }
  ],
  org_unit_member: [],
  member_position: [
    { member_id: M_ME, position_id: 'pos-pres', position: { name: 'President', position_capability: PRES_CAPS } },
    { member_id: 'm-admin', position_id: 'pos-pres', position: { name: 'President', position_capability: PRES_CAPS } }
  ],
  position: [{ id: 'pos-pres', name: 'President' }],
  position_capability: [
    { position_id: 'pos-pres', capability: 'manage_members' }, { position_id: 'pos-pres', capability: 'edit_any_project' },
    { position_id: 'pos-pres', capability: 'manage_taxonomy' }, { position_id: 'pos-pres', capability: 'manage_stater' },
    { position_id: 'pos-pres', capability: 'manage_resources' }, { position_id: 'pos-pres', capability: 'review_skillcard' }
  ],
  skill: [
    { id: DOM, name: 'Data', parent_id: null },
    { id: SK_ANN, name: 'Annotation', parent_id: DOM },
    { id: SK_WRI, name: 'Writing', parent_id: DOM },
    { id: SK_OCR, name: 'OCR', parent_id: DOM }
  ],
  person_skill: [
    { member_id: M_ME, skill_id: SK_WRI, level: 'lead' },
    { member_id: M_LI, skill_id: SK_ANN, level: 'independent' },
    { member_id: M_WANG, skill_id: SK_ANN, level: 'lead' },
    { member_id: M_ZHAO, skill_id: SK_ANN, level: 'learning' }
  ],
  person_skill_evidence: [
    { member_id: M_LI, skill_id: SK_ANN, tasks: 4, shipped: 2 },
    { member_id: M_WANG, skill_id: SK_ANN, tasks: 7, shipped: 3 }
  ],
  resource_type: [
    { id: RT_LABOR, name: 'Labor', unit: 'hour', rank: 0, valuation_method: 'flat' },
    { id: RT_GPU, name: 'GPU', unit: 'GPU-hours', rank: 1, valuation_method: 'gpu' }
  ],
  resource: [
    { id: 'r-labor-li', holder_member_id: M_LI, type_id: RT_LABOR, scope: 'member', monthly_quota: 10, name: 'My time', approval_status: 'approved', availability: 'available', resource_type: { name: 'Labor', unit: 'hour' } },
    { id: 'r-gpu-li', holder_member_id: M_LI, type_id: RT_GPU, scope: 'member', monthly_quota: 80, name: 'RTX 4090', approval_status: 'approved', availability: 'available', resource_type: { name: 'GPU', unit: 'GPU-hours' } },
    { id: 'r-gpu-wang', holder_member_id: M_WANG, type_id: RT_GPU, scope: 'member', monthly_quota: 200, name: 'A100 ×2', approval_status: 'approved', availability: 'available', resource_type: { name: 'GPU', unit: 'GPU-hours' } },
    { id: 'r-cluster-li', holder_member_id: M_LI, type_id: RT_GPU, scope: 'community', monthly_quota: 500, name: 'PKU shared cluster', approval_status: 'approved', availability: 'available', resource_type: { name: 'GPU', unit: 'GPU-hours' } }
  ],
  project: [
    { id: P1, name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging', tag: 'ml', body: 'XBRL multilingual tagging.', summary: 'XBRL tagging across languages', org_unit_id: U_WG, status_id: 'ps-active', target_venue: 'ACL', deadline: '2026-07-30', proposal_url: 'https://example.com' }
  ],
  project_type: [{ id: 'pt-1', name: 'Dataset', leader_stake: 0 }],
  project_status: [
    { id: 'ps-prop', name: 'Proposal', rank: 1, is_active: true },
    { id: 'ps-active', name: 'Active', rank: 2, is_active: true },
    { id: 'ps-review', name: 'Under review', rank: 3, is_active: true },
    { id: 'ps-hold', name: 'Hold', rank: 4, is_active: false },
    { id: 'ps-fin', name: 'Finished', rank: 5, is_active: false }
  ],
  venue: [{ id: 'v-acl', name: 'ACL', kind: 'conference', deadline: '2026-07-30', rank: 1 }],
  project_slot: [
    { id: 's-lead', project_id: P1, slot_kind: 'leader', skill_id: null, resource_type_id: null, desired_level: null, quota: 20, headcount: 1, status: 'open', skill: null, resource_type: null, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 's-ann', project_id: P1, slot_kind: 'work_labor', skill_id: SK_ANN, resource_type_id: null, desired_level: 'independent', quota: 10, headcount: 2, status: 'open', skill: { name: 'Annotation' }, resource_type: null, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 's-gpu', project_id: P1, slot_kind: 'work_resource', skill_id: null, resource_type_id: RT_GPU, desired_level: null, quota: 100, headcount: 1, status: 'open', skill: null, resource_type: { name: 'GPU', unit: 'GPU-hours' }, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } }
  ],
  work_commitment: [
    { id: 'wc-1', project_id: P1, slot_id: 's-ann', member_id: M_ZHAO, monthly_amount: 5, nominal_str: 50, year_month: '2026-06', resource_id: null, slot: { slot_kind: 'work_labor' }, member: { full_name: 'Zhao Lei' }, resource: { unit: 'h' } },
    { id: 'wc-me', project_id: P1, slot_id: null, member_id: M_ME, monthly_amount: 34, nominal_str: 340, year_month: '2026-06', resource_id: null, slot: { slot_kind: 'work_labor' }, member: { full_name: 'Chen Wei' }, resource: { unit: 'h' } }
  ],
  task: [
    { id: 't-1', project_id: P1, grp: null, name: 'Confirm EN taxonomy', skill_id: SK_ANN, owner_member_id: M_ME, state: 'doing', note: 'US/EU/SG differ', sort: 1, updated_at: '2026-06-06T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-2', project_id: P1, grp: null, name: 'Collect JP filings', skill_id: SK_OCR, owner_member_id: null, state: 'open', note: null, sort: 2, updated_at: '2026-06-05T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-3', project_id: P1, grp: 'XBRL Coverage', name: 'EN', skill_id: null, owner_member_id: M_LI, state: 'confirmed', note: '3 taxonomies', sort: 3, updated_at: '2026-06-04T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-4', project_id: P1, grp: 'XBRL Coverage', name: 'JP', skill_id: null, owner_member_id: null, state: 'checking', note: null, sort: 4, updated_at: '2026-06-03T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } }
  ],
  project_milestone: [],
  stater_balance: [{ owner_member_id: M_ME, account_id: 'acct-me', balance: 120, account_type: 'member' }],
  stater_account: [{ id: 'acct-treasury', account_type: 'treasury' }, { id: 'acct-me', account_type: 'member' }],
  stater_policy: [
    { key: 'str_per_hour', value: 10, description: 'STR accrued per committed hour of labour' },
    { key: 'monthly_allowance', value: 0, description: 'Base STR granted to every active member each month' },
    { key: 'settlement_review_hours', value: 72, description: 'Hours a finished project waits in review before its pool can settle' },
    { key: 'leader_multiplier', value: 1.5, description: 'Weight multiplier applied to the first-author share at settlement' }
  ],
  stater_skill_rate: [
    { skill_id: SK_ANN, rate: 8, skill: { name: 'Annotation' } },
    { skill_id: SK_WRI, rate: 12, skill: { name: 'Writing' } }
  ],
  stater_project_member_nominal: [{ member_id: M_ME, nominal: 340 }],
  stater_ledger: [
    { id: 'l-1', amount: 100, entry_type: 'grant', reason: 'welcome_grant', from_account: null, to_account: 'acct-me', created_at: '2026-06-01T00:00:00Z' },
    { id: 'l-2', amount: 20, entry_type: 'payout', reason: 'settlement payout', from_account: null, to_account: 'acct-me', created_at: '2026-06-05T00:00:00Z' }
  ],
  stater_settlement: [],
  project_event: [
    { id: 'pe-1', project_id: P1, event_type: 'created', summary: 'Project created', actor_member_id: M_ME, member: { full_name: 'Chen Wei' }, created_at: '2026-06-01T09:00:00Z' }
  ],
  notification: [
    { id: 'n-1', recipient_member_id: M_ME, kind: 'assigned', title: 'You were assigned to a project', body: 'ml-Tagging · Writing · 6', link: '/projects/' + P1, read_at: null, created_at: '2026-06-06T00:00:00Z' }
  ],
  forge_request: [],
  badge: [],
  announcement: []
};

const FK: Record<string, [string, string]> = {
  project_id: ['project', 'project'], member_id: ['member', 'member'],
  owner_member_id: ['member', 'member'], skill_id: ['skill', 'skill'],
  resource_type_id: ['resource_type', 'resource_type'], holder_member_id: ['member', 'member'],
  resource_id: ['resource', 'resource'], slot_id: ['project_slot', 'slot'],
  status_id: ['project_status', 'project_status']
};

function resolveEmbeds(rows: any[], table: string) {
  // attach common FK embeds (alias = base of fk col) so `r.project?.name` works
  return rows.map((r) => {
    const o = { ...r };
    for (const col of Object.keys(FK)) {
      if (col in r && r[col] != null && o[FK[col][0]] === undefined) {
        const tgt = seed[FK[col][1] === 'project' ? 'project' : FK[col][1]] ?? [];
        const hit = (seed[targetTable(col)] ?? []).find((x) => x.id === r[col]);
        if (hit) o[aliasFor(col)] = hit;
      }
    }
    return o;
  });
}
function targetTable(col: string) {
  if (col === 'project_id') return 'project';
  if (col === 'skill_id') return 'skill';
  if (col === 'resource_type_id') return 'resource_type';
  if (col === 'resource_id') return 'resource';
  if (col === 'slot_id') return 'project_slot';
  if (col === 'status_id') return 'project_status';
  return 'member'; // member_id, owner_member_id, holder_member_id
}
function aliasFor(col: string) {
  if (col === 'project_id') return 'project';
  if (col === 'skill_id') return 'skill';
  if (col === 'resource_type_id') return 'resource_type';
  if (col === 'resource_id') return 'resource';
  if (col === 'slot_id') return 'slot';
  if (col === 'status_id') return 'project_status';
  return 'member';
}

function builder(table: string) {
  recompute();
  let rows = resolveEmbeds((seed[table] ?? []).slice(), table);
  let headCount = false;
  const api: any = {
    select: (_c?: string, opts?: any) => { if (opts?.head) headCount = true; return api; },
    eq: (c: string, v: any) => { rows = rows.filter((r) => r[c] === v); return api; },
    neq: (c: string, v: any) => { rows = rows.filter((r) => r[c] !== v); return api; },
    in: (c: string, v: any[]) => { rows = rows.filter((r) => v.includes(r[c])); return api; },
    is: (c: string, v: any) => { rows = rows.filter((r) => (r[c] ?? null) === v); return api; },
    gt: (c: string, v: any) => { rows = rows.filter((r) => r[c] > v); return api; },
    lt: (c: string, v: any) => { rows = rows.filter((r) => r[c] < v); return api; },
    ilike: (c: string, v: any) => { const s = String(v).replace(/%/g, '').toLowerCase(); rows = rows.filter((r) => String(r[c] ?? '').toLowerCase().includes(s)); return api; },
    not: (c: string, op: string, v: any) => {
      if (op === 'is') rows = rows.filter((r) => (r[c] ?? null) !== v);
      else if (op === 'eq') rows = rows.filter((r) => r[c] !== v);
      else if (op === 'in') rows = rows.filter((r) => !((Array.isArray(v) ? v : [])).includes(r[c]));
      return api;
    },
    or: () => api, gte: () => api, lte: () => api, order: () => api, limit: () => api,
    maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
    single: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
    then: (res: any) => res(headCount ? { count: rows.length, data: null, error: null } : { data: rows, error: null }),
    // real mutations: actually change the seed so admin/config writes persist
    insert: (payload: any) => {
      const list = Array.isArray(payload) ? payload : [payload];
      const inserted = list.map((p) => { const row = { id: p?.id ?? nid(table.slice(0, 3)), ...p }; (seed[table] ??= []).push(row); return row; });
      persist();
      const result = { data: inserted, error: null };
      const single = { data: inserted[0] ?? null, error: null };
      return {
        select: () => ({ single: () => Promise.resolve(single), maybeSingle: () => Promise.resolve(single), then: (r: any) => r(result) }),
        then: (r: any) => r(result)
      };
    },
    update: (patch: any) => {
      const applyWhere = (pred: (r: any) => boolean) => { let n = 0; for (const r of (seed[table] ?? [])) if (pred(r)) { Object.assign(r, patch); n++; } persist(); return n; };
      const chain = (pred: (r: any) => boolean) => ({
        eq: (c: string, v: any) => chain((r: any) => pred(r) && r[c] === v),
        in: (c: string, v: any[]) => chain((r: any) => pred(r) && v.includes(r[c])),
        select: () => ({ single: () => { applyWhere(pred); return Promise.resolve({ data: (seed[table] ?? []).find(pred) ?? null, error: null }); }, then: (r: any) => { applyWhere(pred); r({ data: null, error: null }); } }),
        then: (r: any) => { applyWhere(pred); r({ data: null, error: null }); }
      });
      return chain(() => true);
    },
    delete: () => {
      const chain = (pred: (r: any) => boolean) => ({
        eq: (c: string, v: any) => chain((r: any) => pred(r) && r[c] === v),
        in: (c: string, v: any[]) => chain((r: any) => pred(r) && v.includes(r[c])),
        then: (r: any) => { seed[table] = (seed[table] ?? []).filter((x: any) => !pred(x)); persist(); r({ data: null, error: null }); }
      });
      return chain(() => true);
    }
  };
  return api;
}

// persist the seed across full reloads so mutations survive (the harness is
// only useful if "add task / assign / add person" actually stick).
const LS = 'mockSeedV2';
try {
  if (typeof localStorage !== 'undefined') {
    const s = localStorage.getItem(LS);
    if (s) { const p = JSON.parse(s); for (const k of Object.keys(p)) (seed as any)[k] = p[k]; }
  }
} catch { /* ignore */ }
function persist() {
  try { if (typeof localStorage !== 'undefined') localStorage.setItem(LS, JSON.stringify(seed)); } catch { /* ignore */ }
}

// append a project History event, attributed to whoever is currently logged in
// (matches how the live RPCs stamp the acting auth user), so the audit trail is
// honest under role-switching.
function logEvent(projectId: string, eventType: string, summary: string) {
  const actor = CURRENT_MEMBER() ?? seed.member.find((m: any) => m.id === M_ME);
  const now = new Date(); // dev mock runs in the browser; real wall-clock is fine here
  seed.project_event.unshift({
    id: nid('pe'), project_id: projectId, event_type: eventType, summary,
    actor_member_id: actor?.id ?? M_ME, member: { full_name: actor?.full_name ?? 'You' },
    created_at: now.toISOString()
  });
}

// LOGIC LAYER: derive the ledger views from base data, so the whole loop is live
// (assign → accruing grows; settle → paid). Called before every read.
function recompute() {
  const nom: Record<string, number> = {};
  for (const w of seed.work_commitment) nom[w.member_id] = (nom[w.member_id] || 0) + (Number(w.nominal_str) || 0);
  seed.stater_project_member_nominal = Object.entries(nom).map(([member_id, nominal]) => ({ member_id, nominal }));
}
const PROJECT_POOL = (pid: string) => seed.work_commitment.filter((w) => w.project_id === pid).reduce((t, w) => t + (Number(w.nominal_str) || 0), 0);

let _idc = 1000;
const nid = (p: string) => `${p}-${++_idc}`;

function rpc(name: string, a: any) {
  // --- writes PERSIST into the seed so CRUD survives within the session ---
  if (name === 'task_add') {
    const row = { id: nid('t'), project_id: a.p_project, grp: a.p_grp ?? null, name: a.p_name,
      skill_id: a.p_skill ?? null, owner_member_id: a.p_owner ?? null, state: a.p_state ?? 'open',
      note: a.p_note ?? null, sort: 99, updated_at: '2026-06-06T12:00:00Z' };
    seed.task.push(row); persist();
    return Promise.resolve({ data: resolveEmbeds([row], 'task')[0], error: null });
  }
  if (name === 'task_update') {
    const t = seed.task.find((x) => x.id === a.p_task);
    if (t) Object.assign(t, a.p_patch, { updated_at: '2026-06-06T12:00:00Z' }); persist();
    return Promise.resolve({ data: t ? resolveEmbeds([t], 'task')[0] : null, error: null });
  }
  if (name === 'task_remove') { seed.task = seed.task.filter((x) => x.id !== a.p_task); return Promise.resolve({ data: null, error: null }); } persist();
  if (name === 'task_reorder') return Promise.resolve({ data: null, error: null });
  if (name === 'project_set_meta') {
    const p = seed.project.find((x) => x.id === a.p_project);
    if (p) Object.assign(p, { emoji: a.p_emoji ?? p.emoji, code: a.p_code ?? p.code, tag: a.p_tag ?? p.tag, body: a.p_body ?? p.body }); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'person_skill_set') {
    const m = a.p_member;
    seed.person_skill = seed.person_skill.filter((x) => !(x.member_id === m && x.skill_id === a.p_skill));
    if (a.p_level) seed.person_skill.push({ member_id: m, skill_id: a.p_skill, level: a.p_level }); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'person_set_capacity') {
    const m = seed.member.find((x) => x.id === a.p_member);
    if (m) m.monthly_hours = a.p_hours; persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'forge_member_card') {
    const id = nid('m');
    seed.member.push({ id, full_name: a.p_full_name, email: a.p_email, affiliation: a.p_affiliation ?? null,
      kind: 'card', status: 'active', home_unit_id: a.p_unit, auth_user_id: null, monthly_hours: null, member_position: [] }); persist();
    return Promise.resolve({ data: id, error: null });
  }
  if (name === 'need_post') {
    const id = nid('s');
    seed.project_slot.push({ id, project_id: a.p_project, slot_kind: a.p_kind, skill_id: a.p_skill ?? null,
      resource_type_id: a.p_resource_type ?? null, desired_level: a.p_level ?? null, quota: a.p_capacity,
      headcount: a.p_headcount ?? 1, status: 'open',
      skill: a.p_skill ? { name: (seed.skill.find((s) => s.id === a.p_skill) || {}).name } : null,
      resource_type: a.p_resource_type ? seed.resource_type.find((r) => r.id === a.p_resource_type) : null,
      project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } }); persist();
    return Promise.resolve({ data: seed.project_slot.find((s) => s.id === id), error: null });
  }
  if (name === 'need_update') {
    const committed = (seed.work_commitment ?? []).filter((w: any) => w.slot_id === a.p_slot).length;
    if (committed > 0) return Promise.resolve({ data: null, error: { message: 'this need already has people on it — release them before changing it' } });
    const s = seed.project_slot.find((x: any) => x.id === a.p_slot);
    if (s) {
      s.slot_kind = a.p_kind;
      s.skill_id = a.p_kind === 'work_labor' ? (a.p_skill ?? null) : null;
      s.desired_level = a.p_kind === 'work_labor' ? (a.p_level ?? null) : null;
      s.resource_type_id = a.p_kind === 'work_resource' ? (a.p_resource_type ?? null) : null;
      s.quota = a.p_capacity; s.headcount = a.p_headcount ?? 1;
      s.skill = s.skill_id ? { name: (seed.skill.find((k: any) => k.id === s.skill_id) || {}).name } : null;
      s.resource_type = s.resource_type_id ? seed.resource_type.find((r: any) => r.id === s.resource_type_id) : null;
    }
    persist(); return Promise.resolve({ data: s, error: null });
  }
  if (name === 'assign') {
    const s = seed.project_slot.find((x) => x.id === a.p_slot);
    seed.work_commitment.push({ id: nid('wc'), project_id: s?.project_id, slot_id: a.p_slot, member_id: a.p_member,
      monthly_amount: a.p_hours, nominal_str: Math.round(a.p_hours * 10), year_month: '2026-06', resource_id: null,
      slot: { slot_kind: s?.slot_kind }, member: { full_name: (seed.member.find((m) => m.id === a.p_member) || {}).full_name }, resource: { unit: 'h' } });
    // notify the assignee
    seed.notification.push({ id: nid('n'), recipient_member_id: a.p_member, kind: 'assigned',
      title: 'You were assigned to a project', body: 'ml-Tagging', link: '/projects/p-ml', read_at: null, created_at: '2026-06-06T12:00:00Z' }); persist();
    return Promise.resolve({ data: nid('wc'), error: null });
  }
  if (name === 'unassign') {
    const s = seed.project_slot.find((x) => x.id === a.p_slot);
    seed.work_commitment = seed.work_commitment.filter((w) => !(w.slot_id === a.p_slot && w.member_id === a.p_member));
    if (s) {
      const remaining = new Set(seed.work_commitment.filter((w) => w.slot_id === a.p_slot).map((w) => w.member_id)).size;
      if (remaining < (s.headcount ?? 1) && s.status === 'filled') s.status = 'open';
    }
    persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'member_change_submit') {
    // mock: simulate "the viewer is the member, not an officer" → queue pending,
    // unless acting as admin (uid-admin) → apply directly.
    const asAdmin = (typeof localStorage !== 'undefined' && localStorage.getItem('mockAs') === 'uid-admin');
    if (asAdmin) {
      if (a.p_kind === 'skill') rpc('person_skill_set', { p_skill: a.p_payload.skill_id, p_level: a.p_payload.level, p_member: a.p_member });
      return Promise.resolve({ data: { applied: true }, error: null });
    }
    (seed.member_change_request ??= []).push({ id: nid('mcr'), member_id: a.p_member, kind: a.p_kind, payload: a.p_payload, status: 'pending', created_at: '2026-06-15T00:00:00Z' });
    persist();
    return Promise.resolve({ data: { applied: false, pending: true }, error: null });
  }
  if (name === 'member_change_decide') {
    const r = (seed.member_change_request ?? []).find((x: any) => x.id === a.p_request);
    if (r) { r.status = a.p_approve ? 'approved' : 'rejected'; persist(); }
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'member_archive') {
    const m = seed.member.find((x: any) => x.id === a.p_member);
    if (m) m.archived_at = (a.p_archived ?? true) ? '2026-06-15T00:00:00Z' : null;
    persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'project_archive') {
    const p = seed.project.find((x: any) => x.id === a.p_project);
    if (p) p.archived_at = (a.p_archived ?? true) ? '2026-06-15T00:00:00Z' : null;
    persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'slot_close') {
    const filled = seed.work_commitment.some((w: any) => w.slot_id === a.p_slot);
    if (filled) return Promise.resolve({ data: null, error: { message: 'this need has people on it — remove them first' } });
    const s = seed.project_slot.find((x: any) => x.id === a.p_slot);
    if (s) s.status = 'cancelled';
    persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'release_recipients') {
    const all = (seed.member ?? []).filter((m: any) => m.email && !m.archived_at);
    const rows = a.p_audience === 'preview' ? all.filter((m: any) => m.is_release_reviewer) : all;
    return Promise.resolve({ data: rows.map((m: any) => ({ member_id: m.id, full_name: m.full_name, email: m.email })), error: null });
  }
  if (name === 'notification_read') { const n = seed.notification.find((x) => x.id === a.p_id); if (n) n.read_at = '2026-06-06T12:00:00Z'; return Promise.resolve({ data: null, error: null }); } persist();
  if (name === 'notification_read_all') { seed.notification.forEach((n) => (n.read_at = '2026-06-06T12:00:00Z')); return Promise.resolve({ data: null, error: null }); } persist();

  if (name === 'match_candidates') {
    // computed from the live seed so capacity DECREMENTS after an assign
    const s = seed.project_slot.find((x) => x.id === a.p_slot);
    const ym = '2026-06';
    const rank: Record<string, number> = { lead: 3, independent: 2, learning: 1 };
    const committedHours = (mid: string) => seed.work_commitment
      .filter((w) => w.member_id === mid && w.year_month === ym && ['work_labor', 'leader'].includes(w.slot?.slot_kind))
      .reduce((t, w) => t + (Number(w.monthly_amount) || 0), 0);
    const freeOf = (m: any) => (m.monthly_hours == null ? null : m.monthly_hours - committedHours(m.id));
    if (s?.slot_kind === 'work_resource') {
      const rows = seed.resource.filter((r) => r.type_id === s.resource_type_id && r.scope === 'member').map((r) => {
        const used = seed.work_commitment.filter((w) => w.resource_id === r.id && w.year_month === ym).reduce((t, w) => t + (Number(w.monthly_amount) || 0), 0);
        const m = seed.member.find((x) => x.id === r.holder_member_id);
        return { member_id: r.holder_member_id, full_name: m?.full_name, level: null, tasks: 0, shipped: 0,
          free: (r.monthly_quota ?? 0) - used, unit: (seed.resource_type.find((t) => t.id === r.type_id) || {}).unit || 'units',
          resource_id: r.id, fits: true, reason: 'holds' };
      }).filter((c) => c.free > 0);
      return Promise.resolve({ data: rows, error: null });
    }
    const dl = rank[s?.desired_level] || 0;
    const rows = seed.member
      .filter((m) => (s?.skill_id ? seed.person_skill.some((ps) => ps.member_id === m.id && ps.skill_id === s.skill_id) : true))
      .map((m) => {
        const ps = seed.person_skill.find((p) => p.member_id === m.id && p.skill_id === s?.skill_id);
        const ev = seed.person_skill_evidence.find((e) => e.member_id === m.id && e.skill_id === s?.skill_id) || { tasks: 0, shipped: 0 };
        const lvl = ps?.level ?? null;
        const fits = !s?.skill_id || (rank[lvl as string] || 0) >= dl;
        return { member_id: m.id, full_name: m.full_name, level: lvl, tasks: ev.tasks, shipped: ev.shipped,
          free: freeOf(m), unit: 'h', resource_id: null, fits, reason: fits ? 'ok' : ('below ' + (s?.desired_level ?? 'any')) };
      })
      .filter((c) => c.free == null || c.free > 0)
      .sort((x, y) => (Number(y.fits) - Number(x.fits)) || ((rank[y.level as string] || 0) - (rank[x.level as string] || 0)) || (y.shipped - x.shipped));
    return Promise.resolve({ data: rows, error: null });
  }
  // --- LOGIC LAYER ---
  if (name === 'skill_raise_suggestions') {
    const out: any[] = [];
    for (const e of seed.person_skill_evidence.filter((x) => x.member_id === a.p_member)) {
      const ps = seed.person_skill.find((p) => p.member_id === a.p_member && p.skill_id === e.skill_id);
      const lvl = ps?.level ?? 'learning';
      let suggest: string | null = null;
      if (e.shipped >= 2 && lvl === 'independent') suggest = 'lead';
      else if (e.tasks >= 3 && lvl === 'learning') suggest = 'independent';
      if (suggest) out.push({ skill_id: e.skill_id, skill_name: (seed.skill.find((s) => s.id === e.skill_id) || {}).name, current_level: lvl, suggested_level: suggest, tasks: e.tasks, shipped: e.shipped });
    }
    return Promise.resolve({ data: out, error: null });
  }
  if (name === 'project_set_status') {
    const p = seed.project.find((x) => x.id === a.p_project); if (p) p.status_id = a.p_status;
    const sn = (seed.project_status.find((s) => s.id === a.p_status) || {}).name ?? '—';
    logEvent(a.p_project, 'status', 'Status → ' + sn); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'forge_project_done') {
    const p = seed.project.find((x) => x.id === a.p_project);
    if (p) p.status_id = 'ps-fin';
    logEvent(a.p_project, 'finished', 'Project finished — ready to settle'); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'forge_milestone') {
    seed.project_milestone.push({ id: nid('ms'), project_id: a.p_project, status: 'verified', nominal_value: 100, multiplier_bonus: 0.2 });
    persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'submit_settlement' || name === 'approve_settlement') {
    const pid = a.p ?? a.project_id ?? (a.settlement_id ? P1 : P1);
    const pool = PROJECT_POOL(pid);
    const items = a.items ?? [];
    const totalW = items.filter((i: any) => i.is_author).reduce((t: number, i: any) => t + (Number(i.final_payout_weight) || 0), 0) || 1;
    for (const it of items) {
      if (!it.is_author) continue;
      const share = (Number(it.final_payout_weight) || 0) / totalW;
      const paid = Math.round(share * pool);
      let bal = seed.stater_balance.find((b) => b.owner_member_id === it.member_id);
      if (!bal) { bal = { owner_member_id: it.member_id, account_id: 'acct-' + it.member_id, balance: 0 }; seed.stater_balance.push(bal); }
      bal.balance += paid;
      seed.stater_ledger.push({ id: nid('l'), amount: paid, entry_type: 'payout', reason: 'settlement payout', from_account: null, to_account: bal.account_id, created_at: '2026-06-06T12:00:00Z' });
    }
    // settled: zero the project's accruing + mark project finished
    seed.work_commitment = seed.work_commitment.map((w) => w.project_id === pid ? { ...w, nominal_str: 0 } : w);
    const p = seed.project.find((x) => x.id === pid); if (p) p.status_id = 'ps-fin';
    seed.stater_settlement.push({ project_id: pid, status: 'approved', created_at: '2026-06-06T12:00:00Z' });
    logEvent(pid, 'settled', 'Pool of ' + pool + ' STR settled and paid out to contributors'); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'release_claim') return Promise.resolve({ data: null, error: null });
  if (name === 'member_free_hours') {
    const m = seed.member.find((x: any) => x.id === a.p_member);
    const total = m?.monthly_hours ?? null; if (total == null) return Promise.resolve({ data: null, error: null });
    const used = (seed.work_commitment ?? []).filter((w: any) => w.member_id === a.p_member && (w.slot?.slot_kind === 'work_labor' || w.slot?.slot_kind === 'leader')).reduce((s: number, w: any) => s + (Number(w.monthly_amount) || 0), 0);
    return Promise.resolve({ data: total - used, error: null });
  }
  if (name === 'member_capacity_all') {
    const rows = (seed.member ?? []).map((m: any) => {
      const total = m.monthly_hours ?? null;
      let free = null;
      if (total != null) {
        const used = (seed.work_commitment ?? []).filter((w: any) => w.member_id === m.id && (w.slot?.slot_kind === 'work_labor' || w.slot?.slot_kind === 'leader')).reduce((s: number, w: any) => s + (Number(w.monthly_amount) || 0), 0);
        free = total - used;
      }
      return { member_id: m.id, total, free };
    });
    return Promise.resolve({ data: rows, error: null });
  }
  // ── offerable resources on a person/community card ──
  if (name === 'forge_resource') {
    const rt = (seed.resource_type ?? []).find((t: any) => t.id === a.p_type);
    (seed.resource ??= []).unshift({
      id: nid('r'), holder_member_id: a.p_holder, type_id: a.p_type, scope: a.p_scope ?? 'member',
      monthly_quota: a.p_monthly_quota ?? null, unit: rt?.unit ?? null, name: a.p_name,
      approval_status: 'pending', availability: 'available',
      usd_per_unit: a.p_usd_per_unit ?? null, details: a.p_details ?? null,
      resource_type: rt ? { name: rt.name, unit: rt.unit } : null
    });
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'update_resource') {
    const r = (seed.resource ?? []).find((x: any) => x.id === a.p_resource);
    if (r) { r.name = a.p_name ?? r.name; r.monthly_quota = a.p_monthly_quota ?? r.monthly_quota; r.usd_per_unit = a.p_usd_per_unit ?? r.usd_per_unit; r.details = a.p_details ?? r.details; r.approval_status = 'pending'; }
    persist(); return Promise.resolve({ data: null, error: null });
  }
  // ── project living record: links · notes · meetings ──
  if (name === 'project_link_add') {
    const actor = seed.member.find((m: any) => m.id === (CURRENT_MEMBER()?.id));
    (seed.project_link ??= []).unshift({ id: nid('lk'), project_id: a.p_project, kind: a.p_kind, title: a.p_title ?? null, url: a.p_url, notes: a.p_notes ?? null, added_by: actor?.id ?? M_ME, member: { full_name: actor?.full_name ?? 'You' }, created_at: new Date(2026, 5, 6, 12, (seed.project_link ?? []).length).toISOString() });
    logEvent(a.p_project, 'link', 'Added a ' + a.p_kind + ' link'); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'project_link_remove') {
    seed.project_link = (seed.project_link ?? []).filter((l: any) => l.id !== a.p_link); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'project_note') {
    logEvent(a.p_project, 'note', a.p_text); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'project_meeting_add') {
    const actor = CURRENT_MEMBER();
    (seed.project_meeting ??= []).unshift({ id: nid('mt'), project_id: a.p_project, title: a.p_title, scheduled_at: a.p_scheduled_at, ends_at: a.p_ends_at ?? null, location: a.p_location ?? null, agenda: a.p_agenda ?? null, recurrence: a.p_recurrence ?? 'none', created_by: actor?.id ?? M_ME, member: { full_name: actor?.full_name ?? 'You' } });
    logEvent(a.p_project, 'meeting', 'Scheduled “' + a.p_title + '”'); persist();
    return Promise.resolve({ data: null, error: null });
  }
  if (name === 'project_meeting_remove') {
    seed.project_meeting = (seed.project_meeting ?? []).filter((m: any) => m.id !== a.p_meeting); persist();
    return Promise.resolve({ data: null, error: null });
  }
  // ── admin: officers, member email, STR economy (real mutations) ──
  if (name === 'assign_org_officer') {
    const unit = seed.org_unit.find((u: any) => u.id === a.p_unit);
    (seed.org_unit_officer ??= []).push({ member_id: a.p_member, org_unit_id: a.p_unit, role: a.p_role ?? 'officer', ended_on: null, org_unit: unit ? { id: unit.id, code: unit.code, name: unit.name, kind: unit.kind } : null });
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'remove_org_officer') {
    seed.org_unit_officer = (seed.org_unit_officer ?? []).filter((o: any) => !(o.org_unit_id === a.p_unit && o.member_id === a.p_member && o.role === a.p_role));
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'set_member_email') {
    const m = seed.member.find((x: any) => x.id === a.p_member); if (m) m.email = a.p_email;
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'stater_mint') {
    // mint = create new supply into the treasury
    const amt = Number(a.amt) || 0;
    let tre = seed.stater_balance.find((b: any) => b.account_id === 'acct-treasury');
    if (!tre) { tre = { owner_member_id: 'treasury', account_id: 'acct-treasury', balance: 0, account_type: 'treasury' }; seed.stater_balance.push(tre); }
    tre.balance += amt;
    seed.stater_ledger.unshift({ id: nid('l'), amount: amt, entry_type: 'mint', reason: a.reason ?? 'mint', from_account: null, to_account: 'acct-treasury', created_at: new Date(2026, 5, 6, 12, seed.stater_ledger.length).toISOString() });
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'stater_grant') {
    // grant = TRANSFER from the treasury to a member (no new supply created)
    const amt = Number(a.amt) || 0;
    const tre = seed.stater_balance.find((b: any) => b.account_id === 'acct-treasury');
    if (!tre || tre.balance < amt) return Promise.resolve({ data: null, error: { message: 'Treasury has insufficient STR — mint into the treasury first.' } });
    const acct = 'acct-' + a.target;
    let bal = seed.stater_balance.find((b: any) => b.account_id === acct);
    if (!bal) { bal = { owner_member_id: a.target, account_id: acct, balance: 0, account_type: 'member' }; seed.stater_balance.push(bal); }
    tre.balance -= amt; bal.balance += amt;
    seed.stater_ledger.unshift({ id: nid('l'), amount: amt, entry_type: 'grant', reason: a.reason ?? 'grant', from_account: 'acct-treasury', to_account: acct, created_at: new Date(2026, 5, 6, 12, seed.stater_ledger.length).toISOString() });
    persist(); return Promise.resolve({ data: null, error: null });
  }
  if (name === 'issue_monthly_allowance') {
    return Promise.resolve({ data: { granted: 0 }, error: null });
  }
  if (name === 'can_edit_project') {
    const me = CURRENT_MEMBER();
    const proj = seed.project.find((p: any) => p.id === a.p_project);
    return Promise.resolve({ data: !!me && (isPresident(me) || isOfficerOf(me, proj?.org_unit_id)), error: null });
  }
  if (name === 'manages_card') {
    const me = CURRENT_MEMBER();
    return Promise.resolve({ data: !!me && (isPresident(me) || isChapterOfficer(me)), error: null });
  }
  return Promise.resolve({ data: null, error: null });
}

// ── identity (switchable for role testing): localStorage 'mockAs' holds the
// auth uid of the logged-in persona. Default = Chen Wei (President, both hats).
function currentUid(): string {
  try { return (typeof localStorage !== 'undefined' && localStorage.getItem('mockAs')) || 'mock-uid'; }
  catch { return 'mock-uid'; }
}
function CURRENT_MEMBER(): any { return seed.member.find((m: any) => m.auth_user_id === currentUid()); }
function isPresident(me: any): boolean {
  return (seed.member_position || []).some((mp: any) => mp.member_id === me.id && mp.position_id === 'pos-pres');
}
function isOfficerOf(me: any, unitId: string | undefined): boolean {
  return !!unitId && (seed.org_unit_officer || []).some((o: any) => o.member_id === me.id && o.org_unit_id === unitId && !o.ended_on);
}
function isChapterOfficer(me: any): boolean {
  return (seed.org_unit_officer || []).some((o: any) => o.member_id === me.id && !o.ended_on && o.org_unit?.kind === 'chapter');
}

const _u = currentUid();
const _m = (seed.member || []).find((m: any) => m.auth_user_id === _u);
const fakeSession = { user: { id: _u, email: _m?.email ?? 'chen@test' } };

export const mockSupabase: any = {
  from: builder,
  rpc,
  functions: {
    // mock edge functions (e.g. invite-member): record an invited member so the
    // admin's invite flow visibly works end-to-end.
    invoke: (name: string, opts?: any) => {
      if (name === 'invite-member') {
        const b = opts?.body ?? {};
        const id = nid('m');
        (seed.member ??= []).push({ id, full_name: b.full_name ?? b.email ?? 'Invited', email: b.email ?? '', affiliation: b.affiliation ?? null, kind: b.kind ?? 'operator', status: 'invited', home_unit_id: b.unit_id ?? null, auth_user_id: null, monthly_hours: null, member_position: [] });
        persist();
        return Promise.resolve({ data: { id }, error: null });
      }
      if (name === 'announce-release') {
        const b = opts?.body ?? {};
        const all = (seed.member ?? []).filter((m: any) => m.email && !m.archived_at);
        const ids = Array.isArray(b.recipient_ids) ? new Set(b.recipient_ids) : null;
        const rows = ids ? all.filter((m: any) => ids.has(m.id)) : all;
        const stage = ids ? 'preview' : 'all';
        return Promise.resolve({ data: { sent: rows.length, total: rows.length, audience: stage, results: rows.map((m: any) => ({ email: m.email, ok: true })) }, error: null });
      }
      return Promise.resolve({ data: null, error: null });
    }
  },
  auth: {
    onAuthStateChange: (cb: any) => { setTimeout(() => cb('INITIAL_SESSION', fakeSession), 0); return { data: { subscription: { unsubscribe() {} } } }; },
    getSession: () => Promise.resolve({ data: { session: fakeSession }, error: null }),
    signInWithOtp: () => Promise.resolve({ data: {}, error: null }),
    verifyOtp: () => Promise.resolve({ data: { session: fakeSession }, error: null }),
    signOut: () => Promise.resolve({ error: null })
  }
};
