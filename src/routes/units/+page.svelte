<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  type Unit = { id: string; code: string; name: string; kind: string; description: string | null; rank: number };

  let units = $state<Unit[]>([]);
  let memberCount = $state<Record<string, number>>({});
  let projectCount = $state<Record<string, number>>({});
  let loading = $state(true);

  onMount(async () => {
    if (!supabaseConfigured) { loading = false; return; }
    const [{ data: ou }, { data: oum }, { data: prj }] = await Promise.all([
      supabase.from('org_unit').select('id, code, name, kind, description, rank').order('rank'),
      supabase.from('org_unit_member').select('org_unit_id, status').eq('status', 'active'),
      supabase.from('project').select('id, org_unit_id').not('org_unit_id', 'is', null)
    ]);
    units = (ou as Unit[]) ?? [];
    const mc: Record<string, number> = {};
    for (const r of (oum as { org_unit_id: string }[]) ?? []) mc[r.org_unit_id] = (mc[r.org_unit_id] ?? 0) + 1;
    memberCount = mc;
    const pc: Record<string, number> = {};
    for (const r of (prj as { org_unit_id: string }[]) ?? []) pc[r.org_unit_id] = (pc[r.org_unit_id] ?? 0) + 1;
    projectCount = pc;
    loading = false;
  });

  const chapters = $derived(units.filter((u) => u.kind === 'chapter'));
  const wgroups = $derived(units.filter((u) => u.kind === 'working_group'));
</script>

<div class="stack">
  <div>
    <h1 style="margin-bottom:.15rem;">{$t('Chapters & Working Groups')}</h1>
    <span class="muted" style="font-size:.85rem;">{$t('Every Chapter and Working Group has its own page — its people, members and work. Open one to apply to join.')}</span>
  </div>

  {#if loading}
    <p class="muted">{$t('Loading…')}</p>
  {:else}
    <section class="stack" style="gap:.6rem;">
      <h2 style="margin:0; font-size:1.05rem;">{$t('Chapters')}</h2>
      <div class="ugrid">
        {#each chapters as u (u.id)}
          <a href={`/units/${u.id}`} class="ucard">
            <div class="row" style="justify-content:space-between; align-items:center;">
              <strong>{u.name}</strong>
              <span class="badge dim">{u.code}</span>
            </div>
            {#if u.description}<p class="udesc">{u.description}</p>{/if}
            <span class="usub">{$t('{n} members', { n: memberCount[u.id] ?? 0 })}</span>
          </a>
        {/each}
      </div>
    </section>

    <section class="stack" style="gap:.6rem;">
      <h2 style="margin:0; font-size:1.05rem;">{$t('Working Groups')}</h2>
      <div class="ugrid">
        {#each wgroups as u (u.id)}
          <a href={`/units/${u.id}`} class="ucard">
            <div class="row" style="justify-content:space-between; align-items:center;">
              <strong>{u.name}</strong>
              <span class="badge dim">{u.code}</span>
            </div>
            {#if u.description}<p class="udesc">{u.description}</p>{/if}
            <span class="usub">{$t('{n} members', { n: memberCount[u.id] ?? 0 })} · {$t('{n} projects', { n: projectCount[u.id] ?? 0 })}</span>
          </a>
        {/each}
      </div>
    </section>
  {/if}
</div>

<style>
  .ugrid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }
  .ucard {
    display: flex; flex-direction: column; gap: .4rem;
    border: 1px solid var(--border); border-radius: 10px; padding: .8rem .9rem;
    background: var(--card); text-decoration: none; color: inherit; transition: border-color .12s;
  }
  .ucard:hover { border-color: var(--accent); }
  .udesc { margin: 0; font-size: .82rem; color: var(--text-dim); line-height: 1.4;
    display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
  .usub { font-size: .76rem; color: var(--muted); }
</style>
