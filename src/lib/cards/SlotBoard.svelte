<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';
  import ProjectSlotCard, { type Slot, type Proj } from './ProjectSlotCard.svelte';
  import ForgeCard from './ForgeCard.svelte';

  // WG officer console — the slot board. Claim unclaimed project cards, post
  // needs (forge), seat map per project, and mint completion (→ Settle).
  let { unitId }: { unitId: string } = $props();

  type Skill = { id: string; name: string; parent_id: string | null };
  type ResType = { id: string; name: string; unit: string | null };

  let unit = $state<{ id: string; name: string; kind: string } | null>(null);
  let projects = $state<Proj[]>([]);
  let slotsByProject = $state<Record<string, Slot[]>>({});
  let unclaimed = $state<Proj[]>([]);
  let skills = $state<Skill[]>([]);
  let resTypes = $state<ResType[]>([]);
  let loading = $state(true);
  let msg = $state(''); let busy = $state('');
  let postNeedFor = $state<Proj | null>(null);

  const ym = new Date().toISOString().slice(0, 7);
  const isOfficer = $derived(
    !!unit && (get(capabilities).has('edit_any_project') || get(officerUnits).some((u) => u.unit_id === unit!.id))
  );

  function bucket(p: Proj): string {
    if (/finish/i.test(p.status)) return 'done';
    const slots = slotsByProject[p.id] ?? [];
    const needs = slots.filter((s) => s.slot_kind !== 'leader');
    if (!needs.length) return 'no-need';
    const openGap = needs.some((s) => s.members.length < s.headcount);
    return openGap ? 'open' : 'filled';
  }

  async function load(uid: string) {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; msg = '';
    const { data: u } = await supabase.from('org_unit').select('id, name, kind').eq('id', uid).maybeSingle();
    if (!u) { unit = null; loading = false; return; }
    unit = u as any;

    const [{ data: claimed }, { data: free }, { data: sk }, { data: rt }] = await Promise.all([
      supabase.from('project').select('id, name, deadline, project_status!project_status_id_fkey(name)').eq('org_unit_id', uid).order('name'),
      supabase.from('project').select('id, name, deadline, project_status!project_status_id_fkey(name)').is('org_unit_id', null).order('name').limit(50),
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('resource_type').select('id, name, unit').order('rank')
    ]);
    projects = ((claimed as any[]) ?? []).map((p) => ({ id: p.id, name: p.name, deadline: p.deadline, status: p.project_status?.name ?? '—' }));
    unclaimed = ((free as any[]) ?? []).map((p) => ({ id: p.id, name: p.name, deadline: p.deadline, status: p.project_status?.name ?? '—' }));
    skills = (sk as Skill[]) ?? [];
    resTypes = (rt as ResType[]) ?? [];

    const pids = projects.map((p) => p.id);
    if (pids.length) {
      const { data: sl } = await supabase.from('project_slot')
        .select('id, project_id, slot_kind, req_access, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name)')
        .in('project_id', pids);
      const slots = (sl as any[]) ?? [];
      const slotIds = slots.map((s) => s.id);
      const memMap: Record<string, { id: string; name: string; amount: number; unit: string }[]> = {};
      if (slotIds.length) {
        const { data: wc } = await supabase.from('work_commitment')
          .select('slot_id, member_id, monthly_amount, member:member_id(full_name), resource:resource_id(unit)')
          .in('slot_id', slotIds);
        for (const w of (wc as any[]) ?? []) {
          const arr = (memMap[w.slot_id] ??= []);
          if (arr.some((m) => m.id === w.member_id)) continue;
          arr.push({ id: w.member_id, name: w.member?.full_name ?? '—', amount: Number(w.monthly_amount) || 0, unit: w.resource?.unit ?? 'h' });
        }
      }
      const byP: Record<string, Slot[]> = {};
      for (const s of slots) {
        (byP[s.project_id] ??= []).push({
          id: s.id, slot_kind: s.slot_kind, skill_name: s.skill?.name ?? null,
          resource_type_name: s.resource_type?.name ?? null, req_access: s.req_access,
          quota: s.quota, headcount: s.headcount ?? 1, status: s.status,
          members: memMap[s.id] ?? []
        });
      }
      slotsByProject = byP;
    } else {
      slotsByProject = {};
    }
    loading = false;
  }

  async function doClaim(p: Proj) {
    busy = p.id;
    const { error: e } = await supabase.rpc('forge_claim', { p_project: p.id, p_wg_unit: unitId });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Project claimed.'); await load(unitId);
  }

  async function doPostNeed(payload: Record<string, any>) {
    if (!postNeedFor) return;
    busy = 'need';
    const { error: e } = await supabase.rpc('forge_need', {
      p_project: postNeedFor.id, p_slot_kind: payload.slot_kind,
      p_req_access: payload.req_access, p_skill: payload.skill,
      p_resource_type: payload.resource_type, p_quota: payload.quota,
      p_headcount: payload.headcount, p_requirements: payload.requirements ?? []
    });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Need submitted for review.'); postNeedFor = null; await load(unitId);
  }

  async function doMintDone(p: Proj) {
    busy = p.id;
    const { error: e } = await supabase.rpc('forge_project_done', { p_project: p.id });
    busy = '';
    if (e) { msg = e.message; return; }
    msg = get(t)('Completion submitted for review.'); await load(unitId);
  }

  let lastId = '';
  $effect(() => { if (unitId && unitId !== lastId) { lastId = unitId; load(unitId); } });
</script>

{#if loading}
  <div class="sk sk-row"></div><div class="sk sk-row"></div>
{:else if !unit}
  <p class="muted">{$t('Working group not found.')}</p>
{:else}
  <div class="board">
    <header class="sb-head">
      <div>
        <h2 class="sb-title">{unit.name}</h2>
        <p class="sb-sub">{$t('{n} claimed projects', { n: projects.length })} · {$t('Month {ym}', { ym })}</p>
      </div>
    </header>

    {#if msg}<p class="sb-msg">{msg}</p>{/if}

    {#if isOfficer && unclaimed.length}
      <section class="sb-sec">
        <h3 class="sb-sec-h">{$t('Unclaimed projects')}</h3>
        <div class="sb-claims">
          {#each unclaimed as p (p.id)}
            <div class="claim-row">
              <span class="claim-name">{p.name}</span>
              <span class="badge dim">{p.status}</span>
              <button type="button" class="chip toggle" disabled={busy === p.id} onclick={() => doClaim(p)}>
                {#if busy === p.id}<span class="spin"></span>{/if}{$t('Claim')}
              </button>
            </div>
          {/each}
        </div>
      </section>
    {/if}

    <section class="sb-sec">
      <h3 class="sb-sec-h">{$t('My projects')}</h3>
      <div class="sb-projects rise-stagger">
        {#each projects as p (p.id)}
          <ProjectSlotCard
            project={p}
            slots={slotsByProject[p.id] ?? []}
            canManage={isOfficer}
            onPostNeed={() => (postNeedFor = p)}
            onMintDone={() => doMintDone(p)}
          />
        {/each}
        {#if !projects.length}
          <p class="muted">{$t('No claimed projects yet — claim one above.')}</p>
        {/if}
      </div>
    </section>
  </div>

  {#if postNeedFor}
    <div class="matcher-backdrop" onclick={() => (postNeedFor = null)} role="presentation"></div>
    <aside class="forge-drawer" role="dialog">
      <header class="fd-head">
        <span>{$t('Post need')} · {postNeedFor.name}</span>
        <button type="button" class="x" onclick={() => (postNeedFor = null)}>✕</button>
      </header>
      <div class="fd-body">
        <ForgeCard mode="need" {skills} resourceTypes={resTypes} busy={busy === 'need'}
          onSubmit={doPostNeed} onCancel={() => (postNeedFor = null)} />
      </div>
    </aside>
  {/if}
{/if}

<style>
  .board { display: flex; flex-direction: column; gap: 1.1rem; }
  .sb-title { font-size: 1.25rem; font-weight: 600; color: var(--text); margin: 0; }
  .sb-sub { font-size: .82rem; color: var(--muted); margin: .2rem 0 0; }
  .sb-msg { font-size: .85rem; color: var(--accent); }
  .sb-sec-h { font-size: .74rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: 0 0 .6rem; }
  .sb-claims { display: flex; flex-direction: column; gap: .4rem; }
  .claim-row { display: flex; align-items: center; gap: .6rem; padding: .5rem .7rem; border: 1px solid var(--border); border-radius: var(--r-sm); background: var(--card); }
  .claim-name { font-weight: 500; color: var(--text); flex: 1; min-width: 0; }
  .claim-row .chip.toggle { flex: none; }
  .sb-projects { display: flex; flex-direction: column; gap: .6rem; }
  .muted { color: var(--muted); font-size: .88rem; }

  .matcher-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 80; }
  .forge-drawer {
    position: fixed; top: 0; right: 0; bottom: 0; width: min(400px, 100vw); z-index: 90;
    background: var(--card); border-left: 1px solid var(--border-2); box-shadow: var(--shadow);
    display: flex; flex-direction: column;
  }
  .fd-head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.1rem; border-bottom: 1px solid var(--border); font-weight: 600; color: var(--text); }
  .fd-body { padding: 1rem 1.1rem; }
  .x { background: transparent; border: 0; color: var(--muted); font-size: 1rem; cursor: pointer; }
  .x:hover { color: var(--text); filter: none; }
</style>
