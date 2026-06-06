<script lang="ts">
  // BUILD PLAN P3 — the matching seam (PRD §5.3). A chapter steward fills open
  // Needs from the roster: pick a Need → ranked candidates glow with their level,
  // evidence and FREE CAPACITY → assign in place. Capacity is the hard gate;
  // under-level people still show, ranked lower. Path B (direct, name-and-go) is
  // always one search away. Optimistic.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  type Need = {
    id: string; project_id: string; skill_id: string; desired_level: string | null;
    quota: number | null; headcount: number; filled: number;
    skill: { name: string } | null; project: { name: string; emoji: string | null; code: string | null } | null;
  };
  type Cand = {
    member_id: string; full_name: string; level: string | null;
    tasks: number; shipped: number; free_hours: number | null; fits: boolean; reason: string;
  };
  type Member = { id: string; full_name: string };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };

  let needs = $state<Need[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true);
  let err = $state('');
  let openNeed = $state<string | null>(null);
  let cands = $state<Cand[]>([]);
  let candLoading = $state(false);
  let busy = $state<string | null>(null);
  let hoursFor = $state<Record<string, string>>({});   // member_id → hours draft
  // path B
  let directOpen = $state(false);
  let directQ = $state('');
  let directPick = $state('');
  let directHours = $state('');

  const memberName = (id: string) => members.find((m) => m.id === id)?.full_name ?? '';
  const directChoices = $derived(
    members.filter((m) => m.full_name.toLowerCase().includes(directQ.trim().toLowerCase())).slice(0, 20)
  );

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    loading = true; err = '';
    const [nd, mem] = await Promise.all([
      supabase.from('project_slot')
        .select('id,project_id,skill_id,desired_level,quota,headcount,status,skill:skill_id(name),project:project_id(name,emoji,code)')
        .eq('slot_kind', 'work_labor').eq('status', 'open').not('skill_id', 'is', null),
      supabase.from('member').select('id,full_name').order('full_name')
    ]);
    const rows = (nd.data as any[]) ?? [];
    const ids = rows.map((r) => r.id);
    const filled: Record<string, Set<string>> = {};
    if (ids.length) {
      const { data: wc } = await supabase.from('work_commitment').select('slot_id,member_id').in('slot_id', ids);
      for (const w of (wc as any[]) ?? []) (filled[w.slot_id] ??= new Set()).add(w.member_id);
    }
    needs = rows.map((r) => ({ ...r, filled: filled[r.id]?.size ?? 0 }))
                .filter((r) => r.filled < (r.headcount ?? 1));
    members = (mem.data as Member[]) ?? [];
    loading = false;
  }
  $effect(() => { load(); });

  async function pickNeed(n: Need) {
    if (openNeed === n.id) { openNeed = null; return; }
    openNeed = n.id; cands = []; candLoading = true; err = '';
    const { data, error } = await supabase.rpc('match_candidates', { p_slot: n.id });
    candLoading = false;
    if (error) { err = error.message; return; }
    cands = (data as Cand[]) ?? [];
    hoursFor = {};
    for (const c of cands) {
      const def = Math.min(Number(c.free_hours ?? n.quota ?? 0) || 0, Number(n.quota ?? c.free_hours ?? 0) || 0);
      hoursFor[c.member_id] = String(def > 0 ? def : (n.quota ?? ''));
    }
  }

  async function doAssign(memberId: string, slot: Need, hoursStr: string) {
    const hours = Number(hoursStr) || 0;
    if (hours <= 0) { err = $t('Hours must be greater than 0'); return; }
    busy = memberId; err = '';
    const { error } = await supabase.rpc('assign', { p_member: memberId, p_slot: slot.id, p_hours: hours });
    busy = null;
    if (error) { err = error.message; return; }
    // optimistic: bump filled; drop the need if now full; refresh candidates
    const n = needs.find((x) => x.id === slot.id);
    if (n) { n.filled += 1; if (n.filled >= n.headcount) { needs = needs.filter((x) => x.id !== slot.id); openNeed = null; } }
    needs = needs;
    cands = cands.filter((c) => c.member_id !== memberId);
    directOpen = false; directPick = ''; directQ = ''; directHours = '';
  }
</script>

<section class="mb">
  <div class="mb-head">
    <h2>{$t('Match people to needs')}</h2>
    {#if err}<span class="mb-err">{err}</span>{/if}
  </div>

  {#if loading}
    <p class="mb-dim">{$t('Loading…')}</p>
  {:else if !needs.length}
    <p class="mb-dim">{$t('No open needs right now.')}</p>
  {:else}
    <div class="mb-needs">
      {#each needs as n (n.id)}
        <div class="need" class:open={openNeed === n.id}>
          <button class="need-row" onclick={() => pickNeed(n)}>
            <span class="need-skill">{n.skill?.name}</span>
            {#if n.desired_level}<span class="need-lvl">{$t(LEVEL_LABEL[n.desired_level] ?? n.desired_level)}</span>{/if}
            <span class="need-proj">{n.project?.emoji ?? ''} {n.project?.code || n.project?.name}</span>
            <span class="need-fill">{n.filled}/{n.headcount}</span>
            {#if n.quota}<span class="need-q">{n.quota}h</span>{/if}
          </button>

          {#if openNeed === n.id}
            <div class="cands">
              {#if candLoading}
                <p class="mb-dim">{$t('Loading…')}</p>
              {:else if !cands.length}
                <p class="mb-dim">{$t('No qualified people with free time — assign directly below.')}</p>
              {/if}
              {#each cands as c (c.member_id)}
                <div class="cand" class:dim={!c.fits} class:busy={busy === c.member_id}>
                  <div class="cand-info">
                    <span class="cand-name">{c.full_name}</span>
                    <span class="cand-lvl lv-{c.level}">{$t(LEVEL_LABEL[c.level ?? ''] ?? c.level ?? '')}</span>
                    <span class="cand-ev">{c.tasks} {$t('tasks')} · {c.shipped} {$t('shipped')}</span>
                    <span class="cand-free">{c.free_hours ?? '∞'}h {$t('free')}</span>
                    {#if !c.fits}<span class="cand-reason">{c.reason}</span>{/if}
                  </div>
                  <div class="cand-act">
                    <input class="cand-h" type="number" min="1" bind:value={hoursFor[c.member_id]} />
                    <button class="assign" disabled={busy === c.member_id} onclick={() => doAssign(c.member_id, n, hoursFor[c.member_id])}>{$t('Assign')}</button>
                  </div>
                </div>
              {/each}

              <!-- path B: direct name-and-go -->
              {#if directOpen}
                <div class="direct">
                  <input class="direct-q" placeholder={$t('Search by name…')} bind:value={directQ} />
                  <select bind:value={directPick}>
                    <option value="">{$t('Pick a person')}</option>
                    {#each directChoices as m}<option value={m.id}>{m.full_name}</option>{/each}
                  </select>
                  <input class="cand-h" type="number" min="1" placeholder="h" bind:value={directHours} />
                  <button class="assign" disabled={!directPick || busy === directPick} onclick={() => directPick && doAssign(directPick, n, directHours)}>{$t('Assign directly')}</button>
                  <button class="mb-ghost" onclick={() => (directOpen = false)}>{$t('Cancel')}</button>
                </div>
              {:else}
                <button class="direct-toggle" onclick={() => { directOpen = true; directQ = ''; directPick = ''; directHours = String(n.quota ?? ''); }}>＋ {$t('Assign someone directly')}</button>
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</section>

<style>
  .mb { margin-bottom: 1.5rem; }
  .mb-head { display: flex; align-items: baseline; gap: .7rem; }
  .mb-head h2 { margin: 0 0 .6rem; font-size: 1.1rem; }
  .mb-err { color: var(--neg, #c0392b); font-size: .82rem; }
  .mb-dim { color: var(--muted, #999); font-size: .9rem; }
  .need { border: 1px solid var(--line, #eee); border-radius: 10px; margin-bottom: .5rem; overflow: hidden; }
  .need.open { border-color: var(--accent, #6a7cff); }
  .need-row { width: 100%; display: flex; align-items: center; gap: .6rem; background: none; border: none; cursor: pointer; padding: .55rem .7rem; text-align: left; color: inherit; }
  .need-skill { font-weight: 600; }
  .need-lvl { font-size: .73rem; border: 1px solid #8aa0ff; color: #5566cc; border-radius: 999px; padding: 0 .45rem; }
  .need-proj { font-size: .8rem; color: var(--muted, #999); }
  .need-fill { margin-left: auto; font-size: .8rem; color: var(--muted, #888); }
  .need-q { font-size: .8rem; color: var(--muted, #aaa); }
  .cands { padding: .3rem .7rem .6rem; background: var(--card-bg, #fafafa); }
  .cand { display: flex; align-items: center; justify-content: space-between; gap: .6rem; padding: .35rem .2rem; border-bottom: 1px solid var(--line, #f0f0f0); }
  .cand.dim { opacity: .6; }
  .cand.busy { opacity: .5; }
  .cand-info { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
  .cand-name { font-weight: 500; }
  .cand-lvl { font-size: .73rem; color: var(--muted, #888); }
  .cand-lvl.lv-lead { color: #9a7b12; } .cand-lvl.lv-independent { color: #5566cc; }
  .cand-ev { font-size: .74rem; color: var(--muted, #aaa); }
  .cand-free { font-size: .76rem; color: #2e7d4f; }
  .cand-reason { font-size: .73rem; color: #b8860b; }
  .cand-act { display: flex; gap: .35rem; align-items: center; }
  .cand-h { width: 3.4rem; padding: .2rem .3rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .assign { border: none; background: var(--accent, #6a7cff); color: #fff; border-radius: 7px; padding: .25rem .7rem; cursor: pointer; }
  .assign:disabled { opacity: .5; cursor: default; }
  .direct { display: flex; gap: .35rem; align-items: center; margin-top: .45rem; flex-wrap: wrap; }
  .direct-q { padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .direct select { padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: 6px; }
  .direct-toggle { margin-top: .45rem; border: 1px dashed var(--line, #ddd); background: none; border-radius: 8px; padding: .3rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .84rem; }
  .direct-toggle:hover { border-color: var(--accent, #6a7cff); color: var(--accent, #6a7cff); }
  .mb-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: 7px; padding: .25rem .6rem; cursor: pointer; }
</style>
