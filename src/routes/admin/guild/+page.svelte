<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import AdminConsole from '$lib/admin/AdminConsole.svelte';
  import SkillTreePanel from '$lib/admin/guild/SkillTreePanel.svelte';
  import LeaderReqPanel from '$lib/admin/guild/LeaderReqPanel.svelte';
  import { t } from '$lib/i18n';

  const tabs = [
    { key: 'skills', label: 'Skill tree' },
    { key: 'leader', label: 'Leader requirement' },
    { key: 'masters', label: 'Masters' }
  ];

  type Master = { member_id: string; full_name: string; skill: string };
  let masters = $state<Master[]>([]);
  let mLoading = $state(true);
  async function loadMasters() {
    if (!supabaseConfigured) { mLoading = false; return; }
    const { data } = await supabase.from('badge')
      .select('member_id, level, member:member_id(full_name), skill:skill_id(name)')
      .eq('level', 'master');
    masters = ((data as any[]) ?? []).map((b) => ({ member_id: b.member_id, full_name: b.member?.full_name ?? '—', skill: b.skill?.name ?? '—' }))
      .sort((a, b) => a.full_name.localeCompare(b.full_name));
    mLoading = false;
  }
  onMount(loadMasters);
</script>

<svelte:head><title>Guild · Admin · The Fin AI</title></svelte:head>

<AdminConsole title="Guild & skills" blurb="The craft ladder — the skill tree badges certify against, the skills a leader must hold, and who has reached master." {tabs}>
  {#snippet children(active)}
    {#if active === 'leader'}
      <LeaderReqPanel />
    {:else if active === 'masters'}
      <p class="muted blurb">{$t('Members certified at master level — the top of the guild ladder. Master badges are awarded through the forge queue.')}</p>
      {#if mLoading}
        <p class="muted">{$t('Loading…')}</p>
      {:else if masters.length === 0}
        <p class="muted">{$t('No masters yet.')}</p>
      {:else}
        <div class="mlist">
          {#each masters as m (m.member_id + m.skill)}
            <a class="m" href={`/members/${m.member_id}`}>
              <span class="m-name">{m.full_name}</span>
              <span class="m-skill">{$t(m.skill)}</span>
            </a>
          {/each}
        </div>
      {/if}
    {:else}
      <SkillTreePanel />
    {/if}
  {/snippet}
</AdminConsole>

<style>
  .blurb { margin: 0 0 .2rem; font-size: .85rem; }
  .mlist { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: .5rem; }
  .m { display: flex; align-items: center; justify-content: space-between; gap: .5rem; padding: .55rem .8rem; border: 1px solid var(--border); border-radius: 10px; background: var(--card); text-decoration: none; color: var(--text); }
  .m:hover { border-color: var(--accent); }
  .m-name { font-weight: 600; }
  .m-skill { font-size: .78rem; color: var(--warn, var(--accent)); }
</style>
