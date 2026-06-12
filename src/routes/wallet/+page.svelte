<script lang="ts">
  import { onMount } from 'svelte';
  import { member } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import CountUp from '$lib/CountUp.svelte';
  import Hint from '$lib/Hint.svelte';
  import { t } from '$lib/i18n';

  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };

  let balance = $state(0);     // settled (spendable)
  let accountId = $state('');
  let ledger = $state<LedgerRow[]>([]);
  let accruing = $state(0);    // accruing (locked in live projects)
  let loading = $state(true);
  let gain = $state(0);          // STR gained since last visit → celebrate
  let celebrate = $state(false);

  function maybeCelebrate(memberId: string, current: number) {
    if (typeof window === 'undefined') return;
    const key = `str_last_balance_${memberId}`;
    const prevRaw = window.localStorage.getItem(key);
    window.localStorage.setItem(key, String(current));
    if (prevRaw == null) return;            // first visit: just seed
    const prev = Number(prevRaw);
    if (Number.isFinite(prev) && current > prev) {
      gain = current - prev;
      celebrate = true;
      setTimeout(() => { celebrate = false; gain = 0; }, 1600);
    }
  }

  const total = $derived(balance + accruing);
  const settledPct = $derived(total > 0 ? (balance / total) * 100 : 100);
  const accruingPct = $derived(total > 0 ? (accruing / total) * 100 : 0);

  function txnIcon(e: LedgerRow, incoming: boolean) {
    const r = (e.reason || '').toLowerCase();
    if (r.includes('grant') || r.includes('welcome')) return '🎁';
    if (r.includes('payout') || r.includes('settle') || r.includes('bonus')) return '🏆';
    return incoming ? '↓' : '↑';
  }
  function fmtWhen(ts: string) {
    return new Date(ts).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  async function load(memberId: string) {
    loading = true;
    const [{ data: bal }, { data: nom }] = await Promise.all([
      supabase.from('stater_balance').select('account_id, balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', memberId)
    ]);
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    accruing = ((nom as { nominal: number }[]) ?? []).reduce((a, c) => a + (Number(c.nominal) || 0), 0);
    if (accountId) {
      const { data: lg } = await supabase
        .from('stater_ledger')
        .select('id, amount, entry_type, reason, from_account, to_account, created_at')
        .or(`from_account.eq.${accountId},to_account.eq.${accountId}`)
        .order('created_at', { ascending: false })
        .limit(50);
      ledger = (lg as LedgerRow[]) ?? [];
    }
    loading = false;
    maybeCelebrate(memberId, balance);
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    const unsub = member.subscribe((m) => { if (m) load(m.id); else loading = false; });
    return unsub;
  });
</script>

<div class="stack" style="max-width:760px;">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">{$t('Wallet')}</h1>
      <span class="muted" style="font-size:.85rem;">{$t('Your STR balance and history.')}</span>
    </div>
  </div>

  {#if !$member}
    <div class="card"><p class="muted">{$t('No member record linked to this account yet.')}</p></div>
  {:else}
    <!-- HERO BALANCE -->
    <div class="hero rise" class:celebrate>
      <span class="h-glow"></span>
      {#if celebrate}
        <span class="float-gain" style="left:1.5rem; top:2.3rem;">+{gain.toLocaleString()} STR</span>
        <div class="confetti" aria-hidden="true">
          {#each Array(14) as _, i}<i style="--i:{i}"></i>{/each}
        </div>
      {/if}
      <span class="h-label">{$t('Your STR')} <Hint term="nominal" text={$t("Settled STR you can spend, plus STR still accruing in live projects (locked until each settles).")} /></span>
      <div class="h-balance">
        {#if loading}<span class="sk sk-line" style="width:200px; height:42px;"></span>
        {:else}<CountUp value={total} /><span class="unit">STR</span>{/if}
      </div>

      <div class="alloc">
        <i class="liquid" style="width:{settledPct}%"></i>
        <i class="bonded" style="width:{accruingPct}%"></i>
      </div>
      <div class="alloc-legend">
        <span class="lg"><span class="sw l"></span> {$t('Settled')} <strong class="mono" style="color:var(--text);">{balance.toLocaleString()}</strong></span>
        <span class="lg"><span class="sw b"></span> {$t('Accruing')} <strong class="mono" style="color:var(--text);">{accruing.toLocaleString()}</strong></span>
      </div>
    </div>

    <div class="row rise-stagger" style="align-items:stretch;">
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">{$t('Settled')} <Hint term="liquid" text={$t('Spendable STR in your wallet.')} /></span>
        <span class="value accent"><CountUp value={balance} /></span>
        <span class="sub">{$t('spendable now')}</span>
      </div>
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">{$t('Accruing')} <Hint term="nominal" text={$t('Accruing STR from your committed work in live projects. Locked until each project settles, then becomes settled (spendable) STR.')} /></span>
        <span class="value"><CountUp value={accruing} /></span>
        <span class="sub">{$t('in live projects')}</span>
      </div>
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">{$t('Accruing share')}</span>
        <span class="value"><CountUp value={total > 0 ? accruingPct : 0} decimals={0} suffix="%" /></span>
        <span class="sub">{$t('still locked in projects')}</span>
      </div>
    </div>

    <!-- How you earn STR — the contribution loop made explicit -->
    <div class="card earn">
      <h2 style="margin:0;">{$t('How you earn STR')}</h2>
      <p class="muted" style="font-size:.82rem; margin:-.3rem 0 .2rem;">{$t('STR is earned by contributing to projects that finish. It accrues as you work; settlement converts it to spendable (settled) STR.')}</p>
      <div class="earn-steps">
        <div class="earn-step"><span class="es-n">1</span><div class="es-tx"><strong>{$t('Join or lead a project')}</strong><span class="muted">{$t('Take an open need, or start one as first author.')}</span></div></div>
        <span class="es-arrow">→</span>
        <div class="earn-step"><span class="es-n">2</span><div class="es-tx"><strong>{$t('Contribute monthly')}</strong><span class="muted">{$t('Hours, resources & milestones accrue STR (your accruing: {n}).', { n: accruing.toLocaleString() })}</span></div></div>
        <span class="es-arrow">→</span>
        <div class="earn-step"><span class="es-n">3</span><div class="es-tx"><strong>{$t('Finish the project')}</strong><span class="muted">{$t('The leader drafts a settlement; milestones lift the payout (up to ×3).')}</span></div></div>
        <span class="es-arrow">→</span>
        <div class="earn-step done"><span class="es-n">✓</span><div class="es-tx"><strong>{$t('Get liquid STR')}</strong><span class="muted">{$t('Settlement pays out spendable STR by your share (your settled: {n}).', { n: balance.toLocaleString() })}</span></div></div>
      </div>
    </div>

    <div class="card stack">
      <h2 style="margin:0;">{$t('Activity')}</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.4rem;">
        {$t('Earned by finishing projects; spent to join ({n}/join) and stake.', { n: joinStake })}
      </p>
      {#if loading}
        <div>{#each Array(5) as _}<div class="sk sk-row"></div>{/each}</div>
      {:else if ledger.length === 0}
        <p class="muted">{$t('No transactions yet.')}</p>
      {:else}
        <div class="rise-stagger">
          {#each ledger as e}
            {@const incoming = e.to_account === accountId}
            <div class="txn">
              <span class="t-ico {incoming ? 'in' : 'out'}">{txnIcon(e, incoming)}</span>
              <span class="t-main">
                <span class="t-reason">{e.reason}</span>
                <span class="t-meta"><span class="badge dim">{e.entry_type}</span> {fmtWhen(e.created_at)}</span>
              </span>
              <span class="t-amt {incoming ? 'in' : 'out'}">{incoming ? '+' : '−'}{Number(e.amount).toLocaleString()}</span>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .earn { display: flex; flex-direction: column; gap: .4rem; }
  .earn-steps { display: flex; align-items: stretch; gap: .4rem; flex-wrap: wrap; }
  .earn-step { flex: 1; min-width: 180px; display: flex; gap: .55rem; padding: .65rem .7rem; border: 1px solid var(--border); border-radius: var(--r-md); background: var(--card-2); }
  .earn-step.done { border-color: color-mix(in srgb, var(--accent) 45%, transparent); background: var(--accent-soft); }
  .es-n { flex: none; width: 1.5rem; height: 1.5rem; border-radius: 50%; background: var(--muted); color: var(--card); font-weight: 700; font-size: .82rem; display: grid; place-items: center; }
  .earn-step.done .es-n { background: var(--accent); color: #fff; }
  .es-tx { display: flex; flex-direction: column; gap: .12rem; min-width: 0; }
  .es-tx strong { font-size: .86rem; }
  .es-tx .muted { font-size: .76rem; }
  .es-arrow { align-self: center; color: var(--muted); font-weight: 700; }
  @media (max-width: 720px) { .es-arrow { display: none; } }
</style>
