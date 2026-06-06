<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, officerUnits } from '$lib/session';
  import { get } from 'svelte/store';
  import CountUp from '$lib/CountUp.svelte';
  import { t } from '$lib/i18n';

  // The STR "mining" cockpit — phase 1 frames the loop as mining: people are
  // miners (their monthly hours = hashrate), projects are pools, milestones
  // boost the yield, and settlement is the harvest into liquid STR. This is the
  // home worklist: your output, your pools, what's ready to harvest, idle miners.
  const ym = new Date().toISOString().slice(0, 7);

  let liquid = $state(0);
  let nominal = $state(0);     // total nominal accrued (mining, locked)
  let rate = $state(0);        // nominal minted THIS month (your mining rate /mo)
  type Pool = { id: string; name: string; status: string; finished: boolean; myNominal: number; isLeader: boolean; settleable: boolean };
  let pools = $state<Pool[]>([]);
  let minerCount = $state(0);  // people you operate (officer)
  let idleCount = $state(0);   // of those, with free monthly hours
  let loading = $state(true);

  const harvestable = $derived(pools.filter((p) => p.settleable));
  const chapters = $derived(get(officerUnits).filter((u) => u.kind === 'chapter'));

  async function load() {
    const me = get(member)?.id;
    if (!supabaseConfigured || !me) { loading = false; return; }

    const [{ data: bal }, { data: wc }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle(),
      supabase.from('work_commitment')
        .select('project_id, nominal_str, year_month, slot:slot_id(slot_kind), project:project_id(name, project_status!project_status_id_fkey(name, is_active))')
        .eq('member_id', me)
    ]);
    liquid = Number((bal as any)?.balance ?? 0);

    const byP: Record<string, Pool> = {};
    let nom = 0, r = 0;
    for (const w of (wc as any[]) ?? []) {
      const n = Number(w.nominal_str) || 0; nom += n;
      if (w.year_month === ym) r += n;
      const pid = w.project_id; if (!pid) continue;
      const st = w.project?.project_status?.name ?? '—';
      const fin = st.toLowerCase() === 'finished';
      const p = (byP[pid] ??= { id: pid, name: w.project?.name ?? 'Project', status: st, finished: fin, myNominal: 0, isLeader: false, settleable: false });
      p.myNominal += n;
      if (w.slot?.slot_kind === 'leader') p.isLeader = true;
    }
    nominal = nom; rate = r;

    // which of my finished+led pools still need a settlement (ready to harvest)
    const ledFinished = Object.values(byP).filter((p) => p.isLeader && p.finished).map((p) => p.id);
    if (ledFinished.length) {
      const { data: setl } = await supabase.from('stater_settlement')
        .select('project_id, status').in('project_id', ledFinished);
      const settled = new Set(((setl as any[]) ?? [])
        .filter((s) => ['submitted', 'under_review', 'approved'].includes(s.status))
        .map((s) => s.project_id));
      for (const id of ledFinished) if (!settled.has(id)) byP[id].settleable = true;
    }
    pools = Object.values(byP).sort((a, b) => Number(b.settleable) - Number(a.settleable) || b.myNominal - a.myNominal);

    // officer: how many people you operate, how many have idle hours this month
    const unitIds = chapters.map((u) => u.unit_id);
    if (unitIds.length) {
      const { data: ppl } = await supabase.from('member').select('id').in('home_unit_id', unitIds);
      const ids = ((ppl as any[]) ?? []).map((x) => x.id);
      minerCount = ids.length;
      if (ids.length) {
        const [{ data: res }, { data: used }] = await Promise.all([
          supabase.from('resource').select('holder_member_id, monthly_quota, type_id, resource_type:type_id(name)').in('holder_member_id', ids),
          supabase.from('work_commitment').select('member_id, monthly_amount, slot:slot_id(slot_kind)').in('member_id', ids).eq('year_month', ym)
        ]);
        const quota: Record<string, number> = {};
        for (const x of (res as any[]) ?? []) if (x.resource_type?.name === 'Labor') quota[x.holder_member_id] = (quota[x.holder_member_id] ?? 0) + (Number(x.monthly_quota) || 0);
        const usedH: Record<string, number> = {};
        for (const w of (used as any[]) ?? []) if (w.slot?.slot_kind === 'work_labor' || w.slot?.slot_kind === 'leader') usedH[w.member_id] = (usedH[w.member_id] ?? 0) + (Number(w.monthly_amount) || 0);
        idleCount = ids.filter((id) => (quota[id] ?? 0) > (usedH[id] ?? 0)).length;
      }
    }
    loading = false;
  }
  onMount(load);
</script>

{#if !loading}
  <section class="cockpit">
    <div class="ck-hero">
      <div class="ck-stat">
        <span class="ck-k">{$t('Liquid STR')}</span>
        <span class="ck-v accent"><CountUp value={liquid} /></span>
        <span class="ck-sub">{$t('claimable · spendable')}</span>
      </div>
      <div class="ck-stat">
        <span class="ck-k">⛏ {$t('Mining (nominal)')}</span>
        <span class="ck-v"><CountUp value={nominal} /></span>
        <span class="ck-sub">{$t('locked until projects settle')}</span>
      </div>
      <div class="ck-stat">
        <span class="ck-k">{$t('Your rate')}</span>
        <span class="ck-v">≈<CountUp value={rate} />/{$t('mo')}</span>
        <span class="ck-sub">{$t('nominal minted this month')}</span>
      </div>
      {#if minerCount}
        <div class="ck-stat op">
          <span class="ck-k">{$t('You operate')}</span>
          <span class="ck-v">{minerCount} <span class="ck-unit">{$t('miners')}</span></span>
          <span class="ck-sub">{$t('across {m} pools', { m: pools.length })}</span>
        </div>
      {/if}
    </div>

    {#if harvestable.length}
      <div class="ck-harvest">
        <span class="ck-h-ic">⛏</span>
        <span class="ck-h-tx"><strong>{$t('{n} project(s) ready to harvest', { n: harvestable.length })}</strong><span class="muted">{$t('finished — settle to pay out liquid STR')}</span></span>
        <div class="ck-h-links">
          {#each harvestable.slice(0, 3) as p (p.id)}<a class="ck-h-link" href={`/projects/${p.id}`}>{$t('Settle')} · {p.name} →</a>{/each}
        </div>
      </div>
    {/if}

    {#if idleCount > 0}
      <a class="ck-idle" href={chapters[0] ? `/officer/${chapters[0].unit_id}` : '/officer'}>
        💤 {$t('{n} of your miners have idle hours this month', { n: idleCount })} · <strong>{$t('deploy them →')}</strong>
      </a>
    {/if}

    {#if pools.length}
      <div class="ck-pools">
        <span class="ck-sec">{$t('Your pools')}</span>
        <div class="ck-pool-grid">
          {#each pools as p (p.id)}
            <a class="ck-pool" class:hot={p.settleable} href={`/projects/${p.id}`}>
              <span class="cp-top"><span class="cp-name">{p.name}</span><span class="badge {p.finished ? 'pos' : 'dim'}">{p.settleable ? $t('Harvest') : p.status}</span></span>
              <span class="cp-foot"><span class="muted">{p.isLeader ? $t('Leader') : $t('Contributor')}</span><span class="mono">{p.myNominal.toLocaleString()} {$t('mined')}</span></span>
            </a>
          {/each}
        </div>
      </div>
    {/if}
  </section>
{/if}

<style>
  .cockpit { display: flex; flex-direction: column; gap: .7rem; }
  .ck-hero { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: .5rem; padding: .9rem 1rem; border: 1px solid var(--border); border-radius: 14px; background: linear-gradient(135deg, var(--accent-soft), var(--card)); }
  .ck-stat { display: flex; flex-direction: column; gap: .12rem; }
  .ck-k { font-size: .72rem; text-transform: uppercase; letter-spacing: .04em; color: var(--muted); }
  .ck-v { font-size: 1.5rem; font-weight: 800; color: var(--text); font-variant-numeric: tabular-nums; }
  .ck-v.accent { color: var(--accent); }
  .ck-unit { font-size: .9rem; font-weight: 600; color: var(--muted); }
  .ck-sub { font-size: .72rem; color: var(--muted); }
  .ck-stat.op { border-left: 1px dashed var(--border); padding-left: .8rem; }
  .ck-harvest { display: flex; align-items: center; gap: .7rem; flex-wrap: wrap; padding: .7rem .9rem; border: 1px solid color-mix(in srgb, var(--up) 45%, var(--border)); background: var(--up-soft, color-mix(in srgb, var(--up) 10%, transparent)); border-radius: 12px; }
  .ck-h-ic { font-size: 1.3rem; }
  .ck-h-tx { display: flex; flex-direction: column; }
  .ck-h-tx .muted { font-size: .78rem; }
  .ck-h-links { margin-left: auto; display: flex; flex-direction: column; gap: .15rem; align-items: flex-end; }
  .ck-h-link { font-size: .8rem; font-weight: 600; color: var(--up, var(--accent)); text-decoration: none; }
  .ck-h-link:hover { text-decoration: underline; }
  .ck-idle { display: block; padding: .55rem .9rem; border: 1px dashed var(--border-2); border-radius: 10px; font-size: .85rem; color: var(--text-dim); text-decoration: none; }
  .ck-idle:hover { border-color: var(--accent); }
  .ck-sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .ck-pool-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: .5rem; margin-top: .4rem; }
  .ck-pool { display: flex; flex-direction: column; gap: .4rem; padding: .65rem .75rem; border: 1px solid var(--border); border-radius: 10px; background: var(--card); text-decoration: none; color: var(--text); }
  .ck-pool:hover { border-color: var(--accent); transform: translateY(-1px); }
  .ck-pool.hot { border-color: color-mix(in srgb, var(--up) 45%, transparent); background: color-mix(in srgb, var(--up) 7%, var(--card)); }
  .cp-top { display: flex; justify-content: space-between; gap: .5rem; align-items: center; }
  .cp-name { font-weight: 600; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cp-foot { display: flex; justify-content: space-between; gap: .5rem; font-size: .78rem; }
</style>
