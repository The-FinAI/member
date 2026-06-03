<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { get } from 'svelte/store';
  import { t } from '$lib/i18n';

  type Policy = { key: string; value: number; description: string | null };
  type Member = { id: string; full_name: string };
  type Rate = { skill_id: string; rate: number; skill?: { name: string } | null };
  type LedgerRow = { entry_type: string; amount: number; reason: string | null; created_at: string; dir: 'in' | 'out' };

  let treasury = $state(0), supply = $state(0), circulating = $state(0), escrowTotal = $state(0);
  let mintedTotal = $state(0), sunkTotal = $state(0);
  let treasuryLog = $state<LedgerRow[]>([]);
  let flags = $state<{ level: 'warn' | 'down'; msg: string }[]>([]);
  let policies = $state<Policy[]>([]);
  let rates = $state<Rate[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true); let error = $state(''); let ok = $state('');

  let mintAmt = $state(1000), mintReason = $state('');
  let grantTo = $state(''), grantAmt = $state(100), grantReason = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: allBal }, { data: pol }, { data: mem }, { data: rt }, { data: acc }, { data: led }] = await Promise.all([
      supabase.from('stater_balance').select('balance, account_type'),
      supabase.from('stater_policy').select('key, value, description').order('key'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('stater_skill_rate').select('skill_id, rate, skill(name)').order('rate', { ascending: false }),
      supabase.from('stater_account').select('id, account_type'),
      supabase.from('stater_ledger').select('entry_type, amount, from_account, to_account, reason, created_at').order('created_at', { ascending: false })
    ]);
    policies = (pol as Policy[]) ?? []; members = (mem as Member[]) ?? []; rates = (rt as Rate[]) ?? [];
    // bucket by the real account types: member | project_escrow | market_escrow
    // | treasury. supply = the sum of ALL balances, so it always reconciles with
    // minted − sunk from the ledger.
    treasury = 0; circulating = 0; escrowTotal = 0;
    for (const b of (allBal as { balance: number; account_type: string }[]) ?? []) {
      const v = Number(b.balance) || 0;
      if (b.account_type === 'treasury') treasury += v;
      else if (b.account_type === 'member') circulating += v;
      else escrowTotal += v; // project_escrow + market_escrow
    }
    supply = circulating + escrowTotal + treasury;
    const treId = ((acc as any[]) ?? []).find((a) => a.account_type === 'treasury')?.id ?? null;
    let mint = 0, sink = 0; const tlog: LedgerRow[] = [];
    for (const r of (led as any[]) ?? []) {
      const amt = Number(r.amount) || 0;
      if (r.from_account === null) mint += amt;
      if (r.to_account === null) sink += amt;
      if (treId && (r.from_account === treId || r.to_account === treId) && tlog.length < 20)
        tlog.push({ entry_type: r.entry_type, amount: amt, reason: r.reason, created_at: r.created_at, dir: r.to_account === treId ? 'in' : 'out' });
    }
    mintedTotal = mint; sunkTotal = sink; treasuryLog = tlog;
    const f: { level: 'warn' | 'down'; msg: string }[] = [];
    if (treasury < 0) f.push({ level: 'down', msg: get(t)('Treasury balance is negative — more has been paid out than minted.') });
    if (mintedTotal - sunkTotal !== supply) f.push({ level: 'down', msg: get(t)('Supply mismatch: ledger says {a} but account balances sum to {b}.', { a: (mintedTotal - sunkTotal).toLocaleString(), b: supply.toLocaleString() }) });
    if (treasury > 0 && supply > 0 && treasury / supply > 0.7) f.push({ level: 'warn', msg: get(t)('Over 70% of supply sits idle in the treasury — little is circulating.') });
    flags = f;
    loading = false;
  }
  onMount(load);

  async function mint() {
    error = ''; ok = '';
    const { error: err } = await supabase.rpc('stater_mint', { amt: Number(mintAmt), reason: mintReason.trim() || 'mint' });
    if (err) { error = err.message; return; }
    ok = get(t)('Minted {n} STR into the treasury.', { n: mintAmt }); mintReason = ''; await load();
  }
  async function grant() {
    error = ''; ok = '';
    if (!grantTo) { error = get(t)('Pick a member.'); return; }
    const { error: err } = await supabase.rpc('stater_grant', { target: grantTo, amt: Number(grantAmt), reason: grantReason.trim() || 'grant' });
    if (err) { error = err.message; return; }
    ok = get(t)('Granted.'); grantReason = ''; await load();
  }
  async function allowance() {
    error = ''; ok = '';
    const { data, error: err } = await supabase.rpc('issue_monthly_allowance');
    if (err) { error = err.message; return; }
    ok = get(t)('Monthly allowance issued to {n} active member(s).', { n: data ?? 0 }); await load();
  }
  async function savePolicy(p: Policy) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_policy').update({ value: Number(p.value) }).eq('key', p.key);
    if (err) error = err.message; else ok = get(t)('Saved {k}.', { k: p.key });
  }
  async function saveRate(r: Rate) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_skill_rate').update({ rate: Number(r.rate) }).eq('skill_id', r.skill_id);
    if (err) error = err.message; else ok = get(t)('Saved rate.');
  }
  const fmtDate = (d: string) => new Date(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
</script>

{#if error}<p class="err">{error}</p>{/if}
{#if ok}<p class="ok">{ok}</p>{/if}

{#if loading}
  <p class="muted">{$t('Loading…')}</p>
{:else}
  <!-- supply at a glance -->
  <div class="kpis">
    <div class="kpi"><span class="k-label">{$t('Total supply')}</span><span class="k-value accent">{supply.toLocaleString()}</span></div>
    <div class="kpi"><span class="k-label">{$t('Circulating')}</span><span class="k-value">{circulating.toLocaleString()}</span><span class="k-sub">{$t('member wallets')}</span></div>
    <div class="kpi"><span class="k-label">{$t('In escrow')}</span><span class="k-value">{escrowTotal.toLocaleString()}</span><span class="k-sub">{$t('project pools')}</span></div>
    <div class="kpi"><span class="k-label">{$t('Treasury')}</span><span class="k-value">{treasury.toLocaleString()}</span><span class="k-sub">{$t('minted {m} · sunk {s}', { m: mintedTotal.toLocaleString(), s: sunkTotal.toLocaleString() })}</span></div>
  </div>

  {#if flags.length}
    <div class="flags">
      {#each flags as f}<p class="flag {f.level}">{f.msg}</p>{/each}
    </div>
  {/if}

  <!-- actions -->
  <div class="acts">
    <div class="card act">
      <span class="sec">{$t('Mint to treasury')}</span>
      <div class="row"><input type="number" bind:value={mintAmt} /><input placeholder={$t('Reason')} bind:value={mintReason} /><button class="go" onclick={mint}>{$t('Mint')}</button></div>
    </div>
    <div class="card act">
      <span class="sec">{$t('Grant to a member')}</span>
      <div class="row">
        <select bind:value={grantTo}><option value="">{$t('— member —')}</option>{#each members as m (m.id)}<option value={m.id}>{m.full_name}</option>{/each}</select>
        <input type="number" bind:value={grantAmt} style="max-width:6rem;" /><input placeholder={$t('Reason')} bind:value={grantReason} /><button class="go" onclick={grant}>{$t('Grant')}</button>
      </div>
    </div>
    <div class="card act">
      <span class="sec">{$t('Monthly allowance')}</span>
      <div class="row"><button class="go" onclick={allowance}>{$t('Issue to all active members')}</button></div>
    </div>
  </div>

  <!-- policy knobs -->
  <section>
    <span class="sec">{$t('Policy')}</span>
    <div class="rows">
      {#each policies as p (p.key)}
        <div class="prow">
          <div class="p-id"><code>{p.key}</code>{#if p.description}<span class="p-desc">{p.description}</span>{/if}</div>
          <input type="number" step="any" bind:value={p.value} onblur={() => savePolicy(p)} />
        </div>
      {/each}
    </div>
  </section>

  <!-- skill rates -->
  {#if rates.length}
    <section>
      <span class="sec">{$t('Skill rates')}{$t(' (STR per unit)')}</span>
      <div class="rows">
        {#each rates as r (r.skill_id)}
          <div class="prow"><div class="p-id">{$t(r.skill?.name ?? '—')}</div><input type="number" step="any" bind:value={r.rate} onblur={() => saveRate(r)} /></div>
        {/each}
      </div>
    </section>
  {/if}

  <!-- treasury ledger -->
  {#if treasuryLog.length}
    <section>
      <span class="sec">{$t('Treasury ledger')}</span>
      <div class="rows">
        {#each treasuryLog as l}
          <div class="lrow">
            <span class="l-when">{fmtDate(l.created_at)}</span>
            <span class="l-type">{l.entry_type}{#if l.reason}<span class="l-reason"> · {l.reason}</span>{/if}</span>
            <span class="l-amt" class:in={l.dir === 'in'} class:out={l.dir === 'out'}>{l.dir === 'in' ? '+' : '−'}{l.amount.toLocaleString()}</span>
          </div>
        {/each}
      </div>
    </section>
  {/if}
{/if}

<style>
  .err { color: var(--down); font-size: .85rem; margin: 0; }
  .ok { color: var(--up); font-size: .85rem; margin: 0; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .flags { display: flex; flex-direction: column; gap: .35rem; }
  .flag { margin: 0; font-size: .82rem; padding: .5rem .7rem; border-radius: 8px; }
  .flag.warn { color: var(--accent); background: var(--accent-soft); }
  .flag.down { color: var(--down); background: color-mix(in srgb, var(--down) 10%, transparent); }
  .acts { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: .6rem; }
  .act { display: flex; flex-direction: column; gap: .5rem; }
  .act .row { display: flex; gap: .4rem; flex-wrap: wrap; }
  .act input, .act select { padding: .4rem .55rem; border-radius: 8px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); font-size: .85rem; flex: 1; min-width: 5rem; }
  .go { padding: .4rem .8rem; border-radius: 8px; border: 1px solid transparent; background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer; flex: none; }
  .rows { display: flex; flex-direction: column; gap: .3rem; margin-top: .4rem; }
  .prow { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .45rem .7rem; border: 1px solid var(--border); border-radius: 9px; background: var(--card); }
  .p-id { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
  .p-id code { color: var(--accent); font-size: .82rem; }
  .p-desc { font-size: .74rem; color: var(--muted); }
  .prow input { max-width: 8rem; padding: .35rem .5rem; border-radius: 7px; border: 1px solid var(--border-2); background: var(--card-2); color: var(--text); text-align: right; }
  .lrow { display: grid; grid-template-columns: 4rem 1fr auto; gap: .6rem; align-items: center; padding: .4rem .7rem; border-bottom: 1px solid var(--border); font-size: .82rem; }
  .l-when { color: var(--muted); }
  .l-reason { color: var(--muted); }
  .l-amt { font-variant-numeric: tabular-nums; font-weight: 600; }
  .l-amt.in { color: var(--up); }
  .l-amt.out { color: var(--down); }
</style>
