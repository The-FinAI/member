<script lang="ts">
  import { t } from '$lib/i18n';
  // Static "How it works" explainer for the whole Stater economy. No data calls —
  // it's the always-available reference manual, linked from the nav, empty states,
  // and inline Hint dots (which deep-link to the #term-* glossary anchors below).
  const toc = [
    { id: 'mental-model', label: 'The big picture' },
    { id: 'rollout', label: 'Rollout — where we are now' },
    { id: 'phase1', label: 'Phase 1 playbook — what to do now' },
    { id: 'using', label: 'Using the site — every page' },
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
    <h1 style="margin-bottom:.2rem;">{$t('How The Fin AI works')}</h1>
    <p class="muted" style="margin-top:0;">
      {$t('A research community that runs like an economy: you put work in, it mints into a shared pool, and when a project ships the pool pays out. This page explains the whole model — keep it as a reference.')}
    </p>
  </div>

  <!-- ───────────────────────── Phase 1 launch callout ───────────────────────── -->
  <div class="launch card">
    <span class="lbadge">{$t('Phase 1 · live now')}</span>
    <h2 style="margin:.1rem 0 0;">{$t('Officers — forge your cards & claim your projects')}</h2>
    <p style="margin:.2rem 0 0;">
      {@html $t("We're switching this economy on in stages. <strong>Phase 1 is officers only — ordinary researchers aren't invited yet.</strong> Your job is to forge a card for each person who works under you (their skills, resources and monthly hours) and to claim the projects your chapter already runs. This builds an honest skill graph and seeds the rosters <em>before</em> the member economy opens in Phase 2.")}
    </p>
    <div class="row" style="gap:.6rem; flex-wrap:wrap; margin-top:.3rem;">
      <a class="lbtn" href="/my-chapter">{$t('Go to My Chapter →')}</a>
      <a class="llink" href="#rollout">{$t('See the full rollout →')}</a>
    </div>
  </div>

  <nav class="card toc">
    {#each toc as tn}<a href={`#${tn.id}`}>{$t(tn.label)}</a>{/each}
  </nav>

  <!-- ───────────────────────── big picture ───────────────────────── -->
  <section id="mental-model" class="card stack">
    <h2>{$t('The big picture')}</h2>
    <p>
      {@html $t("Everything here revolves around one idea: <strong>contribution is stake</strong>. When you pledge time or resources to a research project, that pledge is valued and <em>minted</em> into the project's shared pool as your claim on it. Ship the project, and the pool — your minted claims plus a finish bonus — is split among the people who built it and converts into real, spendable <strong>STR</strong>.")}
    </p>
    <p class="muted">
      {@html $t('So the loop is: <strong>join a project → pledge work monthly → it mints your share → the project ships → you get paid</strong>. The sections below unpack each step.')}
    </p>
    <div class="flow">
      <span class="step">{$t('Join (post a small bond)')}</span><span class="arr">→</span>
      <span class="step">{$t('Pledge hours / resources each month')}</span><span class="arr">→</span>
      <span class="step">{$t('Work mints into the pool')}</span><span class="arr">→</span>
      <span class="step">{$t('Project ships')}</span><span class="arr">→</span>
      <span class="step">{$t('Pool pays out in STR')}</span>
    </div>
  </section>

  <!-- ───────────────────────── rollout ───────────────────────── -->
  <section id="rollout" class="card stack">
    <h2>{$t('Rollout — where we are now')}</h2>
    <p>
      {@html $t("Everything on this page is the <em>full</em> picture. We're turning it on in three phases so the community can find its feet before real STR starts moving. Here's the map — and exactly what to do today.")}
    </p>
    <div class="roadmap">
      <div class="pcard now">
        <span class="pn">{$t('Phase 1 · now')}</span>
        <h3>{$t('Officer bootstrap')}</h3>
        <p>{@html $t("<strong>Officers only — no ordinary researchers yet.</strong> Each officer forges a card for every person under them (skills, resources, monthly hours) and claims the projects their chapter already runs, seating cards onto the rosters. This builds the skill graph and sets each member's labor rate before the economy opens.")}</p>
        <a class="pgo" href="/my-chapter">{$t('Go to My Chapter →')}</a>
      </div>
      <div class="pcard">
        <span class="pn">{$t('Phase 2 · next')}</span>
        <h3>{$t('Project economy')}</h3>
        <p>{$t('Projects open: leaders post bonds, contributors join and declare monthly work, milestones and settlements mint and pay out STR. The full loop described below goes live.')}</p>
      </div>
      <div class="pcard">
        <span class="pn">{$t('Phase 3 · later')}</span>
        <h3>{$t('Markets')}</h3>
        <p>{@html $t("A <strong>prediction market</strong> launches, and we explore a two-way <strong>STR ⇄ USD</strong> anchor so STR can flow back out into dollars — not just in.")}</p>
      </div>
    </div>
    <div class="note">
      <h3 style="margin-top:0;">{$t('What to do in Phase 1')}</h3>
      <ol class="start" style="margin:.2rem 0 0;">
        <li>{@html $t("<strong>Forge a card</strong> for each person who works under you from <a href='/my-chapter'>My Chapter</a> — their skills, resources and monthly hours in one batch. Each person is forged only once.")}</li>
        <li>{@html $t("<strong>Claim your existing projects</strong> from <a href='/projects'>Projects</a> and seat your cards onto each roster.")}</li>
        <li>{@html $t("<strong>Clear your <a href='/admin/approvals'>Approvals</a></strong> — the single queue for everything waiting on you.")}</li>
        <li>{@html $t("Watch your Chapter / Working Group climb the <a href='/members'>Leaderboard</a> as cards are forged.")}</li>
      </ol>
    </div>
  </section>

  <!-- ───────────────────────── phase 1 playbook ───────────────────────── -->
  <section id="phase1" class="card stack">
    <h2>{$t('Phase 1 playbook — exactly what to do now')}</h2>
    <p>
      {@html $t("<strong>Phase 1 is officers only.</strong> Ordinary researchers aren't invited yet — right now the only people in the system are chapter chairs, secretaries and working-group leaders. Your job is to bring in the people who already work under you as <strong>cards</strong> and to claim the projects your chapter already runs, so that when the economy opens in Phase 2 the skill graph and rosters are already real.")}
    </p>
    <div class="tracks">
      <div class="track">
        <span class="tlabel">{$t('Officers — now')}</span>
        <p class="tlead">{$t('Chapter chairs & secretaries, working-group leaders.')}</p>
        <ol class="start">
          <li>{@html $t("Open <a href='/my-chapter'>My Chapter</a> and <strong>forge a card</strong> for each person who works under you — their identity, the skills they bring, the resources they offer (compute, API, funding, data) and their monthly hours, all in one batch. <strong>Each person is forged only once.</strong>")}</li>
          <li>{@html $t("<strong>Claim your existing projects.</strong> Open the <a href='/projects'>Projects</a> your chapter or group already runs and use <strong>“Add a member directly”</strong> to seat your cards onto each roster — no application, no bond.")}</li>
          <li>{@html $t("Act as a card to <strong>declare its monthly contributions</strong> on the projects it joins. Value accrues to the card and stays custodial until the real person signs up and claims it.")}</li>
          <li>{@html $t("Clear your <a href='/admin/approvals'>Approvals</a> queue — it's the single place where everything waiting on you lands: role-card requests, chapter & working-group applications, member resources, project milestones, and any over-capacity monthly commitments. Approve or reject each in place.")}</li>
        </ol>
      </div>
      <div class="track">
        <span class="tlabel">{$t('Members — Phase 2')}</span>
        <p class="tlead">{$t('Researchers, once they are invited.')}</p>
        <ol class="start">
          <li>{@html $t("Sign in with your invite and <strong>claim your card</strong> — the identity, skills and resources your officer forged for you become yours.")}</li>
          <li>{@html $t("Fill in or adjust <strong>What I can bring</strong> on your <a href='/'>Home / Portfolio</a>, and request any role cards your officer hasn't already staged.")}</li>
          <li>{@html $t("Join projects, apply to open needs, and the contributions custodied on your card convert into your own balance.")}</li>
        </ol>
      </div>
    </div>
    <div class="note">
      <p style="margin:0;">{@html $t("<strong>Forging cards is free in Phase 1</strong> — no card fees, no payouts yet. Project bonds stay live, so claiming and leading projects still posts the usual stake. This phase is about building an honest skill graph and seeding the rosters; the full member economy below switches on in Phase 2.")}</p>
    </div>
  </section>

  <!-- ───────────────────────── using the site ───────────────────────── -->
  <section id="using" class="card stack">
    <h2>{$t('Using the site — every page, what it’s for')}</h2>
    <p>{$t('The left sidebar is your map. Here is what each destination does.')}</p>
    <table>
      <thead><tr><th>{$t('Page')}</th><th>{$t('What it’s for')}</th></tr></thead>
      <tbody>
        <tr><td><a href="/">{$t('Home')}</a></td><td>{$t('Your portfolio: positions, applications, certifications, recent STR activity, and the “What I can bring” editor for your monthly hours & resources.')}</td></tr>
        <tr><td><a href="/projects">{$t('Projects')}</a></td><td>{$t('Every research project as a market board. Open one to see its roster, open needs, records, meetings, history and settlement.')}</td></tr>
        <tr><td><a href="/opportunities">{$t('Opportunities')}</a></td><td>{$t('The task market — every open need across all projects, typed by labor or resource and filterable by skill. Apply here.')}</td></tr>
        <tr><td><a href="/members">{$t('People')}</a></td><td>{$t('The leaderboard plus everyone’s public profile — their certified role-card medals, resources and project history.')}</td></tr>
        <tr><td><a href="/skills">{$t('Guild')}</a></td><td>{$t('The skill tree. Request or claim role cards, see your medals, and track the cards awaiting review.')}</td></tr>
        <tr><td><a href="/units">{$t('Units')}</a></td><td>{$t('The 3 Chapters and 3 Working Groups — their officers, rosters and attached projects.')}</td></tr>
        <tr><td><a href="/wallet">{$t('Wallet')}</a></td><td>{$t('Your STR balance — liquid vs. nominal — and your full transaction history.')}</td></tr>
        <tr><td>{$t('My Chapter')}</td><td>{$t('Officers only. Mint role cards onto your members and manage your chapter’s cards.')}</td></tr>
        <tr><td>{$t('Approvals')}</td><td>{$t('Officers & reviewers. One queue for every pending decision — role-card requests, chapter & working-group applications, member resources, project milestones, and over-capacity monthly commitments. Approve or reject each in place.')}</td></tr>
        <tr><td>{$t('Admin')}</td><td>{$t('Admins only. Every configurable knob: announcements, invites, positions, capabilities, venues, the skill tree, resources and the STR economy.')}</td></tr>
      </tbody>
    </table>
  </section>

  <!-- ───────────────────────── STR ───────────────────────── -->
  <section id="str" class="card stack">
    <h2>{$t('1 · STR — the unit of account')}</h2>
    <p>
      {@html $t("<strong id='term-str'>STR</strong> is the community's internal token — a unit for measuring and rewarding contribution. It isn't pre-printed in a big fixed amount; new STR is minted <em>only when real work is delivered and settled</em>, so the total supply tracks the value the community has actually produced.")}
    </p>
    <p>{@html $t('There are <strong>two states</strong> of STR, and the difference matters a lot:')}</p>
    <div class="two">
      <div class="mini">
        <h3 id="term-liquid">{$t('Liquid STR')}</h3>
        <p>{@html $t("The spendable balance in your wallet. You use it to post bonds and pay role-card fees. This is what the <span class='chip-ish'>STR</span> chip in the top bar shows.")}</p>
      </div>
      <div class="mini">
        <h3 id="term-nominal">{$t('Nominal STR')}</h3>
        <p>{@html $t("Minted, but <strong>locked inside a project pool</strong> — a provisional claim, not yet spendable and not transferable. It only becomes liquid STR in your wallet when the project <a href='#term-settlement'>settles</a>. Declaring work that you don't deliver simply converts to little or nothing at settlement.")}</p>
      </div>
    </div>
    <p class="muted">
      {@html $t('In short: <strong>nominal = a promise the pool owes you, liquid = money you hold.</strong> Your wallet shows liquid balance separately from nominal locked per project.')}
    </p>
    <div class="note">
      <h3 id="term-anchor" style="margin-top:0;">{$t('How value becomes STR — the USD anchor')}</h3>
      <p style="margin-bottom:.4rem;">
        {@html $t("Every contribution is first priced in <strong>US dollars</strong> at its real-world value — a GPU-hour by its TFLOPs, API tokens by their per-token price, an hour of work by a reference postdoc wage — then minted into STR at a single fixed <strong>anchor</strong> (calibrated so one labour-hour ≈ 10 STR). One scale, so compute, funding and human time all price consistently.")}
      </p>
      <p class="muted" style="margin-bottom:0;">
        {@html $t("The anchor is <strong>one-directional today</strong>: real-world value flows <em>into</em> STR, but STR can't yet be redeemed back out into dollars. It may become <strong>two-way (STR ⇄ USD)</strong> in the future; for now treat STR as the community's internal accounting and reward unit, not a cash-out claim.")}
      </p>
    </div>
  </section>

  <!-- ───────────────────────── contribution ───────────────────────── -->
  <section id="contribution" class="card stack">
    <h2>{$t('2 · Contribution = stake')}</h2>
    <p>
      {@html $t("A <strong id='term-contribution'>contribution</strong> is anything of value you commit to a project. It's valued in STR and minted into the pool as your nominal stake. Flavors:")}
    </p>
    <table>
      <thead><tr><th>{$t('Flavor')}</th><th>{$t('You pledge')}</th><th>{$t('Valued at')}</th><th>{$t('Cadence')}</th></tr></thead>
      <tbody>
        <tr><td>{@html $t('<strong>Labor</strong> (your time)')}</td><td>{$t('hours / month')}</td><td>{$t('hours × your skill rate')}</td><td>{$t('monthly')}</td></tr>
        <tr><td>{$t('Compute')}</td><td>{$t('GPU-hours / month')}</td><td>{$t('steward-set rate')}</td><td>{$t('monthly')}</td></tr>
        <tr><td>{$t('Funding')}</td><td>{$t('$')}</td><td>{$t('steward-set rate')}</td><td>{$t('once or monthly')}</td></tr>
        <tr><td>{$t('Data / equipment')}</td><td>{$t('lump')}</td><td>{$t('steward-set rate')}</td><td>{$t('once')}</td></tr>
      </tbody>
    </table>
    <h3 id="term-bond">{$t('The join bond')}</h3>
    <p>
      {@html $t("To join a project as a contributor you post a small <strong>20 STR bond</strong> (a leader posts <strong>50</strong>). The bond is real liquid STR placed in escrow — it funds the pool and seeds your claim. It's <em>slashable</em>: flake on the project and you can lose it. New members get a welcome grant of STR so the first bond is affordable.")}
    </p>
    <h3>{$t('Rolling monthly commitment')}</h3>
    <p>
      {@html $t("You're not locked in at join. <strong>Each month you declare what you'll put in next month</strong> — bump it up when you're free, down to zero when you're busy, no need to quit and rejoin. <strong>Declaring mints immediately</strong> into the pool (trust-based); the honesty check happens once, at settlement.")}
    </p>
    <h3 id="term-milestone">{$t('Milestones — outcome minting')}</h3>
    <p>
      {@html $t('The pool grows on two axes: <em>input</em> (your monthly hours/resources) and <em>output</em> (<strong>milestones</strong> — verifiable achievements like a paper submission, an acceptance, a release). A verified milestone both adds nominal STR to the pool and raises the settlement <em>multiplier</em> (capped ×3). Milestones decide how big the pie is; contributions decide the slices.')}
    </p>
  </section>

  <!-- ───────────────────────── projects ───────────────────────── -->
  <section id="projects" class="card stack">
    <h2>{$t('3 · Projects & their lifecycle')}</h2>
    <p>
      {@html $t("A <strong id='term-project'>project</strong> is a research effort with a leader, a team, a target venue and deadline. It moves through four phases:")}
    </p>
    <div class="phases">
      <div class="ph"><span class="n">{$t('Proposal')}</span><p>{@html $t("Leader creates the project, posts the 50 STR bond, takes first authorship, sets venue/deadline, and posts <a href='#term-need'>needs</a>. A leaderless project can be claimed by anyone who posts the bond.")}</p></div>
      <div class="ph"><span class="n">{$t('In progress')}</span><p>{$t('Contributors join (post the 20 bond) and declare monthly hours/resources, which mint into the pool. The leader manages the roster and needs; stewards approve resources so what mints is real.')}</p></div>
      <div class="ph"><span class="n">{$t('Under review')}</span><p>{@html $t("Commitments freeze. The leader drafts the <a href='#term-settlement'>settlement</a> — payout weights pre-filled from each person's accrued mint, adjustable down for anyone who declared but didn't deliver.")}</p></div>
      <div class="ph"><span class="n">{$t('Finished')}</span><p id="term-settlement">{@html $t("Leader and the Stater manager <strong>co-sign</strong> the settlement. The pool plus a minted finish bonus is distributed by the agreed weights and converts to liquid STR in each member's wallet.")}</p></div>
    </div>
    <p class="muted">{@html $t('Roles: <strong>Leader</strong> (accountable, posts 50, first author), <strong>Contributor</strong> (any member), <strong>Resource steward</strong> (vets pledges), <strong>Stater manager</strong> (co-settles, keeps the economy honest).')}</p>
  </section>

  <!-- ───────────────────────── opportunities ───────────────────────── -->
  <section id="opportunities" class="card stack">
    <h2>{$t('4 · Finding work — Opportunities')}</h2>
    <p>
      {@html $t("The <a href='/opportunities'>Opportunities</a> board is the task market. Every project posts <strong id='term-need'>needs</strong> — typed requests for a contribution, e.g. <em>“Labor — 40 hrs/mo of NLP, ≥ Advanced”</em> or <em>“Compute — 200 GPU-hrs/mo.”</em> Filter by kind and skill, apply with a short pitch. Leaderless projects appear here too, as “claim leadership.”")}
    </p>
    <p class="muted">{$t("Accepted → you confirm by posting the join bond, then you're on the roster and can start declaring monthly contributions.")}</p>
  </section>

  <!-- ───────────────────────── guild ───────────────────────── -->
  <section id="guild" class="card stack">
    <h2>{$t('5 · The Guild — skills & certification')}</h2>
    <p>
      {@html $t("Skills are organised as a <strong>tree</strong> (domain → branch → concrete leaf skill). A certified skill is a <strong id='term-certification'>role card</strong> — this is what sets your <em>skill rate</em> (and thus how much your labor mints).")}
    </p>
    <h3 id="term-master">{$t('The guild ladder')}</h3>
    <div class="ladder">
      <span class="rung">{$t('Apprentice')}</span><span class="arr">→</span>
      <span class="rung">{$t('Journeyman')}</span><span class="arr">→</span>
      <span class="rung">{$t('Craftsman')}</span><span class="arr">→</span>
      <span class="rung crown">{$t('Master')}</span>
    </div>
    <p>
      {@html $t('A certified skill is a <strong>role card</strong>. There are two ways one is forged. A chapter officer can <strong>mint</strong> cards onto a member (genesis, first cards, bootstrap) — free, but staged as a batch awaiting review. Or you <strong>request</strong> a card yourself, paying the mint or update fee (escrowed, refunded if rejected). Either way a reviewer with the review capability approves or rejects it. There is no exam and no per-skill master.')}
    </p>
  </section>

  <!-- ───────────────────────── reputation ───────────────────────── -->
  <section id="reputation" class="card stack">
    <h2>{$t('6 · Reputation & the leaderboard')}</h2>
    <p>
      {@html $t("Your standing isn't your bank balance. The <a href='/members'>Leaderboard</a> has several boards: <strong>Contribution</strong> (lifetime minted work — the default), <strong>Net worth</strong> (liquid + nominal), and <strong>Wealth</strong> (liquid only).")}
    </p>
    <p class="muted">
      {@html $t('Your <strong>public member page</strong> shows reputation — certified role-card medals, offered resources, project history and milestones — but <strong>never</strong> your liquid balance or ledger. Money is private; reputation is public.')}
    </p>
  </section>

  <!-- ───────────────────────── start ───────────────────────── -->
  <section id="start" class="card stack">
    <h2>{$t('7 · How to start')}</h2>
    <ol class="start">
      <li>{@html $t("<strong>Set up your profile.</strong> List what you can bring — your monthly labor capacity and any resources. <a href='/'>Open your portfolio →</a>")}</li>
      <li>{@html $t("<strong>Browse opportunities.</strong> Find a project that needs your skills. <a href='/opportunities'>Open opportunities →</a>")}</li>
      <li>{@html $t("<strong>Join a project.</strong> Apply to a need; once accepted, post the 20 STR bond and start declaring monthly hours. <a href='/projects'>Browse projects →</a>")}</li>
      <li>{@html $t("<strong>Certify a skill.</strong> Request a role card to turn a skill into a certified credential and raise your labor rate. <a href='/skills'>Visit the Guild →</a>")}</li>
    </ol>
  </section>

  <!-- ───────────────────────── glossary ───────────────────────── -->
  <section id="glossary" class="card stack">
    <h2>{$t('Glossary')}</h2>
    <dl class="glossary">
      <dt id="term-str-g">{$t('STR')}</dt><dd>{@html $t("The community's internal token; minted from delivered work, used to measure and reward contribution. <a href='#str'>More →</a>")}</dd>
      <dt id="term-liquid-g">{$t('Liquid STR')}</dt><dd>{$t('Spendable balance in your wallet. Used for bonds and role-card fees.')}</dd>
      <dt id="term-nominal-g">{$t('Nominal STR')}</dt><dd>{$t('Minted but locked in a project pool — a provisional claim that becomes liquid only at settlement.')}</dd>
      <dt id="term-stake-g">{$t('Stake')}</dt><dd>{@html $t('Your minted claim on a project pool. Your contribution <em>is</em> your stake.')}</dd>
      <dt id="term-bond-g">{$t('Bond')}</dt><dd>{$t('Real liquid STR escrowed to join a project (20 contributor / 50 leader). Funds the pool, seeds your claim, slashable if you flake.')}</dd>
      <dt id="term-contribution-g">{$t('Contribution')}</dt><dd>{$t('Anything of value committed to a project — labor, compute, funding, data — valued in STR and minted into the pool.')}</dd>
      <dt id="term-milestone-g">{$t('Milestone')}</dt><dd>{$t('A verifiable achievement (submission, acceptance, release…). Verifying it mints nominal STR and raises the settlement multiplier.')}</dd>
      <dt id="term-settlement-g">{$t('Settlement')}</dt><dd>{$t('The joint sign-off (leader + Stater manager) that splits a finished project\'s pool into liquid STR by agreed weights, plus a finish bonus.')}</dd>
      <dt id="term-need-g">{$t('Need')}</dt><dd>{$t('A typed request a project posts for a contribution (labor / resource), shown on the Opportunities board.')}</dd>
      <dt id="term-certification-g">{$t('Certification')}</dt><dd>{$t('A hard, reviewed credential for a leaf skill — a role card minted or requested, then approved by a reviewer. Sets your labor rate.')}</dd>
      <dt id="term-master-g">{$t('Master')}</dt><dd>{$t('The top rung of the guild ladder (Apprentice → Journeyman → Craftsman → Master).')}</dd>
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
  .note { border: 1px solid var(--accent-soft); border-left: 3px solid var(--accent); background: var(--accent-soft); border-radius: 10px; padding: .85rem 1rem; }
  .note h3 { color: var(--accent); font-size: .95rem; }
  .note p { font-size: .88rem; }
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
  /* Phase-1 launch callout */
  .launch { border: 1px solid var(--accent); border-left: 3px solid var(--accent);
    background: var(--accent-soft); display: flex; flex-direction: column; gap: .15rem; }
  .launch p { line-height: 1.55; font-size: .92rem; }
  .lbadge { align-self: flex-start; font-family: var(--font-mono); font-size: .72rem; font-weight: 700;
    letter-spacing: .03em; text-transform: uppercase; color: var(--accent);
    background: color-mix(in srgb, var(--accent) 14%, transparent); padding: .15rem .5rem; border-radius: 6px; }
  .lbtn { display: inline-block; background: var(--accent); color: #fff; font-weight: 600; font-size: .85rem;
    padding: .4rem .85rem; border-radius: 8px; text-decoration: none; }
  .lbtn:hover { filter: brightness(1.08); }
  .llink { align-self: center; color: var(--accent); font-size: .85rem; text-decoration: none; }
  .llink:hover { text-decoration: underline; }
  /* phase 1 playbook tracks */
  .tracks { display: grid; grid-template-columns: 1fr 1fr; gap: .9rem; }
  .track { background: var(--elevate); border: 1px solid var(--border); border-radius: 10px; padding: .85rem .95rem; }
  .track .tlabel { display: inline-block; font-family: var(--font-mono); font-size: .72rem; font-weight: 700;
    text-transform: uppercase; letter-spacing: .04em; color: var(--accent);
    background: var(--accent-soft); padding: .15rem .5rem; border-radius: 6px; }
  .track .tlead { margin: .4rem 0 .6rem; font-size: .82rem; color: var(--muted); }
  .track ol.start { gap: .45rem; }
  .track ol.start a { white-space: normal; }
  /* rollout roadmap */
  .roadmap { display: grid; grid-template-columns: repeat(3, 1fr); gap: .8rem; }
  .pcard { background: var(--elevate); border: 1px solid var(--border); border-radius: 10px; padding: .8rem .9rem; display: flex; flex-direction: column; gap: .25rem; }
  .pcard.now { border-color: var(--accent); background: var(--accent-soft); }
  .pcard h3 { margin: .1rem 0 0; font-size: .98rem; }
  .pcard p { margin: 0; font-size: .84rem; }
  .pn { font-family: var(--font-mono); font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
  .pcard.now .pn { color: var(--accent); }
  .pgo { margin-top: auto; color: var(--accent); font-size: .82rem; text-decoration: none; font-weight: 600; }
  .pgo:hover { text-decoration: underline; }
  @media (max-width: 620px) {
    .two, .phases, .roadmap, .tracks { grid-template-columns: 1fr; }
    .glossary { grid-template-columns: 1fr; gap: .15rem 0; }
    .glossary dd { margin-bottom: .5rem; }
  }
</style>
