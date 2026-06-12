<script lang="ts">
  // BUILD PLAN P7A — Home rebuilt as the role-aware "what needs me" router
  // (PRD §4). Not a dashboard: a short, ranked triage list that drops the user
  // into the right surface. STR stays off the home (it lives on My / Settle).
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';

  type Item = { icon: string; title: string; sub: string; href: string; tone: 'go' | 'info' | 'warn' };

  let items = $state<Item[]>([]);
  let loading = $state(true);

  const initials = (n?: string) =>
    (n ?? '').split(/\s+/).filter(Boolean).slice(0, 2).map((s) => s[0]?.toUpperCase()).join('') || '·';
  const myChapters = $derived($officerUnits.filter((u: any) => u.kind === 'chapter'));
  const myWGs = $derived($officerUnits.filter((u: any) => u.kind === 'working_group'));
  const canReview = $derived(
    $capabilities.has('manage_stater') || $capabilities.has('edit_any_project') ||
    $capabilities.has('manage_resources') || $capabilities.has('review_skillcard') || $capabilities.has('manage_members')
  );

  async function load() {
    const me = $member?.id;
    if (!supabaseConfigured || !me) { loading = false; return; }
    loading = true;
    const out: Item[] = [];
    const ym = new Date().toISOString().slice(0, 7);

    // projects I lead (leader commitments) + their status
    const { data: led } = await supabase.from('work_commitment')
      .select('project_id, slot:slot_id(slot_kind), project:project_id(name, project_status:project_status_id(name))')
      .eq('member_id', me);
    const ledIds = new Set<string>();
    const ledName: Record<string, string> = {};
    const ledFinished = new Set<string>();
    for (const w of (led as any[]) ?? []) {
      if (w.slot?.slot_kind !== 'leader') continue;
      ledIds.add(w.project_id); ledName[w.project_id] = w.project?.name ?? '';
      if ((w.project?.project_status?.name ?? '').toLowerCase() === 'finished') ledFinished.add(w.project_id);
    }

    // 1) finished projects I lead, not yet settled → Settle (highest priority)
    if (ledFinished.size) {
      const { data: st } = await supabase.from('stater_settlement')
        .select('project_id, status').in('project_id', [...ledFinished]);
      const inFlight = new Set(((st as any[]) ?? [])
        .filter((s) => ['submitted', 'under_review', 'approved'].includes(s.status)).map((s) => s.project_id));
      for (const pid of ledFinished) if (!inFlight.has(pid))
        out.push({ icon: '💰', title: $t('Settle {name}', { name: ledName[pid] }), sub: $t('Finished — split the credit'), href: `/projects/${pid}`, tone: 'go' });
    }

    // 2) my open tasks
    const { data: mt } = await supabase.from('task')
      .select('id, state').eq('owner_member_id', me).in('state', ['open', 'doing', 'checking']);
    const nOpen = ((mt as any[]) ?? []).length;
    if (nOpen) out.push({ icon: '✓', title: $t('{n} tasks on your plate', { n: nOpen }), sub: $t('Your worklist across all projects'), href: '/my', tone: 'info' });

    // 3) unowned (TBD) tasks in projects I lead → assign owners
    if (ledIds.size) {
      const { data: tbd } = await supabase.from('task')
        .select('id, project_id').in('project_id', [...ledIds]).is('owner_member_id', null).in('state', ['open', 'doing']);
      const n = ((tbd as any[]) ?? []).length;
      if (n) out.push({ icon: '◫', title: $t('{n} tasks need an owner', { n }), sub: $t('In projects you lead'), href: ledIds.size === 1 ? `/projects/${[...ledIds][0]}` : '/projects', tone: 'warn' });
    }

    // 4) chapter officer: people with free time to place
    if (myChapters.length) {
      const unitIds = myChapters.map((u: any) => u.unit_id ?? u.id);
      const { data: roster } = await supabase.from('member').select('id, monthly_hours').in('home_unit_id', unitIds);
      const ids = ((roster as any[]) ?? []).map((r) => r.id);
      let used: Record<string, number> = {};
      if (ids.length) {
        const { data: wc } = await supabase.from('work_commitment')
          .select('member_id, monthly_amount, slot:slot_id(slot_kind)').in('member_id', ids).eq('year_month', ym);
        for (const w of (wc as any[]) ?? []) if (['work_labor', 'leader'].includes(w.slot?.slot_kind))
          used[w.member_id] = (used[w.member_id] ?? 0) + (Number(w.monthly_amount) || 0);
      }
      const free = ((roster as any[]) ?? []).filter((r) => r.monthly_hours && (used[r.id] ?? 0) < r.monthly_hours).length;
      if (free) out.push({ icon: '⇄', title: $t('{n} people have free time', { n: free }), sub: $t('Match them to open needs'), href: '/people', tone: 'go' });
    }

    // 5) WG officer: open needs on my projects
    if (myWGs.length) {
      const unitIds = myWGs.map((u: any) => u.unit_id ?? u.id);
      const { data: prj } = await supabase.from('project').select('id').in('org_unit_id', unitIds);
      const pids = ((prj as any[]) ?? []).map((p) => p.id);
      if (pids.length) {
        const { data: needs } = await supabase.from('project_slot').select('id').in('project_id', pids).eq('status', 'open');
        const n = ((needs as any[]) ?? []).length;
        if (n) out.push({ icon: '◷', title: $t('{n} open needs on your projects', { n }), sub: $t('Post details or wait for a match'), href: '/projects', tone: 'info' });
      }
    }

    // 6) reviewer: pending review inbox
    if (canReview) {
      const { count } = await supabase.from('forge_request').select('id', { count: 'exact', head: true }).eq('status', 'submitted');
      if (count) out.push({ icon: '⚖', title: $t('{n} waiting for review', { n: count }), sub: $t('Badges, resources, needs & settlements'), href: '/admin/forge-queue', tone: 'warn' });
    }

    // 7) unread notifications — so "all clear" never contradicts the bell
    const { count: nUnread } = await supabase.from('notification')
      .select('id', { count: 'exact', head: true }).is('read_at', null);
    if (nUnread) out.push({ icon: '🔔', title: $t('{n} new notifications', { n: nUnread }), sub: $t('Someone updated work that touches you'), href: '/my', tone: 'info' });

    items = out;
    loading = false;
  }
  // reactive: re-run when the member store resolves (avoids a one-shot onMount
  // race that would leave Home stuck on "all clear" if member wasn't ready yet)
  $effect(() => { if ($member) load(); else loading = false; });
</script>

<svelte:head><title>{$t('Home')} · The Fin AI</title></svelte:head>

<section class="home">
  <header class="hh">
    <div class="hh-av">{initials($member?.full_name)}</div>
    <div>
      <h1>{$member ? ($member.full_name?.split(' ')[0] ?? $t('Welcome')) : $t('Welcome')}</h1>
      <div class="hh-roles">
        {#each myChapters as c}<span class="pill warn">{$t('Chapter officer')} · {(c as any).name}</span>{/each}
        {#each myWGs as w}<span class="pill info">{$t('WG officer')} · {(w as any).name}</span>{/each}
        <a class="hh-guide" href="/guide">{$t('Guide')} ↗</a>
      </div>
    </div>
  </header>

  <h2 class="hs">{$t('What needs you')}</h2>
  {#if loading}
    <p class="h-dim">{$t('Loading…')}</p>
  {:else if !items.length}
    <p class="h-clear">✓ {$t('All clear — nothing needs you right now.')}</p>
  {:else}
    <div class="h-list">
      {#each items as it}
        <a class="h-item tone-{it.tone}" href={it.href}>
          <span class="h-ic">{it.icon}</span>
          <span class="h-txt"><span class="h-t">{it.title}</span><span class="h-s">{it.sub}</span></span>
          <span class="h-arrow">→</span>
        </a>
      {/each}
    </div>
  {/if}

  <div class="h-jump">
    <a href="/my">{$t('My tasks')}</a>
    <a href="/projects">{$t('Projects')}</a>
    <a href="/people">{$t('People')}</a>
  </div>
</section>

<style>
  .home { max-width: 760px; padding: 1rem 0 3rem; }
  .hh { display: flex; gap: .9rem; align-items: center; margin-bottom: 1.6rem; }
  .hh-av { width: 3rem; height: 3rem; border-radius: 50%; background: var(--accent, #6a7cff); color: #fff; display: grid; place-items: center; font-weight: 700; }
  .hh h1 { margin: 0; font-size: 1.5rem; }
  .hh-roles { display: flex; gap: .4rem; flex-wrap: wrap; align-items: center; margin-top: .25rem; }
  .pill { font-size: .72rem; padding: .1rem .5rem; border-radius: var(--r-full); border: 1px solid var(--line, #ddd); color: var(--muted, #777); }
  .pill.warn { border-color: #f0c674; color: #9a7b12; }
  .pill.info { border-color: #8aa0ff; color: #5566cc; }
  .hh-guide { font-size: .78rem; color: var(--accent, #6a7cff); text-decoration: none; }
  .hs { font-size: 1rem; margin: 0 0 .6rem; }
  .h-dim { color: var(--muted, #999); }
  .h-clear { color: #2e7d4f; font-size: .95rem; }
  .h-list { display: flex; flex-direction: column; gap: .5rem; }
  .h-item { display: flex; align-items: center; gap: .8rem; text-decoration: none; color: inherit; background: var(--card, #fff); border: 1px solid var(--line, #eee); border-left-width: 3px; border-radius: var(--r-md); padding: .7rem .85rem; }
  .h-item:hover { border-color: var(--accent, #6a7cff); }
  .tone-go { border-left-color: #4caf72; }
  .tone-warn { border-left-color: #e0a64a; }
  .tone-info { border-left-color: #8aa0ff; }
  .h-ic { font-size: 1.15rem; }
  .h-txt { display: flex; flex-direction: column; flex: 1; }
  .h-t { font-weight: 600; }
  .h-s { font-size: .8rem; color: var(--muted, #888); }
  .h-arrow { color: var(--muted, #bbb); }
  .h-jump { display: flex; gap: 1rem; margin-top: 1.6rem; padding-top: 1rem; border-top: 1px solid var(--line, #f0f0f0); }
  .h-jump a { color: var(--accent, #6a7cff); text-decoration: none; font-size: .88rem; }
</style>
