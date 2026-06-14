<script lang="ts">
  // BUILD PLAN P3 — the matching seam (PRD §5.3). A chapter steward fills open
  // Needs from the roster: pick a Need → ranked candidates glow with their level,
  // evidence and FREE CAPACITY → assign in place. Capacity is the hard gate;
  // under-level people still show, ranked lower. Path B (direct, name-and-go) is
  // always one search away. Optimistic.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // projectId scopes the open needs to one project (so the matcher can be
  // embedded on a project — assign in place, no hop to People). embedded hides
  // its own heading. onAssigned lets the host refresh after a seat is filled.
  let { projectId = null, embedded = false, onAssigned }:
    { projectId?: string | null; embedded?: boolean; onAssigned?: () => void } = $props();

  type Need = {
    id: string; project_id: string; slot_kind: string; skill_id: string | null;
    resource_type_id: string | null; desired_level: string | null;
    quota: number | null; headcount: number; filled: number;
    skill: { name: string } | null; resource_type: { name: string; unit: string | null } | null;
    project: { name: string; emoji: string | null; code: string | null } | null;
  };
  type Cand = {
    member_id: string; full_name: string; level: string | null;
    tasks: number; shipped: number; free: number | null; unit: string;
    resource_id: string | null; fits: boolean; reason: string;
  };
  type Member = { id: string; full_name: string };

  const LEVEL_LABEL: Record<string, string> = { learning: 'Learning', independent: 'Independent', lead: 'Lead' };

  let needs = $state<Need[]>([]);
  let members = $state<Member[]>([]);
  let loading = $state(true);
  let err = $state('');
  let msg = $state('');
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
    let slotQ = supabase.from('project_slot')
        .select('id,project_id,slot_kind,skill_id,resource_type_id,desired_level,quota,headcount,status,skill:skill_id(name),resource_type:resource_type_id(name,unit),project:project_id(name,emoji,code)')
        .in('slot_kind', ['work_labor', 'work_resource', 'leader']).eq('status', 'open');
    if (projectId) slotQ = slotQ.eq('project_id', projectId);
    const [nd, mem] = await Promise.all([
      slotQ,
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
    // open the first need so ranked candidates are visible immediately — the
    // matcher is the core operation; it shouldn't hide behind a chevron.
    if (needs.length && !openNeed) pickNeed(needs[0]);
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
      const free = Number(c.free ?? n.quota ?? 0) || 0;
      const need = Number(n.quota ?? c.free ?? 0) || 0;
      const def = Math.min(free || need, need || free);
      hoursFor[c.member_id] = String(def > 0 ? def : (n.quota ?? ''));
    }
  }

  // graded fit (Strong / Fits / Stretch) + capacity bar, per the research
  // graded fit, encoded by SHAPE + LABEL too (not colour alone — colour-blind safe)
  function grade(c: Cand): { cls: string; label: string; glyph: string } {
    if (!c.fits) return { cls: 'stretch', label: 'Stretch', glyph: '○' };
    if (c.level === 'lead' || (c.shipped ?? 0) >= 2) return { cls: 'strong', label: 'Strong fit', glyph: '●' };
    return { cls: 'ok', label: 'Fits', glyph: '◐' };
  }
  // live capacity bar: how much of this person's FREE capacity the planned
  // amount consumes — fills as you type, turns red when it exceeds free.
  function bar(c: Cand, planned: number): { pct: number; over: boolean; unconstrained: boolean } {
    if (c.free == null) return { pct: 0, over: false, unconstrained: true };
    const free = Number(c.free);
    if (free <= 0) return { pct: 100, over: planned > 0, unconstrained: false };
    return { pct: Math.min(100, Math.round((planned / free) * 100)), over: planned > free, unconstrained: false };
  }
  const num = (s: string) => Number(s) || 0;

  async function doAssign(memberId: string, slot: Need, hoursStr: string) {
    const hours = Number(hoursStr) || 0;
    if (hours <= 0) { err = $t('Hours must be greater than 0'); return; }
    busy = memberId; err = '';
    const { error } = await supabase.rpc('assign', { p_member: memberId, p_slot: slot.id, p_hours: hours });
    busy = null;
    if (error) { err = error.message; return; }
    // explicit confirmation (visibility of system status) — the row vanishing
    // alone isn't clear feedback
    const who = memberName(memberId) || cands.find((c) => c.member_id === memberId)?.full_name || '';
    msg = `✓ ${$t('Assigned')} ${who} · ${hours}${slot.slot_kind === 'work_resource' ? (slot.resource_type?.unit ?? '') : 'h'}`;
    // optimistic: bump filled; drop the need if now full; refresh candidates
    const n = needs.find((x) => x.id === slot.id);
    if (n) { n.filled += 1; if (n.filled >= n.headcount) { needs = needs.filter((x) => x.id !== slot.id); openNeed = null; } }
    needs = needs;
    cands = cands.filter((c) => c.member_id !== memberId);
    directOpen = false; directPick = ''; directQ = ''; directHours = '';
    onAssigned?.();   // let the host (project ledger / team) refresh
  }
</script>

<section class="mb">
  <div class="mb-head">
    {#if !embedded}<h2>{$t('Match people to needs')}</h2>{/if}
    {#if err}<span class="mb-err">{err}</span>{/if}
    {#if msg}<span class="mb-ok">{msg}</span>{/if}
  </div>

  {#if loading}
    <p class="mb-dim">{$t('Loading…')}</p>
  {:else if !needs.length}
    <p class="mb-dim">{$t('No open needs right now.')}</p>
  {:else}
    <div class="mb-needs">
      {#each needs as n (n.id)}
        <div class="need" class:open={openNeed === n.id}>
          <button class="need-row" aria-expanded={openNeed === n.id} onclick={() => pickNeed(n)}>
            <span class="need-chev" class:open={openNeed === n.id}>▸</span>
            {#if n.slot_kind === 'leader'}
              <span class="need-skill">{$t('First author')}</span>
              <span class="need-kind">{$t('leader')}</span>
            {:else if n.slot_kind === 'work_resource'}
              <span class="need-skill">{n.resource_type?.name}</span>
              <span class="need-kind">{$t('resource')}</span>
            {:else}
              <span class="need-skill">{n.skill?.name}</span>
              {#if n.desired_level}<span class="need-lvl">{$t(LEVEL_LABEL[n.desired_level] ?? n.desired_level)}</span>{/if}
            {/if}
            <span class="need-proj">{n.project?.emoji ?? ''} {n.project?.code || n.project?.name}</span>
            <span class="need-fill">{n.filled}/{n.headcount}</span>
            {#if n.quota}<span class="need-q">{n.quota}{n.slot_kind === 'work_resource' ? (n.resource_type?.unit ?? '') : 'h'}</span>{/if}
          </button>

          {#if openNeed === n.id}
            <div class="cands">
              {#if candLoading}
                <p class="mb-dim">{$t('Loading…')}</p>
              {:else if !cands.length}
                <p class="mb-dim">{$t('No qualified people with free time — assign directly below.')}</p>
              {/if}
              {#each cands as c (c.member_id)}
                {@const g = grade(c)}
                {@const b = bar(c, num(hoursFor[c.member_id]))}
                <div class="cand" class:busy={busy === c.member_id}>
                  <div class="cand-info">
                    <span class="cand-grade gr-{g.cls}">{g.glyph}<span class="gr-label">{$t(g.label)}</span></span>
                    <span class="cand-name">{c.full_name}</span>
                    {#if c.level}<span class="cand-lvl lv-{c.level}">{$t(LEVEL_LABEL[c.level] ?? c.level)}</span>{/if}
                    {#if n.slot_kind === 'work_labor'}
                      <span class="cand-ev">{c.tasks} {$t('tasks')} · {c.shipped} {$t('shipped')}</span>
                    {:else}
                      <span class="cand-ev">{$t('holds')} {n.resource_type?.name}</span>
                    {/if}
                    {#if !c.fits}<span class="cand-reason">{c.reason}</span>{/if}
                  </div>
                  <div class="cand-cap">
                    <div class="capbar" title="{c.free ?? '∞'} {c.unit} {$t('free')}">
                      {#if b.unconstrained}<span class="cap-inf">∞</span>{:else}<div class="capfill" class:over={b.over} style="width:{b.pct}%"></div>{/if}
                    </div>
                    <span class="cap-txt" class:over={b.over}>{#if b.over}⚠ {/if}{c.free ?? '∞'}{c.unit} {$t('free')}</span>
                  </div>
                  <div class="cand-act">
                    <input class="cand-h" class:over={b.over} type="number" min="1" bind:value={hoursFor[c.member_id]} />
                    <span class="cand-unit">{c.unit}</span>
                    <button class="assign" disabled={busy === c.member_id || b.over || num(hoursFor[c.member_id]) <= 0}
                      onclick={() => doAssign(c.member_id, n, hoursFor[c.member_id])}>{$t('Assign')}</button>
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
  .mb-err { color: var(--neg, var(--down)); font-size: .82rem; }
  .mb-ok { color: var(--up); font-size: .82rem; }
  .mb-dim { color: var(--muted, #999); font-size: .9rem; }
  .need { border: 1px solid var(--line, #eee); border-radius: var(--r-md); margin-bottom: .5rem; overflow: hidden; }
  .need.open { border-color: var(--accent, var(--accent)); }
  .need-row { width: 100%; display: flex; align-items: center; gap: .6rem; background: none; border: none; cursor: pointer; padding: .55rem .7rem; text-align: left; color: inherit; }
  .need-chev { color: var(--muted, #aaa); transition: transform .12s; display: inline-block; }
  .need-chev.open { transform: rotate(90deg); }
  .need-skill { font-weight: 600; }
  .need-lvl { font-size: .73rem; border: 1px solid var(--info); color: var(--info); border-radius: var(--r-full); padding: 0 .45rem; }
  .need-proj { font-size: .8rem; color: var(--muted, #999); }
  .need-fill { margin-left: auto; font-size: .8rem; color: var(--muted, #888); }
  .need-q { font-size: .8rem; color: var(--muted, #aaa); }
  .cands { padding: .3rem .7rem .6rem; background: var(--card-bg, #fafafa); }
  .cand { display: flex; align-items: center; justify-content: space-between; gap: .6rem; padding: .35rem .2rem; border-bottom: 1px solid var(--line, #f0f0f0); }
  .cand.dim { opacity: .6; }
  .cand.busy { opacity: .5; }
  .cand-info { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; flex: 1 1 14rem; }
  .cand-grade { font-size: .72rem; display: inline-flex; align-items: center; gap: .25rem; }
  .gr-label { font-size: .68rem; color: var(--muted, #999); }
  .gr-strong { color: var(--up); } .gr-ok { color: var(--accent); } .gr-stretch { color: var(--warn); }
  .cand-name { font-weight: 500; }
  .cand-lvl { font-size: .73rem; color: var(--muted, #888); }
  .cand-lvl.lv-lead { color: var(--gold); } .cand-lvl.lv-independent { color: var(--info); }
  .cand-ev { font-size: .74rem; color: var(--muted, #aaa); }
  .cand-reason { font-size: .73rem; color: var(--warn); }
  .cand-cap { display: flex; flex-direction: column; gap: .15rem; min-width: 6.5rem; }
  .capbar { height: 6px; background: var(--line, #ececec); border-radius: var(--r-full); overflow: hidden; position: relative; }
  .capfill { height: 100%; background: var(--up); border-radius: var(--r-full); transition: width .12s; }
  .capfill.over { background: var(--down); }
  .cap-inf { font-size: .7rem; color: var(--muted, #bbb); }
  .cap-txt { font-size: .72rem; color: var(--up); }
  .cap-txt.over { color: var(--down); }
  .cand-unit { font-size: .72rem; color: var(--muted, #aaa); }
  .cand-act { display: flex; gap: .3rem; align-items: center; }
  .cand-h.over { border-color: var(--down); color: var(--down); }
  .cand-h { width: 3.4rem; padding: .2rem .3rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .assign { border: none; background: var(--accent, var(--accent)); color: #fff; border-radius: var(--r-sm); padding: .25rem .7rem; cursor: pointer; }
  .assign:disabled { opacity: .5; cursor: default; }
  .direct { display: flex; gap: .35rem; align-items: center; margin-top: .45rem; flex-wrap: wrap; }
  .direct-q { padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .direct select { padding: .25rem .4rem; border: 1px solid var(--line, #ddd); border-radius: var(--r-sm); }
  .direct-toggle { margin-top: .45rem; border: 1px dashed var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .3rem .6rem; cursor: pointer; color: var(--muted, #777); font-size: .84rem; }
  .direct-toggle:hover { border-color: var(--accent, var(--accent)); color: var(--accent, var(--accent)); }
  .mb-ghost { border: 1px solid var(--line, #ddd); background: none; border-radius: var(--r-sm); padding: .25rem .6rem; cursor: pointer; }
</style>
