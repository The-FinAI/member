<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';

  type Type = { id: string; name: string };
  type Member = { id: string; full_name: string };
  type Resource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; type_id: string | null; holder_member_id: string | null;
    resource_type: { name: string } | null; member: { full_name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let resources = $state<Resource[]>([]);
  let types = $state<Type[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true);
  let error = $state('');

  // new community resource
  let name = $state('');
  let typeId = $state('');
  let steward = $state('');
  let capacity = $state('');
  let availability = $state('available');
  let description = $state('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: r }, { data: t }, { data: m }] = await Promise.all([
      supabase.from('resource')
        .select('id, name, description, capacity, availability, type_id, holder_member_id, resource_type(name), member:holder_member_id(full_name)')
        .eq('scope', 'community').order('name'),
      supabase.from('resource_type').select('id, name').order('rank'),
      // only members who hold a position can steward a community resource
      supabase.from('member_position').select('member(id, full_name)')
    ]);
    resources = (r as Resource[]) ?? [];
    types = (t as Type[]) ?? [];
    const seen = new Map<string, string>();
    for (const row of (m as any[]) ?? []) {
      const mm = row.member;
      if (mm) seen.set(mm.id, mm.full_name);
    }
    members = [...seen].map(([id, full_name]) => ({ id, full_name })).sort((a, b) => a.full_name.localeCompare(b.full_name));
    loading = false;
  }

  onMount(load);

  async function add() {
    error = '';
    if (!name.trim()) { error = 'Name is required.'; return; }
    const { error: err } = await supabase.from('resource').insert({
      name: name.trim(), type_id: typeId || null, scope: 'community',
      holder_member_id: steward || null, capacity: capacity || null,
      availability, description: description || null
    });
    if (err) { error = err.message; return; }
    name = ''; typeId = ''; steward = ''; capacity = ''; availability = 'available'; description = '';
    await load();
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from('resource').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← Admin</a></p>
  <h1>Community Resources</h1>
  <p class="muted" style="margin-top:-.75rem;">
    Resources owned by the community. Each is stewarded by a position-holder who is the point of
    contact. (Personal resources are added by members on their own profile.)
  </p>

  {#if error}<p style="color:#b91c1c;">{error}</p>{/if}

  <div class="card stack">
    <h2>Add a community resource</h2>
    <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Name</span>
        <input bind:value={name} placeholder="e.g. 8×A100 cluster" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Type</span>
        <select bind:value={typeId}><option value="">—</option>{#each types as t}<option value={t.id}>{t.name}</option>{/each}</select></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Steward</span>
        <select bind:value={steward}><option value="">—</option>{#each members as m}<option value={m.id}>{m.full_name}</option>{/each}</select></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Capacity</span>
        <input bind:value={capacity} placeholder="e.g. $5k / 200 GPU-hrs" style="width:140px;" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">Availability</span>
        <select bind:value={availability}>{#each AVAIL as a}<option>{a}</option>{/each}</select></label>
      <button onclick={add}>Add</button>
    </div>
    <input bind:value={description} placeholder="Description (optional)" style="width:100%;" />
  </div>

  <div class="card">
    <h2>Community resources</h2>
    {#if loading}
      <p class="muted">Loading…</p>
    {:else if resources.length === 0}
      <p class="muted">None yet.</p>
    {:else}
      <table>
        <thead><tr><th>Name</th><th>Type</th><th>Steward</th><th>Capacity</th><th>Availability</th><th></th></tr></thead>
        <tbody>
          {#each resources as r}
            <tr>
              <td><strong>{r.name}</strong>{#if r.description}<div class="muted" style="font-size:.8rem;">{r.description}</div>{/if}</td>
              <td>{r.resource_type?.name ?? '—'}</td>
              <td>{r.member?.full_name ?? '—'}</td>
              <td>{r.capacity ?? '—'}</td>
              <td><span class="badge">{r.availability}</span></td>
              <td><button class="danger" onclick={() => remove(r.id)}>Delete</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>
