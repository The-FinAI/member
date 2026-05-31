<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Policy = { key: string; value: number; description: string | null };
  type Member = { id: string; full_name: string };

  let treasury = $state(0);
  let supply = $state(0);
  let policies = $state<Policy[]>([]);
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
    const [{ data: tre }, { data: pol }, { data: mem }, { data: bals }] = await Promise.all([
      supabase.from('token_balance').select('balance').eq('kind', 'treasury').maybeSingle(),
      supabase.from('token_policy').select('key, value, description').order('key'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('token_balance').select('balance').eq('kind', 'member')
    ]);
    treasury = Number((tre as { balance: number } | null)?.balance ?? 0);
    policies = (pol as Policy[]) ?? [];
    members = (mem as Member[]) ?? [];
    supply = ((bals as { balance: number }[]) ?? []).reduce((a, b) => a + Number(b.balance), 0) + treasury;
    loading = false;
  }
  onMount(load);

  async function mint() {
    error = ''; ok = '';
    const { error: err } = await supabase.rpc('token_mint', { amt: Number(mintAmt), reason: mintReason.trim() || 'mint' });
    if (err) { error = err.message; return; }
    ok = `Minted ${mintAmt} into the treasury.`; mintReason = '';
    await load();
  }

  async function grant() {
    error = ''; ok = '';
    if (!grantTo) { error = 'Pick a member.'; return; }
    const { error: err } = await supabase.rpc('token_grant', { target: grantTo, amt: Number(grantAmt), reason: grantReason.trim() || 'grant' });
    if (err) { error = err.message; return; }
    ok = 'Granted.'; grantReason = '';
    await load();
  }

  async function savePolicy(p: Policy) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('token_policy').update({ value: Number(p.value) }).eq('key', p.key);
    if (err) { error = err.message; return; }
    ok = `Saved ${p.key}.`;
  }
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Fin Credit</h1>
  <p class="muted" style="margin-top:-.75rem;">
    The community token economy. Credit is earned by finishing projects and spent to join
    projects and endorse peers. Mint supply, grant to members, and tune the rules below.
  </p>

  {#if error}<p style="color:#b91c1c;">{error}</p>{/if}
  {#if ok}<p style="color:#15803d;">{ok}</p>{/if}

  {#if loading}
    <p class="muted">Loading…</p>
  {:else}
    <div class="row" style="align-items:stretch;">
      <div class="card" style="flex:1; min-width:200px;">
        <h2 style="margin:0;">Treasury</h2>
        <strong style="font-size:1.6rem;">{treasury.toLocaleString()}</strong>
        <p class="muted" style="font-size:.8rem;">undistributed supply</p>
      </div>
      <div class="card" style="flex:1; min-width:200px;">
        <h2 style="margin:0;">Total supply</h2>
        <strong style="font-size:1.6rem;">{supply.toLocaleString()}</strong>
        <p class="muted" style="font-size:.8rem;">treasury + all wallets</p>
      </div>
    </div>

    <div class="row" style="align-items:stretch;">
      <div class="card stack" style="flex:1; min-width:260px;">
        <h2>Mint supply</h2>
        <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Amount</span>
            <input type="number" min="1" bind:value={mintAmt} style="width:120px;" /></label>
          <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">Reason</span>
            <input bind:value={mintReason} placeholder="e.g. Q3 funding round" /></label>
          <button onclick={mint}>Mint</button>
        </div>
      </div>

      <div class="card stack" style="flex:1; min-width:260px;">
        <h2>Grant to a member</h2>
        <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Member</span>
            <select bind:value={grantTo}><option value="">—</option>{#each members as m}<option value={m.id}>{m.full_name}</option>{/each}</select></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Amount</span>
            <input type="number" min="1" bind:value={grantAmt} style="width:100px;" /></label>
          <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.75rem;">Reason</span>
            <input bind:value={grantReason} placeholder="e.g. meeting host stipend" /></label>
          <button onclick={grant}>Grant</button>
        </div>
      </div>
    </div>

    <div class="card stack">
      <h2>Policy</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">Parameters that drive the economy. Changes apply to future transactions.</p>
      <table>
        <thead><tr><th>Key</th><th>Value</th><th>What it does</th><th></th></tr></thead>
        <tbody>
          {#each policies as p}
            <tr>
              <td><code>{p.key}</code></td>
              <td><input type="number" bind:value={p.value} style="width:100px;" /></td>
              <td class="muted" style="font-size:.82rem;">{p.description ?? ''}</td>
              <td><button onclick={() => savePolicy(p)}>Save</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="muted" style="font-size:.8rem;">
        Per-role payout weights are edited in <a href="/admin/roles">Project Roles</a>.
      </p>
    </div>
  {/if}
</div>
