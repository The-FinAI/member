<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // Retired (Phase 1 rebuild): project management moved to the WG slot board.
  // Resolve the project's working group and forward to its slot board; if the
  // project is unclaimed, fall back to the officer hub.
  const id = $derived($page.params.id);
  let resolving = $state(true);
  let target = $state('/officer');

  async function resolve(pid: string) {
    resolving = true;
    if (supabaseConfigured) {
      const { data } = await supabase.from('project').select('org_unit_id').eq('id', pid).maybeSingle();
      if (data?.org_unit_id) target = `/officer/wg/${data.org_unit_id}`;
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
    <p>{$t('Taking you to the slot board…')}</p>
  {:else}
    <p>{$t('Project management has moved to the working-group slot board.')}</p>
    <a class="stake" href={target}>{$t('Open officer console')} →</a>
  {/if}
</section>

<style>
  .redir { display: flex; flex-direction: column; align-items: center; gap: 1rem; padding: 4rem 1rem; color: var(--muted); }
  .redir .spin { width: 22px; height: 22px; }
</style>
