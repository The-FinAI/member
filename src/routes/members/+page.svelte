<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type Row = {
    id: string;
    full_name: string;
    affiliation: string | null;
    status: string;
    member_position: { position: { name: string } }[];
  };
  type MemberSkill = { skill_id: string; self_level: string; skill: { name: string } | null };
  type Credit = { skill_id: string; credit: number; endorsements: number };

  let rows = $state<Row[]>([]);
  let balanceOf = $state<Record<string, number>>({});
  let creditOf = $state<Record<string, number>>({});
  let loading = $state(true);
  let q = $state('');
  let myBalance = $state(0);
  let endorseMin = $state(1);

  // expanded member endorse panel
  let openId = $state('');
  let openSkills = $state<MemberSkill[]>([]);
  let openCredit = $state<Record<string, Credit>>({});
  let panelLoading = $state(false);
  let amounts = $state<Record<string, number>>({});
  let notes = $state<Record<string, string>>({});
  let error = $state('');
  let busy = $state('');

  async function loadMyBalance() {
    if (!$member) return;
    const [{ data: bal }, { data: pol }] = await Promise.all([
      supabase.from('stater_balance').select('balance').eq('owner_member_id', $member.id).maybeSingle(),
      supabase.from('stater_policy').select('value').eq('key', 'endorse_min').maybeSingle()
    ]);
    myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);
    endorseMin = Number((pol as { value: number } | null)?.value ?? 1);
  }

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [{ data }, { data: bals }, { data: cr }] = await Promise.all([
      supabase.from('member')
        .select('id, full_name, affiliation, status, member_position(position(name))')
        .order('full_name'),
      supabase.from('stater_balance').select('owner_member_id, balance').not('owner_member_id', 'is', null),
      supabase.from('stater_skill_credit').select('member_id, credit')
    ]);
    rows = (data as Row[]) ?? [];
    const bmap: Record<string, number> = {};
    for (const b of (bals as { owner_member_id: string; balance: number }[]) ?? [])
      bmap[b.owner_member_id] = Number(b.balance) || 0;
    balanceOf = bmap;
    const cmap: Record<string, number> = {};
    for (const c of (cr as { member_id: string; credit: number }[]) ?? [])
      cmap[c.member_id] = (cmap[c.member_id] ?? 0) + (Number(c.credit) || 0);
    creditOf = cmap;
    loading = false;
    const unsub = member.subscribe((m) => { if (m) loadMyBalance(); });
    return unsub;
  });

  async function toggle(id: string) {
    error = '';
    if (openId === id) { openId = ''; return; }
    openId = id;
    panelLoading = true;
    const [{ data: ms }, { data: cr }] = await Promise.all([
      supabase.from('member_skill').select('skill_id, self_level, skill(name)').eq('member_id', id),
      supabase.from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', id)
    ]);
    openSkills = (ms as MemberSkill[]) ?? [];
    const map: Record<string, Credit> = {};
    for (const c of (cr as Credit[]) ?? []) map[c.skill_id] = c;
    openCredit = map;
    panelLoading = false;
  }

  async function endorse(target: string, skillId: string) {
    error = '';
    const amt = Number(amounts[skillId] ?? endorseMin);
    if (amt < endorseMin) { error = `Minimum is ${endorseMin} STR.`; return; }
    if (amt > myBalance) { error = `You only have ${myBalance} STR.`; return; }
    busy = skillId;
    const { error: err } = await supabase.rpc('endorse_skill', {
      target, sk: skillId, amt, note: notes[skillId]?.trim() || null
    });
    busy = '';
    if (err) { error = err.message; return; }
    amounts[skillId] = endorseMin; notes[skillId] = '';
    await Promise.all([loadMyBalance(), toggleReload(target)]);
  }

  async function toggleReload(id: string) {
    const { data: cr } = await supabase
      .from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', id);
    const map: Record<string, Credit> = {};
    for (const c of (cr as Credit[]) ?? []) map[c.skill_id] = c;
    openCredit = map;
  }

  // leaderboard: rank by STR balance (desc), then by reputation credit
  const ranked = $derived(
    [...rows].sort((a, b) =>
      (balanceOf[b.id] ?? 0) - (balanceOf[a.id] ?? 0) ||
      (creditOf[b.id] ?? 0) - (creditOf[a.id] ?? 0) ||
      a.full_name.localeCompare(b.full_name)
    )
  );
  // rank number is assigned on the full ranking, then we filter for display
  const filtered = $derived(
    ranked
      .map((r, i) => ({ row: r, rank: i + 1 }))
      .filter(({ row }) => row.full_name.toLowerCase().includes(q.toLowerCase()))
  );
</script>

<div class="stack">
  <div class="row" style="justify-content:space-between; align-items:flex-end;">
    <div>
      <h1 style="margin-bottom:.15rem;">Leaderboard</h1>
      <span class="muted" style="font-size:.85rem;">Members ranked by STR balance across the research economy.</span>
    </div>
    {#if $member}<span class="muted">Your balance: <strong>{myBalance.toLocaleString()}</strong> STR</span>{/if}
  </div>
  <input placeholder="Search by name…" bind:value={q} style="max-width:320px;" />
  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card" style="padding:0; overflow-x:auto;">
    {#if loading}
      <p class="muted" style="padding:1rem;">Loading…</p>
    {:else if filtered.length === 0}
      <p class="muted" style="padding:1rem;">No members.</p>
    {:else}
      <table>
        <thead><tr><th class="num">#</th><th>Member</th><th>Position</th><th class="num">STR</th><th class="num">Reputation</th><th></th></tr></thead>
        <tbody>
          {#each filtered as { row: r, rank }}
            <tr>
              <td class="num"><span class="rank {rank <= 3 ? 'r' + rank : ''}">{rank}</span></td>
              <td>
                <span class="proj">
                  <span class="pname">{r.full_name}{#if $member && r.id === $member.id}<span class="badge dim" style="margin-left:.4rem;">you</span>{/if}</span>
                  <span class="psub">{r.affiliation ?? '—'}</span>
                </span>
              </td>
              <td class="dim">{r.member_position?.map((p) => p.position?.name).filter(Boolean).join(', ') || '—'}</td>
              <td class="num mono accent" style="color:var(--accent);">{(balanceOf[r.id] ?? 0).toLocaleString()}</td>
              <td class="num mono">{(creditOf[r.id] ?? 0).toLocaleString()}</td>
              <td>
                {#if $member && r.id !== $member.id}
                  <button onclick={() => toggle(r.id)}>{openId === r.id ? 'Close' : 'Endorse'}</button>
                {/if}
              </td>
            </tr>
            {#if openId === r.id}
              <tr>
                <td colspan="6" style="background:var(--card-2);">
                  {#if panelLoading}
                    <p class="muted">Loading skills…</p>
                  {:else if openSkills.length === 0}
                    <p class="muted">{r.full_name} has no skills listed yet.</p>
                  {:else}
                    <div class="stack" style="gap:.5rem; padding:.25rem 0;">
                      <p class="muted" style="font-size:.82rem; margin:0;">
                        Endorse a skill by transferring your own STR — scarce credit means it carries signal.
                      </p>
                      {#each openSkills as s}
                        <div class="row" style="align-items:center; flex-wrap:wrap; gap:.5rem;">
                          <strong style="min-width:160px;">{s.skill?.name ?? s.skill_id}</strong>
                          <span class="badge">{s.self_level}</span>
                          <span class="muted" style="font-size:.8rem;">
                            credit {openCredit[s.skill_id]?.credit ?? 0} · {openCredit[s.skill_id]?.endorsements ?? 0} endorsers
                          </span>
                          <input type="number" min={endorseMin} bind:value={amounts[s.skill_id]} placeholder={String(endorseMin)} style="width:70px;" />
                          <input bind:value={notes[s.skill_id]} placeholder="note (optional)" style="width:180px;" />
                          <button disabled={busy === s.skill_id} onclick={() => endorse(r.id, s.skill_id)}>
                            {busy === s.skill_id ? '…' : 'Endorse'}
                          </button>
                        </div>
                      {/each}
                    </div>
                  {/if}
                </td>
              </tr>
            {/if}
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
