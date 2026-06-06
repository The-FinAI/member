<script lang="ts">
  // R3 — the reference manual, rewritten to the new model (Person · Project ·
  // Need · Task · Skill · STR) and the surfaces (People · Projects · My).
  // Officer-first for Phase 1. Static, no data calls.
  const toc = [
    { id: 'what', label: 'What this is' },
    { id: 'you', label: 'What you do' },
    { id: 'chapter', label: 'If you run a chapter' },
    { id: 'wg', label: 'If you run a working group' },
    { id: 'str', label: 'How STR works' },
    { id: 'pages', label: 'Your pages' },
    { id: 'glossary', label: 'Glossary' }
  ];
</script>

<svelte:head><title>Guide · The Fin AI</title></svelte:head>

<div class="stack guide">
  <header>
    <h1>How The Fin AI Community works</h1>
    <p class="lead">A shared, living record of the community's <strong>projects</strong> and
      <strong>people</strong>. Working groups run their projects in it; chapters keep their people in it;
      finished work settles into <strong>STR</strong> credit. In Phase 1, officers keep the record on
      behalf of members who don't log in yet.</p>
  </header>

  <nav class="toc">{#each toc as s}<a href={`#${s.id}`}>{s.label}</a>{/each}</nav>

  <section class="card" id="what">
    <h2>What this is</h2>
    <p>Six things, and only six:</p>
    <div class="grid3">
      <div class="mc"><div class="mh">Person</div><p>A researcher, with <strong>skills</strong> (at a level) and a monthly <strong>capacity</strong> (hours). Lives in a <strong>chapter</strong>.</p></div>
      <div class="mc"><div class="mh">Project</div><p>Work toward a publication, owned by a <strong>working group</strong>. Has a task board, a team, needs and milestones.</p></div>
      <div class="mc"><div class="mh">Need</div><p>What a project requires to form: a skill at a level, or a resource, with a capacity. Filled by <strong>matching</strong>.</p></div>
      <div class="mc"><div class="mh">Task</div><p>A piece of work with an owner and a status — the living record that replaces a shared doc.</p></div>
      <div class="mc"><div class="mh">Skill</div><p>What someone can do, at <strong>Learning · Independent · Lead</strong>, backed by evidence from the record.</p></div>
      <div class="mc"><div class="mh">STR</div><p>The credit. Contribution <em>accrues</em>; a finished project <em>settles</em> it into spendable STR.</p></div>
    </div>
  </section>

  <section class="card" id="you">
    <h2>What you do</h2>
    <p>The org has two halves, and you steward one (or both):</p>
    <ul class="bul">
      <li><strong>A chapter</strong> holds <strong>people</strong> — you register them, keep their skills &amp; capacity current, and place them onto open work.</li>
      <li><strong>A working group</strong> holds <strong>projects</strong> — you run each project's record, post what it needs, and split the credit when it ships.</li>
    </ul>
    <p>Start from <strong>Home</strong>: it shows a short "what needs you" list and drops you into the right page.</p>
  </section>

  <section class="card" id="chapter">
    <h2>If you run a chapter — you steward people</h2>
    <ol class="acts">
      <li><strong>Add your people.</strong> On <strong>People</strong>, "Add a person" (name + email). Then on their card, set their skills (one tap: Learning / Independent / Lead) and their monthly hours.</li>
      <li><strong>Match them to open work.</strong> On People, "Match people to needs": pick a need, see ranked candidates with their <strong>spare capacity</strong> and why they fit, and <strong>Assign</strong> in place. The capacity bar turns red before it lets you over-commit anyone.</li>
      <li><strong>Keep skills honest.</strong> As someone owns more tasks and ships projects, the system suggests a level raise — earned from the record, not self-rated.</li>
    </ol>
    <a class="cbtn" href="/people">Open People →</a>
  </section>

  <section class="card" id="wg">
    <h2>If you run a working group — you steward projects</h2>
    <ol class="acts">
      <li><strong>Create or claim a project</strong> (free, no bond). Its first-author seat starts open.</li>
      <li><strong>Run its record.</strong> On the project, the <strong>task board</strong> leads — add tasks, set owners and status, keep coverage checklists, links and notes. This replaces the Google Doc.</li>
      <li><strong>Post what it needs.</strong> "Post a role" — a skill at a level, or a resource — and you'll see how many people qualify. Chapter officers match their people into it.</li>
      <li><strong>Finish &amp; split.</strong> When the paper lands, mark it finished and split the credit; weights default to logged hours with a fairness check.</li>
    </ol>
    <a class="cbtn" href="/projects">Open Projects →</a>
  </section>

  <section class="card" id="str">
    <h2>How STR works (quiet until it's real)</h2>
    <p><strong>STR</strong> is the unit of credit. It stays out of the way of the daily record and shows up only where it matters:</p>
    <div class="flow">
      <span class="step">Contribute (hours / resources)</span><span class="arr">→</span>
      <span class="step">Accruing (locked)</span><span class="arr">→</span>
      <span class="step">Finish</span><span class="arr">→</span>
      <span class="step">Split</span><span class="arr">→</span>
      <span class="step">Settled (spendable)</span>
    </div>
    <p style="margin-top:.6rem;">Each month a person's committed hours and resources <strong>accrue</strong> STR into the project's pool (locked). Verified <strong>milestones</strong> (submitted, accepted, released) raise the payout. When the project is finished, the pool <strong>settles</strong>: each contributor is paid their share as spendable STR. You see it on <strong>My</strong> (your wallet) and at settlement — nowhere else.</p>
    <a class="ilink" href="/wallet">See your wallet →</a>
  </section>

  <section class="card" id="pages">
    <h2>Your pages</h2>
    <ul class="pages">
      <li><a href="/">Home</a> — what needs you right now.</li>
      <li><a href="/projects">Projects</a> — your group's projects &amp; their living record.</li>
      <li><a href="/people">People</a> — the roster, skills &amp; capacity, and the matching board.</li>
      <li><a href="/my">My tasks</a> — every task you own, across all projects, plus your wallet.</li>
      <li><a href="/community">Directory</a> — browse people, chapters, working groups &amp; the skill catalog.</li>
    </ul>
  </section>

  <section class="card" id="glossary">
    <h2>Glossary</h2>
    <dl class="gloss">
      <dt>Person</dt><dd>A researcher (in Phase 1, a card an officer manages).</dd>
      <dt>Chapter</dt><dd>A unit that holds people.</dd>
      <dt>Working group</dt><dd>A unit that holds projects.</dd>
      <dt>Need</dt><dd>An open role on a project — a skill@level or a resource — filled by matching.</dd>
      <dt>Task</dt><dd>A unit of work with an owner and a status.</dd>
      <dt>Skill level</dt><dd>Learning · Independent · Lead, backed by evidence (tasks · shipped).</dd>
      <dt>Capacity</dt><dd>How many hours a month a person can give.</dd>
      <dt>Assign</dt><dd>Place a person onto a need.</dd>
      <dt>First author</dt><dd>The project lead — itself a need, matched like any other.</dd>
      <dt>Milestone</dt><dd>A verified outcome (submitted, accepted, released) that raises the payout.</dd>
      <dt>STR</dt><dd>The credit. Accruing (locked) → Settled (spendable).</dd>
      <dt>Settle / Split</dt><dd>Pay out a finished project's pool by each contributor's share.</dd>
    </dl>
  </section>
</div>

<style>
  .guide { max-width: 860px; gap: 1rem; }
  .lead { margin-top: -.4rem; font-size: .95rem; line-height: 1.6; }
  .cbtn { align-self: flex-start; margin-top: .4rem; padding: .5rem .9rem; border-radius: 8px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; display: inline-block; }
  .toc { display: flex; flex-wrap: wrap; gap: .4rem .9rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: 12px; background: var(--card); }
  .toc a { font-size: .85rem; color: var(--muted); text-decoration: none; }
  .toc a:hover { color: var(--accent); }
  section.card { padding: 1.1rem 1.2rem; }
  section h2 { margin: 0 0 .4rem; }
  section p, section li { line-height: 1.6; }
  .acts { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .55rem; }
  .bul { margin: .3rem 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .4rem; }
  .grid3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .7rem; margin-top: .5rem; }
  .mc { border: 1px solid var(--border); border-radius: 11px; background: var(--card-2); padding: .7rem .8rem; }
  .mh { font-size: .72rem; letter-spacing: .05em; text-transform: uppercase; color: var(--accent); font-weight: 700; }
  .mc p { margin: .3rem 0 0; font-size: .88rem; }
  .flow { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; margin-top: .5rem; }
  .step { font-size: .8rem; padding: .3rem .6rem; border: 1px solid var(--border); border-radius: 999px; background: var(--card-2); color: var(--text); }
  .arr { color: var(--muted); }
  .pages { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .5rem; }
  .pages a { font-weight: 600; }
  .ilink { color: var(--accent); text-decoration: none; font-size: .9rem; }
  .ilink:hover { text-decoration: underline; }
  .gloss { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: .4rem 1rem; }
  .gloss dt { font-weight: 600; color: var(--text); }
  .gloss dd { margin: 0; color: var(--muted); font-size: .9rem; }
  @media (max-width: 560px) { .gloss { grid-template-columns: 1fr; gap: .1rem .5rem; } .gloss dd { margin-bottom: .4rem; } }
</style>
