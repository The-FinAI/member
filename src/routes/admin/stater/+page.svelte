<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Policy = { key: string; value: number; description: string | null };
  type Member = { id: string; full_name: string };
  type Rate = { skill_id: string; rate: number; skill?: { name: string } | null };

  type Flow = { type: string; amount: number };
  type LedgerRow = { entry_type: string; amount: number; reason: string | null; created_at: string; dir: 'in' | 'out' };

  let treasury = $state(0);
  let supply = $state(0);
  let circulating = $state(0);   // member wallets
  let escrowTotal = $state(0);   // project escrows
  let minted = $state<Flow[]>([]);
  let sunk = $state<Flow[]>([]);
  let mintedTotal = $state(0);
  let sunkTotal = $state(0);
  let treasuryLog = $state<LedgerRow[]>([]);
  let flags = $state<{ level: 'warn' | 'down'; msg: string }[]>([]);
  let policies = $state<Policy[]>([]);
  let rates = $state<Rate[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true);
  let error = $state('');
  let ok = $state('');

  let mintAmt = $state(1000);
  let mintReason = $state('');
  let grantTo = $state('');
  let grantAmt = $state(100);
  let grantReason = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: tre }, { data: pol }, { data: mem }, { data: bals }, { data: esc }, { data: rt }, { data: acc }, { data: led }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('account_type', 'treasury').maybeSingle(),
      supabase.from('stater_policy').select('key, value, description').order('key'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('stater_balance').select('balance').eq('account_type', 'member'),
      supabase.from('stater_balance').select('balance').eq('account_type', 'project'),
      supabase.from('stater_skill_rate').select('skill_id, rate, skill(name)').order('rate', { ascending: false }),
      supabase.from('stater_account').select('id, account_type'),
      supabase.from('stater_ledger').select('entry_type, amount, from_account, to_account, reason, created_at').order('created_at', { ascending: false })
    ]);
    treasury = Number((tre as { balance: number } | null)?.balance ?? 0);
    policies = (pol as Policy[]) ?? [];
    members = (mem as Member[]) ?? [];
    rates = (rt as Rate[]) ?? [];
    circulating = ((bals as { balance: number }[]) ?? []).reduce((a, b) => a + Number(b.balance), 0);
    escrowTotal = ((esc as { balance: number }[]) ?? []).reduce((a, b) => a + Number(b.balance), 0);
    supply = circulating + escrowTotal + treasury;

    // treasury account id, for ledger direction
    const treId = ((acc as any[]) ?? []).find((a) => a.account_type === 'treasury')?.id ?? null;

    // mint/sink flow from the append-only ledger
    const mintMap: Record<string, number> = {};
    const sunkMap: Record<string, number> = {};
    const tlog: LedgerRow[] = [];
    for (const r of (led as any[]) ?? []) {
      const amt = Number(r.amount) || 0;
      if (r.from_account === null) mintMap[r.entry_type] = (mintMap[r.entry_type] ?? 0) + amt;   // created supply
      if (r.to_account === null)   sunkMap[r.entry_type] = (sunkMap[r.entry_type] ?? 0) + amt;   // destroyed supply
      if (treId && (r.from_account === treId || r.to_account === treId) && tlog.length < 25)
        tlog.push({ entry_type: r.entry_type, amount: amt, reason: r.reason, created_at: r.created_at,
                    dir: r.to_account === treId ? 'in' : 'out' });
    }
    minted = Object.entries(mintMap).map(([type, amount]) => ({ type, amount })).sort((a, b) => b.amount - a.amount);
    sunk = Object.entries(sunkMap).map(([type, amount]) => ({ type, amount })).sort((a, b) => b.amount - a.amount);
    mintedTotal = minted.reduce((a, f) => a + f.amount, 0);
    sunkTotal = sunk.reduce((a, f) => a + f.amount, 0);
    treasuryLog = tlog;

    // health flags
    const f: { level: 'warn' | 'down'; msg: string }[] = [];
    if (treasury < 0) f.push({ level: 'down', msg: get(t)('Treasury balance is negative — more has been paid out than minted.') });
    if (mintedTotal - sunkTotal !== supply)
      f.push({ level: 'down', msg: get(t)('Supply mismatch: ledger says {a} but account balances sum to {b}.', { a: (mintedTotal - sunkTotal).toLocaleString(), b: supply.toLocaleString() }) });
    if (treasury > 0 && supply > 0 && treasury / supply > 0.7)
      f.push({ level: 'warn', msg: get(t)('Over 70% of supply sits idle in the treasury — little is circulating.') });
    if (escrowTotal > 0 && circulating > 0 && escrowTotal / (circulating + escrowTotal) > 0.6)
      f.push({ level: 'warn', msg: get(t)('Most member STR is locked in project escrow rather than spendable.') });
    flags = f;

    loading = false;
  }
  onMount(load);

  async function mint() {
    error = ''; ok = '';
    const { error: err } = await supabase.rpc('stater_mint', { amt: Number(mintAmt), reason: mintReason.trim() || 'mint' });
    if (err) { error = err.message; return; }
    ok = get(t)('Minted {n} STR into the treasury.', { n: mintAmt }); mintReason = '';
    await load();
  }

  async function grant() {
    error = ''; ok = '';
    if (!grantTo) { error = get(t)('Pick a member.'); return; }
    const { error: err } = await supabase.rpc('stater_grant', { target: grantTo, amt: Number(grantAmt), reason: grantReason.trim() || 'grant' });
    if (err) { error = err.message; return; }
    ok = get(t)('Granted.'); grantReason = '';
    await load();
  }

  async function allowance() {
    error = ''; ok = '';
    const { data, error: err } = await supabase.rpc('issue_monthly_allowance');
    if (err) { error = err.message; return; }
    ok = get(t)('Monthly allowance issued to {n} active member(s).', { n: data ?? 0 });
    await load();
  }

  async function savePolicy(p: Policy) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_policy').update({ value: Number(p.value) }).eq('key', p.key);
    if (err) { error = err.message; return; }
    ok = get(t)('Saved {k}.', { k: p.key });
  }

  async function saveRate(r: Rate) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_skill_rate').update({ rate: Number(r.rate) }).eq('skill_id', r.skill_id);
    if (err) { error = err.message; return; }
    ok = get(t)('Saved rate.');
  }
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Stater (STR)')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('The community stake economy. STR is earned via welcome grants, monthly allowance, and project settlement; it is staked to start and join projects. Mint supply, grant to members, issue the monthly allowance, and tune the rules below.')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}
  {#if ok}<p style="color:var(--up);">{ok}</p>{/if}

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else}
    <div class="row" style="align-items:stretch;">
      <div class="card" style="flex:1; min-width:200px;">
        <h2 style="margin:0;">{$t('Treasury')}</h2>
        <strong style="font-size:1.6rem;">{treasury.toLocaleString()}</strong>
        <p class="muted" style="font-size:.8rem;">{$t('undistributed supply')}</p>
      </div>
      <div class="card" style="flex:1; min-width:200px;">
        <h2 style="margin:0;">{$t('Total supply')}</h2>
        <strong style="font-size:1.6rem;">{supply.toLocaleString()}</strong>
        <p class="muted" style="font-size:.8rem;">{$t('treasury + all wallets + escrow')}</p>
      </div>
      <div class="card stack" style="flex:1; min-width:220px;">
        <h2 style="margin:0;">{$t('Monthly allowance')}</h2>
        <p class="muted" style="font-size:.8rem; margin:0;">{$t("Issue this window's allowance to members active in the last 30 days (idempotent per window).")}</p>
        <button onclick={allowance}>{$t('Issue allowance')}</button>
      </div>
    </div>

    <!-- health flags -->
    {#if flags.length > 0}
      <div class="stack" style="gap:.4rem;">
        {#each flags as fl}
          <p style="margin:0; font-size:.85rem; color:{fl.level === 'down' ? 'var(--down)' : 'var(--warn, #c90)'};">
            {fl.level === 'down' ? '⛔' : '⚠️'} {fl.msg}
          </p>
        {/each}
      </div>
    {/if}

    <!-- supply composition + mint/sink flow -->
    <div class="row" style="align-items:stretch;">
      <div class="card stack" style="flex:1; min-width:280px;">
        <h2 style="margin:0;">{$t('Supply at a glance')}</h2>
        <p class="muted" style="font-size:.8rem; margin:-.3rem 0 .2rem;">{$t('Where the {n} STR lives right now.', { n: supply.toLocaleString() })}</p>
        {#each [{ label: 'Circulating (wallets)', val: circulating }, { label: 'Project escrow', val: escrowTotal }, { label: 'Treasury', val: treasury }] as seg}
          <div class="stack" style="gap:.2rem;">
            <div class="row" style="justify-content:space-between; font-size:.85rem;">
              <span>{$t(seg.label)}</span><span class="mono">{seg.val.toLocaleString()} <span class="muted">({supply ? Math.round((seg.val / supply) * 100) : 0}%)</span></span>
            </div>
            <span class="bar"><i style={`width:${supply ? (seg.val / supply) * 100 : 0}%`}></i></span>
          </div>
        {/each}
      </div>

      <div class="card stack" style="flex:1; min-width:280px;">
        <h2 style="margin:0;">{@html $t('Mint &amp; sink flow')}</h2>
        <p class="muted" style="font-size:.8rem; margin:-.3rem 0 .2rem;">{$t('Lifetime STR created vs destroyed, from the ledger.')}</p>
        <div class="row" style="justify-content:space-between;">
          <span class="up" style="font-weight:600;">{$t('↑ Minted {n}', { n: mintedTotal.toLocaleString() })}</span>
          <span class="down" style="font-weight:600; color:var(--down);">{$t('↓ Sunk {n}', { n: sunkTotal.toLocaleString() })}</span>
        </div>
        <table style="font-size:.82rem;">
          <tbody>
            {#each minted as f}
              <tr><td class="muted">{$t(f.type)}</td><td class="num mono up">+{f.amount.toLocaleString()}</td></tr>
            {/each}
            {#each sunk as f}
              <tr><td class="muted">{$t(f.type)}</td><td class="num mono" style="color:var(--down);">−{f.amount.toLocaleString()}</td></tr>
            {/each}
            {#if minted.length === 0 && sunk.length === 0}
              <tr><td class="muted" colspan="2">{$t('No supply events yet.')}</td></tr>
            {/if}
          </tbody>
        </table>
      </div>
    </div>

    <!-- treasury ledger -->
    <div class="card stack">
      <h2 style="margin:0;">{$t('Treasury ledger')}</h2>
      <p class="muted" style="font-size:.8rem; margin:-.3rem 0 .2rem;">{$t('Most recent {n} movements in and out of the treasury.', { n: treasuryLog.length })}</p>
      {#if treasuryLog.length === 0}
        <p class="muted">{$t('No treasury activity yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('When')}</th><th>{$t('Type')}</th><th>{$t('Reason')}</th><th class="num">{$t('Amount')}</th></tr></thead>
          <tbody>
            {#each treasuryLog as l}
              <tr>
                <td class="muted" style="font-size:.8rem; white-space:nowrap;">{new Date(l.created_at).toLocaleDateString()}</td>
                <td><span class="badge dim">{$t(l.entry_type)}</span></td>
                <td class="muted" style="font-size:.82rem;">{l.reason ?? '—'}</td>
                <td class="num mono" style={l.dir === 'in' ? 'color:var(--up);' : 'color:var(--down);'}>{l.dir === 'in' ? '+' : '−'}{l.amount.toLocaleString()}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>

    <div class="row" style="align-items:stretch;">
      <div class="card stack" style="flex:1; min-width:260px;">
        <h2>{$t('Mint supply')}</h2>
        <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Amount')}</span>
            <input type="number" min="1" bind:value={mintAmt} style="width:120px;" /></label>
          <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">{$t('Reason')}</span>
            <input bind:value={mintReason} placeholder={$t('e.g. Q3 funding round')} /></label>
          <button onclick={mint}>{$t('Mint')}</button>
        </div>
      </div>

      <div class="card stack" style="flex:1; min-width:260px;">
        <h2>{$t('Grant to a member')}</h2>
        <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Member')}</span>
            <select bind:value={grantTo}><option value="">—</option>{#each members as m}<option value={m.id}>{m.full_name}</option>{/each}</select></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Amount')}</span>
            <input type="number" min="1" bind:value={grantAmt} style="width:100px;" /></label>
          <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">{$t('Reason')}</span>
            <input bind:value={grantReason} placeholder={$t('e.g. meeting host stipend')} /></label>
          <button onclick={grant}>{$t('Grant')}</button>
        </div>
      </div>
    </div>

    <div class="card stack" style="border-left:3px solid var(--accent);">
      <h2 style="margin:0;">{$t('The USD anchor')}</h2>
      <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">
        {@html $t('Resources and labour are first priced in <strong>US dollars</strong> (<code>gpu</code> by TFLOPs, <code>api</code> by token price, <code>flat</code> by USD-per-unit), then minted to STR via <code>str_per_usd</code> — calibrated against a reference postdoc hour (<code>usd_per_labor_hour</code>) so human time and compute price on one scale. Edit these three keys in the table below.')}
      </p>
      <p class="muted" style="font-size:.82rem; margin:0;">
        {@html $t("The anchor is <strong>one-directional today</strong>: real-world value flows into STR, but STR is not yet redeemable back to USD. A <strong>two-way (STR ⇄ USD)</strong> peg may come later — until then STR stays an internal accounting and reward unit.")}
      </p>
    </div>

    <div class="card stack">
      <h2>{$t('Policy')}</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">
        {$t('Tiered parameters that drive the economy (small / normal / major / flagship). Changes apply to future transactions.')}
      </p>
      <table>
        <thead><tr><th>{$t('Key')}</th><th>{$t('Value')}</th><th>{$t('What it does')}</th><th></th></tr></thead>
        <tbody>
          {#each policies as p}
            <tr>
              <td><code>{p.key}</code></td>
              <td><input type="number" step="0.01" bind:value={p.value} style="width:100px;" /></td>
              <td class="muted" style="font-size:.82rem;">{p.description ?? ''}</td>
              <td><button onclick={() => savePolicy(p)}>{$t('Save')}</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="muted" style="font-size:.8rem;">
        {@html $t('Per-project-type stake defaults (join / leader / finish bonus) are edited in <a href="/admin/types">Project Types</a>. Per-role payout weights in <a href="/admin/roles">Project Roles</a>.')}
      </p>
    </div>

    <div class="card stack">
      <h2>{$t('Skill-time rates')}</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">
        {$t('Token-equivalent valuation per hour when a member joins by pledging skill-time (never enters wallets — settlement weight only).')}
      </p>
      <table>
        <thead><tr><th>{$t('Skill')}</th><th>{$t('STR / hour')}</th><th></th></tr></thead>
        <tbody>
          {#each rates as r}
            <tr>
              <td>{r.skill?.name ?? $t('(default)')}</td>
              <td><input type="number" step="1" bind:value={r.rate} style="width:100px;" /></td>
              <td><button onclick={() => saveRate(r)}>{$t('Save')}</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
