<script lang="ts">
  import LookupEditor from '$lib/LookupEditor.svelte';
  import { t } from '$lib/i18n';
</script>

<div class="stack">
  <p><a href="/admin">← {$t('Admin')}</a></p>
  <h1>{$t('Project Roles')}</h1>
  <p class="muted" style="margin-top:-.75rem;">{$t('Roles within a project. "Can manage" grants edit rights on that project.')}</p>
  <LookupEditor
    table="project_role"
    orderBy="name"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'can_manage', label: 'Can manage', type: 'bool' }
    ]}
  />
</div>
