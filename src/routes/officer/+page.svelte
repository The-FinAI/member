<script lang="ts">
  import { goto } from '$app/navigation';
  import { officerUnits, capabilities, authReady } from '$lib/session';
  import EntityCard from '$lib/EntityCard.svelte';
  import { t } from '$lib/i18n';

  // Officer hub — the matching desk. Each unit opens its console, where the
  // officer pairs people (skills + capacity) with open project needs.
  const chapters = $derived($officerUnits.filter((u) => u.kind === 'chapter'));
  const wgs = $derived($officerUnits.filter((u) => u.kind === 'working_group'));
  const isAdmin = $derived($capabilities.has('manage_members') || $capabilities.has('edit_any_project'));
</script>

<svelte:head><title>Officer console · The Fin AI</title></svelte:head>

<section class="wrap">
  <header class="hd">
    <h1>{$t('Officer console')}</h1>
    <p class="sub">{$t('Match people to open needs — seat your members into project slots across the community.')}</p>
  </header>

  {#if !$authReady}
    <div class="sk sk-row"></div>
  {:else if !$officerUnits.length && !isAdmin}
    <p class="muted">{$t('You are not an officer of any chapter or working group.')}</p>
  {:else}
    {#if chapters.length}
      <span class="sec">{$t('Chapters')}</span>
      <div class="card-grid">
        {#each chapters as u (u.unit_id)}
          <EntityCard
            type="Chapter"
            title={u.name}
            subtitle={$t('Place your roster into open needs')}
            status={$t('Console')}
            statusKind="warn"
            onclick={() => goto(`/officer/${u.unit_id}`)}
          />
        {/each}
      </div>
    {/if}

    {#if wgs.length}
      <span class="sec">{$t('Working Groups')}</span>
      <div class="card-grid">
        {#each wgs as u (u.unit_id)}
          <EntityCard
            type="Working Group"
            title={u.name}
            subtitle={$t('Take on projects · staff your needs')}
            status={$t('Console')}
            statusKind="warn"
            onclick={() => goto(`/officer/${u.unit_id}`)}
          />
        {/each}
      </div>
    {/if}

    {#if $officerUnits.length || isAdmin}
      <span class="sec">{$t('Review')}</span>
      <div class="card-grid">
        <EntityCard
          type="Review"
          title={$t('Unit applications')}
          subtitle={$t('Members applying to join your units')}
          onclick={() => goto('/admin/review')}
        />
        {#if isAdmin}
          <EntityCard
            type="Review"
            title={$t('Forge queue')}
            subtitle={$t('One approval queue for every forge')}
            onclick={() => goto('/admin/forge-queue')}
          />
        {/if}
      </div>
    {/if}
  {/if}
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: .9rem; max-width: 960px; }
  .hd h1 { font-size: 1.5rem; font-weight: 600; color: var(--text); margin: 0; }
  .sub { color: var(--muted); font-size: .88rem; margin: .25rem 0 0; }
  .sec { font-size: .72rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin-top: .6rem; }
  .card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .7rem; }
  .muted { color: var(--muted); }
</style>
