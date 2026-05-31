<script lang="ts">
  import { onMount } from 'svelte';
  import { member, capabilities } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  const LEVELS = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  type Skill = { id: string; name: string; parent_id: string | null };
  type MySkill = { skill_id: string; self_level: string };
  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };
  type ResType = { id: string; name: string };
  type MyResource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; resource_type: { name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let saving = $state(false);
  let affiliation = $state('');
  let saved = $state(false);

  let skills = $state<Skill[]>([]);
  let mySkills = $state<MySkill[]>([]);
  let skillCredit = $state<Record<string, { credit: number; endorsements: number }>>({});
  let balance = $state(0);
  let accountId = $state('');
  let ledger = $state<LedgerRow[]>([]);
  let joinStake = $state(20);
  let addSkill = $state('');
  let addLevel = $state('Intermediate');
  let skillsLoading = $state(true);
  let error = $state('');

  // personal resources
  let resTypes = $state<ResType[]>([]);
  let myResources = $state<MyResource[]>([]);
  let rName = $state('');
  let rType = $state('');
  let rCapacity = $state('');
  let rAvail = $state('available');

  $effect(() => { if ($member) affiliation = $member.affiliation ?? ''; });

  async function loadSkills(memberId: string) {
    skillsLoading = true;
    const [{ data: tree }, { data: ms }, { data: cr }, { data: rt }, { data: mr }, { data: bal }, { data: pol }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, self_level').eq('member_id', memberId),
      supabase.from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', memberId),
      supabase.from('resource_type').select('id, name').order('rank'),
      supabase.from('resource')
        .select('id, name, description, capacity, availability, resource_type(name)')
        .eq('scope', 'member').eq('holder_member_id', memberId).order('name'),
      supabase.from('stater_balance').select('account_id, balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_policy').select('value').eq('key', 'join_stake_normal').maybeSingle()
    ]);
    skills = (tree as Skill[]) ?? [];
    mySkills = (ms as MySkill[]) ?? [];
    const credit: Record<string, { credit: number; endorsements: number }> = {};
    for (const c of (cr as { skill_id: string; credit: number; endorsements: number }[]) ?? [])
      credit[c.skill_id] = { credit: Number(c.credit), endorsements: Number(c.endorsements) };
    skillCredit = credit;
    resTypes = (rt as ResType[]) ?? [];
    myResources = (mr as MyResource[]) ?? [];
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    joinStake = Number((pol as { value: number } | null)?.value ?? 20);
    if (accountId) {
      const { data: lg } = await supabase
        .from('stater_ledger')
        .select('id, amount, entry_type, reason, from_account, to_account, created_at')
        .or(`from_account.eq.${accountId},to_account.eq.${accountId}`)
        .order('created_at', { ascending: false })
        .limit(12);
      ledger = (lg as LedgerRow[]) ?? [];
    }
    skillsLoading = false;
  }

  async function addResource() {
    error = '';
    if (!rName.trim() || !$member) return;
    const { error: err } = await supabase.from('resource').insert({
      name: rName.trim(), type_id: rType || null, scope: 'member',
      holder_member_id: $member.id, capacity: rCapacity || null, availability: rAvail
    });
    if (err) { error = err.message; return; }
    rName = ''; rType = ''; rCapacity = ''; rAvail = 'available';
    await loadSkills($member.id);
  }

  async function removeResource(id: string) {
    if (!$member) return;
    const { error: err } = await supabase.from('resource').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await loadSkills($member.id);
  }

  onMount(() => {
    if (!supabaseConfigured) { skillsLoading = false; return; }
    const unsub = member.subscribe((m) => { if (m) loadSkills(m.id); else skillsLoading = false; });
    return unsub;
  });

  const leafSkills = $derived(skills.filter((s) => s.parent_id));
  function skillName(skillId: string) { return skills.find((s) => s.id === skillId)?.name ?? skillId; }

  async function save() {
    if (!supabaseConfigured || !$member) return;
    saving = true; saved = false;
    const { error: err } = await supabase.from('member').update({ affiliation }).eq('id', $member.id);
    saving = false;
    if (!err) { saved = true; member.update((m) => (m ? { ...m, affiliation } : m)); }
  }

  async function addMySkill() {
    error = '';
    if (!addSkill || !$member) return;
    const { error: err } = await supabase
      .from('member_skill')
      .upsert({ member_id: $member.id, skill_id: addSkill, self_level: addLevel });
    if (err) { error = err.message; return; }
    addSkill = '';
    await loadSkills($member.id);
  }

  async function removeMySkill(skillId: string) {
    if (!$member) return;
    const { error: err } = await supabase
      .from('member_skill').delete().eq('member_id', $member.id).eq('skill_id', skillId);
    if (err) { error = err.message; return; }
    await loadSkills($member.id);
  }
</script>

<div class="stack" style="max-width:620px;">
  <h1>Your profile</h1>

  {#if !$member}
    <div class="card"><p class="muted">No member record linked to this account yet.</p></div>
  {:else}
    <div class="card stack">
      <div><strong>{$member.full_name}</strong></div>
      <div class="muted">{$member.email}</div>
      <label class="stack" style="gap:.3rem;">
        <span class="muted" style="font-size:.8rem;">Affiliation</span>
        <input bind:value={affiliation} />
      </label>
      <div class="row">
        <button onclick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
        {#if saved}<span class="badge">Saved</span>{/if}
      </div>
    </div>

    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:baseline;">
        <h2 style="margin:0;">Stater (STR)</h2>
        <strong style="font-size:1.4rem;">{balance.toLocaleString()} <span class="muted" style="font-size:.7rem;">tokens</span></strong>
      </div>
      <p class="muted" style="font-size:.82rem; margin-top:-.4rem;">
        Earned by finishing projects; spent to join projects ({joinStake}/join) and endorse peers.
      </p>
      {#if ledger.length > 0}
        <table>
          <thead><tr><th>When</th><th>Type</th><th>Reason</th><th style="text-align:right;">Amount</th></tr></thead>
          <tbody>
            {#each ledger as e}
              <tr>
                <td class="muted" style="font-size:.78rem;">{new Date(e.created_at).toLocaleDateString()}</td>
                <td><span class="badge">{e.entry_type}</span></td>
                <td>{e.reason}</td>
                <td style="text-align:right; color:{e.to_account === accountId ? '#15803d' : '#b91c1c'};">
                  {e.to_account === accountId ? '+' : '−'}{Number(e.amount).toLocaleString()}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {:else}
        <p class="muted">No transactions yet.</p>
      {/if}
    </div>

    <div class="card stack">
      <h2>My skills</h2>
      {#if error}<p style="color:#b91c1c;">{error}</p>{/if}
      {#if skillsLoading}
        <p class="muted">Loading…</p>
      {:else}
        {#if mySkills.length === 0}
          <p class="muted">No skills added yet.</p>
        {:else}
          <table>
            <thead><tr><th>Skill</th><th>Self-rating</th><th>Credit (endorsers)</th><th></th></tr></thead>
            <tbody>
              {#each mySkills as s}
                <tr>
                  <td>{skillName(s.skill_id)}</td>
                  <td><span class="badge">{s.self_level}</span></td>
                  <td>{skillCredit[s.skill_id]?.credit ?? 0} <span class="muted" style="font-size:.78rem;">({skillCredit[s.skill_id]?.endorsements ?? 0})</span></td>
                  <td><button class="danger" onclick={() => removeMySkill(s.skill_id)}>Remove</button></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}

        <div class="row" style="align-items:flex-end; border-top:1px dashed var(--border); padding-top:.75rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Skill</span>
            <select bind:value={addSkill}>
              <option value="">— pick a skill —</option>
              {#each leafSkills as s}<option value={s.id}>{s.name}</option>{/each}
            </select>
          </label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Level</span>
            <select bind:value={addLevel}>{#each LEVELS as l}<option>{l}</option>{/each}</select>
          </label>
          <button onclick={addMySkill}>Add skill</button>
        </div>
      {/if}
    </div>

    <div class="card stack">
      <h2>My resources</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">Resources you can bring to projects (compute, funding, data, expertise…).</p>
      {#if skillsLoading}
        <p class="muted">Loading…</p>
      {:else}
        {#if myResources.length === 0}
          <p class="muted">No resources added yet.</p>
        {:else}
          <table>
            <thead><tr><th>Name</th><th>Type</th><th>Capacity</th><th>Availability</th><th></th></tr></thead>
            <tbody>
              {#each myResources as r}
                <tr>
                  <td>{r.name}</td>
                  <td>{r.resource_type?.name ?? '—'}</td>
                  <td>{r.capacity ?? '—'}</td>
                  <td><span class="badge">{r.availability}</span></td>
                  <td><button class="danger" onclick={() => removeResource(r.id)}>Remove</button></td>
                </tr>
              {/each}
            </tbody>
          </table>
        {/if}

        <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.75rem;">
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Name</span>
            <input bind:value={rName} placeholder="e.g. RTX 4090 ×2" /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Type</span>
            <select bind:value={rType}><option value="">—</option>{#each resTypes as t}<option value={t.id}>{t.name}</option>{/each}</select></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Capacity</span>
            <input bind:value={rCapacity} placeholder="optional" style="width:120px;" /></label>
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Availability</span>
            <select bind:value={rAvail}>{#each AVAIL as a}<option>{a}</option>{/each}</select></label>
          <button onclick={addResource}>Add resource</button>
        </div>
      {/if}
    </div>

    <div class="card">
      <h2>Capabilities</h2>
      {#if $capabilities.size === 0}
        <p class="muted">Standard member — no admin capabilities.</p>
      {:else}
        <div class="row">{#each [...$capabilities] as c}<span class="badge">{c}</span>{/each}</div>
      {/if}
    </div>
  {/if}
</div>
