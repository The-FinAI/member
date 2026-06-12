<script lang="ts">
  import { t } from '$lib/i18n';
  import { officerUnits, capabilities } from '$lib/session';

  // Role-aware "what do I do next" panel for the home page. Plain language, no
  // jargon — tells an officer/admin the 2–3 concrete next steps with direct links.
  let { dismissed = $bindable(false) }: { dismissed?: boolean } = $props();

  const chapter = $derived($officerUnits.find((u) => u.kind === 'chapter') ?? null);
  const wg = $derived($officerUnits.find((u) => u.kind === 'working_group') ?? null);
  const canApprove = $derived(
    $capabilities.has('review_skillcard') || $capabilities.has('manage_resources') ||
    $capabilities.has('manage_members') || $capabilities.has('edit_any_project') ||
    $capabilities.has('manage_stater')
  );

  type Step = { n: number; title: string; desc: string; href: string };
  const steps = $derived.by(() => {
    const s: Step[] = [];
    if (chapter) {
      s.push({ n: s.length + 1, title: $t('Add your people'), desc: $t('Create a card for each person you steward — their skills & monthly hours.'), href: `/officer/${chapter.unit_id}` });
      s.push({ n: s.length + 1, title: $t('Put them on projects'), desc: $t('Open your console and match a person to a project’s open need.'), href: `/officer/${chapter.unit_id}` });
    }
    if (wg) {
      s.push({ n: s.length + 1, title: $t('Create or claim a project'), desc: $t('Start a project (free) or claim one your group runs.'), href: `/officer/${wg.unit_id}` });
      s.push({ n: s.length + 1, title: $t('Post what it needs'), desc: $t('On the project, post a need — a skill (with level) or a resource.'), href: `/officer/${wg.unit_id}` });
    }
    if (!chapter && !wg) {
      s.push({ n: 1, title: $t('Explore projects'), desc: $t('Browse what the community is working on.'), href: '/projects' });
    }
    if (canApprove) {
      s.push({ n: s.length + 1, title: $t('Approve what’s waiting'), desc: $t('Clear the queue — badges, resources, needs.'), href: '/admin/forge-queue' });
    }
    return s;
  });
</script>

{#if !dismissed && steps.length}
  <section class="start">
    <div class="start-head">
      <span class="start-title">{$t('Start here')}</span>
      <button type="button" class="start-x" onclick={() => (dismissed = true)} title={$t('Hide')}>✕</button>
    </div>
    <p class="start-sub muted">{$t('A few steps to get going. You can hide this any time.')}</p>
    <div class="start-steps">
      {#each steps as st (st.title)}
        <a class="step" href={st.href}>
          <span class="step-n">{st.n}</span>
          <span class="step-tx"><strong>{st.title}</strong><span class="muted">{st.desc}</span></span>
          <span class="step-go">→</span>
        </a>
      {/each}
    </div>
  </section>
{/if}

<style>
  .start { border: 1px solid color-mix(in srgb, var(--accent) 35%, var(--border)); background: var(--accent-soft); border-radius: var(--r-lg); padding: .9rem 1rem; display: flex; flex-direction: column; gap: .5rem; }
  .start-head { display: flex; align-items: center; justify-content: space-between; }
  .start-title { font-weight: 700; font-size: 1rem; color: var(--text); }
  .start-x { background: transparent; border: 0; cursor: pointer; color: var(--muted); font-size: .9rem; }
  .start-x:hover { color: var(--text); }
  .start-sub { margin: 0; font-size: .82rem; }
  .start-steps { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: .5rem; }
  .step { display: flex; align-items: flex-start; gap: .6rem; padding: .65rem .75rem; background: var(--card); border: 1px solid var(--border); border-radius: var(--r-md); text-decoration: none; color: var(--text); }
  .step:hover { border-color: var(--accent); transform: translateY(-1px); }
  .step-n { flex: none; width: 1.5rem; height: 1.5rem; border-radius: 50%; background: var(--accent); color: #fff; font-weight: 700; font-size: .82rem; display: grid; place-items: center; }
  .step-tx { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
  .step-tx strong { font-size: .9rem; }
  .step-tx .muted { font-size: .78rem; }
  .step-go { margin-left: auto; color: var(--muted); font-weight: 700; }
</style>
