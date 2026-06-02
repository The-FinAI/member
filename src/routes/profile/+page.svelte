<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // ── /profile is the manage surface: everything you EDIT. Identity &
  // affiliation, and the offerable resource catalog (what you can bring). The
  // home overview台 reads your standing; this is where you change it.

  type ResType = { id: string; name: string; valuation_method: string };
  type GpuModel = { id: string; name: string; tflops: number };
  type ApiModel = { id: string; provider: string; name: string; usd_per_million: number };
  type MyResource = {
    id: string; name: string; description: string | null; capacity: string | null;
    availability: string; approval_status: string; type_id: string | null;
    resource_type: { name: string; unit: string | null } | null;
    gpu_model: { name: string } | null;
    api_model: { provider: string; name: string } | null;
  };

  const AVAIL = ['available', 'limited', 'committed'];

  let loading = $state(true);
  let error = $state('');

  // identity
  let saving = $state(false);
  let affiliation = $state('');
  let saved = $state(false);

  // resource catalog
  let resTypes = $state<ResType[]>([]);
  let myResources = $state<MyResource[]>([]);
  let gpuModels = $state<GpuModel[]>([]);
  let apiModels = $state<ApiModel[]>([]);
  let rName = $state('');
  let rType = $state('');
  let rCapacity = $state('');
  let rAvail = $state('available');
  let rGpuModel = $state('');
  let rApiModel = $state('');

  const rSelType = $derived(resTypes.find((t) => t.id === rType) ?? null);
  const rSelMethod = $derived(rSelType?.valuation_method ?? 'flat');

  // labor: a member's time, stored as a Labor-typed resource (hrs/month)
  let laborHours = $state('');
  let laborBusy = $state(false);
  const laborTypeId = $derived(resTypes.find((t) => t.name === 'Labor')?.id ?? '');
  const myLabor = $derived(myResources.find((r) => r.resource_type?.name === 'Labor') ?? null);
  $effect(() => {
    const cap = myLabor?.capacity ?? '';
    const m = cap.match(/\d+/);
    if (m && laborHours === '') laborHours = m[0];
  });

  $effect(() => { if ($member) affiliation = $member.affiliation ?? ''; });

  const catalogResources = $derived(myResources.filter((r) => r.resource_type?.name !== 'Labor'));
  const catalogTypes = $derived(resTypes.filter((t) => t.name !== 'Labor'));

  async function loadResources(memberId: string) {
    loading = true;
    const [{ data: rt }, { data: mr }, { data: gm }, { data: am }] = await Promise.all([
      supabase.from('resource_type').select('id, name, valuation_method').order('rank'),
      supabase.from('resource')
        .select('id, name, description, capacity, availability, approval_status, type_id, resource_type(name, unit), gpu_model(name), api_model(provider, name)')
        .eq('scope', 'member').eq('holder_member_id', memberId).order('name'),
      supabase.from('gpu_model').select('id, name, tflops').eq('is_active', true).order('rank'),
      supabase.from('api_model').select('id, provider, name, usd_per_million').eq('is_active', true).order('rank')
    ]);
    resTypes = (rt as ResType[]) ?? [];
    myResources = (mr as MyResource[]) ?? [];
    gpuModels = (gm as GpuModel[]) ?? [];
    apiModels = (am as ApiModel[]) ?? [];
    loading = false;
  }

  async function saveLabor() {
    error = '';
    if (!$member) return;
    const hrs = parseInt(laborHours, 10);
    if (!Number.isFinite(hrs) || hrs < 0) { error = get(t)('Enter hours per month (a number).'); return; }
    laborBusy = true;
    const capacity = `${hrs} hrs/mo`;
    let err;
    if (myLabor) {
      ({ error: err } = await supabase.from('resource').update({ capacity }).eq('id', myLabor.id));
    } else {
      ({ error: err } = await supabase.from('resource').insert({
        name: 'My time', type_id: laborTypeId || null, scope: 'member',
        holder_member_id: $member.id, capacity, availability: 'available'
      }));
    }
    laborBusy = false;
    if (err) { error = err.message; return; }
    await loadResources($member.id);
  }

  async function addResource() {
    error = '';
    if (!rName.trim() || !$member) return;
    const { error: err } = await supabase.from('resource').insert({
      name: rName.trim(), type_id: rType || null, scope: 'member',
      holder_member_id: $member.id, capacity: rCapacity || null, availability: rAvail,
      gpu_model_id: rSelMethod === 'gpu' ? (rGpuModel || null) : null,
      api_model_id: rSelMethod === 'api' ? (rApiModel || null) : null
    });
    if (err) { error = err.message; return; }
    rName = ''; rType = ''; rCapacity = ''; rAvail = 'available'; rGpuModel = ''; rApiModel = '';
    await loadResources($member.id);
  }

  async function removeResource(id: string) {
    if (!$member) return;
    const { error: err } = await supabase.from('resource').delete().eq('id', id);
    if (err) { error = err.message; return; }
    await loadResources($member.id);
  }

  async function save() {
    if (!supabaseConfigured || !$member) return;
    saving = true; saved = false;
    const { error: err } = await supabase.from('member').update({ affiliation }).eq('id', $member.id);
    saving = false;
    if (!err) { saved = true; member.update((m) => (m ? { ...m, affiliation } : m)); }
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; return; }
    const unsub = member.subscribe((m) => {
      if (m) loadResources(m.id);
      else loading = false;
    });
    return unsub;
  });
</script>

<div class="stack">
  <header class="page-head">
    <div class="stack" style="gap:.25rem;">
      <h1 style="margin:0;">{$t('Profile & resources')}</h1>
      <p class="muted" style="margin:0; font-size:.88rem;">{$t('Your identity, and the catalog of what you can bring to projects.')}</p>
    </div>
    <a class="back-link muted" href="/">← {$t('Overview')}</a>
  </header>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  <!-- identity + capabilities -->
  {#if $member}
    <div class="card stack">
      <h2 style="margin:0;">{$t('Identity')}</h2>
      <div>
        <div><strong>{$member.full_name}</strong></div>
        <div class="muted">{$member.email}</div>
      </div>
      <label class="stack" style="gap:.3rem;">
        <span class="muted" style="font-size:.8rem;">{$t('Affiliation')}</span>
        <input bind:value={affiliation} placeholder={$t('e.g. University / Lab')} />
      </label>
      <div class="row">
        <button onclick={save} disabled={saving}>{saving ? $t('Saving…') : $t('Save')}</button>
        {#if saved}<span class="badge">{$t('Saved')}</span>{/if}
      </div>
      <div class="stack" style="gap:.3rem; border-top:1px solid var(--border); padding-top:.6rem;">
        <span class="muted" style="font-size:.8rem;">{$t('Capabilities')}</span>
        {#if $capabilities.size === 0}
          <p class="muted" style="margin:0;">{$t('Standard member — no admin capabilities.')}</p>
        {:else}
          <div class="row" style="flex-wrap:wrap; gap:.35rem;">{#each [...$capabilities] as c}<span class="badge">{c}</span>{/each}</div>
        {/if}
      </div>
    </div>
  {/if}

  <!-- resources: an offerable catalog (what I can bring), steward-gated -->
  <div class="card stack">
    <h2 style="margin:0;">{$t('What I can bring')}</h2>
    <p class="muted" style="font-size:.82rem; margin-top:-.35rem;">{$t("Your offerable catalog — time, compute, funding, data. You pledge specific amounts to a project when you join it; this is just what's available.")}</p>

    <!-- labor / time -->
    <div class="stack" style="gap:.4rem; border:1px solid var(--border); border-radius:8px; padding:.6rem .75rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <strong style="font-size:.9rem;">⏱ {$t('Time I can commit')}</strong>
        {#if myLabor}<span class="badge {myLabor.approval_status}">{myLabor.approval_status === 'approved' ? $t('✓ approved') : myLabor.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span>{/if}
      </div>
      <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Hours per month')}</span>
          <input type="number" min="0" bind:value={laborHours} placeholder={$t('e.g. 40')} style="width:120px;" /></label>
        <button onclick={saveLabor} disabled={laborBusy}>{laborBusy ? $t('Saving…') : myLabor ? $t('Update time') : $t('Set time')}</button>
      </div>
      <p class="muted" style="font-size:.75rem; margin:0;">{@html $t('Valued at the community’s monthly <code>labor rate</code> and minted into a project once you pledge the hours.')}</p>
    </div>

    <div class="res-pending-note">{$t('⏳ New resources are reviewed by a steward before they can be offered to projects.')}</div>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else}
      {#if catalogResources.length === 0}
        <p class="muted">{$t('No other resources added yet.')}</p>
      {:else}
        <table>
          <thead><tr><th>{$t('Name')}</th><th>{$t('Type')}</th><th>{$t('Capacity')}</th><th>{$t('Availability')}</th><th>{$t('Review')}</th><th></th></tr></thead>
          <tbody>
            {#each catalogResources as r}
              <tr>
                <td>{r.name}{#if r.gpu_model || r.api_model}<div class="muted" style="font-size:.75rem;">{r.gpu_model?.name ?? `${r.api_model?.provider} ${r.api_model?.name}`}</div>{/if}</td>
                <td>{r.resource_type?.name ?? '—'}</td>
                <td>{r.capacity ?? '—'}{#if r.capacity && r.resource_type?.unit}<span class="muted" style="font-size:.75rem;"> {r.resource_type.unit}</span>{/if}</td>
                <td><span class="badge dim">{$t(r.availability)}</span></td>
                <td><span class="badge {r.approval_status}">{r.approval_status === 'approved' ? $t('✓ approved') : r.approval_status === 'rejected' ? $t('✕ rejected') : $t('⏳ pending')}</span></td>
                <td><button class="danger" onclick={() => removeResource(r.id)}>{$t('Remove')}</button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}

      <div class="row" style="align-items:flex-end; flex-wrap:wrap; border-top:1px dashed var(--border); padding-top:.75rem;">
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Name')}</span>
          <input bind:value={rName} placeholder={$t('e.g. RTX 4090 ×2')} /></label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Type')}</span>
          <select bind:value={rType}><option value="">—</option>{#each catalogTypes as ct}<option value={ct.id}>{ct.name}</option>{/each}</select></label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Capacity')}</span>
          <input bind:value={rCapacity} placeholder={$t('optional')} style="width:120px;" /></label>
        <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('Availability')}</span>
          <select bind:value={rAvail}>{#each AVAIL as a}<option value={a}>{$t(a)}</option>{/each}</select></label>
        {#if rSelMethod === 'gpu'}
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('GPU model')}</span>
            <select bind:value={rGpuModel}><option value="">{$t('— pick —')}</option>{#each gpuModels as g}<option value={g.id}>{g.name} · {g.tflops} TFLOPs</option>{/each}</select></label>
        {:else if rSelMethod === 'api'}
          <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.75rem;">{$t('API model')}</span>
            <select bind:value={rApiModel}><option value="">{$t('— pick —')}</option>{#each apiModels as a}<option value={a.id}>{a.provider} {a.name} · ${a.usd_per_million}/M</option>{/each}</select></label>
        {/if}
        <button onclick={addResource}>{$t('Add resource')}</button>
      </div>
      {#if rSelMethod === 'gpu' || rSelMethod === 'api'}
        <p class="muted" style="font-size:.78rem; margin-top:-.4rem;">{$t('Pick the closest model — its built-in throughput/price sets the USD→STR conversion when you declare monthly usage on a project.')}</p>
      {/if}
    {/if}
  </div>
</div>

<style>
  .page-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
  .back-link { font-size: .85rem; white-space: nowrap; }
  .back-link:hover { color: var(--accent); }
  .res-pending-note { font-size: .78rem; color: var(--muted); }
</style>
