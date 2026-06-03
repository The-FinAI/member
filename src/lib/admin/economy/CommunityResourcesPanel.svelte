<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import ResourceForgeForm from '$lib/resources/ResourceForgeForm.svelte';

  // Forge community-owned resources — the SAME type-adaptive form the member
  // profile uses (ResourceForgeForm), here with a holder picker and scope=community.
  type Member = { id: string; full_name: string };
  type Resrc = {
    id: string; name: string; monthly_quota: number; unit: string | null;
    resource_type: { name: string } | null; holder: { full_name: string } | null;
    forge_request: { status: string } | null;
  };

  let members = $state<Member[]>([]);
  let resources = $state<Resrc[]>([]);
  let fHolder = $state('');
  let loading = $state(true);

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true;
    const [{ data: mem }, { data: rs }] = await Promise.all([
      supabase.from('member').select('id, full_name').order('full_name'),
      supabase.from('resource')
        .select('id, name, monthly_quota, unit, resource_type:type_id(name), holder:holder_member_id(full_name), forge_request:forge_request_id(status)')
        .eq('scope', 'community').order('created_at', { ascending: false })
    ]);
    members = (mem as Member[]) ?? [];
    resources = (rs as Resrc[]) ?? [];
    loading = false;
  }
  onMount(load);
</script>

<p class="muted blurb">{$t('Resources the community owns — compute, data, funding. Each needs an in-community holder (steward) and goes through the forge queue.')}</p>

<div class="card" style="padding:1rem;">
  <ResourceForgeForm bind:holder={fHolder} scope="community" holderPicker={true} members={members} onForged={load} />
</div>

<section>
  <span class="sec">{$t('Community resources')}{#if resources.length}<span class="ct"> · {resources.length}</span>{/if}</span>
  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else if resources.length === 0}
    <p class="muted">{$t('None yet.')}</p>
  {:else}
    <div class="rlist">
      {#each resources as r (r.id)}
        <div class="r">
          <div class="r-main">
            <span class="r-name">{r.name}</span>
            <span class="r-sub">{r.resource_type?.name ?? '—'} · {r.holder?.full_name ?? '—'}</span>
          </div>
          <span class="r-quota mono">{r.monthly_quota?.toLocaleString()} {r.unit ?? ''}/mo</span>
          {#if r.forge_request?.status && r.forge_request.status !== 'approved'}<span class="badge dim">{$t(r.forge_request.status)}</span>{/if}
        </div>
      {/each}
    </div>
  {/if}
</section>

<style>
  .blurb { margin: 0 0 .6rem; font-size: .85rem; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .ct { color: var(--text-dim); }
  .rlist { display: flex; flex-direction: column; gap: .4rem; margin-top: .4rem; }
  .r { display: flex; align-items: center; gap: .8rem; padding: .55rem .8rem; border: 1px solid var(--border); border-radius: 10px; background: var(--card); }
  .r-main { display: flex; flex-direction: column; gap: .1rem; flex: 1; min-width: 0; }
  .r-name { font-weight: 600; color: var(--text); }
  .r-sub { font-size: .78rem; color: var(--muted); }
  .r-quota { font-size: .82rem; color: var(--text-dim); white-space: nowrap; }
</style>
