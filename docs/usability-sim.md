# Usability simulation — the feedback loop, and why it misses what it misses

> ## Why the sim still under-finds bugs — the structural ceilings (not "try harder")
>
> The personas got more adversarial and still found little, because the *limits are structural*:
> the breaker and the author are the same head. Naming them so we attack the cause, not the symptom:
>
> 1. **The mock is my own mental model.** Tests run against `mock-supabase.ts`, which I wrote to
>    encode how I *think* the backend behaves — and I "fix" the mock when a test fails. It can only
>    reflect my assumptions back. The reporter's bugs happen on the **deployed build against real
>    Supabase** (RLS, migration drift, real null/empty rows, real RPC shapes). The #43 Save bug was
>    only caught because it was pure front-end. **Anything backend-shaped, the mock papers over.**
>    → *Move: run the suite against a real-Supabase preview/staging, not the mock.* (Blocked on infra.)
> 2. **I author the action AND the assertion.** `expect(x).toBeVisible()` for an `x` I just added
>    confirms my implementation — it cannot discover. Worse failure mode (caught live): the M1/M3
>    "concept bridges" assert `toHaveAttribute('title', …)` — a **hover tooltip**. A black-box
>    explorer *scanning* the page (and every mobile/touch user) never hovers, so it still saw bare
>    "0 STR" and an unexplained "card" pill — yet the tests were GREEN. **I asserted the
>    implementation, not the user's comprehension.** → *Move: assert what's visible without hover;
>    use a separate breaker (below).*
> 3. **Playwright selectors bake in compliance.** Writing `locator('.need-row', {hasText:'Annotation'})`
>    *requires* knowing the path, so the #1 real failure — "I couldn't find where to do this" — is
>    literally unrepresentable. My "low-compliance" personas are still me wearing a hat.
>    → *Move: a black-box explorer agent given only the URL + role + goal, FORBIDDEN from reading
>    source, navigating by what it sees, reporting every dead-end.* (Run once — it works; it surfaced
>    the hover-only-bridge flaw and the create-person coverage hole that all 44 scripted tests missed.)
> 4. **One tidy seed; never messy/empty/concurrent/stale state.** Every test starts from the same
>    fixture; none *creates* a person (WF8 added after a black-box run exposed that the officer's
>    literal first action was untested), none runs an empty chapter, duplicate names, a half-claimed
>    card, a mid-settlement project, a departed officer, or two tabs editing at once. I fuzz *input*,
>    never *state* or *sequence* or *time*. → *Move: adversarial fixtures + cross-session/concurrency.*
>
> **The black-box explorer is the cheapest of these to keep running** and the only one that escapes my
> blind spots without new infra. Caveat learned: `preview_click` does NOT fire Svelte `onclick`
> handlers (only `<a>` nav + native `.click()`), so a black-box agent's "button does nothing" is a
> tooling artifact to re-test with a real click — not a confirmed app bug. (Verified: "Add a person"
> works via native click; the explorer's flagged "blocker" was the harness.)

> ## ⛔ Definition of Done — read before claiming ANY fix
>
> A change is **VERIFIED** only after a **real-user round-trip**, with the evidence written out:
> 1. As the **exact role** the issue names, on the **exact surface** (the real page — not a proxy,
>    not the code, not "the element exists").
> 2. Do the **real interaction**: type a real value into the real field, click the real button.
> 3. **Reload the page** and confirm the change **actually persisted**.
> 4. **Console is clean** (no errors) after the interaction.
>
> Then state it literally: *"as <role> on <url>: typed X → <control> appeared → clicked → reloaded
> → still X → console clean."* No round-trip evidence ⇒ the change is **UNVERIFIED**, and I must
> **say so**, list exactly what's left to confirm, and who can do it (e.g. "needs a prod login").
>
> **Hard rules (these are where I failed):**
> - Never label something "fixed" / "live" on the strength of code-reading, element-presence, a
>   synthetic DOM event, or "the deploy succeeded." Those are *not* verification.
> - **A failing signal in preview is a DEFECT until proven otherwise — never "a harness artifact."**
>   (The #43 Save button was visibly broken in preview and I shipped it anyway by calling it flaky.)
> - Don't infer infrastructure failures (deploy / domain / cache) from weak signals. If a check
>   can't even find a string you *know* is live, the **check** is wrong — say "I can't tell," don't
>   alarm. (I twice declared the deploy broken from a broken grep.)
>
> ## Issue understanding — before touching code
> For each issue, in order: **(1)** restate exactly what the reporter did and saw; **(2)** reproduce
> it on the **current deployed build**; **(3)** classify — *code bug · data · permission · stale/cache ·
> predates-a-fix*; **(4)** only then fix. Before saying anything is "live," check the **deploy commit**
> AND the **report's timestamp vs the deploy time** (often the report just predates the fix).

**The method, stated plainly.** We refactor continuously. A tester (or member) keeps
proposing changes; we keep digesting them; after each pass we ask *which* suggestions are
now absorbed and which remain open. This is not thrash — it **is** how the system is built.
So every incoming issue is treated as two things at once:

1. a **regression scenario** added to our simulated test corpus (below), and
2. evidence of a **blind spot in the simulation itself** — because if our 3-role zero-hint
   sim had been good enough, it would have found the problem before the human did.

The second is the valuable half. A bug we fix is worth one issue; a *reason our sim was
blind* is worth every future issue of that shape. This doc records both.

Personas the sim drives (zero hint, no narration): **Wang Fang** (WG officer), **Chen Wei**
(Chapter officer), **Sai Tan** (President/admin). See `user-stories.md` for their goals.

---

## Part 1 — The 2026-06-14 wave (#16–#35) as scenario corpus

All twenty from one tester (Carolyn-Jiang) in a single deep pass. Status: **F**=fixed in
branch (needs deploy) · **B**=real bug, open · **D**=design decision pending · **P**=process/meta.

| # | Role | What the human hit | Why our sim didn't catch it | St |
|---|------|--------------------|-----------------------------|----|
| 16 | any | A surface renders broken (screenshot) | Sim follows the main flow; this surface wasn't on the path. Also indistinguishable from the headless screenshot-tiling artifact we already know about — sim can't tell "broken" from "render artifact". | B |
| 17 | any | Night mode hard to read | **Sim only ran the light edition.** Dark was never exercised. | D |
| 18 | Chapter | Bottom nav duplicates top nav; "free time" card redundant | **A goal-primed agent treats two routes to the same place as fine** (both work). Humans read duplication as clutter. | D |
| 19 | any | Ranking arrow's meaning unclear | Agent *inferred* the arrow's meaning from context; the human had no tooltip. Sim never flags an **unlabeled affordance** because it doesn't need the label. | D |
| 20 | any | Feedback is passive inline text, easy to miss | Sim **read the inline text as success** — it parses the DOM, so "feedback present" passed even when a human wouldn't notice it. (Toast now added → F for the assign path.) | F |
| 21 | Member | Legacy Craftsman/Master badges coexist with Learning/Independent/Lead | Sim exercised the **main skill UI only**, never the member-profile legacy badge tree. Coverage gap. | D |
| 22 | any | "People" vs "Directory" labels confusing | Agent **knew the intent**, so ambiguous labels didn't disorient it. (People→roster already changed in branch.) | F |
| 23 | any | "Why is Jimin Huang Secretary?" | Sim **never validates seed/content correctness** — only behavior. A wrong title is invisible to a behavioral check. | D |
| 24 | any | Browser **Back** bounces forward, loses context | **Sim only uses in-app navigation; it never presses the browser Back button.** Our own `/`→`/projects` `replaceState` redirect causes it. | B |
| 25 | — | "Prefer incremental fixes; original bugs still open" | **Longitudinal complaint.** A single-session sim cannot feel "this moved again since yesterday." | P |
| 26 | Chapter | "No save button" on availability | Availability **auto-saves on change**; the sim saw the value persist and passed. Our acceptance criterion rewarded the exact thing the human distrusts. | B |
| 27 | any | Wallet URL changes, page doesn't render | Sim may not have clicked the masthead STR link; can't reproduce on current build (renders for admin). Possibly session-specific or already fixed. | B? |
| 28 | all | Guide doesn't reflect the three roles | Sim **never audited guide structure against the role model** — it reads the guide as prose, not as a contract with the UI. | D |
| 29 | — | "Check the guide stays in sync with the UI after each change" | **No guide-vs-UI consistency check exists** in the sim at all. | P |
| 30 | — | "UI changes faster than users can learn it" | Longitudinal, same as #25. | P |
| 31 | Chapter | Assignment errors easy to miss | Happy-path bias + inline-text-accepted (see #20). Toast.error now on the assign path. | F |
| 32 | Chapter | Eligible-looking member can't be assigned to Lead/First-author; error won't say **which** skill is missing | **Seed data always matched the need**, so the failing-match path never ran; and even when an error showed, the sim didn't **inspect the error's content** for actionability. | B |
| 33 | WG | Role assignment has no confirm / no undo / no remove | Sim **rewarded frictionless assign** and never tested the inverse (remove/replace). We tested *create*, never *recover*. | B |
| 34 | all | Audit: every create/claim/assign must also have edit/undo/delete | Same inverse-path gap as #33, generalized. Our stories test the **forward** lifecycle; the **reverse** lifecycle was never a test. | B |
| 35 | WG | Project status changes immediately, no confirm | Sim rewarded **optimistic state change** as good UX; for a no-undo action the human wants a gate. | B |

---

## Part 2 — Blind-spot retrospective (the part that compounds)

Five systemic reasons our simulation was blind. Each is a standing fix to the sim, not to the app.

### BS-1 — Frictionless ≠ safe. Our acceptance criteria were pointed the wrong way.
*(#26, #33, #35, #34, #20, #31)*
Our HCI acceptance rewarded "inline, optimistic, no reload, no extra click." That is correct
for *low-stakes, reversible* edits (toggling a task) and **wrong** for *consequential or
irreversible* ones (assign First Author, change project status, settle). For those the human
wants the opposite: an explicit **Save**, a **Confirm** gate, and a visible **Undo/Remove**.
**Sim fix:** classify every action as reversible/consequential. For consequential ones, the
acceptance test *fails* if the action commits on a single click with no confirm and no undo.

### BS-2 — Happy-path / matched-seed bias.
*(#32, #31, #20)*
Seed data was built so candidates matched needs, so the failure branches (skill gap, over-
capacity, empty states) never executed, and we never read the error *content* for whether a
human could act on it. **Sim fix:** seed at least one deliberately-failing case per matchable
need; assert the error names the missing requirement (skill + level), not just "doesn't meet
requirements."

### BS-3 — In-app only; never the browser, never URL↔content.
*(#24, #27)*
The sim clicks links inside the app and never presses **Back/Forward**, never checks that the
URL and the rendered page agree. Our own `replaceState` landing redirect breaks Back, and a
URL-without-render slips straight through. **Sim fix:** after each navigation, press Back and
assert we land where we came from; assert `location.pathname` matches the rendered surface.

### BS-4 — A goal-primed agent never gets lost.
*(#22, #19, #18)*
We hand the agent the intent, so ambiguous labels, unlabeled glyphs, and duplicate paths cost
it nothing — it reasons past them. Humans pattern-match against prior expectations and stall.
**Sim fix:** a "cold" persona pass that is given only a *goal in plain words* ("find out who's
free this month") and must choose the entry point from the nav labels alone; every unlabeled
symbol it encounters is logged as a defect.

### BS-5 — Single session, single theme, main-flow only.
*(#25, #30, #17, #21, #23, #16, #28, #29)*
One run, light mode, the golden path. So we never feel cross-session churn, never see dark
mode, never visit legacy/secondary surfaces, never validate seed content, never cross-check
the guide against the UI. **Sim fix (coverage matrix):** run each persona in {light, dark};
include a second run "the day after" that flags any moved surface; add a sweep pass that visits
every route (incl. legacy badge tree, member profile, wallet); add a guide-vs-UI assertion that
every role section in the guide maps to a reachable, matching surface.

---

## Part 3 — The upgraded sim protocol (apply on the next run)

Concretely, the next simulated run must additionally:

1. **Press the browser Back button** after every in-app navigation and assert the return target;
   assert URL ↔ rendered surface on every page. *(catches #24, #27)*
2. **Run twice: light and dark edition.** *(catches #17)*
3. **Force one failing match per need** and assert the error names the missing skill+level.
   *(catches #32, #31)*
4. **For every consequential action** (assign First Author, change status, settle, remove a
   person): require a confirm gate and a visible undo/remove; fail if it commits on one click.
   *(catches #33, #35, #34)*
5. **For every create/claim/assign/post,** assert a reachable edit *and* delete/undo path exists.
   *(catches #34, #26)*
6. **Cold-label pass:** a persona given only a plain-words goal, choosing entry from nav labels;
   log every unlabeled glyph and every duplicate path. *(catches #18, #19, #22)*
7. **Full-route sweep** including legacy/secondary surfaces; flag any second competency scale
   still visible. *(catches #16, #21)*
8. **Guide-vs-UI cross-check:** every guide role-section must map to a reachable surface whose
   actions match what the guide claims. *(catches #28, #29)*
9. **Seed-content validation:** assert seeded titles/roles are intentional (no stray "Secretary").
   *(catches #23)*

10. **Exercise every editable field for real.** For each input/select on a card or form: type a
    real value *through the framework* (not a code read, not "the element exists"), assert the
    save/submit control then appears, click it, and assert the value persisted on reload. *(catches
    #43 — the hours Save button never appeared because a number input was bound to a string and the
    dirty-check threw; #26 was "fixed" but never actually exercised end-to-end.)*
11. **Check the browser console after every interaction.** A clean console is part of the pass; any
    thrown error (e.g. the `.trim()` TypeError on a coerced number) is a defect, not noise. *(would
    have caught #43 the instant a value was typed.)*
12. **Never explain away a failing signal.** If a control doesn't behave in preview (a button that
    won't show, a value that won't stick), that is a finding until *proven* to be a harness
    artifact — not assumed to be one. *(The #43 regression was visible in preview and dismissed as
    "synthetic-input flakiness"; that rationalisation is the real miss.)*

When a future issue arrives, add its row to Part 1, find (or add) the matching blind spot in
Part 2, and confirm the Part 3 protocol would now catch it. If it wouldn't, the protocol — not
just the app — gets a fix. That is the loop.

---

## Part 4 — Retro on the 2026-06-15 wave (#41–#47): why the sim missed the Save bug

The single worst miss this cycle was **#43 / #44 — the Available-time Save button never worked**
(a number input bound to a string state, so typing coerced it to a number and the dirty-check's
`.trim()` threw; the button never rendered and hours could not be changed at all — and this had
been broken since #26 "added" the Save).

**Why the sim and our own verification missed it — a new standing blind spot:**

> **BS-6 · Forms were verified by code-reading and element-presence, never by real typed input +
> a persistence assertion — and a failing preview signal was rationalised away.**
> We confirmed "the Save logic looks right" and "the input exists," and when a synthetic fill
> showed the Save button not appearing, we called it a *harness artifact* and moved on. Both the
> coverage gap (never typed + saved + reloaded) and the discipline gap (dismissed a real failing
> signal) let a totally-broken core control ship twice.

**The fix is protocol points 10–12 above**, now mandatory before any "fixed" claim on a form:
type → save control appears → click → value persists on reload → console is clean. And the
class-check we now run: after fixing one control bug, grep the whole app for the same shape
(here: `type="number"` bound to a string that is later `.trim()`'d — confirmed unique, contained).

Other #41–#47 items and their blind spots:
- **#42** (Cancel button invisible) → BS-4 (unlabeled/low-contrast affordance a goal-primed agent
  ignores). Fixed.
- **#44 / #41** (officers can't edit claimed members' skills; permission/persistence inconsistency)
  → a permission-matrix gap: the sim never tried *officer edits another claimed member* (only
  cards). Add to the protocol: run each editable action as **every** role × **every** target kind
  (own card · a card I manage · a claimed member in my chapter · someone outside my chapter) and
  assert allow/deny matches the intended matrix.
- **#45** ("still in the old system") / **#46** ("don't know what to fill in") / **#47** (chapter
  join lacks context) → surface/route-coverage + field-label clarity; the full-route sweep (point
  7) plus the cold-label pass (point 6) should surface these once we have the exact screens.
