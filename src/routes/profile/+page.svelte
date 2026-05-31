<script lang="ts">
  import { onMount } from 'svelte';
  import { member, capabilities } from '$lib/session';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  const LEVELS = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  type Skill = { id: string; name: string; parent_id: string | null };
  type MySkill = { skill_id: string; self_level: string };

  let saving = $state(false);
  let affiliation = $state('');
  let saved = $state(false);

  let skills = $state<Skill[]>([]);
  let mySkills = $state<MySkill[]>([]);
  let endorseCounts = $state<Record<string, number>>({});
  let addSkill = $state('');
  let addLevel = $state('Intermediate');
  let skillsLoading = $state(true);
  let error = $state('');

  $effect(() => { if ($member) affiliation = $member.affiliation ?? ''; });

  async function loadSkills(memberId: string) {
    skillsLoading = true;
    const [{ data: tree }, { data: ms }, { data: end }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, self_level').eq('member_id', memberId),
      supabase.from('skill_endorsement').select('skill_id').eq('member_id', memberId)
    ]);
    skills = (tree as Skill[]) ?? [];
    mySkills = (ms as MySkill[]) ?? [];
    const counts: Record<string, number> = {};
    for (const e of (end as { skill_id: string }[]) ?? []) counts[e.skill_id] = (counts[e.skill_id] ?? 0) + 1;
    endorseCounts = counts;
    skillsLoading = false;
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
      <h2>My skills</h2>
      {#if error}<p style="color:#b91c1c;">{error}</p>{/if}
      {#if skillsLoading}
        <p class="muted">Loading…</p>
      {:else}
        {#if mySkills.length === 0}
          <p class="muted">No skills added yet.</p>
        {:else}
          <table>
            <thead><tr><th>Skill</th><th>Self-rating</th><th>Endorsements</th><th></th></tr></thead>
            <tbody>
              {#each mySkills as s}
                <tr>
                  <td>{skillName(s.skill_id)}</td>
                  <td><span class="badge">{s.self_level}</span></td>
                  <td>{endorseCounts[s.skill_id] ?? 0}</td>
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
