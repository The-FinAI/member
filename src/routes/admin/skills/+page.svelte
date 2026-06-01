<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities } from '$lib/session';

  type Skill = { id: string; parent_id: string | null; name: string; master_member_id: string | null };
  type Mem = { id: string; full_name: string };

  let skills = $state<Skill[]>([]);
  let members = $state<Mem[]>([]);
  let loading = $state(true);
  let error = $state('');
  let newName = $state('');
  let newParent = $state('');
  let busy = $state('');

  const canGuild = $derived($capabilities.has('manage_guild'));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data, error: err }, { data: mem }] = await Promise.all([
      supabase.from('skill').select('id, parent_id, name, master_member_id').order('name'),
      supabase.from('member').select('id, full_name').eq('status', 'active').order('full_name')
    ]);
    if (err) error = err.message;
    skills = (data as Skill[]) ?? [];
    members = (mem as Mem[]) ?? [];
    loading = false;
  }

  onMount(load);

  const roots = $derived(skills.filter((s) => !s.parent_id));
  function childrenOf(id: string) { return skills.filter((s) => s.parent_id === id); }
  function memberName(id: string | null) {
    return id ? (members.find((m) => m.id === id)?.full_name ?? 'Unknown') : '';
  }

  async function add() {
    error = '';
    if (!newName.trim()) return;
    const { error: err } = await supabase
      .from('skill')
      .insert({ name: newName.trim(), parent_id: newParent || null });
    if (err) { error = err.message; return; }
    newName = '';
    await load();
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from('skill').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }

  async function appointMaster(skillId: string, memberId: string) {
    if (!memberId) return;
    error = ''; busy = skillId;
    const { error: err } = await supabase.rpc('appoint_skill_master', { p_skill: skillId, p_member: memberId });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Skill Tree</h1>
  <p class="muted" style="margin-top:-.75rem;">
    Hierarchical skills. Leaves are examinable crafts in <a href="/skills">the Guild</a>; needs filter on these.
    {#if canGuild}You may also <strong>appoint a master</strong> per leaf — they own its rubric and seed the reviewer pool.{/if}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card row">
    <input placeholder="New skill name" bind:value={newName} />
    <select bind:value={newParent}>
      <option value="">— top-level category —</option>
      {#each roots as r}<option value={r.id}>{r.name}</option>{/each}
    </select>
    <button onclick={add}>Add skill</button>
  </div>

  <div class="card">
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if roots.length === 0}
      <p class="muted">No skills yet.</p>
    {:else}
      {#each roots as root}
        <div style="margin-bottom:1rem;">
          <div class="row" style="justify-content:space-between;">
            <strong>{root.name}</strong>
            <button class="danger" onclick={() => remove(root.id)}>Delete</button>
          </div>
          <ul style="margin:.4rem 0 0; padding-left:1.2rem; list-style:none;">
            {#each childrenOf(root.id) as child}
              <li class="row" style="justify-content:space-between; align-items:center; gap:.6rem; max-width:640px; padding:.2rem 0;">
                <span style="flex:1;">{child.name}</span>
                {#if child.master_member_id}
                  <span class="badge pos" style="font-size:.72rem;">👑 {memberName(child.master_member_id)}</span>
                {:else}
                  <span class="badge dim" style="font-size:.72rem;">no master</span>
                {/if}
                {#if canGuild}
                  <select
                    disabled={busy === child.id}
                    onchange={(e) => { appointMaster(child.id, e.currentTarget.value); e.currentTarget.value = ''; }}
                    style="max-width:180px;"
                  >
                    <option value="">{child.master_member_id ? 'Reassign master…' : 'Appoint master…'}</option>
                    {#each members as m}<option value={m.id}>{m.full_name}</option>{/each}
                  </select>
                {/if}
                <button class="danger" onclick={() => remove(child.id)}>Delete</button>
              </li>
            {/each}
          </ul>
        </div>
      {/each}
    {/if}
  </div>
</div>
