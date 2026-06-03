<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // Retired (Phase 1 rebuild): unit management moved to the officer consoles.
  // Resolve the unit's kind and forward to the right console, falling back to a
  // link if the redirect can't run.
  const id = $derived($page.params.id);
  let resolving = $state(true);
  let target = $state('/officer');

  async function resolve(uid: string) {
    resolving = true;
    if (supabaseConfigured) {
      const { data } = await supabase.from('org_unit').select('kind').eq('id', uid).maybeSingle();
      if (data?.kind === 'working_group' || data?.kind === 'chapter') target = `/officer/${uid}`;
    }
    resolving = false;
    goto(target, { replaceState: true });
  }

  let last = '';
  $effect(() => { if (id && id !== last) { last = id; resolve(id); } });
</script>

<svelte:head><title>Officer console · The Fin AI</title></svelte:head>

<section class="redir">
  {#if resolving}
    <div class="spin"></div>
    <p>{$t('Taking you to the officer console…')}</p>
  {:else}
    <p>{$t('Unit management has moved to the officer console.')}</p>
    <a class="stake" href={target}>{$t('Open officer console')} →</a>
  {/if}
</section>

<style>
  .redir { display: flex; flex-direction: column; align-items: center; gap: 1rem; padding: 4rem 1rem; color: var(--muted); }
  .redir .spin { width: 22px; height: 22px; }
</style>
