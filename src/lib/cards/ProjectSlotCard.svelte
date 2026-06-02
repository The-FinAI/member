<script lang="ts">
  import { t } from '$lib/i18n';

  export type SlotMember = { id: string; name: string; amount: number; unit: string };
  export type Slot = {
    id: string;
    slot_kind: 'leader' | 'work_labor' | 'work_resource';
    skill_name: string | null;
    resource_type_name: string | null;
    req_access: string | null;
    quota: number | null;
    headcount: number;
    status: string;
    members: SlotMember[];
  };
  export type Proj = { id: string; name: string; status: string; deadline?: string | null };

  let {
    project,
    slots = [],
    canManage = false,
    onPostNeed,
    onMintDone
  }: {
    project: Proj;
    slots?: Slot[];
    canManage?: boolean;
    onPostNeed?: () => void;
    onMintDone?: () => void;
  } = $props();

  const leader = $derived(slots.find((s) => s.slot_kind === 'leader') ?? null);
  const needs = $derived(slots.filter((s) => s.slot_kind !== 'leader'));
  const isFinished = $derived(/finish/i.test(project.status));

  function kindClass(k: string) { return k === 'work_resource' ? 'warn' : 'pos'; }
  function kindLabel(k: string) {
    return k === 'leader' ? $t('Leader') : k === 'work_resource' ? $t('Resource') : $t('Labor');
  }
  function slotStatusClass(s: Slot) {
    if (s.status === 'filled') return 'pos';
    if (s.members.length >= s.headcount) return 'pos';
    return 'warn';
  }
</script>

<div class="pscard">
  <header class="ps-head">
    <div class="ps-id">
      <span class="ps-name">{project.name}</span>
      <span class="badge dim">{project.status}</span>
    </div>
    {#if canManage}
      <div class="ps-actions">
        <button type="button" class="chip toggle" onclick={onPostNeed}>+ {$t('Post need')}</button>
        {#if !isFinished}
          <button type="button" class="chip toggle" onclick={onMintDone}>{$t('Mint done')}</button>
        {/if}
      </div>
    {/if}
  </header>

  <div class="ps-seats">
    <div class="ps-slot leader">
      <span class="ps-slot-h"><span class="badge warn">{kindLabel('leader')}</span> <span class="ps-auth">{$t('first author')}</span></span>
      {#if leader && leader.members.length}
        {#each leader.members as m (m.id)}<span class="ps-mem">{m.name}</span>{/each}
      {:else}
        <span class="ps-empty">{$t('unfilled')}</span>
      {/if}
    </div>

    {#each needs as s (s.id)}
      <div class="ps-slot">
        <span class="ps-slot-h">
          <span class="badge {kindClass(s.slot_kind)}">{kindLabel(s.slot_kind)}</span>
          {#if s.skill_name}<span class="ps-meta">{s.skill_name}</span>{/if}
          {#if s.resource_type_name}<span class="ps-meta">{s.resource_type_name}</span>{/if}
          {#if s.req_access}<span class="ps-meta">· {$t(s.req_access)}</span>{/if}
          <span class="badge {slotStatusClass(s)} ps-count">{s.members.length}/{s.headcount}</span>
        </span>
        {#if s.members.length}
          <span class="ps-mems">
            {#each s.members as m (m.id)}
              <span class="ps-mem">{m.name} <span class="ps-amt">{m.amount}{m.unit}</span></span>
            {/each}
          </span>
        {:else}
          <span class="ps-empty">{$t('open — awaiting a card')}</span>
        {/if}
      </div>
    {/each}

    {#if !needs.length}
      <p class="ps-none">{$t('No needs posted yet.')}</p>
    {/if}
  </div>
</div>

<style>
  .pscard { border: 1px solid var(--border); border-radius: 12px; background: var(--card); overflow: hidden; }
  .ps-head { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .75rem .9rem; border-bottom: 1px solid var(--border); }
  .ps-id { display: flex; align-items: center; gap: .55rem; min-width: 0; }
  .ps-name { font-weight: 600; color: var(--text); }
  .ps-actions { display: flex; gap: .4rem; flex: none; }
  .ps-seats { display: flex; flex-direction: column; gap: .4rem; padding: .7rem .9rem .85rem; }
  .ps-slot { display: flex; flex-direction: column; gap: .35rem; padding: .5rem .6rem; border-radius: 9px; background: var(--card-2); }
  .ps-slot.leader { background: var(--warn-soft); }
  .ps-slot-h { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
  .ps-auth { font-size: .72rem; color: var(--muted); }
  .ps-meta { font-size: .76rem; color: var(--text-dim); }
  .ps-count { margin-left: auto; }
  .ps-mems { display: flex; flex-wrap: wrap; gap: .4rem; }
  .ps-mem { font-size: .82rem; color: var(--text); }
  .ps-amt { font-family: var(--font-mono); font-size: .74rem; color: var(--info); }
  .ps-empty { font-size: .78rem; color: var(--muted); }
  .ps-none { font-size: .8rem; color: var(--muted); margin: .2rem 0 0; }
</style>
