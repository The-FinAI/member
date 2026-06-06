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

const seed: Record<string, any[]> = {
  org_unit: [
    { id: U_CHAP, code: 'BJ', name: 'Beijing Chapter', kind: 'chapter', description: 'People in Beijing', rank: 1 },
    { id: U_WG, code: 'MM', name: 'Multilingual & Multimodal', kind: 'working_group', description: 'M&M research', rank: 1 }
  ],
  member: [
    { id: M_ME, full_name: 'Chen Wei', email: 'chen@test', affiliation: 'The Fin AI', kind: 'member', status: 'active', home_unit_id: U_CHAP, auth_user_id: 'mock-uid', monthly_hours: 20, bio: 'Chapter & WG officer.', links: {}, member_position: [{ position: { name: 'President' } }] },
    { id: M_LI, full_name: 'Li Hua', email: 'li@test', affiliation: 'PKU', kind: 'card', status: 'active', home_unit_id: U_CHAP, auth_user_id: null, monthly_hours: 10, member_position: [] },
    { id: M_WANG, full_name: 'Wang Fang', email: 'wang@test', affiliation: 'THU', kind: 'card', status: 'active', home_unit_id: U_CHAP, auth_user_id: null, monthly_hours: 30, member_position: [] },
    { id: M_ZHAO, full_name: 'Zhao Lei', email: 'zhao@test', affiliation: 'SJTU', kind: 'card', status: 'active', home_unit_id: U_CHAP, auth_user_id: null, monthly_hours: 8, member_position: [] }
  ],
  org_unit_officer: [
    { member_id: M_ME, org_unit_id: U_CHAP, ended_on: null, org_unit: { id: U_CHAP, name: 'Beijing Chapter', kind: 'chapter' } },
    { member_id: M_ME, org_unit_id: U_WG, ended_on: null, org_unit: { id: U_WG, name: 'Multilingual & Multimodal', kind: 'working_group' } }
  ],
  org_unit_member: [],
  member_position: [{ member_id: M_ME, position_id: 'pos-pres' }],
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
    { id: 'r-labor-li', holder_member_id: M_LI, type_id: RT_LABOR, scope: 'member', monthly_quota: 10, name: 'My time' },
    { id: 'r-gpu-wang', holder_member_id: M_WANG, type_id: RT_GPU, scope: 'member', monthly_quota: 200, name: 'A100 ×2' }
  ],
  project: [
    { id: P1, name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging', tag: 'ml', body: 'XBRL multilingual tagging.', summary: 'XBRL tagging across languages', org_unit_id: U_WG, status_id: 'ps-active', target_venue: 'ACL', deadline: '2026-07-30', proposal_url: 'https://example.com' }
  ],
  project_type: [{ id: 'pt-1', name: 'Dataset', leader_stake: 0 }],
  project_status: [
    { id: 'ps-prop', name: 'Proposal', rank: 1, is_active: true },
    { id: 'ps-active', name: 'Active', rank: 2, is_active: true },
    { id: 'ps-fin', name: 'Finished', rank: 5, is_active: false }
  ],
  venue: [{ id: 'v-acl', name: 'ACL', kind: 'conference', deadline: '2026-07-30', rank: 1 }],
  project_slot: [
    { id: 's-lead', project_id: P1, slot_kind: 'leader', skill_id: null, resource_type_id: null, desired_level: null, quota: 20, headcount: 1, status: 'open', skill: null, resource_type: null, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 's-ann', project_id: P1, slot_kind: 'work_labor', skill_id: SK_ANN, resource_type_id: null, desired_level: 'independent', quota: 10, headcount: 2, status: 'open', skill: { name: 'Annotation' }, resource_type: null, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 's-gpu', project_id: P1, slot_kind: 'work_resource', skill_id: null, resource_type_id: RT_GPU, desired_level: null, quota: 100, headcount: 1, status: 'open', skill: null, resource_type: { name: 'GPU', unit: 'GPU-hours' }, project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } }
  ],
  work_commitment: [
    { id: 'wc-1', project_id: P1, slot_id: 's-ann', member_id: M_ZHAO, monthly_amount: 5, nominal_str: 50, year_month: '2026-06', resource_id: 'r-labor-zhao', slot: { slot_kind: 'work_labor' }, member: { full_name: 'Zhao Lei' }, resource: { unit: 'h' } }
  ],
  task: [
    { id: 't-1', project_id: P1, grp: null, name: 'Confirm EN taxonomy', skill_id: SK_ANN, owner_member_id: M_ME, state: 'doing', note: 'US/EU/SG differ', sort: 1, updated_at: '2026-06-06T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-2', project_id: P1, grp: null, name: 'Collect JP filings', skill_id: SK_OCR, owner_member_id: null, state: 'open', note: null, sort: 2, updated_at: '2026-06-05T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-3', project_id: P1, grp: 'XBRL Coverage', name: 'EN', skill_id: null, owner_member_id: M_LI, state: 'confirmed', note: '3 taxonomies', sort: 3, updated_at: '2026-06-04T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } },
    { id: 't-4', project_id: P1, grp: 'XBRL Coverage', name: 'JP', skill_id: null, owner_member_id: null, state: 'checking', note: null, sort: 4, updated_at: '2026-06-03T00:00:00Z', project: { name: 'ml-Tagging', emoji: '🏷️', code: 'ml-Tagging' } }
  ],
  project_milestone: [],
  stater_balance: [{ owner_member_id: M_ME, account_id: 'acct-me', balance: 120 }],
  stater_project_member_nominal: [{ member_id: M_ME, nominal: 340 }],
  stater_ledger: [
    { id: 'l-1', amount: 100, entry_type: 'grant', reason: 'welcome_grant', from_account: null, to_account: 'acct-me', created_at: '2026-06-01T00:00:00Z' },
    { id: 'l-2', amount: 20, entry_type: 'payout', reason: 'settlement payout', from_account: null, to_account: 'acct-me', created_at: '2026-06-05T00:00:00Z' }
  ],
  stater_settlement: [],
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
  resource_id: ['resource', 'resource'], slot_id: ['project_slot', 'slot']
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
  return 'member'; // member_id, owner_member_id, holder_member_id
}
function aliasFor(col: string) {
  if (col === 'project_id') return 'project';
  if (col === 'skill_id') return 'skill';
  if (col === 'resource_type_id') return 'resource_type';
  if (col === 'resource_id') return 'resource';
  if (col === 'slot_id') return 'slot';
  return 'member';
}

function builder(table: string) {
  let rows = resolveEmbeds((seed[table] ?? []).slice(), table);
  let headCount = false;
  const api: any = {
    select: (_c?: string, opts?: any) => { if (opts?.head) headCount = true; return api; },
    eq: (c: string, v: any) => { rows = rows.filter((r) => r[c] === v); return api; },
    in: (c: string, v: any[]) => { rows = rows.filter((r) => v.includes(r[c])); return api; },
    is: (c: string, v: any) => { rows = rows.filter((r) => (r[c] ?? null) === v); return api; },
    not: () => api, or: () => api, gte: () => api, lte: () => api, order: () => api, limit: () => api,
    maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
    single: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
    then: (res: any) => res(headCount ? { count: rows.length, data: null, error: null } : { data: rows, error: null }),
    insert: () => ({ select: () => ({ single: () => Promise.resolve({ data: rows[0] ?? {}, error: null }) }), then: (r: any) => r({ data: null, error: null }) }),
    update: () => ({ eq: () => ({ then: (r: any) => r({ data: null, error: null }) }), then: (r: any) => r({ data: null, error: null }) }),
    delete: () => ({ eq: () => ({ then: (r: any) => r({ data: null, error: null }) }) })
  };
  return api;
}

function rpc(name: string, _args: any) {
  if (name === 'match_candidates') {
    return Promise.resolve({ data: [
      { member_id: M_WANG, full_name: 'Wang Fang', level: 'lead', tasks: 7, shipped: 3, free: 25, unit: 'h', resource_id: null, fits: true, reason: 'ok' },
      { member_id: M_LI, full_name: 'Li Hua', level: 'independent', tasks: 4, shipped: 2, free: 6, unit: 'h', resource_id: null, fits: true, reason: 'ok' },
      { member_id: M_ZHAO, full_name: 'Zhao Lei', level: 'learning', tasks: 0, shipped: 0, free: 3, unit: 'h', resource_id: null, fits: false, reason: 'below independent' }
    ], error: null });
  }
  if (name === 'skill_raise_suggestions') return Promise.resolve({ data: [], error: null });
  if (name === 'can_edit_project' || name === 'manages_card') return Promise.resolve({ data: true, error: null });
  return Promise.resolve({ data: null, error: null });
}

const fakeSession = { user: { id: 'mock-uid', email: 'chen@test' } };

export const mockSupabase: any = {
  from: builder,
  rpc,
  auth: {
    onAuthStateChange: (cb: any) => { setTimeout(() => cb('INITIAL_SESSION', fakeSession), 0); return { data: { subscription: { unsubscribe() {} } } }; },
    getSession: () => Promise.resolve({ data: { session: fakeSession }, error: null }),
    signInWithOtp: () => Promise.resolve({ data: {}, error: null }),
    verifyOtp: () => Promise.resolve({ data: { session: fakeSession }, error: null }),
    signOut: () => Promise.resolve({ error: null })
  }
};
