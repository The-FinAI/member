<script lang="ts">
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  // Slot-centric seater: from a project, pick an OPEN slot, pick a member card,
  // and seat them via work_seat. The server enforces the real authorization —
  // this UI just scopes the candidate pool to what the viewer may seat:
  //   • admin (manage_members / edit_any_project) → every member card
  //   • chapter officer → cards homed in a chapter they officer
  let { projectId, projectName = '', onSeated }: {
    projectId: string;
    projectName?: string;
    onSeated?: () => void;
  } = $props();

  type Slot = {
    id: string; slot_kind: 'leader' | 'work_labor' | 'work_resource';
    req_access: string | null; skill_id: string | null; skill_name: string | null;
    resource_type_id: string | null; resource_type_name: string | null;
    quota: number | null; headcount: number; status: string; filled: number;
  };
  type Card = { id: string; full_name: string; home_unit_id: string | null };
  type Badge = { skill_id: string; level: string };
  type Res = { id: string; name: string; type_id: string; unit: string | null };

  const ym = new Date().toISOString().slice(0, 7);
  const RANK: Record<string, number> = { apprentice: 1, journeyman: 2, craftsman: 3, master: 4 };
  const rank = (l: string | null | undefined) => (l ? RANK[l] ?? 0 : 0);

  const isAdmin = $derived(get(capabilities).has('manage_members') || get(capabilities).has('edit_any_project'));

  let slots = $state<Slot[]>([]);
  let cards = $state<Card[]>([]);
  let badgesByCard = $state<Record<string, Badge[]>>({});
  let resByCard = $state<Record<string, Res[]>>({});
  let loading = $state(true);
  let busy = $state(''); let msg = $state(''); let err = $state('');

  // open picker state (per slot)
  let openSlot = $state<string | null>(null);
  let q = $state('');
  let pickedCard = $state<string | null>(null);
  let amount = $state<number>(0);
  let resId = $state<string>('');

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = '';

    const { data: sl } = await supabase.from('project_slot')
      .select('id, slot_kind, req_access, skill_id, resource_type_id, quota, headcount, status, skill:skill_id(name), resource_type:resource_type_id(name)')
      .eq('project_id', projectId);
    const raw = (sl as any[]) ?? [];
    const slotIds = raw.map((s) => s.id);
    const fill: Record<string, Set<string>> = {};
    if (slotIds.length) {
      const { data: wc } = await supabase.from('work_commitment').select('slot_id, member_id').in('slot_id', slotIds);
      for (const w of (wc as any[]) ?? []) (fill[w.slot_id] ??= new Set()).add(w.member_id);
    }
    slots = raw.map((s) => ({
      id: s.id, slot_kind: s.slot_kind, req_access: s.req_access,
      skill_id: s.skill_id, skill_name: s.skill?.name ?? null,
      resource_type_id: s.resource_type_id, resource_type_name: s.resource_type?.name ?? null,
      quota: s.quota, headcount: s.headcount ?? 1, status: s.status, filled: fill[s.id]?.size ?? 0
    }));

    // candidate pool — member cards the viewer is allowed to seat
    let cq = supabase.from('member').select('id, full_name, home_unit_id').eq('kind', 'card').order('full_name');
    if (!isAdmin) {
      const myUnits = get(officerUnits).map((u) => u.unit_id);
      if (!myUnits.length) { cards = []; loading = false; return; }
      cq = cq.in('home_unit_id', myUnits);
    }
    const { data: c } = await cq;
    cards = (c as Card[]) ?? [];
    const ids = cards.map((m) => m.id);
    if (ids.length) {
      const [{ data: bg }, { data: rs }] = await Promise.all([
        supabase.from('badge').select('member_id, skill_id, level').in('member_id', ids),
        supabase.from('resource').select('id, name, type_id, unit, holder_member_id').in('holder_member_id', ids)
      ]);
      const bmap: Record<string, Badge[]> = {};
      for (const b of (bg as any[]) ?? []) (bmap[b.member_id] ??= []).push({ skill_id: b.skill_id, level: b.level });
      badgesByCard = bmap;
      const rmap: Record<string, Res[]> = {};
      for (const r of (rs as any[]) ?? []) (rmap[r.holder_member_id] ??= []).push({ id: r.id, name: r.name, type_id: r.type_id, unit: r.unit });
      resByCard = rmap;
    } else { badgesByCard = {}; resByCard = {}; }
    loading = false;
  }

  // slots still needing people: open needs + an empty leader (first-author) seat
  const seatable = $derived(slots.filter((s) =>
    s.filled < s.headcount && (s.slot_kind === 'leader' ? s.filled === 0 : s.status !== 'closed')
  ));

  function kindLabel(k: string) {
    return k === 'leader' ? $t('Leader') : k === 'work_resource' ? $t('Resource') : $t('Labor');
  }

  // can a given card take a given slot? mirrors the work_seat gates
  function qualify(s: Slot, cardId: string): { ok: boolean; reason: string } {
    if (s.req_access && s.skill_id) {
      const have = (badgesByCard[cardId] ?? []).find((b) => b.skill_id === s.skill_id);
      if (!have || rank(have.level) < rank(s.req_access)) return { ok: false, reason: $t('needs {lvl}', { lvl: $t(s.req_access) }) };
    }
    if (s.slot_kind === 'work_resource' && s.resource_type_id) {
      if (!(resByCard[cardId] ?? []).some((r) => r.type_id === s.resource_type_id)) return { ok: false, reason: $t('no matching resource') };
    }
    return { ok: true, reason: '' };
  }

  function openPicker(s: Slot) {
    if (openSlot === s.id) { openSlot = null; return; }
    openSlot = s.id; q = ''; pickedCard = null; amount = s.quota ?? 0; resId = ''; msg = ''; err = '';
  }

  function pickCard(s: Slot, cardId: string) {
    pickedCard = cardId;
    amount = s.quota ?? 0;
    const m = s.resource_type_id ? (resByCard[cardId] ?? []).find((r) => r.type_id === s.resource_type_id) : null;
    resId = m?.id ?? '';
  }

  function candidatesFor(s: Slot) {
    const needle = q.trim().toLowerCase();
    return cards
      .filter((c) => !needle || c.full_name.toLowerCase().includes(needle))
      .map((c) => ({ c, q: qualify(s, c.id) }))
      .sort((a, b) => (a.q.ok === b.q.ok ? a.c.full_name.localeCompare(b.c.full_name) : a.q.ok ? -1 : 1));
  }

  async function seat(s: Slot) {
    if (!pickedCard) return;
    busy = s.id; msg = ''; err = '';
    const { error: e } = await supabase.rpc('work_seat', {
      p_slot: s.id, p_member: pickedCard, p_resource: resId || null,
      p_year_month: ym, p_monthly_amount: Number(amount) || 0, p_as: pickedCard
    });
    busy = '';
    if (e) { err = e.message; return; }
    msg = get(t)('Seated into slot.');
    openSlot = null; pickedCard = null;
    await load();
    onSeated?.();
  }

  $effect(() => { if (projectId) load(); });
</script>

<div class="seater">
  <div class="st-head">
    <span class="st-title">{$t('Seat a member')}</span>
    <span class="st-sub">{$t('Month {ym}', { ym })}</span>
  </div>

  {#if loading}
    <p class="st-muted">{$t('Loading…')}</p>
  {:else if !isAdmin && !cards.length}
    <p class="st-muted">{$t('You can only seat cards from a chapter you officer.')}</p>
  {:else if !seatable.length}
    <p class="st-muted">{$t('Every slot is filled — nothing to seat.')}</p>
  {:else}
    {#if msg}<p class="st-ok">{msg}</p>{/if}
    {#if err}<p class="st-err">{err}</p>{/if}
    <div class="st-slots">
      {#each seatable as s (s.id)}
        <div class="st-slot">
          <button type="button" class="st-slot-row" onclick={() => openPicker(s)}>
            <span class="st-slot-main">
              <span class="badge {s.slot_kind === 'work_resource' ? 'warn' : 'pos'}">{kindLabel(s.slot_kind)}</span>
              {#if s.skill_name}<span class="st-meta">{s.skill_name}</span>{/if}
              {#if s.resource_type_name}<span class="st-meta">{s.resource_type_name}</span>{/if}
              {#if s.req_access}<span class="st-meta">· {$t('needs {lvl}', { lvl: $t(s.req_access) })}</span>{/if}
            </span>
            <span class="st-gap">{s.filled}/{s.headcount}</span>
          </button>

          {#if openSlot === s.id}
            <div class="st-pick">
              <input class="st-search" placeholder={$t('Search by name…')} bind:value={q} />
              <div class="st-cards">
                {#each candidatesFor(s) as d (d.c.id)}
                  <button
                    type="button"
                    class="st-card"
                    class:on={pickedCard === d.c.id}
                    class:blocked={!d.q.ok}
                    disabled={!d.q.ok}
                    onclick={() => pickCard(s, d.c.id)}
                  >
                    <span class="st-name">{d.c.full_name}</span>
                    {#if !d.q.ok}<span class="st-reason">{d.q.reason}</span>{/if}
                  </button>
                {/each}
                {#if !candidatesFor(s).length}<p class="st-muted">{$t('No matching cards.')}</p>{/if}
              </div>

              {#if pickedCard}
                <div class="st-form">
                  {#if s.slot_kind !== 'leader'}
                    <label class="st-field">
                      <span>{$t('Monthly amount')}{#if s.quota}<span class="st-hint"> · {$t('need {q}', { q: s.quota })}</span>{/if}</span>
                      <input type="number" min="0" step="any" bind:value={amount} />
                    </label>
                  {/if}
                  {#if s.slot_kind === 'work_resource'}
                    <label class="st-field">
                      <span>{$t('Resource')}</span>
                      <select bind:value={resId}>
                        <option value="">{$t('Select resource')}</option>
                        {#each (resByCard[pickedCard] ?? []).filter((r) => !s.resource_type_id || r.type_id === s.resource_type_id) as r (r.id)}
                          <option value={r.id}>{r.name}</option>
                        {/each}
                      </select>
                    </label>
                  {/if}
                  <button
                    type="button"
                    class="st-go"
                    disabled={busy === s.id || (s.slot_kind === 'work_resource' && !resId)}
                    onclick={() => seat(s)}
                  >
                    {#if busy === s.id}<span class="spin"></span>{/if}{$t('Seat into slot')}
                  </button>
                </div>
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .seater { border: 1px solid var(--border); border-radius: 12px; background: var(--card); overflow: hidden; }
  .st-head { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; padding: .7rem .9rem; border-bottom: 1px solid var(--border); }
  .st-title { font-weight: 600; color: var(--text); }
  .st-sub { font-size: .76rem; color: var(--muted); }
  .st-muted { font-size: .82rem; color: var(--muted); margin: 0; padding: .8rem .9rem; }
  .st-ok { font-size: .82rem; color: var(--accent); margin: 0; padding: .5rem .9rem 0; }
  .st-err { font-size: .82rem; color: var(--down); margin: 0; padding: .5rem .9rem 0; }
  .st-slots { display: flex; flex-direction: column; }
  .st-slot { border-top: 1px solid var(--border); }
  .st-slot:first-child { border-top: 0; }
  .st-slot-row {
    width: 100%; display: flex; align-items: center; justify-content: space-between; gap: .6rem;
    background: transparent; border: 0; padding: .6rem .9rem; cursor: pointer; font: inherit; color: var(--text);
  }
  .st-slot-row:hover { background: var(--card-2); }
  .st-slot-main { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
  .st-meta { font-size: .78rem; color: var(--text-dim); }
  .st-gap { font-family: var(--font-mono); font-size: .8rem; color: var(--muted); flex: none; }
  .st-pick { padding: 0 .9rem .8rem; display: flex; flex-direction: column; gap: .5rem; }
  .st-search {
    padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem;
  }
  .st-cards { display: flex; flex-direction: column; gap: .25rem; max-height: 220px; overflow-y: auto; }
  .st-card {
    display: flex; align-items: center; justify-content: space-between; gap: .5rem;
    padding: .4rem .55rem; border: 1px solid var(--border); border-radius: 8px;
    background: var(--card); cursor: pointer; font: inherit; color: var(--text); text-align: left;
  }
  .st-card:hover { border-color: var(--accent); }
  .st-card.on { border-color: var(--accent); background: var(--accent-soft); }
  .st-card.blocked { opacity: .55; cursor: not-allowed; }
  .st-name { font-size: .86rem; }
  .st-reason { font-size: .74rem; color: var(--down); }
  .st-form { display: flex; flex-direction: column; gap: .5rem; padding-top: .2rem; border-top: 1px dashed var(--border); }
  .st-field { display: flex; flex-direction: column; gap: .25rem; font-size: .78rem; color: var(--muted); }
  .st-hint { color: var(--info); }
  .st-field input, .st-field select {
    padding: .45rem .55rem; border-radius: 8px; border: 1px solid var(--border-2);
    background: var(--card-2); color: var(--text); font-size: .88rem;
  }
  .st-go {
    align-self: flex-start; padding: .5rem .9rem; border-radius: 8px; border: 1px solid transparent;
    background: var(--accent); color: #fff; font: inherit; font-weight: 600; cursor: pointer;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .st-go:disabled { opacity: .55; cursor: not-allowed; }
</style>
