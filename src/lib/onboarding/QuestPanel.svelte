<script lang="ts">
  // The game-like first-run panel. Shows the current quest step with a plain
  // "why", a "take me there" button, a progress tracker, and a celebration on
  // completion. One-time & skippable. Auto-advances on the chapter quest.
  import { goto } from '$app/navigation';
  import { quest, questStep, questStatus, advance, skip, dismiss, refresh } from '$lib/onboarding';
  import { t } from '$lib/i18n';
  import Icon from '$lib/Icon.svelte';

  let collapsed = $state(false);

  // some steps complete via an IN-PLACE action (adopt a project, staff a person)
  // with no navigation, so afterNavigate can't catch them — poll while active.
  $effect(() => {
    if ($questStatus !== 'active') return;
    const iv = setInterval(() => refresh(), 2500);
    return () => clearInterval(iv);
  });

  const steps = $derived($quest?.steps ?? []);
  const i = $derived($questStep);
  const cur = $derived(steps[i]);
  const total = $derived(steps.length);

  function go() { if (cur) goto(cur.href); }
</script>

{#if $quest && $questStatus === 'active'}
  <div class="quest" class:collapsed>
    <button class="q-grip" onclick={() => (collapsed = !collapsed)} title={collapsed ? $t('Show the getting-started steps') : $t('Hide')}>
      <Icon name={collapsed ? 'chevron' : 'check'} size={14} />
      <span class="q-grip-tx">{$t('Get started')} · {i + 1}/{total}</span>
    </button>

    {#if !collapsed}
      <div class="q-body">
        <div class="q-head">
          <strong>{$t($quest.title)}</strong>
          <button class="q-skip" onclick={skip}>{$t('Skip')}</button>
        </div>
        <p class="q-sub">{$t($quest.subtitle)}</p>

        <ol class="q-steps">
          {#each steps as s, n}
            <li class:done={n < i} class:on={n === i}>
              <span class="q-dot">{#if n < i}<Icon name="check" size={11} />{:else}{n + 1}{/if}</span>
              <span class="q-label">{$t(s.label)}</span>
            </li>
          {/each}
        </ol>

        {#if cur}
          <div class="q-now">
            <p class="q-why">{$t(cur.why)}</p>
            <div class="q-actions">
              <button class="q-go" onclick={go}>{$t(cur.cta)} →</button>
              <button class="q-did" onclick={advance}>{$t('Done ✓')}</button>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>
{:else if $quest && $questStatus === 'done'}
  <div class="quest done-card">
    <div class="q-body">
      <strong>🎉 {$t('You’ve got the hang of it')}</strong>
      <p class="q-sub">{$t('That’s the core loop. The Guide explains the rest in 60 seconds whenever you want it.')}</p>
      <div class="q-actions">
        <button class="q-go" onclick={() => goto('/guide')}>{$t('Read the guide')} →</button>
        <button class="q-did" onclick={dismiss}>{$t('Close')}</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .quest {
    position: fixed; right: 1rem; bottom: 1rem; z-index: var(--z-tooltip, 60);
    width: min(340px, calc(100vw - 2rem));
    background: var(--elevate, var(--card)); border: 1px solid var(--border);
    border-radius: var(--r-md); box-shadow: var(--shadow); overflow: hidden;
    /* visible but click-through, so it never blocks a control behind it; only
       the quest's own buttons capture clicks (see below). */
    pointer-events: none;
  }
  .q-grip, .q-skip, .q-go, .q-did { pointer-events: auto; }
  .q-grip {
    display: flex; align-items: center; gap: .45rem; width: 100%;
    padding: .5rem .7rem; background: var(--accent); color: #fff; border: 0;
    font-weight: 700; font-size: .8rem; cursor: pointer; text-align: left;
  }
  .q-grip-tx { flex: 1; }
  .q-body { padding: .8rem .85rem .9rem; display: flex; flex-direction: column; gap: .5rem; }
  .q-head { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; }
  .q-head strong { font-size: .95rem; }
  .q-skip { background: none; border: 0; color: var(--muted); font-size: .76rem; cursor: pointer; text-decoration: underline; }
  .q-sub { margin: 0; font-size: .8rem; color: var(--text-dim); line-height: 1.45; }
  .q-steps { list-style: none; margin: .2rem 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }
  .q-steps li { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: var(--muted); }
  .q-steps li.on { color: var(--text); font-weight: 600; }
  .q-steps li.done { color: var(--text-dim); }
  .q-dot {
    flex: 0 0 auto; width: 18px; height: 18px; border-radius: 50%;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: .68rem; font-weight: 700; border: 1px solid var(--border-2); color: var(--muted);
  }
  li.on .q-dot { background: var(--accent); color: #fff; border-color: var(--accent); }
  li.done .q-dot { background: var(--ok, #2a9d5c); color: #fff; border-color: transparent; }
  .q-now { border-top: 1px solid var(--border); padding-top: .5rem; display: flex; flex-direction: column; gap: .5rem; }
  .q-why { margin: 0; font-size: .8rem; line-height: 1.45; color: var(--text-dim); }
  .q-actions { display: flex; gap: .45rem; flex-wrap: wrap; }
  .q-go { background: var(--accent); color: #fff; border: 0; border-radius: var(--r-sm); padding: .4rem .7rem; font-weight: 600; font-size: .82rem; cursor: pointer; }
  .q-did { background: transparent; color: var(--text-dim); border: 1px solid var(--border); border-radius: var(--r-sm); padding: .4rem .7rem; font-size: .82rem; cursor: pointer; }
  .done-card { padding: 0; }
</style>
