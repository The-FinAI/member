<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { PHASE2 } from '$lib/phase';

  const allSections = [
    { group: 'Operations', href: '/admin/forge-queue', title: 'Forge queue', desc: 'Approve badges, member cards, needs, resources, over-capacity commitments & settlements' },
    { group: 'Operations', href: '/admin/approvals', title: 'Unit applications', desc: 'Approve members applying to join a chapter or working group' },
    { group: 'Operations', href: '/admin/announcements', title: 'Announcements', desc: 'Post, pin & retire the site-wide notice board' },
    { group: 'Operations', href: '/admin/invites', title: PHASE2 ? 'Invite Members' : 'Invite Officers', desc: PHASE2 ? 'Pre-create members by email (invite-only)' : 'Phase 1: invite chapter chairs, secretaries & working-group leaders by email' },
    { group: 'Operations', href: '/admin/writing', title: 'First-author Writing', desc: "Leaders short on this month's writing hours — remind them by email" },
    { group: 'Community', href: '/admin/org-units', title: 'Chapters & Working Groups', desc: 'Assign chairs, secretaries & leaders to the 3 chapters + 3 working groups' },
    { group: 'Community', href: '/admin/positions', title: 'Positions', desc: 'Community-level titles + ordering' },
    { group: 'Community', href: '/admin/capabilities', title: 'Capabilities', desc: 'Grant capabilities to positions (permission matrix)' },
    { group: 'Projects', href: '/admin/roles', title: 'Project Roles', desc: 'Roles members hold within a project' },
    { group: 'Projects', href: '/admin/types', title: 'Project Types', desc: 'Dataset & Benchmark, Model, Agent…' },
    { group: 'Projects', href: '/admin/statuses', title: 'Project Statuses', desc: 'Proposal → Finished workflow states' },
    { group: 'Projects', href: '/admin/venues', title: 'Venues', desc: 'Conferences & journals + submission deadlines' },
    { group: 'Skills & resources', href: '/admin/skills', title: 'Skill Tree', desc: 'Hierarchical skills used for matching' },
    { group: 'Skills & resources', href: '/admin/resource-types', title: 'Resource Types', desc: 'Categories of resources (compute, funding, data…)' },
    { group: 'Skills & resources', href: '/admin/resources', title: 'Community Resources', desc: 'Community-owned resources + their stewards' },
    { group: 'Economy', href: '/admin/stater', title: 'STR Economy', desc: 'Supply at a glance, mint/sink flow, treasury ledger, health flags — plus mint, grant, allowance & policy knobs' },
    { group: 'Economy', href: '/admin/milestone-catalog', title: 'Milestone Catalog', desc: 'Achievement catalog — nominal STR + multiplier bonus per milestone' }
  ];
  const GROUPS = ['Operations', 'Community', 'Projects', 'Skills & resources', 'Economy'];
  const sections = allSections.filter((s) => PHASE2 || !s.phase2);
  const grouped = $derived(GROUPS.map((g) => ({ group: g, items: sections.filter((s) => s.group === g) })).filter((g) => g.items.length));

  let loading = $state(true);
  let members = $state(0);
  let activeMembers = $state(0);
  let projects = $state(0);
  let openNeeds = $state(0);
  let pendingForge = $state(0);
  let pendingCommits = $state(0);
  let pendingSettlements = $state(0);
  let pendingUnitApps = $state(0);
  let skillLeaves = $state(0);
  let circulating = $state(0);

  // things that want an admin's attention (Phase-1 model: forge queue +
  // over-capacity commitments + settlements live on the forge queue; unit
  // applications on approvals)
  const attention = $derived([
    { n: pendingForge, label: 'items awaiting review', href: '/admin/forge-queue' },
    { n: pendingCommits, label: 'over-capacity commitments to review', href: '/admin/forge-queue' },
    { n: pendingSettlements, label: 'settlements awaiting payout', href: '/admin/forge-queue' },
    { n: pendingUnitApps, label: 'unit applications to review', href: '/admin/approvals' },
    { n: openNeeds, label: 'open needs on the market', href: '/projects?tab=needs' }
  ].filter((a) => a.n > 0));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const c = (q: any) => q.select('id', { count: 'exact', head: true });
    const [m, am, p, on, fr, cm, st, ua, sk, bal] = await Promise.all([
      c(supabase.from('member')),
      c(supabase.from('member')).eq('status', 'active'),
      c(supabase.from('project')),
      c(supabase.from('project_slot')).eq('status', 'open').in('slot_kind', ['work_labor', 'work_resource']),
      c(supabase.from('forge_request')).eq('status', 'submitted'),
      c(supabase.from('work_commitment')).eq('approval', 'needs_review'),
      c(supabase.from('stater_settlement')).in('status', ['submitted', 'under_review']),
      c(supabase.from('org_unit_member')).eq('status', 'pending'),
      supabase.from('skill').select('id', { count: 'exact', head: true }).not('parent_id', 'is', null),
      supabase.from('stater_balance').select('balance')
    ]);
    members = m.count ?? 0;
    activeMembers = am.count ?? 0;
    projects = p.count ?? 0;
    openNeeds = on.count ?? 0;
    pendingForge = fr.count ?? 0;
    pendingCommits = cm.count ?? 0;
    pendingSettlements = st.count ?? 0;
    pendingUnitApps = ua.count ?? 0;
    skillLeaves = sk.count ?? 0;
    circulating = ((bal.data as { balance: number }[]) ?? []).reduce((a, b) => a + (Number(b.balance) || 0), 0);
    loading = false;
  }

  onMount(load);
</script>

<div class="stack">
  <h1>{$t('Admin dashboard')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('The community at a glance, and every configurable knob. Nothing here is hard-coded.')}</p>

  <!-- headline metrics -->
  <div class="kpis">
    <div class="kpi">
      <span class="k-label">{$t('Members')}</span>
      <span class="k-value accent">{loading ? '–' : members.toLocaleString()}</span>
      <span class="k-sub">{loading ? '' : $t('{n} active', { n: activeMembers })}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Projects')}</span>
      <span class="k-value">{loading ? '–' : projects.toLocaleString()}</span>
      <span class="k-sub">{$t('across all statuses')}</span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('STR circulating')}</span>
      <span class="k-value">{loading ? '–' : circulating.toLocaleString()}</span>
      <span class="k-sub"><a href="/admin/stater">{$t('economy →')}</a></span>
    </div>
    <div class="kpi">
      <span class="k-label">{$t('Skills')}</span>
      <span class="k-value">{loading ? '–' : skillLeaves.toLocaleString()}</span>
      <span class="k-sub">{$t('certifiable crafts')}</span>
    </div>
  </div>

  <!-- needs attention -->
  {#if !loading && attention.length > 0}
    <div class="attention">
      <span class="sec">{$t('Needs attention')}</span>
      <div class="att-row">
        {#each attention as a}
          <a class="att-chip" href={a.href}>
            <strong>{a.n}</strong> {$t(a.label)} →
          </a>
        {/each}
      </div>
    </div>
  {/if}

  <!-- configuration, grouped -->
  {#each grouped as g (g.group)}
    <section class="grp">
      <span class="sec">{$t(g.group)}</span>
      <div class="admin-grid">
        {#each g.items as s (s.href)}
          <a class="admin-card" href={s.href}>
            <span class="ac-title">{$t(s.title)}</span>
            <span class="ac-desc">{$t(s.desc)}</span>
          </a>
        {/each}
      </div>
    </section>
  {/each}
</div>

<style>
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .attention { display: flex; flex-direction: column; gap: .5rem; }
  .att-row { display: flex; flex-wrap: wrap; gap: .45rem; }
  .att-chip {
    display: inline-flex; align-items: center; gap: .35rem; font-size: .82rem;
    padding: .35rem .7rem; border-radius: 999px; text-decoration: none;
    color: var(--accent); background: var(--accent-soft);
    border: 1px solid color-mix(in srgb, var(--accent) 22%, transparent);
  }
  .att-chip:hover { border-color: var(--accent); }
  .grp { display: flex; flex-direction: column; gap: .5rem; }
  .admin-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(248px, 1fr)); gap: .7rem; }
  .admin-card {
    display: flex; flex-direction: column; gap: .25rem; padding: .85rem .95rem;
    background: var(--card); border: 1px solid var(--border); border-radius: 12px;
    text-decoration: none; color: var(--text); transition: border-color .12s ease, transform .12s ease;
  }
  .admin-card:hover { border-color: var(--accent); transform: translateY(-2px); }
  .ac-title { font-weight: 600; font-size: .95rem; color: var(--text); }
  .ac-desc { font-size: .8rem; line-height: 1.45; color: var(--muted); }
</style>
