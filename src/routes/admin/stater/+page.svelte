<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Policy = { key: string; value: number; description: string | null };
  type Member = { id: string; full_name: string };
  type Rate = { skill_id: string; rate: number; skill?: { name: string } | null };

  let treasury = $state(0);
  let supply = $state(0);
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
    const [{ data: tre }, { data: pol }, { data: mem }, { data: bals }, { data: rt }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('account_type', 'treasury').maybeSingle(),
      supabase.from('stater_policy').select('key, value, description').order('key'),
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('stater_balance').select('balance').eq('account_type', 'member'),
      supabase.from('stater_skill_rate').select('skill_id, rate, skill(name)').order('rate', { ascending: false })
    ]);
    treasury = Number((tre as { balance: number } | null)?.balance ?? 0);
    policies = (pol as Policy[]) ?? [];
    members = (mem as Member[]) ?? [];
    rates = (rt as Rate[]) ?? [];
    supply = ((bals as { balance: number }[]) ?? []).reduce((a, b) => a + Number(b.balance), 0) + treasury;
    loading = false;
  }
  onMount(load);

  async function mint() {
    error = ''; ok = '';
    const { error: err } = await supabase.rpc('stater_mint', { amt: Number(mintAmt), reason: mintReason.trim() || 'mint' });
    if (err) { error = err.message; return; }
    ok = `Minted ${mintAmt} STR into the treasury.`; mintReason = '';
    await load();
  }

  async function grant() {
    error = ''; ok = '';
    if (!grantTo) { error = 'Pick a member.'; return; }
    const { error: err } = await supabase.rpc('stater_grant', { target: grantTo, amt: Number(grantAmt), reason: grantReason.trim() || 'grant' });
    if (err) { error = err.message; return; }
    ok = 'Granted.'; grantReason = '';
    await load();
  }

  async function allowance() {
    error = ''; ok = '';
    const { data, error: err } = await supabase.rpc('issue_monthly_allowance');
    if (err) { error = err.message; return; }
    ok = `Monthly allowance issued to ${data ?? 0} active member(s).`;
    await load();
  }

  async function savePolicy(p: Policy) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_policy').update({ value: Number(p.value) }).eq('key', p.key);
    if (err) { error = err.message; return; }
    ok = `Saved ${p.key}.`;
  }

  async function saveRate(r: Rate) {
    error = ''; ok = '';
    const { error: err } = await supabase.from('stater_skill_rate').update({ rate: Number(r.rate) }).eq('skill_id', r.skill_id);
    if (err) { error = err.message; return; }
    ok = `Saved rate.`;
  }
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Stater (STR)</h1>
  <p class="muted" style="margin-top:-.75rem;">
    The community stake economy. STR is earned via welcome grants, monthly allowance, and project
    settlement; it is staked to start and join projects, and transferred to endorse peers. Mint
    supply, grant to members, issue the monthly allowance, and tune the rules below.
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
        <p class="muted" style="font-size:.8rem;">treasury + all wallets + escrow</p>
      </div>
      <div class="card stack" style="flex:1; min-width:220px;">
        <h2 style="margin:0;">Monthly allowance</h2>
        <p class="muted" style="font-size:.8rem; margin:0;">Issue this window's allowance to members active in the last 30 days (idempotent per window).</p>
        <button onclick={allowance}>Issue allowance</button>
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
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">
        Tiered parameters that drive the economy (small / normal / major / flagship). Changes apply to future transactions.
      </p>
      <table>
        <thead><tr><th>Key</th><th>Value</th><th>What it does</th><th></th></tr></thead>
        <tbody>
          {#each policies as p}
            <tr>
              <td><code>{p.key}</code></td>
              <td><input type="number" step="0.01" bind:value={p.value} style="width:100px;" /></td>
              <td class="muted" style="font-size:.82rem;">{p.description ?? ''}</td>
              <td><button onclick={() => savePolicy(p)}>Save</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="muted" style="font-size:.8rem;">
        Per-project-type stake defaults (join / leader / finish bonus) are edited in
        <a href="/admin/types">Project Types</a>. Per-role payout weights in
        <a href="/admin/roles">Project Roles</a>.
      </p>
    </div>

    <div class="card stack">
      <h2>Skill-time rates</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">
        Token-equivalent valuation per hour when a member joins by pledging skill-time (never enters wallets — settlement weight only).
      </p>
      <table>
        <thead><tr><th>Skill</th><th>STR / hour</th><th></th></tr></thead>
        <tbody>
          {#each rates as r}
            <tr>
              <td>{r.skill?.name ?? '(default)'}</td>
              <td><input type="number" step="1" bind:value={r.rate} style="width:100px;" /></td>
              <td><button onclick={() => saveRate(r)}>Save</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
