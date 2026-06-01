<script lang="ts">
  const sections = [
    { href: '/admin/invites', title: 'Invite Members', desc: 'Pre-create members by email (invite-only)' },
    { href: '/admin/positions', title: 'Positions', desc: 'Community-level titles + ordering' },
    { href: '/admin/capabilities', title: 'Capabilities', desc: 'Grant capabilities to positions (permission matrix)' },
    { href: '/admin/roles', title: 'Project Roles', desc: 'Roles members hold within a project' },
    { href: '/admin/types', title: 'Project Types', desc: 'Dataset & Benchmark, Model, Agent…' },
    { href: '/admin/statuses', title: 'Project Statuses', desc: 'Proposal → Finished workflow states' },
    { href: '/admin/venues', title: 'Venues', desc: 'Conferences & journals + submission deadlines' },
    { href: '/admin/skills', title: 'Skill Tree', desc: 'Hierarchical skills used for matching' },
    { href: '/admin/resource-types', title: 'Resource Types', desc: 'Categories of resources (compute, funding, data…)' },
    { href: '/admin/resources', title: 'Community Resources', desc: 'Community-owned resources + their stewards' },
    { href: '/admin/stater', title: 'STR Economy', desc: 'Supply at a glance, mint/sink flow, treasury ledger, health flags — plus mint, grant, allowance & policy knobs' }
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
