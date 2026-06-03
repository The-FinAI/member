<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { PHASE2 } from '$lib/phase';
  import CountUp from '$lib/CountUp.svelte';
  import GettingStarted from '$lib/GettingStarted.svelte';
  import Medal from '$lib/Medal.svelte';
  import EntityCard from '$lib/EntityCard.svelte';
  import { goto } from '$app/navigation';
  import { t } from '$lib/i18n';

  // ── Home is the overview台: only things you READ. Everything you EDIT
  // (resources you can bring, identity/affiliation) lives on /profile; the full
  // ledger lives on /wallet. This page answers "what's my standing, and what
  // needs me next."

  type MyProject = { project: { id: string; name: string; project_status: { name: string; is_active: boolean } | null } | null; project_role: { name: string } | null };
  type MyApp = { id: string; status: string; open_need: { project: { id: string; name: string } | null } | null };
  type Skill = { id: string; name: string; parent_id: string | null };
  type MySkill = { skill_id: string; certified_level: string | null };
  type LedgerRow = {
    id: string; amount: number; entry_type: string; reason: string;
    from_account: string | null; to_account: string | null; created_at: string;
  };

  const GUILD_RANK = ['apprentice', 'journeyman', 'craftsman', 'master'];
  const LEVEL_LABEL: Record<string, string> = {
    apprentice: 'Apprentice', journeyman: 'Journeyman', craftsman: 'Craftsman', master: 'Master'
  };

  let myProjects = $state<MyProject[]>([]);
  let myApps = $state<MyApp[]>([]);
  let openCount = $state(0);
  let projectCount = $state(0);
  let balance = $state(0);
  let staked = $state(0);
  let loading = $state(true);

  let skills = $state<Skill[]>([]);
  let mySkills = $state<MySkill[]>([]);
  let accountId = $state('');
  let totalNominal = $state(0);
  let ledger = $state<LedgerRow[]>([]);
  let skillsLoading = $state(true);

  async function loadPortfolio(memberId: string) {
    loading = true;
    const [{ data: mp }, { data: ma }, { count: oc }, { count: pc }, { data: bal }, { data: cm }] = await Promise.all([
      supabase.from('project_member')
        .select('project(id, name, project_status!project_status_id_fkey(name, is_active)), project_role(name)')
        .eq('member_id', memberId),
      supabase.from('need_application')
        .select('id, status, open_need(project(id, name))')
        .eq('member_id', memberId)
        .order('created_at', { ascending: false }),
      supabase.from('open_need').select('*', { count: 'exact', head: true }).eq('status', 'open'),
      supabase.from('project').select('*', { count: 'exact', head: true }),
      supabase.from('stater_balance').select('balance').eq('owner_member_id', memberId).maybeSingle(),
      supabase.from('stater_project_stake_commitment')
        .select('token_amount, status').eq('member_id', memberId)
    ]);
    myProjects = (mp as MyProject[]) ?? [];
    myApps = (ma as MyApp[]) ?? [];
    openCount = oc ?? 0;
    projectCount = pc ?? 0;
    balance = Number((bal as { balance: number } | null)?.balance ?? 0);
    staked = ((cm as { token_amount: number; status: string }[]) ?? [])
      .filter((c) => ['pledged', 'accepted', 'verified'].includes(c.status))
      .reduce((a, c) => a + Number(c.token_amount), 0);
    loading = false;
  }

  // badges (read-only craft), accrued contribution, and a short ledger preview
  async function loadStanding(memberId: string) {
    skillsLoading = true;
    const [{ data: tree }, { data: ms }, { data: nom }] = await Promise.all([
      supabase.from('skill').select('id, name, parent_id').order('name'),
      supabase.from('member_skill').select('skill_id, certified_level').eq('member_id', memberId),
      supabase.from('stater_project_member_nominal').select('nominal').eq('member_id', memberId)
    ]);
    skills = (tree as Skill[]) ?? [];
    mySkills = ((ms as MySkill[]) ?? []).sort(
      (a, b) => GUILD_RANK.indexOf(b.certified_level ?? '') - GUILD_RANK.indexOf(a.certified_level ?? '')
        || skillName(a.skill_id).localeCompare(skillName(b.skill_id))
    );
    totalNominal = ((nom as { nominal: number }[]) ?? []).reduce((a, n) => a + (Number(n.nominal) || 0), 0);

    const { data: bal } = await supabase.from('stater_balance').select('account_id').eq('owner_member_id', memberId).maybeSingle();
    accountId = (bal as { account_id: string } | null)?.account_id ?? '';
    if (accountId) {
      const { data: lg } = await supabase
        .from('stater_ledger')
        .select('id, amount, entry_type, reason, from_account, to_account, created_at')
        .or(`from_account.eq.${accountId},to_account.eq.${accountId}`)
        .order('created_at', { ascending: false })
        .limit(6);
      ledger = (lg as LedgerRow[]) ?? [];
    }
    skillsLoading = false;
  }

  onMount(() => {
    if (!supabaseConfigured) { loading = false; skillsLoading = false; return; }
    const unsub = member.subscribe((m) => {
      if (m) { loadPortfolio(m.id); loadStanding(m.id); }
      else { loading = false; skillsLoading = false; }
    });
    return unsub;
  });

  function skillName(skillId: string) { return skills.find((s) => s.id === skillId)?.name ?? skillId; }
  function statusKindOf(name: string | null | undefined): 'pos' | 'warn' | 'dim' {
    if (name === 'Finished') return 'pos';
    if (name === 'Hold' || name === 'Under review') return 'warn';
    return 'dim';
  }
  function appKind(status: string): 'pos' | 'warn' | 'down' | 'dim' {
    if (status === 'joined') return 'pos';
    if (status === 'accepted') return 'warn';
    if (status === 'declined') return 'down';
    return 'dim';
  }
  function initials(name: string | undefined) {
    const p = (name ?? '').trim().split(/\s+/).filter(Boolean);
    return ((p[0]?.[0] ?? '') + (p.length > 1 ? p[p.length - 1][0] : '')).toUpperCase() || '·';
  }

  // the officer's home unit — prefer a chapter (where cards are forged)
  const myUnit = $derived($officerUnits.find((u) => u.kind === 'chapter') ?? $officerUnits[0] ?? null);
  const canAdmin = $derived(
    $capabilities.has('manage_taxonomy') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('edit_any_project')
  );
  const canApprove = $derived(
    $capabilities.has('manage_resources') ||
      $capabilities.has('manage_stater') ||
      $capabilities.has('manage_members') ||
      $capabilities.has('review_skillcard')
  );
  const isSteward = $derived(canAdmin || canApprove);

  const certifiedCount = $derived(mySkills.filter((s) => s.certified_level).length);
  const myCards = $derived(mySkills.filter((s) => s.certified_level));
  const pendingSkills = $derived(mySkills.filter((s) => !s.certified_level));
  // mySkills is sorted rank-desc, so the first certified card carries the top tier.
  const topTierLabel = $derived(
    myCards[0]?.certified_level ? (LEVEL_LABEL[myCards[0].certified_level] ?? '') : ''
  );
  // the single most actionable thing: applications the team accepted, awaiting
  // your confirmation to actually join.
  const acceptedApps = $derived(myApps.filter((a) => a.status === 'accepted'));
  // "My projects" = in-play only; status.is_active is the real field (false for
  // Finished & Hold). Delivered/parked ones drop off the active list.
  const myActiveProjects = $derived(myProjects.filter((p) => p.project?.project_status?.is_active !== false));
  const myShipped = $derived(myProjects.length - myActiveProjects.length);
</script>

<div class="stack">
  <!-- self card: you, as a card — identity + role, two aspects (Craft /
       Standing), the liquid STR resource, and the verbs you act with. -->
  <section class="selfcard">
    <div class="sc-head">
      <span class="sc-ava">{initials($member?.full_name)}</span>
      <div class="sc-id">
        <h1 class="sc-name">{$member ? $member.full_name.split(' ')[0] : $t('Overview')}</h1>
        <span class="sc-sub muted">{$member?.affiliation || $member?.email || ''}</span>
      </div>
      {#if myUnit || isSteward}
        <div class="sc-roles">
          {#if myUnit}<span class="rolepill">{$t('Officer')} · {myUnit.name}</span>{/if}
          {#if isSteward}<span class="rolepill warn">{$t('Community steward')}</span>{/if}
        </div>
      {/if}
    </div>

    <div class="sc-aspects">
      <div class="aspect">
        <span class="asp-k">{$t('Craft')}</span>
        <span class="asp-v">{certifiedCount}</span>
        <span class="asp-sub">{topTierLabel ? $t(topTierLabel) : $t(certifiedCount === 1 ? 'badge earned' : 'badges earned')}</span>
      </div>
      <div class="aspect">
        <span class="asp-k">{$t('Standing')}</span>
        <span class="asp-v"><CountUp value={totalNominal} /></span>
        <span class="asp-sub">{$t('nominal STR minted through work')}</span>
      </div>
      <div class="aspect liquid">
        <span class="asp-k">{$t('Liquid STR')}</span>
        <span class="asp-v accent"><CountUp value={balance} /></span>
        <span class="asp-sub"><a href="/wallet">{$t('open wallet →')}</a></span>
      </div>
    </div>

    <div class="sc-verbs">
      <a class="verb" href="/projects">
        <span class="vb-ic">◷</span>
        <span class="vb-tx"><strong>{$t('Browse projects')}</strong><span class="muted">{$t('{n} open needs across {m} projects', { n: openCount, m: projectCount })}</span></span>
      </a>
      {#if myUnit && myUnit.kind === 'chapter'}
        <a class="verb" href={`/units/${myUnit.unit_id}#forge`}>
          <span class="vb-ic">✦</span>
          <span class="vb-tx"><strong>{$t('Forge a member card')}</strong><span class="muted">{myUnit.name}</span></span>
        </a>
      {:else if $member}
        <a class="verb" href={`/members/${$member.id}`}>
          <span class="vb-ic">◇</span>
          <span class="vb-tx"><strong>{$t('Your public page')}</strong><span class="muted">{$t('how others see your card')}</span></span>
        </a>
      {/if}
      {#if canApprove}
        <a class="verb" href="/admin/forge-queue">
          <span class="vb-ic">⊞</span>
          <span class="vb-tx"><strong>{$t('Review forge queue')}</strong><span class="muted">{$t('clear pending approvals')}</span></span>
        </a>
      {:else}
        <a class="verb" href="/guide">
          <span class="vb-ic">❖</span>
          <span class="vb-tx"><strong>{$t('Read the guide')}</strong><span class="muted">{$t('how the community works')}</span></span>
        </a>
      {/if}
    </div>
  </section>

  {#if PHASE2 && $member}<GettingStarted memberId={$member.id} />{/if}

  <!-- needs you now: the one digest of things waiting on your action -->
  {#if acceptedApps.length > 0}
    <div class="needs">
      <span class="nx-ic">!</span>
      <span class="nx-tx">{$t('{n} application accepted — confirm to join', { n: acceptedApps.length })}</span>
      <div class="nx-acts">
        {#each acceptedApps.slice(0, 3) as a}
          {#if a.open_need?.project}
            <a class="chip toggle" href={`/projects/${a.open_need.project.id}`}>{a.open_need.project.name} →</a>
          {/if}
        {/each}
      </div>
    </div>
  {/if}

  <!-- my projects: each seat I hold, as a project card -->
  <section class="block">
    <div class="block-head">
      <h2>{$t('My projects')}</h2>
      {#if myActiveProjects.length > 0}<span class="block-meta">{$t('{n} active', { n: myActiveProjects.length })}{#if myShipped > 0} · {$t('{n} shipped', { n: myShipped })}{/if}{#if staked > 0} · {$t('{s} STR bonded', { s: staked })}{/if}</span>{/if}
    </div>
    {#if loading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if myActiveProjects.length === 0}
      <p class="muted">{$t('No positions yet.')} <a href="/projects">{$t('Browse projects')}</a> {$t('to stake into one.')}</p>
    {:else}
      <div class="card-grid">
        {#each myActiveProjects as p}
          <EntityCard
            type="Project"
            title={p.project?.name ?? '—'}
            status={p.project?.project_status?.name ?? ''}
            statusKind={statusKindOf(p.project?.project_status?.name)}
            stats={[{ label: 'Role', value: p.project_role?.name ?? '—' }]}
            onclick={() => p.project && goto(`/projects/${p.project.id}`)}
          />
        {/each}
      </div>
    {/if}

    {#if myApps.length > 0}
      <div class="block-sub">
        <span class="block-sublabel">{$t('Applications')}</span>
        <div class="card-grid">
          {#each myApps as a}
            <EntityCard
              type="Application"
              title={a.open_need?.project?.name ?? '—'}
              status={a.status === 'accepted' ? $t('accepted · confirm to join →') : a.status}
              statusKind={appKind(a.status)}
              onclick={() => a.open_need?.project && goto(`/projects/${a.open_need.project.id}`)}
            />
          {/each}
        </div>
      </div>
    {/if}
  </section>

  <!-- my badges: read-only craft. A certified skill IS a badge. -->
  <section class="block">
    <div class="block-head">
      <h2>{$t('My badges')}</h2>
      <a class="block-link" href="/community?tab=badges">{$t('Badge catalog →')}</a>
    </div>
    {#if skillsLoading}
      <p class="muted">{$t('Loading…')}</p>
    {:else if mySkills.length === 0}
      <p class="muted">{$t('No badges yet — a reviewer certifies your skills as you demonstrate them.')}</p>
    {:else}
      {#if myCards.length > 0}
        <div class="row" style="gap:.5rem; flex-wrap:wrap;">
          {#each myCards as s}<Medal name={skillName(s.skill_id)} level={s.certified_level!} />{/each}
        </div>
      {/if}
      {#if pendingSkills.length > 0}
        <div class="stack" style="gap:.35rem; margin-top:.6rem;">
          <span class="muted" style="font-size:.78rem;">{$t('Skills awaiting a badge')}</span>
          <div class="row" style="gap:.35rem; flex-wrap:wrap;">
            {#each pendingSkills as s}<span class="badge dim">{skillName(s.skill_id)}</span>{/each}
          </div>
        </div>
      {/if}
    {/if}
  </section>

  <!-- recent activity: a short preview; the full ledger lives in the wallet -->
  {#if ledger.length > 0}
    <section class="block">
      <div class="block-head">
        <h2>{$t('Recent activity')}</h2>
        <a class="block-link" href="/wallet">{$t('Full ledger →')}</a>
      </div>
      <div class="acts">
        {#each ledger as l}
          {@const incoming = l.to_account === accountId}
          <div class="act">
            <span class="act-when muted">{new Date(l.created_at).toLocaleDateString()}</span>
            <span class="act-reason">{l.reason ?? l.entry_type}</span>
            <span class="act-amt mono {incoming ? 'up' : 'down'}">{incoming ? '+' : '−'}{l.amount.toLocaleString()}</span>
          </div>
        {/each}
      </div>
    </section>
  {/if}

  <!-- footer link to the manage surface (resources + identity) -->
  {#if $member}
    <a class="manage-link" href="/profile">{$t('Manage your resources & profile')} →</a>
  {/if}
</div>

<style>
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .8rem; }

  /* self card */
  .selfcard {
    border: 1px solid var(--border); border-radius: 16px; background: var(--card);
    padding: 1.4rem 1.5rem; display: flex; flex-direction: column; gap: 1.25rem;
    box-shadow: var(--shadow);
  }
  .sc-head { display: flex; align-items: center; gap: .9rem; }
  .sc-ava {
    width: 48px; height: 48px; border-radius: 14px; flex: none;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: 1.05rem; font-weight: 700; color: var(--accent-ink); background: var(--accent);
  }
  .sc-id { min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
  .sc-name { margin: 0; font-size: 1.5rem; line-height: 1.1; letter-spacing: -.01em; }
  .sc-sub { font-size: .85rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sc-roles { margin-left: auto; display: flex; gap: .4rem; flex-wrap: wrap; justify-content: flex-end; }
  .rolepill {
    font-size: .72rem; font-weight: 600; padding: .25rem .6rem; border-radius: 999px;
    color: var(--accent); background: var(--accent-soft); white-space: nowrap;
  }
  .rolepill.warn { color: var(--warn); background: var(--warn-soft); }

  .sc-aspects {
    display: grid; grid-template-columns: repeat(3, 1fr); gap: 1px;
    background: var(--border); border: 1px solid var(--border);
    border-radius: 12px; overflow: hidden;
  }
  .aspect { background: var(--card-2); padding: .85rem 1rem; display: flex; flex-direction: column; gap: .25rem; }
  .aspect.liquid { background: var(--accent-soft); }
  .asp-k { font-size: .68rem; letter-spacing: .1em; text-transform: uppercase; color: var(--muted); font-weight: 600; }
  .asp-v { font-size: 1.7rem; font-weight: 700; line-height: 1; font-variant-numeric: tabular-nums; color: var(--text); }
  .asp-v.accent { color: var(--accent); }
  .asp-sub { font-size: .76rem; color: var(--muted); }
  .asp-sub a { color: var(--accent); }

  .sc-verbs { display: grid; grid-template-columns: repeat(3, 1fr); gap: .6rem; }
  .verb {
    display: flex; align-items: center; gap: .7rem; padding: .75rem .85rem;
    border: 1px solid var(--border); border-radius: 11px; background: var(--card-2);
    text-decoration: none; color: var(--text); transition: border-color .12s, background .12s, transform .12s;
  }
  .verb:hover { border-color: var(--accent); background: var(--card); transform: translateY(-1px); }
  .vb-ic {
    width: 32px; height: 32px; border-radius: 9px; flex: none;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: 1rem; color: var(--accent); background: var(--accent-soft);
  }
  .vb-tx { display: flex; flex-direction: column; gap: .05rem; min-width: 0; }
  .vb-tx strong { font-size: .9rem; font-weight: 600; }
  .vb-tx .muted { font-size: .74rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  /* needs-you digest */
  .needs {
    display: flex; align-items: center; gap: .7rem; flex-wrap: wrap;
    border: 1px solid color-mix(in srgb, var(--warn) 35%, transparent);
    background: var(--warn-soft); border-radius: 12px; padding: .7rem .9rem;
  }
  .nx-ic {
    width: 22px; height: 22px; border-radius: 50%; flex: none;
    display: inline-flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: .8rem; color: var(--accent-ink); background: var(--warn);
  }
  .nx-tx { font-size: .88rem; font-weight: 600; }
  .nx-acts { display: flex; gap: .4rem; flex-wrap: wrap; margin-left: auto; }

  /* generic content block */
  .block { display: flex; flex-direction: column; gap: .7rem; }
  .block-head { display: flex; align-items: baseline; justify-content: space-between; gap: .6rem; }
  .block-head h2 { margin: 0; }
  .block-meta { font-size: .8rem; color: var(--muted); }
  .block-link { font-size: .82rem; }
  .block-sub { display: flex; flex-direction: column; gap: .45rem; margin-top: .5rem; }
  .block-sublabel { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }

  /* activity list */
  .acts { display: flex; flex-direction: column; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
  .act {
    display: grid; grid-template-columns: auto 1fr auto; gap: .8rem; align-items: center;
    padding: .55rem .9rem; border-bottom: 1px solid var(--border); background: var(--card);
  }
  .act:last-child { border-bottom: 0; }
  .act-when { font-size: .76rem; white-space: nowrap; }
  .act-reason { font-size: .85rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .act-amt { font-size: .85rem; font-weight: 600; white-space: nowrap; }

  .manage-link { font-size: .85rem; color: var(--muted); padding: .2rem 0; }
  .manage-link:hover { color: var(--accent); }

  @media (max-width: 720px) {
    .sc-aspects, .sc-verbs { grid-template-columns: 1fr; }
    .sc-head { flex-wrap: wrap; }
    .sc-roles { margin-left: 0; width: 100%; justify-content: flex-start; }
  }
</style>
