<script lang="ts">
  import { onMount } from 'svelte';
  import { member } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';

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
    <div class="row" style="align-items:stretch;">
      <div class="tile" style="flex:1; min-width:170px;">
        <span class="label">STR balance</span>
        <span class="value accent">{balance.toLocaleString()}</span>
        <span class="sub">liquid, spendable</span>
      </div>
      <div class="tile" style="flex:1; min-width:170px;">
        <span class="label">Staked</span>
        <span class="value">{staked.toLocaleString()}</span>
        <span class="sub">bonded in projects</span>
      </div>
      <div class="tile" style="flex:1; min-width:170px;">
        <span class="label">Net worth</span>
        <span class="value">{(balance + staked).toLocaleString()}</span>
        <span class="sub">liquid + bonded</span>
      </div>
    </div>

    <div class="card stack">
      <h2 style="margin:0;">Transactions</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.4rem;">
        Earned by finishing projects; spent to join projects ({joinStake}/join) and endorse peers.
      </p>
      {#if loading}
        <p class="muted">Loading…</p>
      {:else if ledger.length === 0}
        <p class="muted">No transactions yet.</p>
      {:else}
        <table>
          <thead><tr><th>When</th><th>Type</th><th>Reason</th><th class="num">Amount</th></tr></thead>
          <tbody>
            {#each ledger as e}
              <tr>
                <td class="muted" style="font-size:.78rem; white-space:nowrap;">{new Date(e.created_at).toLocaleDateString()}</td>
                <td><span class="badge dim">{e.entry_type}</span></td>
                <td>{e.reason}</td>
                <td class="num mono" style="color:{e.to_account === accountId ? 'var(--up)' : 'var(--down)'};">
                  {e.to_account === accountId ? '+' : '−'}{Number(e.amount).toLocaleString()}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </div>
  {/if}
</div>
