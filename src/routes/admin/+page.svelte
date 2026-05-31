<script lang="ts">
  const sections = [
    { href: '/admin/invites', title: 'Invite Members', desc: 'Pre-create members by email (invite-only)' },
    { href: '/admin/positions', title: 'Positions', desc: 'Community-level titles + capability grants' },
    { href: '/admin/roles', title: 'Project Roles', desc: 'Roles members hold within a project' },
    { href: '/admin/types', title: 'Project Types', desc: 'Dataset & Benchmark, Model, Agent…' },
    { href: '/admin/statuses', title: 'Project Statuses', desc: 'Proposal → Finished workflow states' },
    { href: '/admin/skills', title: 'Skill Tree', desc: 'Hierarchical skills used for matching' }
  ];
</script>

<div class="stack">
  <h1>Admin</h1>
  <p class="muted" style="margin-top:-.75rem;">Adjust the configurable taxonomy. Nothing here is hard-coded.</p>
  <div class="row" style="align-items:stretch;">
    {#each sections as s}
      <a class="card" href={s.href} style="flex:1; min-width:220px;">
        <h2>{s.title}</h2>
        <p class="muted">{s.desc}</p>
      </a>
    {/each}
  </div>
</div>
