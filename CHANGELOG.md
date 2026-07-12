# Governance Changelog

> Issue #48. Records **every change to governance documents** — permanently,
> append-only, never overwritten. Current version: see [`VERSION.md`](VERSION.md).
>
> **Governance documents covered:** `docs/architecture.md` (roles, permissions,
> ownership, approval — #49) · `docs/audit-framework.md` (#50) ·
> `docs/permissions.md` (plain-language companion) · `docs/usability-sim.md`
> (verification requirements / Definition of Done) · `docs/user-journeys.md`
> (workflow rules for testing).
>
> **Update process (required for any governance change):**
> 1. a **governance issue** describing the change and its reason;
> 2. the **document update** itself;
> 3. an **entry here** (date · version · issue · summary · reason);
> 4. a **version increment** in `VERSION.md` (semver: major = model change,
>    minor = new rules/sections, patch = clarifications).
>
> Releases touching governance may not ship unless all four are present.

---

## v1.0.1 — 2026-06-19

**Issues:** #52, #53 (filed by the first formal I-4 audit cycle under #50).

### Changed
- `docs/architecture.md` v0.1 → v0.1.1: gaps **G4** (create-form offers WGs the
  creator can't use, #52) and **G5** (Assign shown to officers `work_seat`
  rejects; §4 assignment-editor row corrected to match SQL — whether a WG
  leader may seat their own project is UNDEFINED pending decision in #53).
  *Reason:* audit findings must be reflected in the baseline document so later
  audits don't re-discover them (#50 §1 retro step).

---

## v1.0.0 — 2026-06-19

**Issues:** #49, #50, #48 (this framework), building on #37/#38.

### Added
- `docs/architecture.md` v0.1 (**PROPOSED**, awaiting President approval): role
  inventory, role×entity permission matrix, entity inventory, ownership model,
  CRUD lifecycles, approval workflows, known-gaps list (G1–G5).
  *Reason:* #49 — the platform operated without a formally approved permission
  model; users could not tell intentional limits from bugs (e.g. #51, #44).
- `docs/audit-framework.md` v1.0: the proactive audit loop (baseline → probe →
  finding → issue → human approval → remediation → pinned test → retro), 7
  instruments with cadences, standard finding format with `UNDEFINED` as a
  first-class outcome. *Reason:* #50 — problems were discovered mainly through
  user reports; a systematic, repeatable agent audit process was required.
- `CHANGELOG.md` + `VERSION.md` (this mechanism). *Reason:* #48 — governance
  changes were untraceable (what/when/why/which issue).

### Existing documents brought under governance
- `docs/usability-sim.md` — the Definition of Done (real-role round-trip,
  reload-persists, console-clean; a failing signal is a defect until proven
  otherwise) and the issue-understanding process. Originated from the #26/#43
  verification failures.
- `docs/permissions.md` — plain-language "who can do what" (#44 companion).
- `docs/user-journeys.md` — the workflow/persona testing rules (#30 retro).

### Standing rules (restated as governance)
- Agents **never close issues**; they comment and leave decisions to humans.
- **No remediation before human approval** of a finding (#50 §6).
- Every fix ships with a pinned regression test; user-found bugs get a
  "why did the audit miss it" retro.
