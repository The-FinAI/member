<script lang="ts">
  import { onMount } from 'svelte';
  import { member } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import CountUp from '$lib/CountUp.svelte';

  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };

  let balance = $state(0);
  let accountId = $state('');
  let ledger = $state<LedgerRow[]>([]);
  let staked = $state(0);
  let joinStake = $state(20);
  let loading = $state(true);

  const netWorth = $derived(balance + staked);
  const liquidPct = $derived(netWorth > 0 ? (balance / netWorth) * 100 : 100);
  const bondedPct = $derived(netWorth > 0 ? (staked / netWorth) * 100 : 0);

  function txnIcon(e: LedgerRow, incoming: boolean) {
    const r = (e.reason || '').toLowerCase();
    if (r.includes('stake')) return '🔒';
    if (r.includes('grant') || r.includes('welcome')) return '🎁';
    if (r.includes('endorse')) return '★';
    if (r.includes('payout') || r.includes('settle') || r.includes('bonus')) return '🏆';
    return incoming ? '↓' : '↑';
  }
  function fmtWhen(ts: string) {
    return new Date(ts).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  async function load(memberId: string) {
    loading = true;
    const [{ data: bal }, { data: pol }, { data: cm }] = await Promise.all([
      supabase.from('stater_balance').select('account_id, balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_policy').select('value').eq('key', 'join_stake_normal').maybeSingle(),
      supabase.from('stater_project_stake_commitment').select('token_amount, status').eq('member_id', memberId)
    ]);
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    joinStake = Number((pol as { value: number } | null)?.value ?? 20);
    staked = ((cm as { token_amount: number; status: string }[]) ?? [])
      .filter((c) => ['pledged', 'accepted', 'verified'].includes(c.status))
      .reduce((a, c) => a + Number(c.token_amount), 0);
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
      <h1 style="margin-bottom:.15rem;">Wallet</h1>
      <span class="muted" style="font-size:.85rem;">Your Stater (STR) balance and transaction history.</span>
    </div>
  </div>

  {#if !$member}
    <div class="card"><p class="muted">No member record linked to this account yet.</p></div>
  {:else}
    <!-- HERO BALANCE -->
    <div class="hero rise">
      <span class="h-glow"></span>
      <span class="h-label">Net worth</span>
      <div class="h-balance">
        {#if loading}<span class="sk sk-line" style="width:200px; height:42px;"></span>
        {:else}<CountUp value={netWorth} /><span class="unit">STR</span>{/if}
      </div>

      <div class="alloc">
        <i class="liquid" style="width:{liquidPct}%"></i>
        <i class="bonded" style="width:{bondedPct}%"></i>
      </div>
      <div class="alloc-legend">
        <span class="lg"><span class="sw l"></span> Liquid <strong class="mono" style="color:var(--text);">{balance.toLocaleString()}</strong></span>
        <span class="lg"><span class="sw b"></span> Staked <strong class="mono" style="color:var(--text);">{staked.toLocaleString()}</strong></span>
      </div>
    </div>

    <div class="row rise-stagger" style="align-items:stretch;">
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">Liquid balance</span>
        <span class="value accent"><CountUp value={balance} /></span>
        <span class="sub">spendable now</span>
      </div>
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">Staked</span>
        <span class="value"><CountUp value={staked} /></span>
        <span class="sub">bonded in projects</span>
      </div>
      <div class="tile" style="flex:1; min-width:160px;">
        <span class="label">Bonded ratio</span>
        <span class="value"><CountUp value={netWorth > 0 ? bondedPct : 0} decimals={0} suffix="%" /></span>
        <span class="sub">of net worth at work</span>
      </div>
    </div>

    <div class="card stack">
      <h2 style="margin:0;">Activity</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.4rem;">
        Earned by finishing projects; spent to join ({joinStake}/join), stake, and endorse peers.
      </p>
      {#if loading}
        <div>{#each Array(5) as _}<div class="sk sk-row"></div>{/each}</div>
      {:else if ledger.length === 0}
        <p class="muted">No transactions yet.</p>
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
