<script lang="ts">
  import { t } from '$lib/i18n';
  // The STR paper — a standalone reference for the unit of account and its USD
  // anchor. Static; linked from the guide. Numbers mirror the live policy seeds
  // (str_per_usd 0.2, usd_per_labor_hour 50 → 10 STR/hour).
  const toc = [
    { id: 'what', label: 'What STR is' },
    { id: 'anchor', label: 'The dollar anchor' },
    { id: 'pricing', label: 'Pricing any contribution' },
    { id: 'states', label: 'Nominal vs liquid' },
    { id: 'bonds', label: 'Bonds & staking' },
    { id: 'supply', label: 'Supply & accounting' },
    { id: 'flows', label: 'Allowances, fees & sinks' },
    { id: 'multiplier', label: 'Milestones & the multiplier' },
    { id: 'governance', label: 'Governance & anti-gaming' },
    { id: 'policy', label: 'Every number is a knob' }
  ];
  // worked examples (USD → STR at str_per_usd = 0.2)
  const examples = [
    { what: 'One labour hour', basis: '$50 (reference)', str: '10 STR' },
    { what: 'Expert hour', basis: '$75', str: '15 STR' },
    { what: 'Annotation hour', basis: '$20', str: '4 STR' },
    { what: 'H100 GPU-hour', basis: '990 TFLOPs × $0.005', str: '≈ 1 STR' },
    { what: 'A100 GPU-hour', basis: '312 TFLOPs × $0.005', str: '≈ 0.31 STR' },
    { what: 'GPT-4o · 1M tokens', basis: '$7.50', str: '1.5 STR' },
    { what: 'Dataset release', basis: '$200', str: '40 STR' },
    { what: 'Funding', basis: '$1 = $1', str: '0.2 STR' }
  ];
</script>

<svelte:head><title>STR — the unit · The Fin AI</title></svelte:head>

<div class="stack paper">
  <header>
    <h1>{$t('STR — the research-time unit')}</h1>
    <p class="muted lead">{$t('STR (Stater) is the community’s internal unit of account. It is not a cryptocurrency, not for sale, and never leaves the community — it measures research contribution on one consistent scale, anchored to the US dollar.')}</p>
  </header>

  <nav class="toc">
    {#each toc as tn}<a href={`#${tn.id}`}>{$t(tn.label)}</a>{/each}
  </nav>

  <section id="what" class="card stack">
    <h2>{$t('What STR is')}</h2>
    <p>{@html $t('Every contribution — an hour of work, a GPU-hour, a dataset, a dollar of funding — is valued and <strong>minted</strong> into STR. STR is how the community keeps a fair, comparable ledger of who put in what, and how a finished project’s value is shared. It is a unit of <em>account</em> and <em>incentive</em>, not a tradable token.')}</p>
    <ul class="bul">
      <li>{@html $t('<strong>One scale.</strong> Human time, compute, data and money all price into the same unit, so they can be compared and pooled.')}</li>
      <li>{@html $t('<strong>Earned, not bought.</strong> STR is minted by verified contribution and paid out at settlement — there is no way to purchase it.')}</li>
      <li>{@html $t('<strong>Internal.</strong> It circulates only inside the community; it carries no external monetary claim.')}</li>
    </ul>
  </section>

  <section id="anchor" class="card stack">
    <h2>{$t('The dollar anchor')}</h2>
    <p>{@html $t('To keep every kind of contribution on one honest scale, STR is anchored to the US dollar by a single rate:')}</p>
    <div class="eq">
      <code>STR = round( USD_value × str_per_usd )</code>
      <span class="eq-where">str_per_usd = 0.2</span>
    </div>
    <p>{@html $t('The anchor is calibrated on human time. One <strong>standard labour hour</strong> is referenced at <strong>$50</strong>, so:')}</p>
    <div class="eq">
      <code>$50 × 0.2 = 10 STR per labour hour</code>
    </div>
    <p class="muted">{@html $t('That 10 STR/hour is the baseline writing rate. The dollar figures are an <em>alignment device</em>, not a payout — no dollars change hands. They simply let a GPU-hour, a million tokens and an expert-hour all settle onto one comparable number.')}</p>
  </section>

  <section id="pricing" class="card stack">
    <h2>{$t('Pricing any contribution')}</h2>
    <p>{@html $t('Each resource <em>type</em> declares how a monthly quantity becomes USD; then the anchor turns USD into STR. Four valuation methods cover everything:')}</p>
    <ul class="bul">
      <li>{@html $t('<strong>flat</strong> — quantity × the type’s USD-per-unit (e.g. an expert-hour at $75).')}</li>
      <li>{@html $t('<strong>gpu</strong> — pick a GPU model; USD = TFLOPs × GPU-hours × usd_per_tflop_hour ($0.005).')}</li>
      <li>{@html $t('<strong>api</strong> — pick an API model; USD = its $/1M-tokens × millions of tokens.')}</li>
      <li>{@html $t('<strong>usd</strong> — the quantity is already dollars (funding).')}</li>
    </ul>
    <div class="card2">
      <table class="ex">
        <thead><tr><th>{$t('Contribution')}</th><th>{$t('USD basis')}</th><th class="num">{$t('Mints')}</th></tr></thead>
        <tbody>
          {#each examples as e}<tr><td>{$t(e.what)}</td><td class="dim">{e.basis}</td><td class="num mono">{e.str}</td></tr>{/each}
        </tbody>
      </table>
    </div>
    <p class="muted">{$t('GPU TFLOPs and API token prices come from built-in catalogues admins can edit; the per-hour and per-unit USD values live on each resource type.')}</p>
  </section>

  <section id="states" class="card stack">
    <h2>{$t('Nominal vs liquid')}</h2>
    <p>{@html $t('Minted STR exists in two states, and the difference is the whole incentive:')}</p>
    <div class="states">
      <div class="st st-nom">
        <span class="st-h">{$t('Nominal STR')}</span>
        <p>{@html $t('Minted by monthly work and by verified milestones, locked in a <strong>project pool</strong>. It is your accruing claim — but you cannot spend it. If the project never ships, the pool stays nominal forever.')}</p>
      </div>
      <div class="st st-liq">
        <span class="st-h">{$t('Liquid STR')}</span>
        <p>{@html $t('Spendable STR in your wallet. The only way nominal becomes liquid is <strong>settlement</strong>: when a project is Finished, its pool converts and pays out by contribution.')}</p>
      </div>
    </div>
    <p class="muted">{$t('So your monthly contribution accrues nominal STR; cashing it out is bet on the project actually shipping. That bond between earning and outcome is the point.')}</p>
  </section>

  <section id="bonds" class="card stack">
    <h2>{$t('Bonds & staking')}</h2>
    <p>{@html $t('Leading a project isn’t free. To take a leader seat you post a <strong>bond</strong> — <strong>50 STR</strong> by default — from your own liquid balance into the project’s escrow. Unlike nominal STR (minted, locked), a bond is <em>real</em> STR you already hold, parked in escrow as skin in the game.')}</p>
    <p>{@html $t('At settlement the bond is already real, so the system mints only the work-backed difference (<code>pool × multiplier − bonds already escrowed</code>) and returns your bond on top of your payout. Stake nothing, lead nothing — the bond is how leadership commits value to the project it steers.')}</p>
  </section>

  <section id="supply" class="card stack">
    <h2>{$t('Supply & accounting')}</h2>
    <p>{@html $t('Every STR is an append-only ledger entry, so the books always balance. Total supply lives in three kinds of account:')}</p>
    <div class="flow">
      <span class="step">{$t('Circulating (member wallets)')}</span><span class="plus">+</span>
      <span class="step">{$t('Escrow (project pools)')}</span><span class="plus">+</span>
      <span class="step">{$t('Treasury')}</span><span class="eqls">=</span>
      <span class="step total">{$t('Total supply')}</span>
    </div>
    <p>{@html $t('Supply is created by <strong>minting</strong> (work, milestones, allowances, grants) and destroyed by <strong>sinking</strong> (fees). By construction, <code>total supply = minted − sunk</code> — the dashboard flags any drift. The <strong>treasury</strong> is the community account that funds monthly allowances and grants.')}</p>
  </section>

  <section id="flows" class="card stack">
    <h2>{$t('Allowances, fees & sinks')}</h2>
    <p>{@html $t('The treasury seeds enough liquid STR to get the economy moving, and recycles it:')}</p>
    <ul class="bul">
      <li>{@html $t('<strong>Monthly allowance</strong> — every member active in the last 30 days can draw <strong>20 STR</strong> from the treasury, so newcomers have a little liquid to post a leader bond.')}</li>
      <li>{@html $t('<strong>Grants</strong> — admins can grant STR from the treasury for one-off needs, logged with a reason.')}</li>
      <li>{@html $t('<strong>Fees (the sink)</strong> — forging a new badge costs <strong>10 STR</strong>, upgrading one costs <strong>5</strong>; fees flow back to the treasury. Sinks are what stop pure minting from inflating the unit — they remove STR from circulation.')}</li>
    </ul>
  </section>

  <section id="multiplier" class="card stack">
    <h2>{$t('Milestones & the multiplier')}</h2>
    <p>{@html $t('A project’s pool grows on two axes. <strong>Work</strong> (input) mints nominal monthly. <strong>Milestones</strong> (output) are verified achievements that do two things at once:')}</p>
    <ol class="acts">
      <li>{@html $t('add their catalogue value to the nominal pool (e.g. accepted = 100, top venue = 200), and')}</li>
      <li>{@html $t('bump the <strong>settlement multiplier</strong> by a per-milestone amount — capped at <strong>×3</strong>.')}</li>
    </ol>
    <div class="eq">
      <code>payout = your_share × pool × multiplier</code>
      <span class="eq-where">multiplier = min( 1 + Σ milestone bonuses , 3 )</span>
    </div>
    <p class="muted">{$t('Milestones make the pie bigger and raise the conversion rate; monthly work decides the slices. A project with no milestones converts at ×1 — face value only.')}</p>
  </section>

  <section id="governance" class="card stack">
    <h2>{$t('Governance & anti-gaming')}</h2>
    <p>{@html $t('The model has guardrails against inflating contribution:')}</p>
    <ul class="bul">
      <li>{@html $t('<strong>Outcomes are verified, not trusted.</strong> Monthly hours are trust-based, but a milestone only mints once a reviewer marks it <em>verified</em> — and over-capacity commitments go to review too.')}</li>
      <li>{@html $t('<strong>The multiplier is capped at ×3.</strong> No amount of milestones can run the conversion rate away.')}</li>
      <li>{@html $t('<strong>Reversible.</strong> A reviewer can reject or revoke a milestone, and pause or reduce minting on abuse. Every mint, sink and payout is an immutable ledger line.')}</li>
    </ul>
  </section>

  <section id="policy" class="card stack">
    <h2>{$t('Every number is a knob')}</h2>
    <p>{@html $t('Nothing here is hard-coded. The anchor (str_per_usd), the labour-hour reference, the compute price, the multiplier cap, the monthly allowance, the milestone catalogue — all are policy values an admin tunes from the economy console, and changes are logged. The model is fixed; the parameters are governed.')}</p>
  </section>

  <p class="muted foot">{@html $t('New here? Start with the <a href="/guide">officer guide</a>, or open the <a href="/admin/economy">economy console</a> to see the live supply.')}</p>
</div>

<style>
  .paper { max-width: 820px; gap: 1rem; }
  .lead { margin-top: -.4rem; font-size: .95rem; line-height: 1.6; }
  .toc { display: flex; flex-wrap: wrap; gap: .4rem .9rem; padding: .7rem .9rem; border: 1px solid var(--border); border-radius: 12px; background: var(--card); }
  .toc a { font-size: .85rem; color: var(--muted); text-decoration: none; }
  .toc a:hover { color: var(--accent); }
  section.card { padding: 1.1rem 1.2rem; }
  section h2 { margin: 0 0 .2rem; }
  section p, section li { line-height: 1.65; }
  .bul, .acts { margin: 0; padding-left: 1.1rem; display: flex; flex-direction: column; gap: .5rem; }
  .eq { display: flex; flex-wrap: wrap; align-items: baseline; gap: .5rem .9rem; padding: .7rem .9rem; border: 1px solid var(--border-2); border-radius: 10px; background: var(--card-2); }
  .eq code { font-size: 1rem; color: var(--accent); }
  .eq-where { font-size: .8rem; color: var(--muted); }
  .card2 { border: 1px solid var(--border); border-radius: 10px; background: var(--card); overflow-x: auto; }
  table.ex { width: 100%; border-collapse: collapse; font-size: .88rem; }
  table.ex th { text-align: left; font-size: .72rem; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); padding: .55rem .8rem; border-bottom: 1px solid var(--border); }
  table.ex td { padding: .5rem .8rem; border-bottom: 1px solid var(--border); }
  table.ex tr:last-child td { border-bottom: 0; }
  .num { text-align: right; }
  .mono { font-variant-numeric: tabular-nums; color: var(--accent); font-weight: 600; }
  .dim { color: var(--muted); }
  .states { display: grid; grid-template-columns: 1fr 1fr; gap: .7rem; }
  @media (max-width: 560px) { .states { grid-template-columns: 1fr; } }
  .st { border: 1px solid var(--border); border-radius: 11px; padding: .8rem .9rem; background: var(--card-2); }
  .st-nom { border-left: 3px solid var(--info, var(--accent)); }
  .st-liq { border-left: 3px solid var(--up, var(--accent)); }
  .st-h { font-size: .72rem; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
  .st p { margin: .3rem 0 0; font-size: .88rem; }
  .flow { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; }
  .step { font-size: .8rem; padding: .3rem .6rem; border: 1px solid var(--border); border-radius: 999px; background: var(--card-2); }
  .step.total { border-color: var(--accent); color: var(--accent); font-weight: 600; }
  .plus, .eqls { color: var(--muted); font-weight: 600; }
  .foot { font-size: .9rem; }
</style>
