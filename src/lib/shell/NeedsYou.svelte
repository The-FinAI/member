<script lang="ts">
  // "What needs you" — the role-aware triage strip. Ported out of the old Home
  // page so it can ride atop the Project Ledger (the single landing surface).
  // Compact by default; deep-links into the exact surface for each item.
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { member, capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';

  type Item = { icon: string; title: string; sub: string; href: string; tone: 'go' | 'info' | 'warn' };
  let items = $state<Item[]>([]);
  let loading = $state(true);

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

    if (ledFinished.size) {
      const { data: st } = await supabase.from('stater_settlement')
        .select('project_id, status').in('project_id', [...ledFinished]);
      const inFlight = new Set(((st as any[]) ?? [])
        .filter((s) => ['submitted', 'under_review', 'approved'].includes(s.status)).map((s) => s.project_id));
      for (const pid of ledFinished) if (!inFlight.has(pid))
        out.push({ icon: 'str', title: $t('Settle {name}', { name: ledName[pid] }), sub: $t('Finished — split the credit'), href: `/projects/${pid}`, tone: 'go' });
    }

    const { data: mt } = await supabase.from('task')
      .select('id, state').eq('owner_member_id', me).in('state', ['open', 'doing', 'checking']);
    const nOpen = ((mt as any[]) ?? []).length;
    if (nOpen) out.push({ icon: 'check', title: $t('{n} tasks on your plate', { n: nOpen }), sub: $t('Your worklist across all projects'), href: '/my', tone: 'info' });

    if (ledIds.size) {
      const { data: tbd } = await supabase.from('task')
        .select('id, project_id').in('project_id', [...ledIds]).is('owner_member_id', null).in('state', ['open', 'doing']);
      const n = ((tbd as any[]) ?? []).length;
      if (n) out.push({ icon: 'tasks', title: $t('{n} tasks need an owner', { n }), sub: $t('In projects you lead'), href: ledIds.size === 1 ? `/projects/${[...ledIds][0]}` : '/projects', tone: 'warn' });
    }

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
      // a chapter officer's core job is PEOPLE, but the landing is the project
      // ledger — so always surface a path to their roster. Critical on first
      // login when the chapter is empty and nothing else points them anywhere.
      const rosterN = ((roster as any[]) ?? []).length;
      if (rosterN === 0)
        out.push({ icon: 'user', title: $t('Your chapter has no people yet'), sub: $t('Add your researchers — that’s a chapter officer’s first job'), href: '/people', tone: 'warn' });
      else
        out.push({ icon: 'user', title: $t('Your chapter · {n} people', { n: rosterN }), sub: $t('Add or update people — their skills & available time'), href: '/people', tone: 'info' });

      const free = ((roster as any[]) ?? []).filter((r) => r.monthly_hours && (used[r.id] ?? 0) < r.monthly_hours).length;
      if (free) out.push({ icon: 'swap', title: $t('{n} people have free time', { n: free }), sub: $t('Open a project and assign them to a need'), href: '/projects', tone: 'go' });
    }

    if (myWGs.length) {
      const unitIds = myWGs.map((u: any) => u.unit_id ?? u.id);
      const { data: prj } = await supabase.from('project').select('id').in('org_unit_id', unitIds);
      const pids = ((prj as any[]) ?? []).map((p) => p.id);
      if (pids.length) {
        const { data: needs } = await supabase.from('project_slot').select('id').in('project_id', pids).eq('status', 'open');
        const n = ((needs as any[]) ?? []).length;
        if (n) out.push({ icon: 'clock', title: $t('{n} open needs on your projects', { n }), sub: $t('Post details or wait for a match'), href: '/projects?tab=needs', tone: 'info' });
      }
    }

    if (canReview) {
      const { count } = await supabase.from('forge_request').select('id', { count: 'exact', head: true }).eq('status', 'submitted');
      if (count) out.push({ icon: 'scale', title: $t('{n} waiting for review', { n: count }), sub: $t('Badges, resources, needs & settlements'), href: '/admin/forge-queue', tone: 'warn' });
    }

    const { count: nUnread } = await supabase.from('notification')
      .select('id', { count: 'exact', head: true }).is('read_at', null);
    if (nUnread) out.push({ icon: 'bell', title: $t('{n} new notifications', { n: nUnread }), sub: $t('Someone updated work that touches you'), href: '/my', tone: 'info' });

    items = out;
    loading = false;
  }
  $effect(() => { if ($member) load(); else loading = false; });
</script>

{#if loading}
  <div class="ny"><div class="sk sk-line" style="width:50%;"></div></div>
{:else if items.length}
  <div class="ny">
    <span class="ny-label">{$t('What needs you')}</span>
    <div class="ny-list">
      {#each items as it}
        <a class="ny-item tone-{it.tone}" href={it.href}>
          <span class="ny-ic"><Icon name={it.icon} size={17} /></span>
          <span class="ny-txt"><b>{it.title}</b><span class="ny-s">{it.sub}</span></span>
          <span class="ny-arr">→</span>
        </a>
      {/each}
    </div>
  </div>
{/if}

<style>
  .ny { border-top: 2px solid var(--rule-ink); padding: .55rem 0 .9rem; margin-bottom: 1rem; }
  .ny-label { font-size: .68rem; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; color: var(--text-dim); }
  .ny-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: .5rem; margin-top: .5rem; }
  .ny-item { display: flex; align-items: center; gap: .7rem; text-decoration: none; color: inherit;
    background: var(--card); border: 1px solid var(--border); border-left: 3px solid var(--border-2);
    border-radius: var(--r-md); padding: .55rem .75rem; }
  .ny-item:hover { border-color: var(--border-2); background: var(--card-2); }
  .ny-item.tone-go { border-left-color: var(--accent); }
  .ny-item.tone-warn { border-left-color: var(--warn); }
  .ny-item.tone-info { border-left-color: var(--info); }
  .ny-ic { font-size: 1.05rem; }
  .ny-txt { display: flex; flex-direction: column; flex: 1; min-width: 0; }
  .ny-txt b { font-weight: 600; font-size: .9rem; }
  .ny-s { font-size: .76rem; color: var(--muted); }
  .ny-arr { color: var(--muted); }
</style>
