<script lang="ts">
  import { onMount } from 'svelte';
  import { member, capabilities } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  const LEVELS = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  // guild certification ladder (member_skill.certified_level)
  const GUILD_LABEL: Record<string, string> = {
    apprentice: 'Apprentice 学徒', journeyman: 'Journeyman 职人',
    craftsman: 'Craftsman 名匠', master: 'Master 宗师'
  };
  const GUILD_RANK = ['apprentice', 'journeyman', 'craftsman', 'master'];

  type Skill = { id: string; name: string; parent_id: string | null };
  type MySkill = { skill_id: string; self_level: string; certified_level: string | null };
  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };
  type ResType = { id: string; name: string };
  type MyResource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; approval_status: string; resource_type: { name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let saving = $state(false);
  let affiliation = $state('');
  let saved = $state(false);

  let skills = $state<Skill[]>([]);
  let mySkills = $state<MySkill[]>([]);
  let skillCredit = $state<Record<string, { credit: number; endorsements: number }>>({});
  let masterCount = $state(0);
  let balance = $state(0);
  let accountId = $state('');
  let totalNominal = $state(0);
  let ledger = $state<LedgerRow[]>([]);
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
    const [{ data: tree }, { data: ms }, { data: cr }, { data: rt }, { data: mr }, { data: bal }, { data: nom }, { count: mc }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, self_level, certified_level').eq('member_id', memberId),
      supabase.from('stater_skill_credit').select('skill_id, credit, endorsements').eq('member_id', memberId),
      supabase.from('resource_type').select('id, name').order('rank'),
      supabase.from('resource')
        .select('id, name, description, capacity, availability, approval_status, resource_type(name)')
        .eq('scope', 'member').eq('holder_member_id', memberId).order('name'),
      supabase.from('stater_balance').select('account_id, balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', memberId),
      supabase.from('skill').select('id', { count: 'exact', head: true }).eq('master_member_id', memberId)
    ]);
    skills = (tree as Skill[]) ?? [];
    mySkills = ((ms as MySkill[]) ?? []).sort(
      (a, b) => GUILD_RANK.indexOf(b.certified_level ?? '') - GUILD_RANK.indexOf(a.certified_level ?? '')
        || skillName(a.skill_id).localeCompare(skillName(b.skill_id))
    );
    const credit: Record<string, { credit: number; endorsements: number }> = {};
    for (const c of (cr as { skill_id: string; credit: number; endorsements: number }[]) ?? [])
      credit[c.skill_id] = { credit: Number(c.credit), endorsements: Number(c.endorsements) };
    skillCredit = credit;
    resTypes = (rt as ResType[]) ?? [];
    myResources = (mr as MyResource[]) ?? [];
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    totalNominal = ((nom as { nominal: number }[]) ?? []).reduce((a, n) => a + (Number(n.nominal) || 0), 0);
    masterCount = mc ?? 0;
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
  function levelClass(l: string) {
    return l === 'Expert' ? 'up' : l === 'Advanced' ? 'info' : l === 'Intermediate' ? '' : 'dim';
  }
  const certifiedCount = $derived(mySkills.filter((s) => s.certified_level).length);
  const totalCredit = $derived(Object.values(skillCredit).reduce((a, c) => a + c.credit, 0));

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

<div class="stack" style="max-width:680px;">
  <h1>Your profile</h1>

  {#if !$member}
    <div class="card"><p class="muted">No member record linked to this account yet.</p></div>
  {:else}
    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:flex-start;">
        <div>
          <div><strong>{$member.full_name}</strong></div>
          <div class="muted">{$member.email}</div>
        </div>
        <a href={`/members/${$member.id}`}><button class="ghost">Public page →</button></a>
      </div>
      <label class="stack" style="gap:.3rem;">
        <span class="muted" style="font-size:.8rem;">Affiliation</span>
        <input bind:value={affiliation} />
      </label>
      <div class="row">
        <button onclick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
        {#if saved}<span class="badge">Saved</span>{/if}
      </div>
    </div>

    <!-- standing at a glance -->
    <div class="kpis">
      <div class="kpi">
        <span class="k-label">Contribution</span>
        <span class="k-value accent">{totalNominal.toLocaleString()}</span>
        <span class="k-sub">nominal STR minted through work</span>
      </div>
      <div class="kpi">
        <span class="k-label">Liquid balance</span>
        <span class="k-value">{balance.toLocaleString()}</span>
        <span class="k-sub"><a href="/wallet">open wallet →</a></span>
      </div>
      <div class="kpi">
        <span class="k-label">Guild rank</span>
        <span class="k-value">{certifiedCount}</span>
        <span class="k-sub">{certifiedCount === 1 ? 'skill' : 'skills'} certified{masterCount ? ` · ${masterCount} mastered` : ''}</span>
      </div>
      <div class="kpi">
        <span class="k-label">Reputation</span>
        <span class="k-value">{totalCredit.toLocaleString()}</span>
        <span class="k-sub">peer-endorsement credit</span>
      </div>
    </div>

    <div class="card stack">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">Skills &amp; certifications</h2>
        <a href="/skills"><button class="ghost">The Guild →</button></a>
      </div>
      <p class="muted" style="font-size:.82rem; margin-top:-.35rem;">
        Set your self-rating here. The hard credential — Apprentice → Journeyman → Craftsman → Master —
        is earned by paid, peer-reviewed exam in <a href="/skills">the Guild</a>.
      </p>
      {#if error}<p style="color:var(--down);">{error}</p>{/if}
      {#if skillsLoading}
        <p class="muted">Loading…</p>
      {:else}
        {#if mySkills.length === 0}
          <p class="muted">No skills yet. Add one below, then sit its exam in the Guild to get certified.</p>
        {:else}
          <table>
            <thead><tr><th>Skill</th><th>Self-rating</th><th>Guild certification</th><th class="num">Reputation</th><th></th></tr></thead>
            <tbody>
              {#each mySkills as s}
                <tr>
                  <td><strong>{skillName(s.skill_id)}</strong></td>
                  <td><span class="badge {levelClass(s.self_level)}">{s.self_level}</span></td>
                  <td>
                    {#if s.certified_level}
                      <span class="badge pos">✓ {GUILD_LABEL[s.certified_level] ?? s.certified_level}</span>
                    {:else}
                      <a href="/skills" class="badge dim" style="text-decoration:none;">Uncertified — sit exam →</a>
                    {/if}
                  </td>
                  <td class="num mono dim">{skillCredit[s.skill_id]?.credit ?? 0}</td>
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
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Self-rating</span>
            <select bind:value={addLevel}>{#each LEVELS as l}<option>{l}</option>{/each}</select>
          </label>
          <button onclick={addMySkill}>Add skill</button>
        </div>
      {/if}
    </div>

    <div class="card stack">
      <h2>My resources</h2>
      <p class="muted" style="font-size:.82rem; margin-top:-.5rem;">Resources you can bring to projects (compute, funding, data, expertise…).</p>
      <div class="res-pending-note">⏳ New resources are reviewed by a steward before they can be offered to projects.</div>
      {#if skillsLoading}
        <p class="muted">Loading…</p>
      {:else}
        {#if myResources.length === 0}
          <p class="muted">No resources added yet.</p>
        {:else}
          <table>
            <thead><tr><th>Name</th><th>Type</th><th>Capacity</th><th>Availability</th><th>Review</th><th></th></tr></thead>
            <tbody>
              {#each myResources as r}
                <tr>
                  <td>{r.name}</td>
                  <td>{r.resource_type?.name ?? '—'}</td>
                  <td>{r.capacity ?? '—'}</td>
                  <td><span class="badge dim">{r.availability}</span></td>
                  <td><span class="badge {r.approval_status}">{r.approval_status === 'approved' ? '✓ approved' : r.approval_status === 'rejected' ? '✕ rejected' : '⏳ pending'}</span></td>
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

    {#if ledger.length > 0}
      <div class="card stack">
        <div class="row" style="justify-content:space-between; align-items:center;">
          <h2 style="margin:0;">Recent STR activity</h2>
          <a href="/wallet"><button class="ghost">Full ledger →</button></a>
        </div>
        <table>
          <thead><tr><th>When</th><th>Type</th><th>Reason</th><th class="num">Amount</th></tr></thead>
          <tbody>
            {#each ledger as l}
              {@const incoming = l.to_account === accountId}
              <tr>
                <td class="muted" style="font-size:.78rem;">{new Date(l.created_at).toLocaleDateString()}</td>
                <td><span class="badge dim">{l.entry_type}</span></td>
                <td class="muted" style="font-size:.82rem;">{l.reason ?? '—'}</td>
                <td class="num mono {incoming ? 'up' : 'down'}">{incoming ? '+' : '−'}{l.amount.toLocaleString()}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}

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
