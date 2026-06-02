<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';
  import { PHASE2 } from '$lib/phase';

  const allSections = [
    { href: '/admin/approvals', title: 'Approvals', desc: 'One queue for everything awaiting a decision — resources, role cards, unit applications & over-capacity commitments' },
    { href: '/admin/announcements', title: 'Announcements', desc: 'Post, pin & retire the site-wide notice board' },
    { href: '/admin/invites', title: PHASE2 ? 'Invite Members' : 'Invite Officers', desc: PHASE2 ? 'Pre-create members by email (invite-only)' : 'Phase 1: invite chapter chairs, secretaries & working-group leaders by email' },
    { href: '/admin/org-units', title: 'Chapters & Working Groups', desc: 'Assign chairs, secretaries & leaders to the 3 chapters + 3 working groups' },
    { href: '/admin/positions', title: 'Positions', desc: 'Community-level titles + ordering' },
    { href: '/admin/capabilities', title: 'Capabilities', desc: 'Grant capabilities to positions (permission matrix)' },
    { href: '/admin/roles', title: 'Project Roles', desc: 'Roles members hold within a project' },
    { href: '/admin/types', title: 'Project Types', desc: 'Dataset & Benchmark, Model, Agent…' },
    { href: '/admin/statuses', title: 'Project Statuses', desc: 'Proposal → Finished workflow states' },
    { href: '/admin/venues', title: 'Venues', desc: 'Conferences & journals + submission deadlines' },
    { href: '/admin/skills', title: 'Skill Tree', desc: 'Hierarchical skills used for matching' },
    { href: '/admin/resource-types', title: 'Resource Types', desc: 'Categories of resources (compute, funding, data…)' },
    { href: '/admin/resources', title: 'Community Resources', desc: 'Community-owned resources + their stewards' },
    { href: '/admin/stater', title: 'STR Economy', desc: 'Supply at a glance, mint/sink flow, treasury ledger, health flags — plus mint, grant, allowance & policy knobs' },
    { href: '/admin/writing', title: 'First-author Writing', desc: "Leaders short on this month's writing hours — remind them by email" }
  ];
  const sections = allSections.filter((s) => PHASE2 || !s.phase2);

  let loading = $state(true);
  let members = $state(0);
  let activeMembers = $state(0);
  let projects = $state(0);
  let openNeeds = $state(0);
  let pendingResources = $state(0);
  let examsInReview = $state(0);
  let pendingCommits = $state(0);
  let pendingMilestones = $state(0);
  let skillLeaves = $state(0);
  let circulating = $state(0);

  // things that want an admin's attention
  const attention = $derived([
    { n: pendingResources, label: 'resources awaiting review', href: '/admin/approvals' },
    { n: examsInReview, label: 'role cards awaiting review', href: '/admin/approvals' },
    { n: pendingMilestones, label: 'milestones awaiting review', href: '/admin/approvals' },
    { n: pendingCommits, label: 'over-capacity commitments to review', href: '/admin/approvals' },
    { n: openNeeds, label: 'open needs on the market', href: '/opportunities' }
  ].filter((a) => a.n > 0));

  async function load() {
    if (!supabaseConfigured) { loading = false; return; }
    const c = (q: any) => q.select('id', { count: 'exact', head: true });
    const [m, am, p, on, pr, ex, cm, mi, sk, bal] = await Promise.all([
      c(supabase.from('member')),
      c(supabase.from('member')).eq('status', 'active'),
      c(supabase.from('project')),
      c(supabase.from('open_need')).eq('status', 'open'),
      c(supabase.from('resource')).eq('approval_status', 'pending'),
      c(supabase.from('skillcard_request')).eq('status', 'submitted'),
      c(supabase.from('commitment_review_queue')),
      c(supabase.from('project_milestone')).in('status', ['claimed', 'under_review']),
      supabase.from('skill').select('id', { count: 'exact', head: true }).not('parent_id', 'is', null),
      supabase.from('stater_balance').select('balance')
    ]);
    members = m.count ?? 0;
    activeMembers = am.count ?? 0;
    projects = p.count ?? 0;
    openNeeds = on.count ?? 0;
    pendingResources = pr.count ?? 0;
    examsInReview = ex.count ?? 0;
    pendingCommits = cm.count ?? 0;
    pendingMilestones = mi.count ?? 0;
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
    <div class="card stack" style="gap:.5rem;">
      <h2 style="margin:0; font-size:1rem;">{$t('Needs attention')}</h2>
      <div class="row" style="flex-wrap:wrap; gap:.5rem;">
        {#each attention as a}
          <a class="badge warn" href={a.href} style="text-decoration:none; font-size:.82rem; padding:.35rem .6rem;">
            <strong>{a.n}</strong> {$t(a.label)} →
          </a>
        {/each}
      </div>
    </div>
  {/if}

  <!-- configuration sections -->
  <h2 style="margin:.5rem 0 -.25rem; font-size:1rem;">{$t('Configuration')}</h2>
  <div class="row" style="align-items:stretch;">
    {#each sections as s}
      <a class="card" href={s.href} style="flex:1; min-width:220px;">
        <h2>{$t(s.title)}</h2>
        <p class="muted">{$t(s.desc)}</p>
      </a>
    {/each}
  </div>
</div>
