<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Type = { id: string; name: string; valuation_method: string };
  type GpuModel = { id: string; name: string; tflops: number };
  type ApiModel = { id: string; provider: string; name: string; usd_per_million: number };
  type Member = { id: string; full_name: string };
  type Resource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; type_id: string | null; holder_member_id: string | null;
    approval_status: string; scope: string;
    resource_type: { name: string } | null; member: { full_name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let resources = $state<Resource[]>([]);
  let pending = $state<Resource[]>([]);
  let types = $state<Type[]>([]);
  let gpuModels = $state<GpuModel[]>([]);
  let apiModels = $state<ApiModel[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  // new community resource
  let name = $state('');
  let typeId = $state('');
  let steward = $state('');
  let capacity = $state('');
  let availability = $state('available');
  let description = $state('');
  let gpuModelId = $state('');
  let apiModelId = $state('');

  const selType = $derived(types.find((ty) => ty.id === typeId) ?? null);
  const selMethod = $derived(selType?.valuation_method ?? 'flat');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const sel = 'id, name, description, capacity, availability, type_id, holder_member_id, approval_status, scope, resource_type(name), member:holder_member_id(full_name)';
    const [{ data: r }, { data: pq }, { data: t }, { data: gm }, { data: am }, { data: m }] = await Promise.all([
      supabase.from('resource').select(sel).eq('scope', 'community').order('name'),
      supabase.from('resource').select(sel).eq('approval_status', 'pending').order('created_at', { ascending: false }),
      supabase.from('resource_type').select('id, name, valuation_method').order('rank'),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank'),
      // only members who hold a position can steward a community resource
      supabase.from('member_position').select('member(id, full_name)')
    ]);
    resources = (r as Resource[]) ?? [];
    pending = (pq as Resource[]) ?? [];
    types = (t as Type[]) ?? [];
    gpuModels = (gm as GpuModel[]) ?? [];
    apiModels = (am as ApiModel[]) ?? [];
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
    if (!name.trim()) { error = get(t)('Name is required.'); return; }
    const { error: err } = await supabase.from('resource').insert({
      name: name.trim(), type_id: typeId || null, scope: 'community',
      holder_member_id: steward || null, capacity: capacity || null,
      availability, description: description || null, approval_status: 'approved',
      gpu_model_id: selMethod === 'gpu' ? (gpuModelId || null) : null,
      api_model_id: selMethod === 'api' ? (apiModelId || null) : null
    });
    if (err) { error = err.message; return; }
    name = ''; typeId = ''; steward = ''; capacity = ''; availability = 'available'; description = ''; gpuModelId = ''; apiModelId = '';
    await load();
  }

  async function remove(id: string) {
    error = '';
    const { error: err } = await supabase.from('resource').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await load();
  }

  async function review(id: string, status: 'approved' | 'rejected') {
    error = ''; busy = id;
    const { error: err } = await supabase.from('resource').update({ approval_status: status }).eq('id', id);
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Community Resources')}</h1>
  <p class="muted" style="margin-top:-.75rem;">
    {$t('Resources owned by the community. Each is stewarded by a position-holder who is the point of contact. (Personal resources are added by members on their own profile.)')}
  </p>

  {#if error}<p style="color:var(--down);">{error}</p>{/if}

  <div class="card stack">
    <div class="row" style="justify-content:space-between; align-items:center;">
      <h2 style="margin:0;">{$t('Pending approvals')}</h2>
      {#if pending.length}<span class="badge warn">{$t('{n} waiting', { n: pending.length })}</span>{/if}
    </div>
    <p class="muted" style="font-size:.82rem; margin-top:-.3rem;">
      {$t("Member-submitted resources can't be offered to projects until a steward approves them.")}
    </p>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if pending.length === 0}
      <p class="muted">{$t('Nothing waiting for review.')}</p>
    {:else}
      <table>
        <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Submitted by')}</th><th>{$t('Scope')}</th><th></th></tr></thead>
        <tbody>
          {#each pending as r}
            <tr>
              <td><strong>{r.name}</strong>{#if r.description}<div class="muted" style="font-size:.8rem;">{r.description}</div>{/if}{#if r.capacity}<div class="muted" style="font-size:.78rem;">{$t('Capacity: {c}', { c: r.capacity })}</div>{/if}</td>
              <td>{r.resource_type?.name ?? '—'}</td>
              <td>{r.member?.full_name ?? '—'}</td>
              <td><span class="badge dim">{$t(r.scope)}</span></td>
              <td class="row">
                <button disabled={busy === r.id} onclick={() => review(r.id, 'approved')}>{$t('Approve')}</button>
                <button class="danger" disabled={busy === r.id} onclick={() => review(r.id, 'rejected')}>{$t('Reject')}</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <div class="card stack">
    <h2>{$t('Add a community resource')}</h2>
    <div class="row" style="align-items:flex-end; flex-wrap:wrap;">
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Name')}</span>
        <input bind:value={name} placeholder={$t('e.g. 8×A100 cluster')} /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type')}</span>
        <select bind:value={typeId}><option value="">—</option>{#each types as ty}<option value={ty.id}>{ty.name}</option>{/each}</select></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Steward')}</span>
        <select bind:value={steward}><option value="">—</option>{#each members as m}<option value={m.id}>{m.full_name}</option>{/each}</select></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Capacity')}</span>
        <input bind:value={capacity} placeholder={$t('e.g. $5k / 200 GPU-hrs')} style="width:140px;" /></label>
      <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Availability')}</span>
        <select bind:value={availability}>{#each AVAIL as a}<option value={a}>{$t(a)}</option>{/each}</select></label>
      {#if selMethod === 'gpu'}
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('GPU model')}</span>
          <select bind:value={gpuModelId}><option value="">{$t('— pick —')}</option>{#each gpuModels as g}<option value={g.id}>{g.name} · {g.tflops} TFLOPs</option>{/each}</select></label>
      {:else if selMethod === 'api'}
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('API model')}</span>
          <select bind:value={apiModelId}><option value="">{$t('— pick —')}</option>{#each apiModels as a}<option value={a.id}>{a.provider} {a.name} · ${a.usd_per_million}/M</option>{/each}</select></label>
      {/if}
      <button onclick={add}>{$t('Add')}</button>
    </div>
    <input bind:value={description} placeholder={$t('Description (optional)')} style="width:100%;" />
  </div>

  <div class="card">
    <h2>{$t('Community resources')}</h2>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if resources.length === 0}
      <p class="muted">{$t('None yet.')}</p>
    {:else}
      <table>
        <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Steward')}</th><th>{$t('Capacity')}</th><th>{$t('Availability')}</th><th></th></tr></thead>
        <tbody>
          {#each resources as r}
            <tr>
              <td><strong>{r.name}</strong>{#if r.description}<div class="muted" style="font-size:.8rem;">{r.description}</div>{/if}</td>
              <td>{r.resource_type?.name ?? '—'}</td>
              <td>{r.member?.full_name ?? '—'}</td>
              <td>{r.capacity ?? '—'}</td>
              <td><span class="badge">{$t(r.availability)}</span></td>
              <td><button class="danger" onclick={() => remove(r.id)}>{$t('Delete')}</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>

  <div class="card stack">
    <h2 style="margin:0;">{$t('GPU catalogue')}</h2>
    <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">{$t('Built-in GPU models with FP16/BF16 dense TFLOPs. A gpu-type resource picks one; monthly GPU-hours × TFLOPs × the cloud $/TFLOP-hour policy gives its USD value.')}</p>
    <LookupEditor
      table="gpu_model"
      columns={[
        { key: 'name', label: 'Name' },
        { key: 'tflops', label: 'TFLOPs', type: 'number' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'is_active', label: 'Active', type: 'bool' }
      ]}
    />
  </div>

  <div class="card stack">
    <h2 style="margin:0;">{$t('API catalogue')}</h2>
    <p class="muted" style="font-size:.82rem; margin:-.3rem 0 0;">{$t('Built-in API models with a blended USD price per 1M tokens. An api-type resource picks one; monthly millions-of-tokens × the price gives its USD value.')}</p>
    <LookupEditor
      orderBy="rank"
      table="api_model"
      columns={[
        { key: 'provider', label: 'Provider' },
        { key: 'name', label: 'Name' },
        { key: 'usd_per_million', label: 'USD / 1M', type: 'number' },
        { key: 'rank', label: 'Rank', type: 'number' },
        { key: 'is_active', label: 'Active', type: 'bool' }
      ]}
    />
  </div>
</div>
