<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // Unified Forge approval queue — ONE entry point over forge_request, the
  // over-capacity work_commitment queue, and pending project settlements.
  // Dispatches to review_forge / review_capacity / approve_settlement.
  const canSettle = $derived($capabilities.has('manage_stater') || $capabilities.has('edit_any_project'));
  const canMilestone = $derived($capabilities.has('manage_stater') || $capabilities.has('edit_any_project') || $capabilities.has('manage_resources'));
  type Req = {
    id: string; target_type: string; action: string; target_id: string | null;
    payload: Record<string, any>; batch_id: string | null; fee: number;
    submitted_by: string | null; created_at: string;
  };
  type Cap = {
    id: string; member_id: string; project_id: string; monthly_amount: number;
    nominal_str: number; year_month: string;
    member: { full_name: string } | null; project: { name: string } | null;
    resource: { name: string; monthly_quota: number | null } | null;
  };
  type Settle = {
    id: string; project_id: string; status: string; meeting_notes: string | null;
    submitted_by: string | null; review_window_ends_at: string | null;
    project: { name: string } | null;
    items: { member_id: string; final_payout_weight: number; is_author: boolean; author_order: number | null; is_corresponding: boolean }[];
  };

  type Mstone = {
    id: string; project_id: string; status: string; nominal_value: number; multiplier_bonus: number;
    catalog: { item: string; category: string } | null; project: { name: string } | null;
  };
  let requests = $state<Req[]>([]);
  let resInfo = $state<Record<string, any>>({}); // resource target_id → full row (for review detail)
  let capacity = $state<Cap[]>([]);
  let settlements = $state<Settle[]>([]);
  let milestones = $state<Mstone[]>([]);
  let names = $state<{ members: Record<string, string>; skills: Record<string, string>; projects: Record<string, string>; resTypes: Record<string, string> }>({ members: {}, skills: {}, projects: {}, resTypes: {} });
  let loading = $state(true);
  let busy = $state(''); let msg = $state('');
  let filter = $state<'all' | 'badge' | 'resource' | 'need' | 'project_done' | 'milestone' | 'settlement'>('all');

  const TYPE_LABEL: Record<string, string> = {
    member_card: 'Member card', badge: 'Badge', resource: 'Resource',
    need: 'Need', claim: 'Claim', project_done: 'Completion', milestone: 'Milestone', settlement: 'Settlement'
  };
  const TYPE_CLASS: Record<string, string> = {
    badge: 'info', resource: 'warn', need: 'pos', project_done: 'pos', member_card: 'dim', claim: 'dim'
  };

  const shown = $derived(filter === 'all' ? requests : requests.filter((r) => r.target_type === filter));

  // Requests forged together (a batch of badge raises) share a batch_id and must
  // review as ONE item — otherwise a 10-skill submission shows as 10 approvals.
  type Group = { key: string; ids: string[]; items: Req[]; rep: Req; count: number };
  const shownGroups = $derived.by(() => {
    const groups: Group[] = [];
    const byBatch: Record<string, number> = {};
    for (const r of shown) {
      if (r.batch_id && byBatch[r.batch_id] != null) {
        const g = groups[byBatch[r.batch_id]]; g.ids.push(r.id); g.items.push(r); g.count++;
      } else {
        if (r.batch_id) byBatch[r.batch_id] = groups.length;
        groups.push({ key: r.batch_id ?? r.id, ids: [r.id], items: [r], rep: r, count: 1 });
      }
    }
    return groups;
  });

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; msg = '';
    const [{ data: rq }, { data: cap }, { data: st }, { data: ms }, { data: m }, { data: sk }, { data: pr }, { data: rt }] = await Promise.all([
      supabase.from('forge_request').select('id, target_type, action, target_id, payload, batch_id, fee, submitted_by, created_at').eq('status', 'submitted').order('created_at'),
      supabase.from('work_commitment').select('id, member_id, project_id, monthly_amount, nominal_str, year_month, member:member_id(full_name), project:project_id(name), resource:resource_id(name, monthly_quota)').eq('approval', 'needs_review'),
      supabase.from('stater_settlement').select('id, project_id, status, meeting_notes, submitted_by, review_window_ends_at, project:project_id(name), items:stater_settlement_item(member_id, final_payout_weight, is_author, author_order, is_corresponding)').in('status', ['submitted', 'under_review']).order('review_window_ends_at'),
      supabase.from('project_milestone').select('id, project_id, status, nominal_value, multiplier_bonus, catalog:catalog_id(item, category), project:project_id(name)').in('status', ['claimed', 'under_review']).order('created_at'),
      supabase.from('member').select('id, full_name'),
      supabase.from('skill').select('id, name'),
      supabase.from('project').select('id, name'),
      supabase.from('resource_type').select('id, name')
    ]);
    requests = (rq as Req[]) ?? [];
    // pull the full resource rows behind resource requests so review shows the
    // actual type / quota / skills+levels / description, not just a one-liner.
    const resIds = requests.filter((r) => r.target_type === 'resource' && r.target_id).map((r) => r.target_id as string);
    if (resIds.length) {
      const { data: rr } = await supabase.from('resource').select('id, details, unit, monthly_quota, type_id, skills').in('id', resIds);
      resInfo = Object.fromEntries(((rr as any[]) ?? []).map((x) => [x.id, x]));
    } else resInfo = {};
    capacity = (cap as any[]) ?? [];
    settlements = (st as any[]) ?? [];
    milestones = (ms as any[]) ?? [];
    names = {
      members: Object.fromEntries(((m as any[]) ?? []).map((x) => [x.id, x.full_name])),
      skills: Object.fromEntries(((sk as any[]) ?? []).map((x) => [x.id, x.name])),
      projects: Object.fromEntries(((pr as any[]) ?? []).map((x) => [x.id, x.name])),
      resTypes: Object.fromEntries(((rt as any[]) ?? []).map((x) => [x.id, x.name]))
    };
    loading = false;
  }

  function summary(r: Req): string {
    const p = r.payload ?? {};
    const mem = (id?: string) => (id ? names.members[id] ?? '—' : '—');
    const sk = (id?: string) => (id ? names.skills[id] ?? '—' : '—');
    const pj = (id?: string) => (id ? names.projects[id] ?? '—' : '—');
    const rt = (id?: string) => (id ? names.resTypes[id] ?? '—' : '');
    if (r.target_type === 'badge') return `${mem(p.member_id)} · ${sk(p.skill_id)} → ${get(t)(cap(p.target_level))}`;
    if (r.target_type === 'resource') return `${p.name ?? '—'} · ${mem(p.holder_member_id)} · ${p.monthly_quota ?? '?'}/mo`;
    if (r.target_type === 'need') return `${pj(p.project_id)} · ${p.slot_kind === 'work_resource' ? rt(p.resource_type_id) : sk(p.skill_id)} ×${p.headcount ?? 1}`;
    if (r.target_type === 'project_done') return pj(p.project_id);
    if (r.target_type === 'member_card') return p.full_name ?? mem(r.target_id ?? undefined);
    return pj(p.project_id) || mem(r.target_id ?? undefined);
  }
  function cap(s?: string) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : '—'; }

  const skName = (id?: string) => (id ? names.skills[id] ?? '—' : '—');
  function skillsLine(arr: any[], lvlKey: string): string {
    return (arr ?? []).map((x) => `${skName(x.skill_id)} ${get(t)(cap(x[lvlKey] ?? x.level ?? x.min_level))}`).join(' · ');
  }
  // the specific content of a request, for the reviewer to actually see
  function detailLines(r: Req): string[] {
    const p = r.payload ?? {};
    const out: string[] = [];
    if (r.target_type === 'resource') {
      const info = resInfo[r.target_id ?? ''] ?? {};
      const rt = info.type_id ? names.resTypes[info.type_id] : '';
      out.push(`${rt ? rt + ' · ' : ''}${p.monthly_quota ?? info.monthly_quota ?? '?'} ${info.unit ?? ''}/mo`.trim());
      const sk = (info.skills && info.skills.length ? info.skills : p.skills) ?? [];
      if (sk.length) out.push(get(t)('Skills') + ': ' + skillsLine(sk, 'level'));
      if (info.details) out.push(info.details);
    } else if (r.target_type === 'need') {
      const kind = p.slot_kind === 'work_resource' ? get(t)('Resource need') : p.slot_kind === 'leader' ? get(t)('Leader') : get(t)('Labor need');
      out.push(`${kind}${p.quota ? ' · ' + p.quota : ''} · ×${p.headcount ?? 1}`);
      const reqs = p.requirements ?? [];
      if (reqs.length) out.push(get(t)('Requires') + ': ' + skillsLine(reqs, 'min_level'));
      else if (p.resource_type_id) out.push(get(t)('Resource type') + ': ' + (names.resTypes[p.resource_type_id] ?? '—'));
    }
    return out;
  }

  function groupSummary(g: Group): string {
    if (g.count > 1 && g.rep.target_type === 'badge') {
      const p = g.rep.payload ?? {};
      return `${p.member_id ? names.members[p.member_id] ?? '—' : '—'} · ${g.count} ${get(t)('badges')}`;
    }
    return summary(g.rep);
  }
  async function reviewGroup(g: Group, approve: boolean) {
    busy = g.key;
    for (const id of g.ids) {
      const { error: e } = await supabase.rpc('review_forge', { p_request: id, p_approve: approve, p_note: null });
      if (e) { busy = ''; msg = e.message; await load(); return; }
    }
    busy = '';
    msg = approve ? get(t)('Approved.') : get(t)('Rejected.');
    await load();
  }
  async function reviewCap(c: Cap, approve: boolean) {
    busy = c.id;
    const { error: e } = await supabase.rpc('review_capacity', { p_commitment: c.id, p_approve: approve });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = approve ? get(t)('Capacity approved.') : get(t)('Capacity rejected.');
    await load();
  }
  async function reviewSettlement(s: Settle, approve: boolean) {
    busy = s.id;
    const { error: e } = approve
      ? await supabase.rpc('approve_settlement', { settlement_id: s.id })
      : await supabase.rpc('reject_settlement', { settlement_id: s.id, reason: 'rejected' });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = approve ? get(t)('Settlement approved — STR paid out.') : get(t)('Settlement rejected.');
    await load();
  }
  async function reviewMilestone(m: Mstone, approve: boolean) {
    busy = m.id;
    const { error: e } = await supabase.rpc('verify_milestone', { p_milestone: m.id, p_approve: approve });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = approve ? get(t)('Milestone verified.') : get(t)('Milestone rejected.');
    await load();
  }
  function settleSummary(s: Settle): string {
    const items = s.items ?? [];
    const authors = items.filter((i) => i.is_author).length;
    const first = items.find((i) => i.author_order === 1);
    return `${s.project?.name ?? '—'} · ${items.length} ${get(t)('contributors')} · ${authors} ${get(t)('authors')}${first ? ' · ' + get(t)('1st {n}', { n: names.members[first.member_id] ?? '—' }) : ''}`;
  }

  $effect(() => { load(); });
</script>

<div class="fq">
  <header class="fq-head">
    <h2 class="fq-title">{$t('Forge queue')}</h2>
    <div class="fq-filters">
      {#each ['all', 'badge', 'resource', 'need', 'project_done', ...(canMilestone ? ['milestone'] : []), ...(canSettle ? ['settlement'] : [])] as f}
        <button type="button" class="chip toggle" class:on={filter === f} onclick={() => (filter = f as any)}>
          {f === 'all' ? $t('All') : $t(TYPE_LABEL[f])}
        </button>
      {/each}
    </div>
  </header>

  {#if msg}<p class="fq-msg">{msg}</p>{/if}

  {#if loading}
    <div class="sk sk-row"></div><div class="sk sk-row"></div>
  {:else}
    {#if filter !== 'settlement'}
    <div class="fq-list">
      {#each shownGroups as g (g.key)}
        <div class="fq-row">
          <span class="badge {TYPE_CLASS[g.rep.target_type] ?? 'dim'}">{$t(TYPE_LABEL[g.rep.target_type] ?? g.rep.target_type)}{#if g.rep.action === 'update'} · {$t('edit')}{/if}</span>
          <div class="fq-body">
            <span class="fq-sum">{groupSummary(g)}{#if g.count > 1}<span class="fq-fee" style="color:var(--muted)"> ×{g.count}</span>{/if}</span>
            {#if g.rep.target_type === 'badge' && g.count > 1}
              <div class="fq-detail">{#each g.items as it}<span class="fq-chip">{skName(it.payload?.skill_id)} → {$t(cap(it.payload?.target_level))}</span>{/each}</div>
            {:else}
              {#each detailLines(g.rep) as d}<div class="fq-detail-line">{d}</div>{/each}
            {/if}
          </div>
          {#if g.rep.fee > 0}<span class="fq-fee">−{g.rep.fee} STR</span>{/if}
          <span class="fq-act">
            <button type="button" class="chip toggle ok" disabled={busy === g.key} onclick={() => reviewGroup(g, true)}>
              {#if busy === g.key}<span class="spin"></span>{/if}{$t('Approve')}
            </button>
            <button type="button" class="chip toggle no" disabled={busy === g.key} onclick={() => reviewGroup(g, false)}>{$t('Reject')}</button>
          </span>
        </div>
      {/each}
      {#if !shownGroups.length}
        <p class="muted">{$t('Nothing awaiting review.')}</p>
      {/if}
    </div>
    {/if}

    {#if (filter === 'all') && capacity.length}
      <h3 class="fq-sec">{$t('Over-capacity commitments')}</h3>
      <div class="fq-list">
        {#each capacity as c (c.id)}
          <div class="fq-row">
            <span class="badge warn">{$t('Capacity')}</span>
            <span class="fq-sum">
              {c.member?.full_name ?? '—'} · {c.project?.name ?? '—'} ·
              <span class="fq-mono">{c.monthly_amount}</span>
              {#if c.resource?.monthly_quota}<span class="muted"> / {c.resource.monthly_quota} {$t('quota')}</span>{/if}
              · {c.year_month}
            </span>
            <span class="fq-act">
              <button type="button" class="chip toggle ok" disabled={busy === c.id} onclick={() => reviewCap(c, true)}>
                {#if busy === c.id}<span class="spin"></span>{/if}{$t('Approve')}
              </button>
              <button type="button" class="chip toggle no" disabled={busy === c.id} onclick={() => reviewCap(c, false)}>{$t('Reject')}</button>
            </span>
          </div>
        {/each}
      </div>
    {/if}

    {#if canMilestone && (filter === 'all' || filter === 'milestone') && milestones.length}
      <h3 class="fq-sec">{$t('Milestones')}</h3>
      <div class="fq-list">
        {#each milestones as m (m.id)}
          <div class="fq-row">
            <span class="badge info">{$t('Milestone')}</span>
            <span class="fq-sum">
              {m.project?.name ?? '—'} · {m.catalog?.item ?? '—'}
              <span class="muted"> · +{m.nominal_value} {$t('nominal')} · ×{(1 + Number(m.multiplier_bonus)).toFixed(3)}</span>
            </span>
            <span class="fq-act">
              <button type="button" class="chip toggle ok" disabled={busy === m.id} onclick={() => reviewMilestone(m, true)}>
                {#if busy === m.id}<span class="spin"></span>{/if}{$t('Verify')}
              </button>
              <button type="button" class="chip toggle no" disabled={busy === m.id} onclick={() => reviewMilestone(m, false)}>{$t('Reject')}</button>
            </span>
          </div>
        {/each}
      </div>
    {/if}

    {#if canSettle && (filter === 'all' || filter === 'settlement') && settlements.length}
      <h3 class="fq-sec">{$t('Settlements')}</h3>
      <div class="fq-list">
        {#each settlements as s (s.id)}
          <div class="fq-row">
            <span class="badge up">{$t('Settlement')}</span>
            <span class="fq-sum">
              {settleSummary(s)}
              {#if s.review_window_ends_at}<span class="muted"> · {$t('window ends {d}', { d: new Date(s.review_window_ends_at).toLocaleDateString() })}</span>{/if}
            </span>
            <span class="fq-act">
              <button type="button" class="chip toggle ok" disabled={busy === s.id} onclick={() => reviewSettlement(s, true)}>
                {#if busy === s.id}<span class="spin"></span>{/if}{$t('Approve & pay')}
              </button>
              <button type="button" class="chip toggle no" disabled={busy === s.id} onclick={() => reviewSettlement(s, false)}>{$t('Reject')}</button>
            </span>
          </div>
        {/each}
      </div>
    {/if}
  {/if}
</div>

<style>
  .fq { display: flex; flex-direction: column; gap: 1rem; }
  .fq-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
  .fq-title { font-size: 1.25rem; font-weight: 600; color: var(--text); margin: 0; }
  .fq-filters { display: flex; gap: .4rem; flex-wrap: wrap; }
  .fq-msg { font-size: .85rem; color: var(--accent); }
  .fq-sec { font-size: .74rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: .6rem 0 0; }
  .fq-list { display: flex; flex-direction: column; gap: .45rem; }
  .fq-body { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .25rem; }
  .fq-detail-line { font-size: .78rem; color: var(--muted); }
  .fq-detail { display: flex; flex-wrap: wrap; gap: .25rem; }
  .fq-chip { font-size: .72rem; padding: .1rem .4rem; border: 1px solid var(--border-2); border-radius: 6px; color: var(--text-dim); }
  .fq-row { display: flex; align-items: flex-start; gap: .7rem; padding: .6rem .75rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); }
  .fq-sum { flex: 1; min-width: 0; font-size: .88rem; color: var(--text); }
  .fq-mono { font-family: var(--font-mono); color: var(--info); }
  .fq-fee { font-family: var(--font-mono); font-size: .76rem; color: var(--down); flex: none; }
  .fq-act { display: flex; gap: .35rem; flex: none; }
  .chip.toggle.ok.on, .chip.toggle.ok:hover { color: var(--up); border-color: var(--up); }
  .chip.toggle.no:hover { color: var(--down); border-color: var(--down); }
  .muted { color: var(--muted); font-size: .88rem; }
</style>
