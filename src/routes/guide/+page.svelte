<script lang="ts">
  // Static "How it works" explainer for the whole Stater economy. No data calls —
  // it's the always-available reference manual, linked from the nav, empty states,
  // and inline Hint dots (which deep-link to the #term-* glossary anchors below).
  const toc = [
    { id: 'mental-model', label: 'The big picture' },
    { id: 'str', label: '1 · STR — the unit' },
    { id: 'contribution', label: '2 · Contribution = stake' },
    { id: 'projects', label: '3 · Projects & their lifecycle' },
    { id: 'opportunities', label: '4 · Finding work' },
    { id: 'guild', label: '5 · The Guild — skills & certification' },
    { id: 'reputation', label: '6 · Reputation & leaderboard' },
    { id: 'start', label: '7 · How to start' },
    { id: 'glossary', label: 'Glossary' }
  ];
</script>

<div class="stack guide">
  <div>
    <h1 style="margin-bottom:.2rem;">How The Fin AI works</h1>
    <p class="muted" style="margin-top:0;">
      A research community that runs like an economy: you put work in, it mints into a shared
      pool, and when a project ships the pool pays out. This page explains the whole model —
      keep it as a reference.
    </p>
  </div>

  <nav class="card toc">
    {#each toc as t}<a href={`#${t.id}`}>{t.label}</a>{/each}
  </nav>

  <!-- ───────────────────────── big picture ───────────────────────── -->
  <section id="mental-model" class="card stack">
    <h2>The big picture</h2>
    <p>
      Everything here revolves around one idea: <strong>contribution is stake</strong>. When you
      pledge time or resources to a research project, that pledge is valued and <em>minted</em> into
      the project's shared pool as your claim on it. Ship the project, and the pool — your minted
      claims plus a finish bonus — is split among the people who built it and converts into real,
      spendable <strong>STR</strong>.
    </p>
    <p class="muted">
      So the loop is: <strong>join a project → pledge work monthly → it mints your share → the
      project ships → you get paid</strong>. The sections below unpack each step.
    </p>
    <div class="flow">
      <span class="step">Join (post a small bond)</span><span class="arr">→</span>
      <span class="step">Pledge hours / resources each month</span><span class="arr">→</span>
      <span class="step">Work mints into the pool</span><span class="arr">→</span>
      <span class="step">Project ships</span><span class="arr">→</span>
      <span class="step">Pool pays out in STR</span>
    </div>
  </section>

  <!-- ───────────────────────── STR ───────────────────────── -->
  <section id="str" class="card stack">
    <h2>1 · STR — the unit of account</h2>
    <p>
      <strong id="term-str">STR</strong> is the community's internal token — a unit for measuring and
      rewarding contribution. It isn't pre-printed in a big fixed amount; new STR is minted <em>only
      when real work is delivered and settled</em>, so the total supply tracks the value the
      community has actually produced.
    </p>
    <p>There are <strong>two states</strong> of STR, and the difference matters a lot:</p>
    <div class="two">
      <div class="mini">
        <h3 id="term-liquid">Liquid STR</h3>
        <p>The spendable balance in your wallet. You use it to post bonds and pay Guild exam fees.
          This is what the <span class="chip-ish">STR</span> chip in the top bar shows.</p>
      </div>
      <div class="mini">
        <h3 id="term-nominal">Nominal STR</h3>
        <p>Minted, but <strong>locked inside a project pool</strong> — a provisional claim, not yet
          spendable and not transferable. It only becomes liquid STR in your wallet when the project
          <a href="#term-settlement">settles</a>. Declaring work that you don't deliver simply
          converts to little or nothing at settlement.</p>
      </div>
    </div>
    <p class="muted">
      In short: <strong>nominal = a promise the pool owes you, liquid = money you hold.</strong>
      Your wallet shows liquid balance separately from nominal locked per project.
    </p>
  </section>

  <!-- ───────────────────────── contribution ───────────────────────── -->
  <section id="contribution" class="card stack">
    <h2>2 · Contribution = stake</h2>
    <p>
      A <strong id="term-contribution">contribution</strong> is anything of value you commit to a
      project. It's valued in STR and minted into the pool as your nominal stake. Flavors:
    </p>
    <table>
      <thead><tr><th>Flavor</th><th>You pledge</th><th>Valued at</th><th>Cadence</th></tr></thead>
      <tbody>
        <tr><td><strong>Labor</strong> (your time)</td><td>hours / month</td><td>hours × your skill rate</td><td>monthly</td></tr>
        <tr><td>Compute</td><td>GPU-hours / month</td><td>steward-set rate</td><td>monthly</td></tr>
        <tr><td>Funding</td><td>$</td><td>steward-set rate</td><td>once or monthly</td></tr>
        <tr><td>Data / equipment</td><td>lump</td><td>steward-set rate</td><td>once</td></tr>
      </tbody>
    </table>
    <h3 id="term-bond">The join bond</h3>
    <p>
      To join a project as a contributor you post a small <strong>20 STR bond</strong> (a leader
      posts <strong>50</strong>). The bond is real liquid STR placed in escrow — it funds the pool
      and seeds your claim. It's <em>slashable</em>: flake on the project and you can lose it. New
      members get a welcome grant of STR so the first bond is affordable.
    </p>
    <h3>Rolling monthly commitment</h3>
    <p>
      You're not locked in at join. <strong>Each month you declare what you'll put in next month</strong>
      — bump it up when you're free, down to zero when you're busy, no need to quit and rejoin.
      <strong>Declaring mints immediately</strong> into the pool (trust-based); the honesty check
      happens once, at settlement.
    </p>
    <h3 id="term-milestone">Milestones — outcome minting</h3>
    <p>
      The pool grows on two axes: <em>input</em> (your monthly hours/resources) and <em>output</em>
      (<strong>milestones</strong> — verifiable achievements like a paper submission, an acceptance,
      a release). A verified milestone both adds nominal STR to the pool and raises the settlement
      <em>multiplier</em> (capped ×3). Milestones decide how big the pie is; contributions decide
      the slices.
    </p>
  </section>

  <!-- ───────────────────────── projects ───────────────────────── -->
  <section id="projects" class="card stack">
    <h2>3 · Projects & their lifecycle</h2>
    <p>
      A <strong id="term-project">project</strong> is a research effort with a leader, a team, a
      target venue and deadline. It moves through four phases:
    </p>
    <div class="phases">
      <div class="ph"><span class="n">Proposal</span><p>Leader creates the project, posts the 50 STR
        bond, takes first authorship, sets venue/deadline, and posts <a href="#term-need">needs</a>.
        A leaderless project can be claimed by anyone who posts the bond.</p></div>
      <div class="ph"><span class="n">In progress</span><p>Contributors join (post the 20 bond) and
        declare monthly hours/resources, which mint into the pool. The leader manages the roster and
        needs; stewards approve resources so what mints is real.</p></div>
      <div class="ph"><span class="n">Under review</span><p>Commitments freeze. The leader drafts the
        <a href="#term-settlement">settlement</a> — payout weights pre-filled from each person's
        accrued mint, adjustable down for anyone who declared but didn't deliver.</p></div>
      <div class="ph"><span class="n">Finished</span><p id="term-settlement">Leader and the Stater
        manager <strong>co-sign</strong> the settlement. The pool plus a minted finish bonus is
        distributed by the agreed weights and converts to liquid STR in each member's wallet.</p></div>
    </div>
    <p class="muted">Roles: <strong>Leader</strong> (accountable, posts 50, first author),
      <strong>Contributor</strong> (any member), <strong>Resource steward</strong> (vets pledges),
      <strong>Stater manager</strong> (co-settles, keeps the economy honest).</p>
  </section>

  <!-- ───────────────────────── opportunities ───────────────────────── -->
  <section id="opportunities" class="card stack">
    <h2>4 · Finding work — Opportunities</h2>
    <p>
      The <a href="/opportunities">Opportunities</a> board is the task market. Every project posts
      <strong id="term-need">needs</strong> — typed requests for a contribution, e.g.
      <em>“Labor — 40 hrs/mo of NLP, ≥ Advanced”</em> or <em>“Compute — 200 GPU-hrs/mo.”</em>
      Filter by kind and skill, apply with a short pitch. Leaderless projects appear here too, as
      “claim leadership.”
    </p>
    <p class="muted">Accepted → you confirm by posting the join bond, then you're on the roster and
      can start declaring monthly contributions.</p>
  </section>

  <!-- ───────────────────────── guild ───────────────────────── -->
  <section id="guild" class="card stack">
    <h2>5 · The Guild — skills & certification</h2>
    <p>
      Skills are organised as a <strong>tree</strong> (domain → branch → concrete leaf skill).
      They go from <em>self-declared</em> to <strong id="term-certification">certified</strong> via a
      paid, peer-reviewed exam — this is what sets your <em>skill rate</em> (and thus how much your
      labor mints).
    </p>
    <h3 id="term-master">The guild ladder</h3>
    <div class="ladder">
      <span class="rung">Apprentice</span><span class="arr">→</span>
      <span class="rung">Journeyman</span><span class="arr">→</span>
      <span class="rung">Craftsman</span><span class="arr">→</span>
      <span class="rung crown">👑 Master</span>
    </div>
    <p>
      Each examinable leaf skill has a <strong>Master</strong> — appointed by an admin — who owns its
      rubric and seeds the reviewer pool. To certify, you <strong>sit an exam</strong>: pay the
      level fee (liquid STR) into escrow, the system randomly assigns 3 qualified reviewers
      (certified at ≥ your target level), they grade against the rubric, and <strong>2 of 3 pass →
      certified</strong>. The fee is split 80% to reviewers / 20% to treasury regardless of outcome,
      so an exam is pay-to-sit, not pay-only-if-pass.
    </p>
    <p class="muted">Lightweight peer endorsements (bronze→silver→gold) still exist as a soft
      popularity signal, but a certified medal is the hard credential and outranks them.</p>
  </section>

  <!-- ───────────────────────── reputation ───────────────────────── -->
  <section id="reputation" class="card stack">
    <h2>6 · Reputation & the leaderboard</h2>
    <p>
      Your standing isn't your bank balance. The <a href="/members">Leaderboard</a> has several
      boards: <strong>Contribution</strong> (lifetime minted work — the default),
      <strong>Net worth</strong> (liquid + nominal), <strong>Wealth</strong> (liquid only), and
      <strong>Masters</strong> (certifications and crowns).
    </p>
    <p class="muted">
      Your <strong>public member page</strong> shows reputation — certified medals, Master crowns,
      offered resources, project history and milestones — but <strong>never</strong> your liquid
      balance or ledger. Money is private; reputation is public.
    </p>
  </section>

  <!-- ───────────────────────── start ───────────────────────── -->
  <section id="start" class="card stack">
    <h2>7 · How to start</h2>
    <ol class="start">
      <li><strong>Set up your profile.</strong> List what you can bring — your monthly labor capacity
        and any resources. <a href="/profile">Open profile →</a></li>
      <li><strong>Browse opportunities.</strong> Find a project that needs your skills.
        <a href="/opportunities">Open opportunities →</a></li>
      <li><strong>Join a project.</strong> Apply to a need; once accepted, post the 20 STR bond and
        start declaring monthly hours. <a href="/projects">Browse projects →</a></li>
      <li><strong>Certify a skill.</strong> Sit a Guild exam to turn a self-declared skill into a
        certified credential and raise your labor rate. <a href="/skills">Visit the Guild →</a></li>
    </ol>
  </section>

  <!-- ───────────────────────── glossary ───────────────────────── -->
  <section id="glossary" class="card stack">
    <h2>Glossary</h2>
    <dl class="glossary">
      <dt id="term-str-g">STR</dt><dd>The community's internal token; minted from delivered work, used to measure and reward contribution. <a href="#str">More →</a></dd>
      <dt id="term-liquid-g">Liquid STR</dt><dd>Spendable balance in your wallet. Used for bonds and exam fees.</dd>
      <dt id="term-nominal-g">Nominal STR</dt><dd>Minted but locked in a project pool — a provisional claim that becomes liquid only at settlement.</dd>
      <dt id="term-stake-g">Stake</dt><dd>Your minted claim on a project pool. Your contribution <em>is</em> your stake.</dd>
      <dt id="term-bond-g">Bond</dt><dd>Real liquid STR escrowed to join a project (20 contributor / 50 leader). Funds the pool, seeds your claim, slashable if you flake.</dd>
      <dt id="term-contribution-g">Contribution</dt><dd>Anything of value committed to a project — labor, compute, funding, data — valued in STR and minted into the pool.</dd>
      <dt id="term-milestone-g">Milestone</dt><dd>A verifiable achievement (submission, acceptance, release…). Verifying it mints nominal STR and raises the settlement multiplier.</dd>
      <dt id="term-settlement-g">Settlement</dt><dd>The joint sign-off (leader + Stater manager) that splits a finished project's pool into liquid STR by agreed weights, plus a finish bonus.</dd>
      <dt id="term-need-g">Need</dt><dd>A typed request a project posts for a contribution (labor / resource), shown on the Opportunities board.</dd>
      <dt id="term-certification-g">Certification</dt><dd>A hard, peer-reviewed credential for a leaf skill, earned by a paid Guild exam. Sets your labor rate.</dd>
      <dt id="term-master-g">Master</dt><dd>The admin-appointed owner of a leaf skill's rubric and reviewer pool; the top of the guild ladder.</dd>
    </dl>
  </section>
</div>

<style>
  .guide :global(h2) { margin: 0; }
  .guide h3 { margin: .2rem 0 -.4rem; font-size: 1rem; }
  .guide p { line-height: 1.6; }
  .toc { display: flex; flex-wrap: wrap; gap: .5rem 1.1rem; padding: .85rem 1.1rem; }
  .toc a { color: var(--text-dim); font-size: .85rem; text-decoration: none; }
  .toc a:hover { color: var(--accent); }
  section { scroll-margin-top: 80px; }
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: .9rem; }
  .mini { background: var(--elevate); border: 1px solid var(--border); border-radius: 10px; padding: .8rem .9rem; }
  .mini h3 { margin: 0 0 .3rem; color: var(--accent); }
  .mini p { margin: 0; font-size: .88rem; }
  .chip-ish { font-family: var(--font-mono); font-size: .72rem; background: var(--accent-soft); color: var(--accent); padding: .05rem .35rem; border-radius: 5px; }
  .flow, .ladder { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; }
  .step, .rung { background: var(--elevate); border: 1px solid var(--border); border-radius: 999px; padding: .3rem .7rem; font-size: .8rem; }
  .rung.crown { background: var(--accent-soft); border-color: transparent; color: var(--accent); font-weight: 600; }
  .arr { color: var(--muted); }
  .phases { display: grid; grid-template-columns: 1fr 1fr; gap: .8rem; }
  .ph { background: var(--elevate); border: 1px solid var(--border); border-radius: 10px; padding: .75rem .85rem; }
  .ph .n { display: inline-block; font-weight: 700; color: var(--accent); margin-bottom: .3rem; font-size: .9rem; }
  .ph p { margin: 0; font-size: .85rem; }
  ol.start { margin: 0; padding-left: 1.2rem; display: flex; flex-direction: column; gap: .55rem; line-height: 1.55; }
  ol.start a { color: var(--accent); text-decoration: none; white-space: nowrap; }
  ol.start a:hover { text-decoration: underline; }
  .glossary { display: grid; grid-template-columns: max-content 1fr; gap: .5rem 1rem; margin: 0; }
  .glossary dt { font-weight: 700; color: var(--text); scroll-margin-top: 80px; }
  .glossary dd { margin: 0; color: var(--text-dim); font-size: .9rem; }
  .glossary a { color: var(--accent); text-decoration: none; }
  @media (max-width: 620px) {
    .two, .phases { grid-template-columns: 1fr; }
    .glossary { grid-template-columns: 1fr; gap: .15rem 0; }
    .glossary dd { margin-bottom: .5rem; }
  }
</style>
