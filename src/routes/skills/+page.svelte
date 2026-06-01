<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, actingAs } from '$lib/session';
  import Hint from '$lib/Hint.svelte';
  import { t } from '$lib/i18n';
  import { get } from 'svelte/store';

  type Skill = { id: string; name: string; parent_id: string | null; master_member_id: string | null };
  type Rubric = { skill_id: string; level: string; requirements: string };
  type ExamRow = {
    id: string; skill_id: string; target_level: string; status: string; fee: number;
    applicant_member_id: string;
    skill: { name: string } | null; applicant: { full_name: string } | null;
  };
  type CardReq = {
    id: string; skill_id: string; member_id: string; target_level: string; kind: string;
    fee: number; status: string;
    skill: { name: string } | null; member: { full_name: string } | null;
  };
  type Mem = { id: string; full_name: string };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman',
    craftsman: 'Craftsman', master: 'Master'
  };
  const levelRank = (l: string | null) => (l ? LEVELS.indexOf(l) : -1);

  let skills = $state<Skill[]>([]);
  let masterName = $state<Record<string, string>>({});
  let holders = $state<Record<string, number>>({});          // certified holders per skill
  let myCert = $state<Record<string, string>>({});           // my certified_level per skill
  let rubrics = $state<Record<string, Record<string, string>>>({}); // skill -> level -> text
  let fees = $state<Record<string, number>>({});
  let myBalance = $state(0);
  let reviewerQueue = $state<ExamRow[]>([]);
  let myExams = $state<ExamRow[]>([]);
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

  // direct mint (forge / update any member's skill profile — no fee, no review)
  let members = $state<Mem[]>([]);
  let mintMember = $state(''); let mintMsg = $state('');
  let mintCert = $state<Record<string, string>>({});     // selected member's certified levels per skill
  let mintPending = $state<Record<string, string>>({});  // selected member's pending request target levels

  let selected = $state(''); // selected leaf skill id
  let cardLevel = $state('apprentice');
  let cardNote = $state<Record<string, string>>({});
  let examLevel = $state('apprentice');
  let rubricLevel = $state('apprentice');
  let rubricText = $state('');
  let voteNote = $state<Record<string, string>>({});

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const me = effId;
    const [{ data: sk }, { data: ms }, { data: ru }, { data: pol }, { data: cardPol }, { data: mineCert }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id, master_member_id, master:master_member_id(full_name)').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').not('certified_level', 'is', null),
      supabase.from('skill_exam_rubric').select('skill_id, level, requirements'),
      supabase.from('stater_policy').select('key, value').like('key', 'skill_exam_fee_%'),
      supabase.from('stater_policy').select('key, value').in('key', ['skillcard_mint_fee', 'skillcard_update_fee']),
      me ? supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', me) : Promise.resolve({ data: [] })
    ]);
    for (const p of (cardPol as { key: string; value: number }[]) ?? []) {
      if (p.key === 'skillcard_mint_fee') mintFee = Number(p.value);
      if (p.key === 'skillcard_update_fee') updateFee = Number(p.value);
    }

    skills = ((sk as any[]) ?? []).map((s) => ({ id: s.id, name: s.name, parent_id: s.parent_id, master_member_id: s.master_member_id }));
    const mn: Record<string, string> = {};
    for (const s of (sk as any[]) ?? []) if (s.master?.full_name) mn[s.id] = s.master.full_name;
    masterName = mn;

    const h: Record<string, number> = {};
    for (const r of (ms as any[]) ?? []) h[r.skill_id] = (h[r.skill_id] ?? 0) + 1;
    holders = h;

    const rb: Record<string, Record<string, string>> = {};
    for (const r of (ru as Rubric[]) ?? []) { (rb[r.skill_id] ??= {})[r.level] = r.requirements; }
    rubrics = rb;

    const f: Record<string, number> = {};
    for (const p of (pol as { key: string; value: number }[]) ?? [])
      f[p.key.replace('skill_exam_fee_', '')] = Number(p.value);
    fees = f;

    const mc: Record<string, string> = {};
    for (const r of (mineCert as any[]) ?? []) if (r.certified_level) mc[r.skill_id] = r.certified_level;
    myCert = mc;

    if (me) {
      const [{ data: q }, { data: mx }, { data: bal }] = await Promise.all([
        supabase.from('skill_exam_vote')
          .select('exam:exam_id(id, skill_id, target_level, status, fee, applicant_member_id, skill:skill_id(name), applicant:applicant_member_id(full_name))')
          .eq('reviewer_member_id', me).is('vote', null),
        supabase.from('skill_exam')
          .select('id, skill_id, target_level, status, fee, applicant_member_id, skill:skill_id(name), applicant:applicant_member_id(full_name)')
          .eq('applicant_member_id', me).order('created_at', { ascending: false }),
        supabase.from('stater_balance').select('balance').eq('owner_member_id', me).maybeSingle()
      ]);
      reviewerQueue = ((q as any[]) ?? []).map((r) => r.exam).filter((e) => e && e.status === 'in_review');
      myExams = (mx as ExamRow[]) ?? [];
      myBalance = Number((bal as { balance: number } | null)?.balance ?? 0);

      // my (or acting card's) role-card requests
      const { data: mr } = await supabase
        .from('skillcard_request')
        .select('id, skill_id, member_id, target_level, kind, fee, status, skill:skill_id(name), member:member_id(full_name)')
        .eq('member_id', me).order('created_at', { ascending: false });
      myCardReqs = (mr as CardReq[]) ?? [];
    }

    // 审 review queue — all open requests (reviewer acts as the current operator)
    if ($capabilities.has('review_skillcard')) {
      const { data: cq } = await supabase
        .from('skillcard_request')
        .select('id, skill_id, member_id, target_level, kind, fee, status, skill:skill_id(name), member:member_id(full_name)')
        .eq('status', 'submitted').order('created_at');
      cardQueue = (cq as CardReq[]) ?? [];
    } else {
      cardQueue = [];
    }

    // member roster for the direct-mint tool (forge any member's profile)
    if ($capabilities.has('mint_skillcard')) {
      const { data: mem } = await supabase.from('member').select('id, full_name').eq('status', 'active').order('full_name');
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
  async function reviewCard(req: CardReq, approve: boolean) {
    error = ''; busy = req.id;
    const { error: err } = await supabase.rpc('review_skillcard_request', { p_request: req.id, p_approve: approve, p_note: cardNote[req.id] ?? null });
    busy = '';
    if (err) { error = err.message; return; }
    cardNote[req.id] = '';
    await load();
  }

  // direct mint (铸 — click a member's talent tree to PROPOSE a certification)
  async function loadMintCert() {
    mintMsg = ''; mintCert = {}; mintPending = {};
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
  async function mintAt(skillId: string, level: string) {
    error = ''; mintMsg = ''; busy = 'mint:' + skillId;
    const { error: err } = await supabase.rpc('mint_skillcard', { p_member: mintMember, p_skill: skillId, p_level: level });
    busy = '';
    if (err) { error = err.message; return; }
    const mn = members.find((m) => m.id === mintMember)?.full_name ?? '';
    const sn = skills.find((s) => s.id === skillId)?.name ?? '';
    mintMsg = get(t)('Submitted a {level} role-card request for {member} in {skill} — awaiting review.', { member: mn, skill: sn, level: get(t)(LEVEL_LABEL[level]) });
    await loadMintCert();
    await load(); // surface the new request in the review queue
  }

  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name));
  }
  const sel = $derived(skills.find((s) => s.id === selected) ?? null);
  const iAmMaster = $derived(!!sel && !!$member && sel.master_member_id === $member.id);
  const myLevelHere = $derived(sel ? (myCert[sel.id] ?? null) : null);
  const unclaimed = $derived(!!sel && !sel.master_member_id);

  function pick(id: string) {
    selected = selected === id ? '' : id;
    error = '';
    if (selected) {
      rubricLevel = 'apprentice';
      rubricText = rubrics[selected]?.['apprentice'] ?? '';
      examLevel = 'apprentice';
    }
  }
  $effect(() => { if (selected) rubricText = rubrics[selected]?.[rubricLevel] ?? ''; });

  async function requestExam() {
    if (!sel || !$member) return;
    error = ''; busy = 'exam';
    const { error: err } = await supabase.rpc('request_skill_exam', { p_skill: sel.id, p_level: examLevel });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
  async function castVote(exam: ExamRow, pass: boolean) {
    error = ''; busy = exam.id;
    const { error: err } = await supabase.rpc('cast_exam_vote', { p_exam: exam.id, p_pass: pass, p_note: voteNote[exam.id] ?? null });
    busy = '';
    if (err) { error = err.message; return; }
    voteNote[exam.id] = '';
    await load();
  }
  async function saveRubric() {
    if (!sel) return;
    error = ''; busy = 'rubric';
    const { error: err } = await supabase.rpc('set_exam_rubric', { p_skill: sel.id, p_level: rubricLevel, p_requirements: rubricText.trim() });
    busy = '';
    if (err) { error = err.message; return; }
    await load();
  }
</script>

<div class="stack">
  <div>
    <h1 style="margin-bottom:.15rem;">{$t('The Guild')} <Hint term="certification" text={$t('Certification turns a self-declared skill into a hard, peer-reviewed credential — and sets your labor rate, which is how much your monthly hours mint.')} /></h1>
    <span class="muted" style="font-size:.85rem;">
      {$t("Skills are a craft ladder — Apprentice → Journeyman → Craftsman → Master. A certified skill is a role card: request one (paying the mint or update fee) and a reviewer approves it. A paid peer exam is also available where a craft has a master.")}
    </span>
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  {#if $actingAs}
    <p class="muted" style="font-size:.82rem; margin:0;">{$t('Requesting role cards for card {name}; the fee is paid from the card’s balance.', { name: $actingAs.full_name })}</p>
  {/if}

  <!-- 审 role-card review queue -->
  {#if canReview && cardQueue.length > 0}
    <div class="card stack" style="gap:.5rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">{$t('Role cards awaiting your review')}</h2>
        <span class="badge warn">{cardQueue.length}</span>
      </div>
      {#each cardQueue as r}
        <div class="stack" style="gap:.35rem; padding:.5rem .2rem; border-top:1px solid var(--border-2);">
          <div class="row" style="justify-content:space-between; align-items:center; flex-wrap:wrap; gap:.4rem;">
            <span>{@html $t('<strong>{name}</strong> requests <strong>{skill}</strong>', { name: r.member?.full_name ?? $t('A member'), skill: r.skill?.name ?? '' })}
              · <span class="badge dim">{$t(LEVEL_LABEL[r.target_level])}</span>
              · <span class="badge {r.kind === 'mint' ? 'pos' : 'dim'}">{r.kind === 'mint' ? $t('mint') : $t('update')}</span>
              · <span class="muted" style="font-size:.78rem;">{r.fee} STR</span></span>
            <div class="row" style="gap:.4rem;">
              <button class="up" disabled={busy === r.id} onclick={() => reviewCard(r, true)}>{$t('Approve')}</button>
              <button class="danger" disabled={busy === r.id} onclick={() => reviewCard(r, false)}>{$t('Reject')}</button>
            </div>
          </div>
          {#if rubrics[r.skill_id]?.[r.target_level]}
            <p class="muted" style="font-size:.8rem; margin:0;"><strong>{$t('Rubric:')}</strong> {rubrics[r.skill_id][r.target_level]}</p>
          {/if}
          <input bind:value={cardNote[r.id]} placeholder={$t('Note (optional; shown on the record)')} style="max-width:380px;" />
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
          {#each members as m}<option value={m.id}>{m.full_name}</option>{/each}
        </select>
      </label>
      {#if mintMember}
        <p class="muted" style="font-size:.76rem; margin:0;">{$t('Click a node to submit a certification request — like a talent tree. Filled = earned; dashed = pending review.')}</p>
        {#if mintMsg}<p class="pos" style="font-size:.82rem; margin:0;">{mintMsg}</p>{/if}
        <div class="talent">
          {#each domains as d}
            <div class="stack" style="gap:.3rem;">
              <h3 style="margin:0; font-size:.9rem;">{d.name}</h3>
              {#each leavesOf(d.id) as s}
                {@const cur = levelRank(mintCert[s.id] ?? null)}
                {@const pend = levelRank(mintPending[s.id] ?? null)}
                <div class="talent-row">
                  <span class="talent-name">{s.name}</span>
                  <div class="pips">
                    {#each LEVELS as lv, i}
                      <button
                        class="pip {i <= cur ? 'on' : (pend >= 0 && i <= pend ? 'pending' : '')}"
                        title={$t(LEVEL_LABEL[lv])}
                        disabled={i <= cur || pend >= 0 || busy === 'mint:' + s.id}
                        onclick={() => mintAt(s.id, lv)}
                        aria-label={$t(LEVEL_LABEL[lv])}
                      ><span class="pip-dot"></span></button>
                    {/each}
                  </div>
                  <span class="talent-cur muted">
                    {cur >= 0 ? $t(LEVEL_LABEL[LEVELS[cur]]) : '—'}{#if pend >= 0} · {$t('pending {lvl}', { lvl: $t(LEVEL_LABEL[LEVELS[pend]]) })}{/if}
                  </span>
                </div>
              {/each}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  <!-- my role-card requests -->
  {#if myCardReqs.length > 0}
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

  <!-- reviewer queue -->
  {#if reviewerQueue.length > 0}
    <div class="card stack" style="gap:.5rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">{$t('Exams awaiting your review')}</h2>
        <span class="badge warn">{reviewerQueue.length}</span>
      </div>
      {#each reviewerQueue as e}
        <div class="stack" style="gap:.35rem; padding:.5rem .2rem; border-top:1px solid var(--border-2);">
          <div class="row" style="justify-content:space-between; align-items:center; flex-wrap:wrap; gap:.4rem;">
            <span>{@html $t('<strong>{name}</strong> sits <strong>{skill}</strong>', { name: e.applicant?.full_name ?? $t('A member'), skill: e.skill?.name ?? '' })} · <span class="badge dim">{$t(LEVEL_LABEL[e.target_level])}</span></span>
            <div class="row" style="gap:.4rem;">
              <button class="up" disabled={busy === e.id} onclick={() => castVote(e, true)}>{$t('Pass')}</button>
              <button class="danger" disabled={busy === e.id} onclick={() => castVote(e, false)}>{$t('Fail')}</button>
            </div>
          </div>
          {#if rubrics[e.skill_id]?.[e.target_level]}
            <p class="muted" style="font-size:.8rem; margin:0;"><strong>{$t('Rubric:')}</strong> {rubrics[e.skill_id][e.target_level]}</p>
          {:else}
            <p class="muted" style="font-size:.8rem; margin:0;">{$t('No rubric on file — grade on your own judgement.')}</p>
          {/if}
          <input bind:value={voteNote[e.id]} placeholder={$t('Note to applicant (optional)')} style="max-width:380px;" />
        </div>
      {/each}
    </div>
  {/if}

  <!-- my exams -->
  {#if myExams.length > 0}
    <div class="card stack" style="gap:.4rem;">
      <h2 style="margin:0;">{$t('My exams')}</h2>
      {#each myExams as e}
        <div class="row" style="justify-content:space-between; padding:.35rem .2rem; border-top:1px solid var(--border-2);">
          <span>{e.skill?.name} · {$t(LEVEL_LABEL[e.target_level])}</span>
          <span class="badge {e.status === 'passed' ? 'pos' : e.status === 'failed' ? 'neg' : 'dim'}">{e.status === 'in_review' ? $t('in review') : $t(e.status)}</span>
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
                    {#if myCert[s.id]}<span class="badge pos" style="font-size:.62rem;">✓ {myCert[s.id]}</span>{/if}
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
        <p class="muted">{$t('Pick a skill from the tree to see its master, rubric, and exam.')}</p>
      {:else}
        <div>
          <h2 style="margin:0;">{sel.name}</h2>
          <p class="muted" style="font-size:.82rem; margin:.2rem 0 0;">
            {$t('Master')}<Hint term="master" text={$t("The admin-appointed owner of this craft's rubric and reviewer pool — the top of the guild ladder. Certification opens once a master is appointed.")} />: {masterName[sel.id] ?? $t('— none appointed —')}
            {#if holders[sel.id]}· {$t('{n} certified holder(s)', { n: holders[sel.id] })}{/if}
            {#if myLevelHere}· {@html $t('you are <strong class="pos">✓ {level}</strong>', { level: $t(LEVEL_LABEL[myLevelHere]) })}{/if}
          </p>
        </div>

        <!-- rubric display -->
        <div class="stack" style="gap:.3rem;">
          <h3 style="margin:0; font-size:.9rem;">{$t('Rubric')}</h3>
          {#each LEVELS as lv}
            {#if rubrics[sel.id]?.[lv]}
              <div style="font-size:.82rem;"><span class="badge dim">{$t(LEVEL_LABEL[lv])}</span> {rubrics[sel.id][lv]}</div>
            {/if}
          {/each}
          {#if !rubrics[sel.id] || Object.keys(rubrics[sel.id]).length === 0}
            <p class="muted" style="font-size:.82rem; margin:0;">{$t('No rubric published yet.')}</p>
          {/if}
        </div>

        <!-- no master appointed yet → certification can't open -->
        {#if unclaimed}
          <div class="card" style="background:var(--card-2); border-color:transparent; padding:.6rem .8rem;">
            <p class="muted" style="font-size:.8rem; margin:0;">
              {$t('No master appointed yet. An admin appoints a master in')} <a href="/admin/skills">{$t('the skill tree')}</a>{$t('; certification opens once a master seeds the reviewer pool.')}
            </p>
          </div>
        {/if}

        <!-- request a role card (mint / update) — the primary certification path -->
        {#if effId && !iAmMaster}
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

        <!-- take exam (only once the craft has a Master + reviewer pool) -->
        {#if $member && !iAmMaster && !unclaimed}
          <div class="card" style="background:var(--accent-soft); border-color:transparent; padding:.6rem .8rem;">
            <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Sit exam at')}</span>
                <select bind:value={examLevel}>
                  {#each LEVELS as lv}<option value={lv} disabled={levelRank(myLevelHere) >= levelRank(lv)}>{$t(LEVEL_LABEL[lv])} · {fees[lv] ?? '—'} STR</option>{/each}
                </select></label>
              <button class="stake" onclick={requestExam} disabled={busy === 'exam' || (fees[examLevel] ?? 0) > myBalance}>
                {busy === 'exam' ? $t('Requesting…') : $t('Sit exam · {n} STR', { n: fees[examLevel] ?? '—' })}</button>
            </div>
            {#if (fees[examLevel] ?? 0) > myBalance}<span class="neg" style="font-size:.75rem;">{$t('Insufficient balance ({bal} STR).', { bal: myBalance })}</span>{/if}
            <p class="muted" style="font-size:.74rem; margin:.4rem 0 0;">{$t('A panel of certified peers grades you. The fee pays the reviewers (80%) and treasury (20%) whether you pass or fail.')}</p>
          </div>
        {/if}

        <!-- master tools: the appointed master owns the rubric -->
        {#if iAmMaster}
          <div class="stack" style="gap:.5rem; border-top:1px solid var(--border-2); padding-top:.6rem;">
            <h3 style="margin:0; font-size:.9rem;">{$t('Master tools — rubric')}</h3>
            <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">{$t('Rubric for')}</span>
                <select bind:value={rubricLevel}>{#each LEVELS as lv}<option value={lv}>{$t(LEVEL_LABEL[lv])}</option>{/each}</select></label>
            </div>
            <textarea bind:value={rubricText} rows="3" placeholder={$t('What must a candidate demonstrate at this level?')}></textarea>
            <div class="row"><button onclick={saveRubric} disabled={busy === 'rubric'}>{busy === 'rubric' ? $t('Saving…') : $t('Save rubric')}</button></div>
            <p class="muted" style="font-size:.74rem; margin:0;">{$t('You were appointed master of this craft — define how each level is tested. The tree itself (adding or branching skills) is managed by admins in')} <a href="/admin/skills">{$t('the skill tree')}</a>.</p>
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
  .pip:not(.on):not(.pending):not(:disabled):hover .pip-dot { border-color: var(--accent); background: var(--accent-soft); }
</style>
