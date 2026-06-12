<script lang="ts">
  // THE DAILY LEDGER — living style contract. Every primitive the app may use,
  // in one place, in both editions. If an element on any page doesn't match
  // this sheet, the page is wrong, not the sheet.
  const inkSwatches = [
    { v: '--bg', n: 'bg · paper' }, { v: '--bg-2', n: 'bg-2' },
    { v: '--card', n: 'card · sheet' }, { v: '--card-2', n: 'card-2' },
    { v: '--border', n: 'border · hairline' }, { v: '--border-2', n: 'border-2' },
    { v: '--text', n: 'text · ink' }, { v: '--text-dim', n: 'text-dim' }, { v: '--muted', n: 'muted' }
  ];
  const semSwatches = [
    { v: '--accent', n: 'accent · vermillion — the ONLY action color' },
    { v: '--up', n: 'up · forest — gain/success' },
    { v: '--down', n: 'down · wine — loss/danger' },
    { v: '--warn', n: 'warn · bronze — attention' },
    { v: '--info', n: 'info · slate — neutral note' },
    { v: '--gold', n: 'gold — STR ONLY (wallet · settlement · gold seal)' }
  ];
</script>

<svelte:head><title>Style contract · The Fin AI</title></svelte:head>

<div class="stack" style="max-width: 980px;">
  <header>
    <h1>The Daily Ledger</h1>
    <p class="muted">The visual contract. Warm paper · ink rules · letterpress stamps · one vermillion · gold is STR's alone.</p>
  </header>

  <!-- palette -->
  <div class="card stack">
    <h3>Palette</h3>
    <div class="sg-swatches">
      {#each inkSwatches as s}
        <div class="sg-sw"><i style={`background: var(${s.v});`}></i><span>{s.n}</span></div>
      {/each}
    </div>
    <div class="sg-swatches">
      {#each semSwatches as s}
        <div class="sg-sw"><i style={`background: var(${s.v});`}></i><span>{s.n}</span></div>
      {/each}
    </div>
  </div>

  <!-- type -->
  <div class="card stack">
    <h3>Type</h3>
    <h1 style="margin:0;">Headline — Fraunces 600</h1>
    <h2 style="margin:0;">Deck — Fraunces 600</h2>
    <p style="margin:0;">Body — Inter 400. The living record of who does what, set for long reading on paper.</p>
    <p style="margin:0;" class="muted">Caption — Inter 400 muted.</p>
    <p style="margin:0;"><span class="mono">MONO 1,234.56 / 10 h·mo</span> — JetBrains Mono, tabular, every number wears its unit.</p>
    <h3 style="margin:0;">Section heading — small caps over a rule</h3>
  </div>

  <!-- buttons & forms -->
  <div class="card stack">
    <h3>Controls</h3>
    <div class="row">
      <button>Primary — vermillion</button>
      <button class="ghost">Secondary — ruled</button>
      <button class="danger">Destructive — wine</button>
      <button disabled title="Disabled is explained: why, and what unblocks it.">Disabled (hover me)</button>
      <button><span class="spin"></span> Working…</button>
    </div>
    <div class="row">
      <input placeholder="Input — sheet white, ink on focus" style="min-width: 240px;" />
      <select><option>Select</option></select>
      <label class="search" style="min-width: 200px;"><span class="ico">⌕</span><input placeholder="Search" /></label>
    </div>
  </div>

  <!-- stamps & status -->
  <div class="card stack">
    <h3>Stamps & status</h3>
    <div class="row">
      <span class="badge">Default</span>
      <span class="badge pos">Approved</span>
      <span class="badge neg">Rejected</span>
      <span class="badge warn">Pending</span>
      <span class="badge info">Note</span>
      <span class="badge dim">Muted</span>
      <span class="badge gold">120 STR</span>
    </div>
    <div class="row">
      <span class="status st-proposal"><span class="sdot"></span>Proposal</span>
      <span class="status st-wip"><span class="sdot"></span>Active</span>
      <span class="status st-review"><span class="sdot"></span>Under review</span>
      <span class="status st-finished"><span class="sdot"></span>Finished</span>
      <span class="status st-hold"><span class="sdot"></span>Hold</span>
    </div>
    <div class="row">
      <span class="chip">slug · 12</span>
      <span class="chip toggle">filter</span>
      <span class="chip toggle on">filter · on</span>
      <span class="ava">CW</span>
      <span class="rank r1">1</span><span class="rank r2">2</span><span class="rank r3">3</span>
    </div>
  </div>

  <!-- figures -->
  <div class="card stack">
    <h3>Figures</h3>
    <div class="kpis">
      <div class="kpi"><span class="k-label">Members</span><span class="k-value">24</span><span class="k-sub">21 active</span></div>
      <div class="kpi"><span class="k-label">Projects</span><span class="k-value">7</span><span class="k-sub">3 open needs</span></div>
      <div class="kpi"><span class="k-label">Free hours</span><span class="k-value">112<span style="font-size:.7em;">/210</span></span><span class="k-sub">this month</span></div>
      <div class="kpi"><span class="k-label">STR supply</span><span class="k-value" style="color: var(--gold);">1,120</span><span class="k-sub">treasury 900</span></div>
    </div>
  </div>

  <!-- table -->
  <div class="card stack">
    <h3>The financial page (table)</h3>
    <table>
      <thead><tr><th>Task</th><th>Owner</th><th>Status</th><th class="num">Hours</th></tr></thead>
      <tbody>
        <tr><td>Collect JP filings</td><td>Wang Fang</td><td><span class="status st-wip"><span class="sdot"></span>Doing</span></td><td class="num">10/30</td></tr>
        <tr><td>Confirm EN taxonomy</td><td>Chen Wei</td><td><span class="status st-finished"><span class="sdot"></span>Done</span></td><td class="num">6/20</td></tr>
        <tr class="me-row"><td>Draft intro (you)</td><td>—</td><td><span class="status st-proposal"><span class="sdot"></span>Open</span></td><td class="num">—</td></tr>
      </tbody>
    </table>
  </div>

  <!-- order book -->
  <div class="card stack">
    <h3>The order book (matching)</h3>
    <button class="match-row qualified">
      <span class="mr-main"><span class="mr-title">Wang Fang — strong fit</span><span class="mr-sub">Annotation · Independent · 3 tasks · 1 shipped</span></span>
      <span class="mr-gap">20h free</span>
    </button>
    <button class="match-row">
      <span class="mr-main"><span class="mr-title">Li Hua</span><span class="mr-sub">Annotation · Learning</span></span>
      <span class="mr-gap">10h free</span>
    </button>
    <button class="match-row blocked">
      <span class="mr-main"><span class="mr-title">Zhao Lei</span><span class="mr-sub">below level · 3h free</span></span>
      <span class="mr-gap">⚠</span>
    </button>
  </div>

  <!-- ledger lines + market report -->
  <div class="card stack">
    <h3>The market report (STR — the only gold on the site)</h3>
    <div class="hero" style="padding: 1rem 1.2rem;">
      <span class="h-label">Settled · spendable</span>
      <div class="h-balance">460 <span class="unit">STR</span></div>
      <div class="alloc"><i class="liquid" style="width: 28%;"></i><i class="bonded" style="width: 72%;"></i></div>
      <div class="alloc-legend">
        <span class="lg"><span class="sw l"></span> settled 460</span>
        <span class="lg"><span class="sw b"></span> accruing 340</span>
      </div>
    </div>
    <div>
      <div class="txn"><span class="t-ico in">＋</span><span class="t-main"><span class="t-reason">Settlement payout — ml-Tagging</span><span class="t-meta">Jun 6 · 12:00</span></span><span class="t-amt in">+340</span></div>
      <div class="txn"><span class="t-ico out">−</span><span class="t-main"><span class="t-reason">Grant to working group</span><span class="t-meta">Jun 2 · 09:30</span></span><span class="t-amt out">−100</span></div>
    </div>
  </div>

  <!-- chronicle + seals -->
  <div class="card stack">
    <h3>Chronicle & seals</h3>
    <div class="timeline">
      <div class="tl-item"><span class="tl-dot">✓</span><span class="tl-body"><span class="tl-text">Pool of 390 STR settled and paid out</span><span class="tl-meta">Chen Wei · Jun 6</span></span></div>
      <div class="tl-item"><span class="tl-dot">✎</span><span class="tl-body"><span class="tl-text">Added a paper link</span><span class="tl-meta">Wu Jing · Jun 6</span></span></div>
    </div>
    <div class="medals" style="max-width: 480px;">
      <div class="medal tier-g"><div class="emblem"><span class="star">✦</span></div><div class="m-name">Annotation</div><div class="m-tier">Lead</div></div>
      <div class="medal tier-s"><div class="emblem"><span class="star">✦</span></div><div class="m-name">Writing</div><div class="m-tier">Independent</div></div>
      <div class="medal tier-0"><div class="emblem"><span class="star">·</span></div><div class="m-name">OCR</div><div class="m-tier">Learning</div></div>
    </div>
  </div>

  <!-- feedback -->
  <div class="card stack">
    <h3>Feedback</h3>
    <p class="banner" style="margin:0;">Attention — a warn banner carries a bronze rule.</p>
    <div class="acting-banner" style="margin:0;">An accent notice with an action. <button class="ghost">Undo</button></div>
    <div class="res-pending-note">⚠ Pending review — submitted to the steward.</div>
    <div><div class="sk sk-line" style="width: 60%;"></div><div class="sk sk-line" style="width: 40%;"></div><div class="sk sk-row" style="width: 100%;"></div></div>
    <p class="muted" style="margin:0; font-style: italic;">Nothing filed under this heading yet — <a href="/styleguide">post the first entry</a>.</p>
  </div>
</div>

<style>
  .sg-swatches { display: flex; flex-wrap: wrap; gap: .6rem 1.1rem; }
  .sg-sw { display: inline-flex; align-items: center; gap: .45rem; font-size: .76rem; color: var(--text-dim); }
  .sg-sw i { width: 22px; height: 22px; border-radius: var(--r-sm); border: 1px solid var(--border-2); display: inline-block; }
</style>
