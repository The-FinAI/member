<script lang="ts">
  import { t } from '$lib/i18n';
  // The reference manual — officer-first for Phase 1. Static, no data calls;
  // linked from the nav and empty states. Grounded in the card / slot / verb model.
  const toc = [
    { id: 'phase1', label: 'Phase 1 — what you’re here to do' },
    { id: 'model', label: 'The model — cards, slots, verbs' },
    { id: 'chapter', label: 'If you run a chapter' },
    { id: 'wg', label: 'If you run a working group' },
    { id: 'str', label: 'How STR flows' },
    { id: 'pages', label: 'Your pages' },
    { id: 'glossary', label: 'Glossary' },
    { href: '/str', label: 'STR paper — the dollar anchor ↗' }
  ];
</script>

<svelte:head><title>Guide · The Fin AI</title></svelte:head>

<div class="stack guide">
  <header>
    <h1>{$t('How The Fin AI works')}</h1>
    <p class="muted lead">{$t('A research community run as an economy: contribution is minted into a shared pool, and when a project ships the pool pays out. Phase 1 is officers only — this is your manual.')}</p>
  </header>

  <!-- Phase 1 callout -->
  <div class="callout">
    <span class="cbadge">{$t('Phase 1 · live now')}</span>
    <h2>{$t('Officers only — mirror reality into the system')}</h2>
    <p>{@html $t('We switch the economy on in stages. <strong>Phase 1 is officers only;</strong> ordinary researchers don’t log in yet — they exist as <em>member cards</em> their officer manages. Your job: forge a card for each person you steward, take on the projects you already run, and seat the people who are really on them. Three acts → the system matches reality.')}</p>
    <a class="cbtn" href="/officer">{$t('Open your officer console →')}</a>
  </div>

  <nav class="toc">
    {#each toc as tn}<a href={tn.href ?? `#${tn.id}`}>{$t(tn.label)}</a>{/each}
  </nav>

  <!-- Phase 1 playbook -->
  <section id="phase1" class="card stack">
    <h2>{$t('Phase 1 — what you’re here to do')}</h2>
    <p>{@html $t('The goal isn’t to start fresh operations — it’s <strong>reality-mirroring onboarding</strong>: make the system’s state equal what your community already does, as fast as possible. Everything you do is one of three acts:')}</p>
    <ol class="acts">
      <li><strong>{$t('Forge')}</strong> — {$t('create or stamp a card: a member card, a badge, a resource, a project need. Forging goes through a review queue.')}</li>
      <li><strong>{$t('Seat')}</strong> — {$t('place a person into an open slot on a project, with their monthly hours. This is how work is committed.')}</li>
      <li><strong>{$t('Settle')}</strong> — {$t('when a project ships, its pool is paid out by contribution. (Mostly later in the phase.)')}</li>
    </ol>
  </section>

  <!-- mental model -->
  <section id="model" class="card stack">
    <h2>{$t('The model — cards, slots, verbs')}</h2>
    <p>{@html $t('Three kinds of card: a <strong>member card</strong> is a person, a <strong>project card</strong> is a project, a <strong>badge</strong> is a certified skill stamped on a member card. A project card has <strong>slots</strong>; people get <strong>seated</strong> into them.')}</p>

    <div class="grid3">
      <div class="mc"><span class="mh">{$t('Two aspects a card carries')}</span>
        <p>{@html $t('<strong>Access</strong> (badges) — can you enter a slot. <strong>Authority</strong> (capabilities, or holding a leader seat) — can you decide / post needs.')}</p></div>
      <div class="mc"><span class="mh">{$t('A project’s slots')}</span>
        <p>{@html $t('<strong>Leader</strong> = first author. <strong>Labor needs</strong> = work hours of a skill → co-authors. <strong>Resource needs</strong> = compute / data / funding → corresponding / last author.')}</p></div>
      <div class="mc"><span class="mh">{$t('A slot’s requirements')}</span>
        <p>{@html $t('Every need is <strong>skill + resource</strong>: the right badge(s), and a held resource with monthly capacity (a labor need’s resource is the person’s working hours).')}</p></div>
    </div>

    <div class="flow">
      <span class="step">{$t('Forge cards')}</span><span class="arr">→</span>
      <span class="step">{$t('Seat into slots (monthly)')}</span><span class="arr">→</span>
      <span class="step">{$t('Work mints nominal STR')}</span><span class="arr">→</span>
      <span class="step">{$t('Project ships → Settle')}</span><span class="arr">→</span>
      <span class="step">{$t('Pool pays out')}</span>
    </div>
  </section>

  <!-- chapter officer -->
  <section id="chapter" class="card stack">
    <h2>{$t('If you run a chapter')}</h2>
    <p class="muted">{$t('A chapter officer is the custodian of people. You steward member cards.')}</p>
    <ol class="steps">
      <li>{@html $t('<strong>Forge a member card</strong> for each researcher you steward (name + email). Do it from your officer console or a chapter drawer.')}</li>
      <li>{@html $t('<strong>Stamp their badges and add their resources</strong> — certify skills (the talent tree), and declare their monthly working hours (a <em>Labor</em> resource) and any compute/data they hold.')}</li>
      <li>{@html $t('<strong>Seat them into open needs.</strong> Your console is a matching desk: pick an open need, qualified roster members light up (skill + spare hours); pick a person, the needs they can fill light up. Seat them with their monthly amount.')}</li>
    </ol>
    <a class="ilink" href="/officer">{$t('Open your officer console →')}</a>
  </section>

  <!-- WG officer -->
  <section id="wg" class="card stack">
    <h2>{$t('If you run a working group')}</h2>
    <p class="muted">{$t('A working-group officer is the custodian of projects. You steward project cards.')}</p>
    <ol class="steps">
      <li>{@html $t('<strong>Take on your projects</strong> — claim the project cards your group already runs (claiming is instant for your own group).')}</li>
      <li>{@html $t('<strong>Post needs</strong> — open the slots you need filled (a skill at a level, or a resource type, with a monthly quota). Posting a need goes through review.')}</li>
      <li>{@html $t('<strong>Claim milestones & mint completion</strong> — as the project hits verifiable outcomes (submitted, accepted, released…), claim the milestone; when it ships, mint completion to open settlement.')}</li>
    </ol>
    <a class="ilink" href="/officer">{$t('Open your officer console →')}</a>
  </section>

  <!-- STR -->
  <section id="str" class="card stack">
    <h2>{$t('How STR flows')}</h2>
    <p>{@html $t('<strong>STR</strong> is the unit of account. Work and milestones mint <strong>nominal</strong> STR (locked, accruing in the project pool); only when a project ships does it <strong>settle</strong> into <strong>liquid</strong> STR you can spend.')}</p>
    <ul class="bul">
      <li>{@html $t('<strong>Input axis — Work.</strong> Each month a seated person’s hours/resources mint nominal STR into the pool (trust-based; over-capacity goes to review).')}</li>
      <li>{@html $t('<strong>Output axis — Milestones.</strong> A verified outcome (arXiv, accepted, SOTA…) adds its nominal to the pool <em>and</em> bumps the settlement multiplier — capped at ×3.')}</li>
      <li>{@html $t('<strong>Settlement.</strong> When the project is Finished: <code>payout = your share × pool × multiplier</code>. No ship, no payout — your nominal stays locked.')}</li>
    </ul>
    <p class="muted">{$t('So milestones make the pie bigger and raise the conversion rate; monthly work decides the slices.')}</p>
    <a class="ilink" href="/str">{$t('Read the full STR paper — the dollar anchor & pricing →')}</a>
  </section>

  <!-- pages -->
  <section id="pages" class="card stack">
    <h2>{$t('Your pages')}</h2>
    <ul class="pages">
      <li><a href="/officer">{$t('Officer console')}</a> — {$t('your matching desk: forge cards, take on projects, post needs, seat people.')}</li>
      <li><a href="/community">{$t('Community')}</a> — {$t('everyone, the chapters & working groups, the badge catalog, and the standing boards.')}</li>
      <li><a href="/projects">{$t('Projects')}</a> — {$t('every project card: status, slots, the nominal pool, milestones & history.')}</li>
      <li><a href="/admin/forge-queue">{$t('Review queue')}</a> — {$t('one review queue for every forge — badges, cards, needs, resources, milestones, over-capacity & settlements.')}</li>
      <li><a href="/wallet">{$t('Wallet')}</a> — {$t('your own STR — liquid and nominal — and where it came from.')}</li>
    </ul>
  </section>

  <!-- glossary -->
  <section id="glossary" class="card stack">
    <h2>{$t('Glossary')}</h2>
    <dl class="gloss">
      <dt>{$t('Forge')}</dt><dd>{$t('Create or update a card (member, badge, resource, need) — reviewed once.')}</dd>
      <dt>{$t('Seat / Work')}</dt><dd>{$t('Place a person into a slot with a monthly commitment; mints nominal STR.')}</dd>
      <dt>{$t('Slot / Need')}</dt><dd>{$t('A position on a project card: leader, a labor need, or a resource need.')}</dd>
      <dt>{$t('Badge')}</dt><dd>{$t('A certified skill on a member card, ranked apprentice → master.')}</dd>
      <dt>{$t('Nominal STR')}</dt><dd>{$t('Locked value accruing in a project pool; can’t be spent until settlement.')}</dd>
      <dt>{$t('Liquid STR')}</dt><dd>{$t('Spendable STR, paid out at settlement.')}</dd>
      <dt>{$t('Milestone')}</dt><dd>{$t('A verified project outcome that adds nominal and lifts the settlement multiplier.')}</dd>
      <dt>{$t('Settle')}</dt><dd>{$t('Convert a finished project’s pool into liquid STR, split by contribution.')}</dd>
    </dl>
  </section>
</div>

<style>
  .guide { max-width: 860px; gap: 1rem; }
  .lead { margin-top: -.4rem; font-size: .95rem; line-height: 1.6; }
  .callout { display: flex; flex-direction: column; gap: .5rem; padding: 1rem 1.1rem; border: 1px solid color-mix(in srgb, var(--accent) 35%, transparent); border-radius: 14px; background: var(--accent-soft); }
  .cbadge { align-self: flex-start; font-size: .7rem; letter-spacing: .05em; text-transform: uppercase; font-weight: 700; color: var(--accent); }
  .callout h2 { margin: 0; font-size: 1.2rem; }
  .callout p { margin: 0; line-height: 1.6; }
  .cbtn { align-self: flex-start; margin-top: .2rem; padding: .5rem .9rem; border-radius: 8px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; }
  .toc { display: flex; flex-wrap: wrap; gap: .4rem .9rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: 12px; background: var(--card); }
  .toc a { font-size: .85rem; color: var(--muted); text-decoration: none; }
  .toc a:hover { color: var(--accent); }
  section.card { padding: 1.1rem 1.2rem; }
  section h2 { margin: 0 0 .2rem; }
  section p, section li { line-height: 1.6; }
  .acts, .steps { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .5rem; }
  .acts li, .steps li { padding-left: .2rem; }
  .grid3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .7rem; }
  .mc { border: 1px solid var(--border); border-radius: 11px; background: var(--card-2); padding: .7rem .8rem; }
  .mh { font-size: .72rem; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
  .mc p { margin: .3rem 0 0; font-size: .88rem; }
  .flow { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; margin-top: .3rem; }
  .step { font-size: .8rem; padding: .3rem .6rem; border: 1px solid var(--border); border-radius: 999px; background: var(--card-2); color: var(--text); }
  .arr { color: var(--muted); }
  .bul, .pages { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .5rem; }
  .pages a { font-weight: 600; }
  .ilink { color: var(--accent); text-decoration: none; font-size: .9rem; }
  .ilink:hover { text-decoration: underline; }
  .gloss { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: .4rem 1rem; }
  .gloss dt { font-weight: 600; color: var(--text); }
  .gloss dd { margin: 0; color: var(--muted); font-size: .9rem; }
  @media (max-width: 560px) { .gloss { grid-template-columns: 1fr; gap: .1rem .5rem; } .gloss dd { margin-bottom: .4rem; } }
</style>
