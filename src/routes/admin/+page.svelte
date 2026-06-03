<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { capabilities, officerUnits } from '$lib/session';
  import { t } from '$lib/i18n';
  import { PHASE2 } from '$lib/phase';

  // Admin center — organised by responsibility domain and permission-aware:
  // a top review band (what's waiting on a decision, with live counts) and
  // governance groups that only appear when you hold a capability in them. A
  // Steering member (invite_members only) sees just the invite tool; the
  // President sees everything.
  const can = (k: string) => $capabilities.has(k);
  const isOfficer = $derived($officerUnits.length > 0);

  // ---- review band (gated + counted) ----
  const canForge = $derived(
    can('manage_stater') || can('edit_any_project') || can('manage_resources') ||
    can('review_skillcard') || can('manage_members')
  );
  const canUnits = $derived(can('manage_members') || isOfficer);

  // ---- governance sections: { group, title, desc, href, caps[] } ----
  const SECTIONS = [
    { group: 'People & access', title: 'Officers & access', desc: 'Forge officers, assign them to chapters & working groups, and grant capabilities to positions', href: '/admin/access', caps: ['manage_members', 'invite_members'] },
    { group: 'People & access', title: 'Announcements', desc: 'Post, pin & retire the site-wide notice board', href: '/admin/announcements', caps: ['manage_members'] },

    { group: 'Projects', title: 'Project Types', desc: 'Dataset & Benchmark, Model, Agent…', href: '/admin/projects?tab=types', caps: ['manage_taxonomy'] },
    { group: 'Projects', title: 'Project Statuses', desc: 'Proposal → Finished workflow states', href: '/admin/projects?tab=statuses', caps: ['manage_taxonomy'] },
    { group: 'Projects', title: 'Project Roles', desc: 'Roles members hold within a project', href: '/admin/projects?tab=roles', caps: ['manage_taxonomy'] },
    { group: 'Projects', title: 'Venues', desc: 'Conferences & journals + submission deadlines', href: '/admin/projects?tab=venues', caps: ['manage_taxonomy', 'edit_any_project'] },

    { group: 'Guild & skills', title: 'Skill tree & guild', desc: 'The skill tree, the leader requirement & the masters', href: '/admin/guild', caps: ['manage_taxonomy', 'manage_guild'] },

    { group: 'Resources & economy', title: 'Resource Types', desc: 'Categories of resources (compute, funding, data…)', href: '/admin/resource-types', caps: ['manage_taxonomy', 'manage_resources'] },
    { group: 'Resources & economy', title: 'Community Resources', desc: 'Community-owned resources + their stewards', href: '/admin/resources', caps: ['manage_resources'] },
    { group: 'Resources & economy', title: 'STR Economy', desc: 'Supply, mint/sink flow, treasury ledger & policy knobs', href: '/admin/stater', caps: ['manage_stater'] }
  ];
  const GROUPS = ['People & access', 'Projects', 'Guild & skills', 'Resources & economy'];
  const visibleGroups = $derived(
    GROUPS.map((g) => ({
      group: g,
      items: SECTIONS.filter((s) => s.group === g && s.caps.some((c) => can(c)))
    })).filter((g) => g.items.length)
  );

  // ---- counts ----
  let loading = $state(true);
  let members = $state(0), activeMembers = $state(0), projects = $state(0);
  let openNeeds = $state(0), skillLeaves = $state(0), circulating = $state(0);
  let pendingForge = $state(0), pendingCommits = $state(0), pendingSettlements = $state(0), pendingUnitApps = $state(0);

  const review = $derived([
    canForge ? { title: 'Forge queue', desc: 'Badges, member cards, needs, resources, over-capacity commitments & settlements', href: '/admin/review?tab=forge', n: pendingForge + pendingCommits + pendingSettlements } : null,
    canUnits ? { title: 'Unit applications', desc: 'Members applying to join a chapter or working group', href: '/admin/review?tab=units', n: pendingUnitApps } : null
  ].filter(Boolean) as { title: string; desc: string; href: string; n: number }[]);

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
    members = m.count ?? 0; activeMembers = am.count ?? 0; projects = p.count ?? 0;
    openNeeds = on.count ?? 0; pendingForge = fr.count ?? 0; pendingCommits = cm.count ?? 0;
    pendingSettlements = st.count ?? 0; pendingUnitApps = ua.count ?? 0; skillLeaves = sk.count ?? 0;
    circulating = ((bal.data as { balance: number }[]) ?? []).reduce((a, b) => a + (Number(b.balance) || 0), 0);
    loading = false;
  }
  onMount(load);
</script>

<div class="stack">
  <header>
    <h1>{$t('Admin center')}</h1>
    <p class="muted hsub">{$t('The community at a glance, what needs a decision, and every knob you’re cleared to turn.')}</p>
  </header>

  <!-- headline metrics -->
  <div class="kpis">
    <div class="kpi"><span class="k-label">{$t('Members')}</span><span class="k-value accent">{loading ? '–' : members.toLocaleString()}</span><span class="k-sub">{loading ? '' : $t('{n} active', { n: activeMembers })}</span></div>
    <div class="kpi"><span class="k-label">{$t('Projects')}</span><span class="k-value">{loading ? '–' : projects.toLocaleString()}</span><span class="k-sub"><a href="/projects?tab=needs">{$t('{n} open needs', { n: openNeeds })} →</a></span></div>
    <div class="kpi"><span class="k-label">{$t('STR circulating')}</span><span class="k-value">{loading ? '–' : circulating.toLocaleString()}</span><span class="k-sub"><a href="/admin/stater">{$t('economy →')}</a></span></div>
    <div class="kpi"><span class="k-label">{$t('Skills')}</span><span class="k-value">{loading ? '–' : skillLeaves.toLocaleString()}</span><span class="k-sub">{$t('certifiable crafts')}</span></div>
  </div>

  <!-- review band -->
  {#if review.length}
    <section class="grp">
      <span class="sec">{$t('Review queue')}</span>
      <div class="review-grid">
        {#each review as r (r.href)}
          <a class="review-card" class:hot={r.n > 0} href={r.href}>
            <div class="rc-top">
              <span class="rc-title">{$t(r.title)}</span>
              <span class="rc-count" class:zero={r.n === 0}>{loading ? '·' : r.n}</span>
            </div>
            <span class="rc-desc">{$t(r.desc)}</span>
          </a>
        {/each}
      </div>
    </section>
  {/if}

  <!-- governance, grouped by domain (permission-gated) -->
  {#each visibleGroups as g (g.group)}
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

  {#if !loading && !review.length && !visibleGroups.length}
    <div class="card"><p class="muted">{$t('You don’t have any admin tools yet.')}</p></div>
  {/if}
</div>

<style>
  .hsub { margin-top: -.5rem; font-size: .9rem; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
  .grp { display: flex; flex-direction: column; gap: .5rem; }

  .review-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: .7rem; }
  .review-card {
    display: flex; flex-direction: column; gap: .3rem; padding: .9rem 1rem;
    border: 1px solid var(--border); border-radius: 12px; background: var(--card);
    text-decoration: none; color: var(--text); transition: border-color .12s, transform .12s;
  }
  .review-card:hover { border-color: var(--accent); transform: translateY(-2px); }
  .review-card.hot { border-color: color-mix(in srgb, var(--accent) 45%, transparent); background: var(--accent-soft); }
  .rc-top { display: flex; align-items: center; justify-content: space-between; gap: .6rem; }
  .rc-title { font-weight: 600; font-size: 1rem; }
  .rc-count {
    min-width: 1.6rem; text-align: center; font-weight: 700; font-variant-numeric: tabular-nums;
    padding: .1rem .45rem; border-radius: 999px; background: var(--accent); color: #fff; font-size: .82rem;
  }
  .rc-count.zero { background: var(--card-2); color: var(--muted); }
  .rc-desc { font-size: .8rem; line-height: 1.45; color: var(--muted); }

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
