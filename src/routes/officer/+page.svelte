<script lang="ts">
  import { officerUnits, capabilities, authReady } from '$lib/session';
  import { t } from '$lib/i18n';

  // Officer hub — routes the signed-in officer to their console(s) by unit kind.
  // Chapter officers run the card binder; WG officers run the slot board.
  const chapters = $derived($officerUnits.filter((u) => u.kind === 'chapter'));
  const wgs = $derived($officerUnits.filter((u) => u.kind === 'working_group'));
  const isAdmin = $derived($capabilities.has('manage_members') || $capabilities.has('edit_any_project'));
</script>

<svelte:head><title>Officer · The Fin AI</title></svelte:head>

<section class="wrap">
  <header class="hd">
    <h1>{$t('Officer console')}</h1>
    <p class="sub">{$t('Forge cards, claim projects, and seat members into open slots.')}</p>
  </header>

  {#if !$authReady}
    <div class="sk sk-row"></div>
  {:else if !$officerUnits.length && !isAdmin}
    <p class="muted">{$t('You are not an officer of any chapter or working group.')}</p>
  {:else}
    {#if chapters.length}
      <h2 class="sec">{$t('Chapters — card binder')}</h2>
      <div class="grid">
        {#each chapters as u (u.unit_id)}
          <a class="tile console" href={`/officer/chapter/${u.unit_id}`}>
            <span class="label">{$t('Chapter')}</span>
            <span class="value">{u.name}</span>
            <span class="sub">{$t('Forge member cards · badges · seat into slots')}</span>
          </a>
        {/each}
      </div>
    {/if}

    {#if wgs.length}
      <h2 class="sec">{$t('Working groups — slot board')}</h2>
      <div class="grid">
        {#each wgs as u (u.unit_id)}
          <a class="tile console" href={`/officer/wg/${u.unit_id}`}>
            <span class="label">{$t('Working group')}</span>
            <span class="value">{u.name}</span>
            <span class="sub">{$t('Claim projects · post needs · mint completion')}</span>
          </a>
        {/each}
      </div>
    {/if}

    {#if isAdmin}
      <h2 class="sec">{$t('Admin')}</h2>
      <div class="grid">
        <a class="tile console" href="/admin/forge-queue">
          <span class="label">{$t('Review')}</span>
          <span class="value">{$t('Forge queue')}</span>
          <span class="sub">{$t('One approval queue for every forge')}</span>
        </a>
      </div>
    {/if}
  {/if}
</section>

<style>
  .wrap { display: flex; flex-direction: column; gap: 1rem; max-width: 960px; }
  .hd h1 { font-size: 1.5rem; font-weight: 600; color: var(--text); margin: 0; }
  .sub { color: var(--muted); font-size: .88rem; margin: .25rem 0 0; }
  .sec { font-size: .74rem; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); margin: 1rem 0 0; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: .7rem; }
  .console { text-decoration: none; display: flex; flex-direction: column; gap: .25rem; transition: border-color .12s ease, transform .12s ease; }
  .console:hover { border-color: var(--accent); transform: translateY(-2px); }
  .muted { color: var(--muted); }
</style>
