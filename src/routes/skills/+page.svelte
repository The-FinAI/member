<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, actingAs } from '$lib/session';
  import { PHASE2 } from '$lib/phase';
  import Hint from '$lib/Hint.svelte';
  import Medal from '$lib/Medal.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Skill = { id: string; name: string; parent_id: string | null };
  type CardReq = {
    id: string; skill_id: string; member_id: string; target_level: string; kind: string;
    fee: number; status: string; batch_id: string | null;
    skill: { name: string } | null; member: { full_name: string } | null;
  };
  type Mem = { id: string; full_name: string; kind?: string };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman',
    craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  let skills = $state<Skill[]>([]);
  let holders = $state<Record<string, number>>({});          // certified holders per skill
  let myCert = $state<Record<string, string>>({});           // my certified_level per skill
  let myBalance = $state(0);
  // role-card (mint/review) flow
  let cardQueue = $state<CardReq[]>([]);   // requests awaiting my review (审)
  let myCardReqs = $state<CardReq[]>([]);  // my own / acting-card's requests
  let mintFee = $state(10);
  let updateFee = $state(5);
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  const canReview = $derived($capabilities.has('review_skillcard'));
  const canMint = $derived($capabilities.has('mint_skillcard'));
  // effective identity: act for a card (officer proxy) when one is selected
  const effId = $derived($actingAs?.id ?? $member?.id ?? null);
  const asArg = $derived($actingAs?.id ?? null);

  // direct mint (forge / update any member's skill profile — staged as one batch)
  let members = $state<Mem[]>([]);
  let mintMember = $state(''); let mintMsg = $state('');
  let mintCert = $state<Record<string, string>>({});     // selected member's certified levels per skill
  let mintPending = $state<Record<string, string>>({});  // selected member's pending request target levels
  let staged = $state<Record<string, string>>({});       // staged skillId -> level, submitted as one batch

  let selected = $state(''); // selected leaf skill id
  let cardLevel = $state('apprentice');
  let cardNote = $state<Record<string, string>>({});

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const me = effId;
    const [{ data: sk }, { data: ms }, { data: cardPol }, { data: mineCert }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').not('certified_level', 'is', null),
      supabase.from('stater_policy').select('key, value').in('key', ['skillcard_mint_fee', 'skillcard_update_fee']),
      me ? supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', me) : Promise.resolve({ data: [] })
    ]);
    for (const p of (cardPol as { key: string; value: number }[]) ?? []) {
      if (p.key === 'skillcard_mint_fee') mintFee = Number(p.value);
      if (p.key === 'skillcard_update_fee') updateFee = Number(p.value);
    }

    skills = ((sk as any[]) ?? []).map((s) => ({ id: s.id, name: s.name, parent_id: s.parent_id }));

    const h: Record<string, number> = {};
    for (const r of (ms as any[]) ?? []) h[r.skill_id] = (h[r.skill_id] ?? 0) + 1;
    holders = h;

    const mc: Record<string, string> = {};
    for (const r of (mineCert as any[]) ?? []) if (r.certified_level) mc[r.skill_id] = r.certified_level;
    myCert = mc;

    if (me) {
      const { data: bal } = await supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle();
      myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);

      // my (or acting card's) role-card requests
      const { data: mr } = await supabase
        .from('skillcard_request')
        .select('id, skill_id, member_id, target_level, kind, fee, status, batch_id, skill:skill_id(name), member:member_id(full_name)')
        .eq('member_id', me).order('created_at', { ascending: false });
      myCardReqs = (mr as CardReq[]) ?? [];
    }

    // 审 review queue — all open requests (reviewer acts as the current operator)
    if ($capabilities.has('review_skillcard')) {
      const { data: cq } = await supabase
        .from('skillcard_request')
        .select('id, skill_id, member_id, target_level, kind, fee, status, batch_id, skill:skill_id(name), member:member_id(full_name)')
        .eq('status', 'submitted').order('created_at');
      cardQueue = (cq as CardReq[]) ?? [];
    } else {
      cardQueue = [];
    }

    // member roster for the direct-mint tool — includes member-cards (not yet
    // signed up), so officers can pre-certify a card before it is claimed
    if ($capabilities.has('mint_skillcard')) {
      const { data: mem } = await supabase.from('member').select('id, full_name, kind')
        .in('status', ['active', 'invited']).order('full_name');
      members = (mem as Mem[]) ?? [];
    } else {
      members = [];
    }
    loading = false;
  }

  onMount(load);
  // reload when the signed-in member or the acting card changes
  $effect(() => { const _ = effId; if (supabaseConfigured) load(); });

  // mint when first certifying this skill, otherwise an update (level-up)
  function cardFeeFor(skillId: string | null) {
    return skillId && myCert[skillId] ? updateFee : mintFee;
  }
  async function submitCard() {
    if (!sel || !effId) return;
    error = ''; busy = 'card';
    const { error: err } = await supabase.rpc('submit_skillcard_request', { p_skill: sel.id, p_level: cardLevel, p_as: asArg });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function cancelCard(req: CardReq) {
    error = ''; busy = req.id;
    const { error: err } = await supabase.rpc('cancel_skillcard_request', { p_request: req.id, p_as: asArg });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function reviewBatch(batchId: string, approve: boolean) {
    error = ''; busy = 'batch:' + batchId;
    const { error: err } = await supabase.rpc('review_skillcard_batch', { p_batch: batchId, p_approve: approve, p_note: cardNote[batchId] ?? null });
    busy = '';
    if (err) { error = err.message; return; }
    cardNote[batchId] = '';
    await load();
  }
  // group the review queue by batch — a reviewer acts on a whole batch at once
  const cardBatches = $derived.by(() => {
    const m = new Map<string, CardReq[]>();
    for (const r of cardQueue) {
      const k = r.batch_id ?? r.id;
      (m.get(k) ?? m.set(k, []).get(k)!).push(r);
    }
    return [...m.entries()].map(([batch_id, items]) => ({ batch_id, items }));
  });

  // direct mint (铸 — click a member's talent tree to PROPOSE a certification)
  async function loadMintCert() {
    mintMsg = ''; mintCert = {}; mintPending = {}; staged = {};
    if (!mintMember) return;
    const [{ data: cert }, { data: pend }] = await Promise.all([
      supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', mintMember).not('certified_level', 'is', null),
      supabase.from('skillcard_request').select('skill_id, target_level').eq('member_id', mintMember).eq('status', 'submitted')
    ]);
    const c: Record<string, string> = {};
    for (const r of (cert as any[]) ?? []) if (r.certified_level) c[r.skill_id] = r.certified_level;
    const p: Record<string, string> = {};
    for (const r of (pend as any[]) ?? []) p[r.skill_id] = r.target_level;
    mintCert = c; mintPending = p;
  }
  // stage a node (toggle: clicking the staged level un-stages it)
  function stageAt(skillId: string, level: string) {
    mintMsg = '';
    if (staged[skillId] === level) { const { [skillId]: _, ...rest } = staged; staged = rest; }
    else staged = { ...staged, [skillId]: level };
  }
  const stagedCount = $derived(Object.keys(staged).length);
  async function submitBatch() {
    if (stagedCount === 0 || !mintMember) return;
    error = ''; mintMsg = ''; busy = 'batch';
    const items = Object.entries(staged).map(([skill, level]) => ({ skill, level }));
    const { error: err } = await supabase.rpc('mint_skillcard_batch', { p_member: mintMember, p_items: items });
    busy = '';
    if (err) { error = err.message; return; }
    const mn = members.find((m) => m.id === mintMember)?.full_name ?? '';
    mintMsg = get(t)('Submitted {n} role-card request(s) for {member} as one batch — awaiting review.', { n: stagedCount, member: mn });
    staged = {};
    await loadMintCert();
    await load(); // surface the new batch in the review queue
  }

  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name));
  }
  const sel = $derived(skills.find((s) => s.id === selected) ?? null);
  const myLevelHere = $derived(sel ? (myCert[sel.id] ?? null) : null);

  function pick(id: string) {
    selected = selected === id ? '' : id;
    error = '';
    if (selected) cardLevel = 'apprentice';
  }
</script>

<div class="stack">
  <div>
    <h1 style="margin-bottom:.15rem;">{$t('The Guild')} <Hint term="certification" text={$t('Certification turns a skill into a hard, reviewed credential — and sets your labor rate, which is how much your monthly hours mint.')} /></h1>
    <span class="muted" style="font-size:.85rem;">
      {#if PHASE2}
        {$t("Skills are a craft ladder — Apprentice → Journeyman → Craftsman → Master. A certified skill is a role card: request one (paying the mint or update fee) and a reviewer approves it.")}
      {:else}
        {$t("Skills are a craft ladder — Apprentice → Journeyman → Craftsman → Master. A certified skill is a role card. In Phase 1, officers mint cards onto their members for review; self-service requests open in Phase 2.")}
      {/if}
    </span>
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  {#if PHASE2 && $actingAs}
    <p class="muted" style="font-size:.82rem; margin:0;">{$t('Requesting role cards for card {name}; the fee is paid from the card’s balance.', { name: $actingAs.full_name })}</p>
  {/if}

  <!-- 审 role-card review queue — grouped by batch, approved/rejected as one -->
  {#if canReview && cardBatches.length > 0}
    <div class="card stack" style="gap:.5rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">{$t('Role cards awaiting your review')}</h2>
        <span class="badge warn">{cardQueue.length}</span>
      </div>
      {#each cardBatches as b}
        {@const head = b.items[0]}
        <div class="stack" style="gap:.4rem; padding:.55rem .2rem; border-top:1px solid var(--border-2);">
          <div class="row" style="justify-content:space-between; align-items:center; flex-wrap:wrap; gap:.4rem;">
            <span>{@html $t('<strong>{name}</strong> — {n} role card(s)', { name: head.member?.full_name ?? $t('A member'), n: b.items.length })}</span>
            <div class="row" style="gap:.4rem;">
              <button class="up" disabled={busy === 'batch:' + b.batch_id} onclick={() => reviewBatch(b.batch_id, true)}>{$t('Approve all')}</button>
              <button class="danger" disabled={busy === 'batch:' + b.batch_id} onclick={() => reviewBatch(b.batch_id, false)}>{$t('Reject all')}</button>
            </div>
          </div>
          <ul style="margin:0; padding:0; list-style:none;">
            {#each b.items as r}
              <li class="stack" style="gap:.2rem; padding:.2rem 0;">
                <span style="font-size:.85rem;">{r.skill?.name ?? ''}
                  · <span class="badge dim">{$t(LEVEL_LABEL[r.target_level])}</span>
                  · <span class="badge {r.kind === 'mint' ? 'pos' : 'dim'}">{r.kind === 'mint' ? $t('mint') : $t('update')}</span>
                  {#if r.fee > 0}· <span class="muted" style="font-size:.78rem;">{r.fee} STR</span>{/if}</span>
              </li>
            {/each}
          </ul>
          <input bind:value={cardNote[b.batch_id]} placeholder={$t('Note (optional; shown on the record)')} style="max-width:380px;" />
        </div>
      {/each}
    </div>
  {/if}

  <!-- direct mint (铸) — light up a member's talent tree -->
  {#if canMint}
    <div class="card stack" style="gap:.6rem;">
      <h2 style="margin:0;">{$t('Mint a role card')}</h2>
      <p class="muted" style="font-size:.85rem; margin:0;">
        {$t('Propose certifying a member’s skills — genesis, first cards, bootstrap or waiver. No fee, but a reviewer must approve each request before it takes effect.')}
      </p>
      <label class="row" style="gap:.5rem; align-items:center; flex-wrap:wrap;">
        <span class="muted" style="font-size:.78rem;">{$t('Member')}</span>
        <select bind:value={mintMember} onchange={loadMintCert} style="max-width:260px;">
          <option value="">{$t('— pick a member —')}</option>
          {#each members as m}<option value={m.id}>{m.full_name}{m.kind === 'card' ? ' · ' + $t('card') : ''}</option>{/each}
        </select>
      </label>
      {#if mintMember}
        <p class="muted" style="font-size:.76rem; margin:0;">{$t('Click nodes to stage them — like a talent tree — then submit the set as one batch for review. Filled = earned; dashed = pending; ringed = staged.')}</p>
        {#if mintMsg}<p class="pos" style="font-size:.82rem; margin:0;">{mintMsg}</p>{/if}
        <div class="talent">
          {#each domains as d}
            <div class="stack" style="gap:.3rem;">
              <h3 style="margin:0; font-size:.9rem;">{d.name}</h3>
              {#each leavesOf(d.id) as s}
                {@const cur = levelRank(mintCert[s.id] ?? null)}
                {@const pend = levelRank(mintPending[s.id] ?? null)}
                {@const stg = levelRank(staged[s.id] ?? null)}
                <div class="talent-row">
                  <span class="talent-name">{s.name}</span>
                  <div class="pips">
                    {#each LEVELS as lv, i}
                      <button
                        class="pip {i <= cur ? 'on' : (pend >= 0 && i <= pend ? 'pending' : (stg === i ? 'staged' : ''))}"
                        title={$t(LEVEL_LABEL[lv])}
                        disabled={i <= cur || pend >= 0}
                        onclick={() => stageAt(s.id, lv)}
                        aria-label={$t(LEVEL_LABEL[lv])}
                      ><span class="pip-dot"></span></button>
                    {/each}
                  </div>
                  <span class="talent-cur muted">
                    {cur >= 0 ? $t(LEVEL_LABEL[LEVELS[cur]]) : '—'}{#if pend >= 0} · {$t('pending {lvl}', { lvl: $t(LEVEL_LABEL[LEVELS[pend]]) })}{/if}{#if stg >= 0} · {$t('staged {lvl}', { lvl: $t(LEVEL_LABEL[LEVELS[stg]]) })}{/if}
                  </span>
                </div>
              {/each}
            </div>
          {/each}
        </div>
        <div class="row" style="gap:.5rem; align-items:center; border-top:1px solid var(--border-2); padding-top:.6rem;">
          <button class="stake" disabled={stagedCount === 0 || busy === 'batch'} onclick={submitBatch}>
            {busy === 'batch' ? $t('Submitting…') : $t('Submit batch for review · {n}', { n: stagedCount })}</button>
          {#if stagedCount > 0}<button onclick={() => (staged = {})} disabled={busy === 'batch'}>{$t('Clear')}</button>{/if}
        </div>
      {/if}
    </div>
  {/if}

  <!-- my role-card requests (self-service — Phase 2) -->
  {#if PHASE2 && myCardReqs.length > 0}
    <div class="card stack" style="gap:.4rem;">
      <h2 style="margin:0;">{$actingAs ? $t('{name}’s role-card requests', { name: $actingAs.full_name }) : $t('My role-card requests')}</h2>
      {#each myCardReqs as r}
        <div class="row" style="justify-content:space-between; align-items:center; padding:.35rem .2rem; border-top:1px solid var(--border-2);">
          <span>{r.skill?.name} · {$t(LEVEL_LABEL[r.target_level])} · <span class="muted" style="font-size:.78rem;">{r.fee} STR</span></span>
          <div class="row" style="gap:.4rem;">
            <span class="badge {r.status === 'approved' ? 'pos' : r.status === 'rejected' ? 'neg' : r.status === 'cancelled' ? 'dim' : 'warn'}">{$t(r.status)}</span>
            {#if r.status === 'submitted'}<button disabled={busy === r.id} onclick={() => cancelCard(r)}>{$t('Cancel')}</button>{/if}
          </div>
        </div>
      {/each}
    </div>
  {/if}

  <div class="row" style="gap:1rem; align-items:flex-start; flex-wrap:wrap;">
    <!-- tree -->
    <div class="card stack" style="flex:1; min-width:280px; gap:.8rem;">
      {#if loading}
        <p class="muted">{$t('Loading…')}</p>
      {:else}
        {#each domains as d}
          <div class="stack" style="gap:.3rem;">
            <h3 style="margin:0; font-size:.95rem;">{d.name}</h3>
            <div class="stack" style="gap:.15rem;">
              {#each leavesOf(d.id) as s}
                <button class="tree-leaf {selected === s.id ? 'on' : ''}" onclick={() => pick(s.id)}>
                  <span>{s.name}</span>
                  <span class="row" style="gap:.3rem;">
                    {#if myCert[s.id]}<Medal level={myCert[s.id]} size="sm" />{/if}
                    {#if holders[s.id]}<span class="muted" style="font-size:.72rem;">{holders[s.id]}⚒</span>{/if}
                  </span>
                </button>
              {/each}
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <!-- detail -->
    <div class="card stack" style="flex:1.2; min-width:300px; gap:.8rem;">
      {#if !sel}
        <p class="muted">{PHASE2 ? $t('Pick a skill from the tree to request a role card.') : $t('Pick a skill from the tree to see who holds it.')}</p>
      {:else}
        <div>
          <h2 style="margin:0;">{sel.name}</h2>
          <p class="muted" style="font-size:.82rem; margin:.2rem 0 0;">
            {#if holders[sel.id]}{$t('{n} certified holder(s)', { n: holders[sel.id] })}{:else}{$t('No certified holders yet.')}{/if}
            {#if myLevelHere}· {@html $t('you are <strong class="pos">✓ {level}</strong>', { level: $t(LEVEL_LABEL[myLevelHere]) })}{/if}
          </p>
        </div>

        <!-- request a role card (mint / update) — self-service, Phase 2 -->
        {#if PHASE2 && effId}
          <div class="card" style="background:var(--card-2); border-color:transparent; padding:.6rem .8rem;">
            <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Request role card at')}</span>
                <select bind:value={cardLevel}>
                  {#each LEVELS as lv}<option value={lv} disabled={levelRank(myLevelHere) >= levelRank(lv)}>{$t(LEVEL_LABEL[lv])}</option>{/each}
                </select></label>
              <button class="stake" onclick={submitCard} disabled={busy === 'card' || cardFeeFor(sel.id) > myBalance}>
                {busy === 'card' ? $t('Submitting…') : $t('Request · {n} STR', { n: cardFeeFor(sel.id) })}</button>
            </div>
            {#if cardFeeFor(sel.id) > myBalance}<span class="neg" style="font-size:.75rem;">{$t('Insufficient balance ({bal} STR).', { bal: myBalance })}</span>{/if}
            <p class="muted" style="font-size:.74rem; margin:.4rem 0 0;">
              {myLevelHere ? $t('Update fee {n} STR — escrowed and refunded if rejected.', { n: updateFee }) : $t('Mint fee {n} STR — escrowed and refunded if rejected.', { n: mintFee })}
              {$t('A reviewer approves or rejects your request.')}
            </p>
          </div>
        {/if}
      {/if}
    </div>
  </div>
</div>

<style>
  .tree-leaf {
    display: flex; justify-content: space-between; align-items: center; gap: .5rem;
    width: 100%; text-align: left; padding: .35rem .55rem; border-radius: 6px;
    background: transparent; border: 1px solid transparent; color: inherit; cursor: pointer;
    font-size: .85rem;
  }
  .tree-leaf:hover { background: var(--card-2); }
  .tree-leaf.on { background: var(--accent-soft); border-color: var(--accent); }

  /* talent-tree mint grid */
  .talent {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: .9rem 1.4rem;
  }
  .talent-row {
    display: flex; align-items: center; gap: .5rem; padding: .15rem 0;
  }
  .talent-name { flex: 1; font-size: .85rem; }
  .talent-cur { font-size: .68rem; min-width: 64px; text-align: right; }
  .pips { display: flex; gap: .28rem; }
  .pip {
    display: inline-flex; align-items: center; justify-content: center;
    background: transparent; border: none; padding: 2px; cursor: pointer;
  }
  .pip:disabled { cursor: default; }
  .pip-dot {
    width: 13px; height: 13px; border-radius: 50%;
    border: 1.5px solid var(--border); background: transparent; transition: all .12s;
  }
  .pip.on .pip-dot { background: var(--accent); border-color: var(--accent); }
  .pip.pending .pip-dot { border-style: dashed; border-color: var(--accent); background: var(--accent-soft); }
  .pip.staged .pip-dot { border-color: var(--accent); box-shadow: 0 0 0 2px var(--accent-soft); background: transparent; }
  .pip:not(.on):not(.pending):not(:disabled):hover .pip-dot { border-color: var(--accent); background: var(--accent-soft); }
</style>
