<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, officerUnits } from '$lib/session';
  import { get } from 'svelte/store';
  import CountUp from '$lib/CountUp.svelte';
  import { t } from '$lib/i18n';

  // Research-collaboration cockpit. The economy underneath is the contribution
  // loop (contribute → finish → settle → STR), but the surface speaks research:
  // collaborators, projects, contribution accruing, projects ready to settle.
  // HCI: one focal figure (a ring of claimable vs accruing), a one-line status,
  // and a SINGLE next-best action. Detail is disclosed quietly below.
  const ym = new Date().toISOString().slice(0, 7);

  let liquid = $state(0);        // claimable / spendable STR
  let nominal = $state(0);       // contribution accruing, locked until settlement
  let rate = $state(0);          // STR of contribution recorded this month
  type Proj = { id: string; name: string; status: string; finished: boolean; myNominal: number; isLeader: boolean; settleable: boolean };
  let projects = $state<Proj[]>([]);
  let teamCount = $state(0);
  let freeCount = $state(0);
  let loading = $state(true);

  const harvestable = $derived(projects.filter((p) => p.settleable));
  const chapters = $derived(get(officerUnits).filter((u) => u.kind === 'chapter'));
  const claimablePct = $derived(liquid + nominal > 0 ? Math.round((liquid / (liquid + nominal)) * 100) : 0);

  // the single most useful thing to do right now
  const nextAction = $derived.by(() => {
    if (harvestable.length) return { label: get(t)('Settle {name}', { name: harvestable[0].name }), href: `/projects/${harvestable[0].id}`, tone: 'go' };
    if (freeCount > 0 && chapters[0]) return { label: get(t)('Assign {n} collaborators with free time', { n: freeCount }), href: `/officer/${chapters[0].unit_id}`, tone: 'go' };
    if (!projects.length) return { label: get(t)('Find a project to join'), href: '/projects', tone: 'ghost' };
    return null;
  });

  // a calm one-line narration of where you are
  const statusLine = $derived.by(() => {
    if (!projects.length) return get(t)('You’re not on a project yet — join or start one to begin contributing.');
    const parts: string[] = [];
    parts.push(get(t)('Contributing ≈{r}/mo across {m} projects', { r: rate.toLocaleString(), m: projects.length }));
    if (harvestable.length) parts.push(get(t)('{n} ready to settle', { n: harvestable.length }));
    return parts.join(' · ');
  });

  async function load() {
    const me = get(member)?.id;
    if (!supabaseConfigured || !me) { loading = false; return; }
    const [{ data: bal }, { data: wc }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle(),
      supabase.from('work_commitment')
        .select('project_id, nominal_str, year_month, slot:slot_id(slot_kind), project:project_id(name, project_status!project_status_id_fkey(name))')
        .eq('member_id', me)
    ]);
    liquid = Number((bal as any)?.balance ?? 0);
    const byP: Record<string, Proj> = {};
    let nom = 0, r = 0;
    for (const w of (wc as any[]) ?? []) {
      const n = Number(w.nominal_str) || 0; nom += n;
      if (w.year_month === ym) r += n;
      const pid = w.project_id; if (!pid) continue;
      const st = w.project?.project_status?.name ?? '—';
      const p = (byP[pid] ??= { id: pid, name: w.project?.name ?? 'Project', status: st, finished: st.toLowerCase() === 'finished', myNominal: 0, isLeader: false, settleable: false });
      p.myNominal += n;
      if (w.slot?.slot_kind === 'leader') p.isLeader = true;
    }
    nominal = nom; rate = r;
    const ledFinished = Object.values(byP).filter((p) => p.isLeader && p.finished).map((p) => p.id);
    if (ledFinished.length) {
      const { data: setl } = await supabase.from('stater_settlement').select('project_id, status').in('project_id', ledFinished);
      const settled = new Set(((setl as any[]) ?? []).filter((s) => ['submitted', 'under_review', 'approved'].includes(s.status)).map((s) => s.project_id));
      for (const id of ledFinished) if (!settled.has(id)) byP[id].settleable = true;
    }
    projects = Object.values(byP).sort((a, b) => Number(b.settleable) - Number(a.settleable) || b.myNominal - a.myNominal);

    const unitIds = chapters.map((u) => u.unit_id);
    if (unitIds.length) {
      const { data: ppl } = await supabase.from('member').select('id').in('home_unit_id', unitIds);
      const ids = ((ppl as any[]) ?? []).map((x) => x.id);
      teamCount = ids.length;
      if (ids.length) {
        const [{ data: res }, { data: used }] = await Promise.all([
          supabase.from('resource').select('holder_member_id, monthly_quota, resource_type:type_id(name)').in('holder_member_id', ids),
          supabase.from('work_commitment').select('member_id, monthly_amount, slot:slot_id(slot_kind)').in('member_id', ids).eq('year_month', ym)
        ]);
        const quota: Record<string, number> = {};
        for (const x of (res as any[]) ?? []) if (x.resource_type?.name === 'Labor') quota[x.holder_member_id] = (quota[x.holder_member_id] ?? 0) + (Number(x.monthly_quota) || 0);
        const usedH: Record<string, number> = {};
        for (const w of (used as any[]) ?? []) if (w.slot?.slot_kind === 'work_labor' || w.slot?.slot_kind === 'leader') usedH[w.member_id] = (usedH[w.member_id] ?? 0) + (Number(w.monthly_amount) || 0);
        freeCount = ids.filter((id) => (quota[id] ?? 0) > (usedH[id] ?? 0)).length;
      }
    }
    loading = false;
  }
  onMount(load);
</script>

{#if !loading}
  <section class="ck">
    <!-- focal hero: claimable vs accruing, status, one next action -->
    <div class="ck-hero">
      <div class="ck-ring" style={`--pct:${claimablePct}`}>
        <div class="ck-ring-hole">
          <span class="ck-ring-v"><CountUp value={liquid} /></span>
          <span class="ck-ring-k">{$t('claimable STR')}</span>
        </div>
      </div>
      <div class="ck-figs">
        <div class="ck-line">
          <span class="ck-accrue">+<CountUp value={nominal} /> <span class="muted">{$t('accruing in projects')}</span></span>
        </div>
        <p class="ck-status">{statusLine}</p>
        {#if nextAction}
          <a class="ck-cta" class:ghost={nextAction.tone === 'ghost'} href={nextAction.href}>{nextAction.label} →</a>
        {:else}
          <span class="ck-allgood">✓ {$t('All your projects are on track.')}</span>
        {/if}
      </div>
    </div>

    {#if projects.length}
      <div class="ck-block">
        <span class="ck-sec">{$t('Your projects')}</span>
        <div class="ck-grid">
          {#each projects as p (p.id)}
            <a class="ck-card" class:hot={p.settleable} href={`/projects/${p.id}`}>
              <span class="cc-top"><span class="cc-name">{p.name}</span><span class="badge {p.settleable ? 'pos' : p.finished ? 'info' : 'dim'}">{p.settleable ? $t('Ready to settle') : p.status}</span></span>
              <span class="cc-foot"><span class="muted">{p.isLeader ? $t('First author') : $t('Contributor')}</span><span class="mono">{p.myNominal.toLocaleString()} {$t('contributed')}</span></span>
            </a>
          {/each}
        </div>
      </div>
    {/if}

    {#if teamCount > 0}
      <a class="ck-team" href={chapters[0] ? `/officer/${chapters[0].unit_id}` : '/officer'}>
        <span>{$t('Your team')}: <strong>{teamCount}</strong> {$t('collaborators')}{#if freeCount > 0} · <strong class="free">{freeCount}</strong> {$t('with free time this month')}{/if}</span>
        <span class="ck-team-go">{$t('Open console')} →</span>
      </a>
    {/if}
  </section>
{/if}

<style>
  .ck { display: flex; flex-direction: column; gap: .8rem; }
  .ck-hero { display: flex; gap: 1.2rem; align-items: center; padding: 1.1rem 1.2rem; border: 1px solid var(--border); border-radius: 16px; background: var(--card); }
  .ck-ring { --pct: 0; flex: none; width: 116px; height: 116px; border-radius: 50%;
    background: conic-gradient(var(--accent) calc(var(--pct) * 1%), color-mix(in srgb, var(--accent) 16%, var(--border)) 0);
    display: grid; place-items: center; }
  .ck-ring-hole { width: 88px; height: 88px; border-radius: 50%; background: var(--card); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .1rem; }
  .ck-ring-v { font-size: 1.45rem; font-weight: 800; color: var(--accent); font-variant-numeric: tabular-nums; }
  .ck-ring-k { font-size: .66rem; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
  .ck-figs { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .45rem; }
  .ck-accrue { font-size: 1.05rem; font-weight: 700; color: var(--text); }
  .ck-accrue .muted { font-size: .82rem; font-weight: 400; }
  .ck-status { margin: 0; font-size: .88rem; color: var(--text-dim); }
  .ck-cta { align-self: flex-start; padding: .55rem 1rem; border-radius: 9px; background: var(--accent); color: #fff; font-weight: 700; text-decoration: none; font-size: .9rem; }
  .ck-cta:hover { filter: brightness(1.06); }
  .ck-cta.ghost { background: transparent; color: var(--accent); border: 1px solid var(--border); }
  .ck-allgood { font-size: .85rem; color: var(--up, var(--accent)); }
  .ck-sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .ck-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: .5rem; margin-top: .4rem; }
  .ck-card { display: flex; flex-direction: column; gap: .4rem; padding: .65rem .75rem; border: 1px solid var(--border); border-radius: 11px; background: var(--card); text-decoration: none; color: var(--text); }
  .ck-card:hover { border-color: var(--accent); transform: translateY(-1px); }
  .ck-card.hot { border-color: color-mix(in srgb, var(--up) 45%, transparent); background: color-mix(in srgb, var(--up) 7%, var(--card)); }
  .cc-top { display: flex; justify-content: space-between; gap: .5rem; align-items: center; }
  .cc-name { font-weight: 600; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cc-foot { display: flex; justify-content: space-between; gap: .5rem; font-size: .78rem; }
  .ck-team { display: flex; align-items: center; justify-content: space-between; gap: .6rem; padding: .6rem .9rem; border: 1px dashed var(--border-2); border-radius: 11px; font-size: .85rem; color: var(--text-dim); text-decoration: none; }
  .ck-team:hover { border-color: var(--accent); }
  .ck-team .free { color: var(--accent); }
  .ck-team-go { font-size: .8rem; color: var(--muted); white-space: nowrap; }
  @media (max-width: 640px) { .ck-hero { flex-direction: column; align-items: flex-start; } }
</style>
