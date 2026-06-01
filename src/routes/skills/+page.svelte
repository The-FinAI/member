<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member } from '$lib/session';

  type Skill = { id: string; name: string; parent_id: string | null; master_member_id: string | null };
  type Rubric = { skill_id: string; level: string; requirements: string };
  type ExamRow = {
    id: string; skill_id: string; target_level: string; status: string; fee: number;
    applicant_member_id: string;
    skill: { name: string } | null; applicant: { full_name: string } | null;
  };

  const LEVELS = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice 学徒', journeyman: 'Journeyman 职人',
    craftsman: 'Craftsman 名匠', master: 'Master 宗师'
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
  let loading = $state(true);
  let error = $state('');
  let busy = $state('');

  let selected = $state(''); // selected leaf skill id
  let examLevel = $state('apprentice');
  let rubricLevel = $state('apprentice');
  let rubricText = $state('');
  let branchName = $state('');
  let voteNote = $state<Record<string, string>>({});

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const me = $member?.id ?? null;
    const [{ data: sk }, { data: ms }, { data: ru }, { data: pol }, { data: mineCert }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id, master_member_id, master:master_member_id(full_name)').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').not('certified_level', 'is', null),
      supabase.from('skill_exam_rubric').select('skill_id, level, requirements'),
      supabase.from('stater_policy').select('key, value').like('key', 'skill_exam_fee_%'),
      me ? supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', me) : Promise.resolve({ data: [] })
    ]);

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
    }
    loading = false;
  }

  onMount(() => {
    load();
    const unsub = member.subscribe((m) => { if (m) load(); });
    return unsub;
  });

  const domains = $derived(skills.filter((s) => !s.parent_id).sort((a, b) => a.name.localeCompare(b.name)));
  function leavesOf(domainId: string) {
    return skills.filter((s) => s.parent_id === domainId).sort((a, b) => a.name.localeCompare(b.name));
  }
  const sel = $derived(skills.find((s) => s.id === selected) ?? null);
  const iAmMaster = $derived(!!sel && !!$member && sel.master_member_id === $member.id);
  const myLevelHere = $derived(sel ? (myCert[sel.id] ?? null) : null);

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
  async function branch() {
    if (!sel || !branchName.trim()) return;
    error = ''; busy = 'branch';
    const { error: err } = await supabase.rpc('branch_skill', { p_parent: sel.id, p_name: branchName.trim() });
    busy = '';
    if (err) { error = err.message; return; }
    branchName = '';
    await load();
  }
</script>

<div class="stack">
  <div>
    <h1 style="margin-bottom:.15rem;">The Guild</h1>
    <span class="muted" style="font-size:.85rem;">
      Skills are a craft ladder — Apprentice → Journeyman → Craftsman → Master. Certification is earned by paid, peer-reviewed exam. The first to hold a skill masters it, owns its rubric, and may branch new sub-crafts.
    </span>
  </div>

  {#if error}<p class="neg" style="font-size:.85rem;">{error}</p>{/if}

  <!-- reviewer queue -->
  {#if reviewerQueue.length > 0}
    <div class="card stack" style="gap:.5rem;">
      <div class="row" style="justify-content:space-between; align-items:center;">
        <h2 style="margin:0;">Exams awaiting your review</h2>
        <span class="badge warn">{reviewerQueue.length}</span>
      </div>
      {#each reviewerQueue as e}
        <div class="stack" style="gap:.35rem; padding:.5rem .2rem; border-top:1px solid var(--border-2);">
          <div class="row" style="justify-content:space-between; align-items:center; flex-wrap:wrap; gap:.4rem;">
            <span><strong>{e.applicant?.full_name ?? 'A member'}</strong> sits <strong>{e.skill?.name}</strong> · <span class="badge dim">{LEVEL_LABEL[e.target_level]}</span></span>
            <div class="row" style="gap:.4rem;">
              <button class="up" disabled={busy === e.id} onclick={() => castVote(e, true)}>Pass</button>
              <button class="danger" disabled={busy === e.id} onclick={() => castVote(e, false)}>Fail</button>
            </div>
          </div>
          {#if rubrics[e.skill_id]?.[e.target_level]}
            <p class="muted" style="font-size:.8rem; margin:0;"><strong>Rubric:</strong> {rubrics[e.skill_id][e.target_level]}</p>
          {:else}
            <p class="muted" style="font-size:.8rem; margin:0;">No rubric on file — grade on your own judgement.</p>
          {/if}
          <input bind:value={voteNote[e.id]} placeholder="Note to applicant (optional)" style="max-width:380px;" />
        </div>
      {/each}
    </div>
  {/if}

  <!-- my exams -->
  {#if myExams.length > 0}
    <div class="card stack" style="gap:.4rem;">
      <h2 style="margin:0;">My exams</h2>
      {#each myExams as e}
        <div class="row" style="justify-content:space-between; padding:.35rem .2rem; border-top:1px solid var(--border-2);">
          <span>{e.skill?.name} · {LEVEL_LABEL[e.target_level]}</span>
          <span class="badge {e.status === 'passed' ? 'pos' : e.status === 'failed' ? 'neg' : 'dim'}">{e.status === 'in_review' ? 'in review' : e.status}</span>
        </div>
      {/each}
    </div>
  {/if}

  <div class="row" style="gap:1rem; align-items:flex-start; flex-wrap:wrap;">
    <!-- tree -->
    <div class="card stack" style="flex:1; min-width:280px; gap:.8rem;">
      {#if loading}
        <p class="muted">Loading…</p>
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
        <p class="muted">Pick a skill from the tree to see its master, rubric, and exam.</p>
      {:else}
        <div>
          <h2 style="margin:0;">{sel.name}</h2>
          <p class="muted" style="font-size:.82rem; margin:.2rem 0 0;">
            Master: {masterName[sel.id] ?? '— unclaimed —'}
            {#if holders[sel.id]}· {holders[sel.id]} certified holder{holders[sel.id] === 1 ? '' : 's'}{/if}
            {#if myLevelHere}· you are <strong class="pos">✓ {LEVEL_LABEL[myLevelHere]}</strong>{/if}
          </p>
        </div>

        <!-- rubric display -->
        <div class="stack" style="gap:.3rem;">
          <h3 style="margin:0; font-size:.9rem;">Rubric</h3>
          {#each LEVELS as lv}
            {#if rubrics[sel.id]?.[lv]}
              <div style="font-size:.82rem;"><span class="badge dim">{LEVEL_LABEL[lv]}</span> {rubrics[sel.id][lv]}</div>
            {/if}
          {/each}
          {#if !rubrics[sel.id] || Object.keys(rubrics[sel.id]).length === 0}
            <p class="muted" style="font-size:.82rem; margin:0;">No rubric published yet.</p>
          {/if}
        </div>

        <!-- take exam -->
        {#if $member && !iAmMaster}
          <div class="card" style="background:var(--accent-soft); border-color:transparent; padding:.6rem .8rem;">
            <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">Sit exam at</span>
                <select bind:value={examLevel}>
                  {#each LEVELS as lv}<option value={lv} disabled={levelRank(myLevelHere) >= levelRank(lv)}>{LEVEL_LABEL[lv]} · {fees[lv] ?? '—'} STR</option>{/each}
                </select></label>
              <button class="stake" onclick={requestExam} disabled={busy === 'exam' || (fees[examLevel] ?? 0) > myBalance}>
                {busy === 'exam' ? 'Requesting…' : `Sit exam · ${fees[examLevel] ?? '—'} STR`}</button>
            </div>
            {#if (fees[examLevel] ?? 0) > myBalance}<span class="neg" style="font-size:.75rem;">Insufficient balance ({myBalance} STR).</span>{/if}
            <p class="muted" style="font-size:.74rem; margin:.4rem 0 0;">A panel of certified peers grades you. The fee pays the reviewers (80%) and treasury (20%) whether you pass or fail.</p>
          </div>
        {/if}

        <!-- master tools -->
        {#if iAmMaster}
          <div class="stack" style="gap:.5rem; border-top:1px solid var(--border-2); padding-top:.6rem;">
            <h3 style="margin:0; font-size:.9rem;">Master tools</h3>
            <div class="row" style="align-items:flex-end; gap:.5rem; flex-wrap:wrap;">
              <label class="stack" style="gap:.2rem;"><span class="muted" style="font-size:.72rem;">Rubric for</span>
                <select bind:value={rubricLevel}>{#each LEVELS as lv}<option value={lv}>{LEVEL_LABEL[lv]}</option>{/each}</select></label>
            </div>
            <textarea bind:value={rubricText} rows="3" placeholder="What must a candidate demonstrate at this level?"></textarea>
            <div class="row"><button onclick={saveRubric} disabled={busy === 'rubric'}>{busy === 'rubric' ? 'Saving…' : 'Save rubric'}</button></div>
            <div class="row" style="gap:.5rem; align-items:flex-end;">
              <label class="stack" style="gap:.2rem; flex:1;"><span class="muted" style="font-size:.72rem;">Branch a sub-skill</span>
                <input bind:value={branchName} placeholder="e.g. Relation extraction" /></label>
              <button onclick={branch} disabled={busy === 'branch' || !branchName.trim()}>{busy === 'branch' ? '…' : 'Branch'}</button>
            </div>
            <p class="muted" style="font-size:.74rem; margin:0;">You author this craft. Define how each level is tested, and split it into finer sub-crafts you'll master.</p>
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
</style>
