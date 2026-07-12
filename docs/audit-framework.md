# Issue Decomposition Audit Framework

> **Status: v1.0, 2026-06-19 — issue #50.** How agents *proactively* find
> platform problems, report them for human review, and only then remediate.
> This framework is not aspirational: every instrument below has already been
> executed at least once, and its past findings are cited as evidence.
>
> Baseline for all audits: [`architecture.md`](architecture.md) (#49). An audit
> compares **observed behavior** against **that document**; a mismatch is a
> finding. If the document itself is wrong, that's a finding *against the
> document* (fix via its version history, #48).

---

## 1 · The audit loop

```
baseline (architecture.md)
   → probe (instruments below, per category)
      → finding (evidence + classification)
         → GitHub issue (template §5) — comment-only; agents NEVER close issues
            → human review: approve / reject / reclassify   ← THE GATE
               → remediation (only after approval)
                  → regression test (pins the fix)
                     → retro: why didn't the previous audit catch it?
                        → new/changed instrument  ← the loop improves itself
```

Two hard rules, standing:
- **No remediation before human approval.** Finding ≠ permission to fix.
- **Definition of Done applies to every finding & fix** (usability-sim.md): a
  real-role, real-surface round-trip with reload; a failing signal is a defect
  until proven otherwise, never "a harness artifact".

## 2 · Why user reports alone under-find (the four ceilings)

Documented in usability-sim.md and repeated here because the instruments are
designed against them:

1. the mock encodes the author's own mental model;
2. the same head writes both the action and the assertion;
3. scripted selectors bake in compliance ("couldn't find it" is untestable);
4. one tidy seed — never messy / empty / concurrent / stale state.

Instruments I-2, I-4 and I-6 exist specifically to escape these.

---

## 3 · Instruments (what actually runs)

| # | Instrument | Catches | Proven findings |
|---|---|---|---|
| **I-1** | **e2e regression suite** — 58 Playwright tests on the mock (`npm run test:e2e`); every fixed bug gets a pinned test; suite must be green before any push | regressions; previously-fixed bugs returning | proven red↔green on #43 (save), the wallet crash, #51 |
| **I-2** | **Source-blind explorer** — an agent given ONLY the running URL + a role + a plain-language goal; forbidden from reading source; navigates by what it sees; reports every dead-end and unexplained term | discoverability, orientation, terminology, silent failures — the "couldn't find it" class scripted tests cannot express | 5 runs: orphaned `/my` (no nav entry) · wallet dead page (#27) · hover-only concept "bridges" · create-person flow had zero coverage · empty-chapter officer stranded |
| **I-3** | **Crash-class sweep** — `svelte-check` errors of the `Cannot find name` subclass are treated as runtime crashes, not type noise; plus `smoke.spec.ts` walks every surface via client-side nav and fails on any pageerror | silently-dead pages (a ReferenceError aborts the mount and leaves the previous page on screen) | 4 real crashes (joinStake / openProject / awardOpen ×2) that had been dismissed as "pre-existing type errors" |
| **I-4** | **Gate-vs-UI consistency check** — for each RPC in the migrations, extract its permission gate; for each UI control, note the role it renders for; flag any control shown to a role the backend rejects (and vice-versa: capabilities with no reachable surface) | "UI offers it, backend forbids it" and inaccessible features | gap **G3**: `/my` offers Start/Reopen but `task_update` has no owner exception — found by running this check while writing architecture.md |
| **I-5** | **CRUD lifecycle probe** — per entity (architecture.md §2): create → view → edit → **reload-persists** → archive → restore-path exists? Each leg as the *least-privileged role allowed* | create-only workflows, dropped saves, delete-without-restore | task delete didn't persist (mock); resource quota edit silently reverted; member's pending self-edit hid its submitted value |
| **I-6** | **State & seed adversarial probes** — empty community, all-shipped, junk/negative/whitespace input, double-click, cross-surface staleness, mid-flow abandonment | cold-start dead ends; state the tidy seed never reaches | "No projects match" shown to a brand-new community; empty-chapter officer had no path to their job |
| **I-7** | **Terminology & guide-consistency pass** — every invented concept (STR, card, need, two officer types) must be explained *visibly* where first met (hover-only ≠ explained); every guide claim must match a reachable surface (#29) | jargon walls; guide drift | M1/M3 were green while users still saw bare "STR"/"card" — tests asserted a `title=` attribute, not comprehension |

**Cadence:** I-1 and I-3 run on every push (blocking). I-2/I-5/I-6 run per
release and whenever a surface is redesigned — one explorer per affected role.
I-4 and I-7 run whenever migrations or nav/labels change, and quarterly in full.

## 4 · Category → instrument map (issue #50's deliverables)

| #50 deliverable | Verified by |
|---|---|
| **D1 Architecture** — roles documented & non-duplicated; permissions consistent, no escalation; ownership complete with transfer & override rules | architecture.md is the checklist itself; I-4 verifies code matches it; any entity without an owner row in §4 is automatically a finding |
| **D2 Workflow** — CRUD complete; restore exists; approval chains defined (reviewer/approver/reject/resubmit); contributions persist | I-5 per entity; approval legs of I-5 follow architecture.md §6; contribution records ride the settlement tests (WF5) |
| **D3 UI** — navigation stability, terminology, layout stability, feedback visibility | I-2 (fresh eyes per role) + I-7; feedback visibility = every data-changing action must toast/confirm (I-5 asserts it); layout stability guarded by keeping changes additive & release-noted (#25/#30) |
| **D4 Quality** — regression, state persistence, feature inventory | I-1 (+ every fix pins a test); persistence legs of I-5; feature inventory = architecture.md §2·§3 (an undocumented feature found by I-2 is a finding) |

## 5 · Finding format (the GitHub issue an audit files)

```
Title: [audit/<instrument>] <one-line symptom>
- Category: architecture | workflow | ui | quality
- Severity: blocker | major | minor | question
- Role & surface: as <role> on <url>
- Steps: exactly what was done (real interaction, not code reading)
- Expected: per architecture.md §<n> (quote the rule)
- Actual: what happened (evidence: persisted-after-reload? console clean?)
- Classification: code bug | doc bug | UNDEFINED (needs a design decision)
- Proposed next step: (never started before approval)
```

`UNDEFINED` is a first-class outcome: when architecture.md has no rule for the
observed behavior, the finding asks for a **design decision**, not a fix —
that's how "is this intentional or a bug?" stops recurring.

## 6 · Human review gate

- Findings are **filed as issues and left open**; agents comment, never close.
- The President (or a delegate) approves / rejects / reclassifies each finding.
- Remediation starts only on approved findings; each fix ships with its pinned
  regression test (I-1) and a "why did the audit not catch this sooner" retro
  if the finding came from a user instead of an audit.

## 7 · Version history

| Version | Date | Change | Trigger |
|---|---|---|---|
| v1.0 | 2026-06-19 | formalized the practiced method: loop, 7 instruments, category map, finding format, human gate | #50 |
