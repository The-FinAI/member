<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase, supabaseConfigured } from '$lib/supabase';
  import { t } from '$lib/i18n';

  // First-run onboarding checklist for the dashboard. Reads real signals so a
  // step ticks off once the member actually does it; auto-hides when all done or
  // when the member dismisses it (remembered in localStorage).
  let { memberId }: { memberId: string } = $props();

  type Step = { key: string; title: string; blurb: string; href: string; cta: string; done: boolean };

  let steps = $state<Step[]>([]);
  let ready = $state(false);
  let dismissed = $state(false);

  const KEY = 'fin_onboard_dismissed';

  onMount(async () => {
    if (typeof localStorage !== 'undefined' && localStorage.getItem(KEY) === '1') dismissed = true;
    if (!supabaseConfigured) { ready = true; return; }

    const [{ data: res }, { count: apps }, { count: pos }, { data: certs }] = await Promise.all([
      supabase.from('resource').select('id, resource_type(name)').eq('scope', 'member').eq('holder_member_id', memberId),
      supabase.from('need_application').select('*', { count: 'exact', head: true }).eq('member_id', memberId),
      supabase.from('project_member').select('*', { count: 'exact', head: true }).eq('member_id', memberId),
      supabase.from('member_skill').select('certified_level').eq('member_id', memberId).not('certified_level', 'is', null)
    ]);

    const offersSomething = ((res as { resource_type: { name: string } | null }[]) ?? []).length > 0;
    const hasApps = (apps ?? 0) > 0;
    const hasPos = (pos ?? 0) > 0;
    const certified = ((certs as unknown[]) ?? []).length > 0;

    steps = [
      { key: 'profile', title: 'Set up your profile', blurb: 'List what you can bring — monthly labor and any resources.', href: '/profile', cta: 'Open profile', done: offersSomething },
      { key: 'browse', title: 'Find an opportunity', blurb: 'Browse open needs and apply to one that fits your skills.', href: '/projects?tab=needs', cta: 'Browse opportunities', done: hasApps },
      { key: 'join', title: 'Join a project', blurb: 'Post the join bond and start declaring monthly contributions.', href: '/projects', cta: 'Browse projects', done: hasPos },
      { key: 'certify', title: 'Certify a skill', blurb: 'Sit a Guild exam to earn a credential and raise your labor rate.', href: '/skills', cta: 'Visit the Guild', done: certified }
    ];
    ready = true;
  });

  const doneCount = $derived(steps.filter((s) => s.done).length);
  const allDone = $derived(ready && steps.length > 0 && doneCount === steps.length);

  function dismiss() {
    dismissed = true;
    if (typeof localStorage !== 'undefined') localStorage.setItem(KEY, '1');
  }
</script>

{#if ready && !dismissed && !allDone}
  <div class="card onboard">
    <div class="row" style="justify-content:space-between; align-items:flex-start;">
      <div>
        <h2 style="margin:0 0 .15rem;">{$t('Get started')}</h2>
        <p class="muted" style="margin:0; font-size:.85rem;">
          {$t('{done} of {total} done · new here?', { done: doneCount, total: steps.length })}
          <a href="/guide">{$t('Read how it works →')}</a>
        </p>
      </div>
      <button class="dismiss" onclick={dismiss} title={$t('Dismiss')}>{$t('Dismiss')} ✕</button>
    </div>

    <div class="progress"><span style={`width:${(doneCount / steps.length) * 100}%`}></span></div>

    <ol class="steps">
      {#each steps as s, i}
        <li class:done={s.done}>
          <span class="mark">{s.done ? '✓' : i + 1}</span>
          <div class="body">
            <div class="t">{$t(s.title)}</div>
            <div class="b">{$t(s.blurb)}</div>
          </div>
          {#if !s.done}
            <a href={s.href} class="go">{$t(s.cta)} →</a>
          {:else}
            <span class="badge pos" style="font-size:.7rem;">{$t('done')}</span>
          {/if}
        </li>
      {/each}
    </ol>
  </div>
{/if}

<style>
  .onboard { border: 1px solid var(--accent-soft); }
  .dismiss { background: transparent; border: none; color: var(--muted); font-size: .78rem; cursor: pointer; padding: .2rem; }
  .dismiss:hover { color: var(--text); }
  .progress { height: 5px; background: var(--elevate); border-radius: 999px; overflow: hidden; margin: .7rem 0 .2rem; }
  .progress span { display: block; height: 100%; background: var(--accent); transition: width .4s ease; }
  ol.steps { list-style: none; margin: .4rem 0 0; padding: 0; display: flex; flex-direction: column; }
  ol.steps li { display: flex; align-items: center; gap: .75rem; padding: .65rem .15rem; border-top: 1px solid var(--border); }
  ol.steps li:first-child { border-top: none; }
  .mark {
    flex: none; width: 24px; height: 24px; border-radius: 50%;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: .8rem; font-weight: 700; border: 1px solid var(--border); color: var(--muted);
  }
  li.done .mark { background: var(--accent-soft); border-color: transparent; color: var(--accent); }
  .body { flex: 1; min-width: 0; }
  .body .t { font-weight: 600; font-size: .92rem; }
  li.done .body .t { color: var(--muted); text-decoration: line-through; }
  .body .b { font-size: .8rem; color: var(--muted); }
  .go { white-space: nowrap; color: var(--accent); text-decoration: none; font-size: .84rem; font-weight: 600; }
  .go:hover { text-decoration: underline; }
  @media (max-width: 560px) {
    ol.steps li { flex-wrap: wrap; }
    .go { margin-left: 35px; }
  }
</style>
