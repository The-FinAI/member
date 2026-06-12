# Design system v2 — “The Daily Ledger”

*2026-06-12. The visual layer of redesign-v2 (supersedes its original “no visual
redesign” clause — overruled by decision). The product is a living record, so
the interface is typeset like one: a research broadsheet. Implemented in
`src/app.css` (the single source of truth) + the masthead shell in
`src/routes/+layout.svelte`. The living contract page is `/styleguide`: if an
element on any page doesn’t match that sheet, the page is wrong, not the sheet.*

## 1. The idea

Not a SaaS dashboard. A **daily ledger / financial broadsheet** for a research
community:

- **Paper, not panels.** Warm cream paper; sheets are *ruled* (a black section
  rule on top, hairlines elsewhere), never floating — no drop shadows on the
  page; only popovers (physically lifted paper) cast one.
- **Ink, not chrome.** Near-black warm ink for text; hierarchy from type and
  rules, not boxes and tints.
- **One action color.** Vermillion `#b53a1c` is the only interactive hue —
  buttons, links, active section, qualified match. If it’s vermillion, you can
  act on it.
- **Gold belongs to STR.** `--gold` appears *only* in the wallet, at
  settlement, and on gold-tier seals. The credit economy is visually quiet
  everywhere else by construction — the palette enforces the PRD.
- **Print geometry.** Corners are 2–4 px (`--r-sm/md/lg`); pills exist only as
  avatars/monograms (`--r-full`). Status dots are **squares** (press marks).
  Badges are **letterpress stamps**: uppercase, letterspaced, bordered in
  their own color, no filled pills.
- **Two editions, one soul.** Day edition (default) and night edition share
  identical structure and hue logic; night is ink paper with lifted tones — it
  is not a second aesthetic (the old dark “exchange” theme is gone).

## 2. Tokens (all in `:root` of app.css)

| group | tokens |
|---|---|
| paper | `--bg` `#f3eee3` · `--bg-2` · `--card` (sheet) · `--card-2` · `--elevate` |
| rules | `--border` (hairline) · `--border-2` · `--rule-ink` (the black rule) |
| ink | `--text` `#1e1a12` · `--text-dim` · `--muted` |
| action | `--accent` vermillion `#b53a1c` · `--accent-2` · `--accent-ink` · `--accent-soft` |
| semantics | `--up` forest · `--down` wine · `--warn` bronze · `--info` slate (+ `-soft`) |
| STR | `--gold` `#94731b` · `--gold-soft` — **nowhere else** |
| depth | `--shadow` (paper lift) · `--shadow-pop` (popovers only) · `--ring` (focus) |
| type | `--font-display` **Fraunces** · `--font-sans` Inter · `--font-mono` JetBrains Mono |
| geometry | `--r-sm 2px` · `--r-md 3px` · `--r-lg 4px` · `--r-full` · `--ctl-h 36px` |

Night edition overrides the same names under `[data-theme="dark"]`.

## 3. Type

- **Headlines (h1/h2): Fraunces 600** — real headline sizes (1.95 / 1.3 rem).
  Pages have *headlines*, not labels.
- **Section headings (h3): Inter 700 small-caps** over the section rule.
- **Body: Inter 400.** Long-reading line-height 1.5.
- **Every number: JetBrains Mono, tabular**, wearing its unit (`7/10 h·mo`).

## 4. The element vocabulary (one implementation each)

| element | recipe |
|---|---|
| Sheet (`.card`) | sheet bg · hairline border · **2px ink rule on top** · r-lg |
| Figure (`.tile` `.kpi`) | transparent, **2.5px ink rule-top**, small-caps label, big mono value |
| Stamp (`.badge`) | uppercase · letterspaced · 1px border in own color · transparent |
| Press mark (`.sdot`) | 7px **square** in the status color |
| Slug (`.chip`) | rectangular bordered tag; `.toggle.on` = ink block reversed |
| Button | vermillion block (primary) · ruled ghost · wine outline (danger); one height; spinner slot |
| Input/search | sheet-white, ink border on focus + ring |
| Table | **2px ink rule under the head**, small-caps headers, hairline rows, hover wash |
| Order-book row (`.match-row`) | hairline row; **qualified = 3px vermillion left rule + tint**; blocked = greyed |
| Ledger line (`.txn`) | hairline rows, outlined square icon, mono amount |
| Market report (`.hero`) | **double ink rule** on top; balance mono; unit + alloc in gold |
| Monogram (`.ava` `.avatar-btn`) | engraved: ink ring + ink initials, no fill |
| Seal (`.medal`) | engraved plate; tier = ring color; **gold tier = double gold rule** |
| Chronicle (`.timeline`) | square dots, hairline spine |
| Skeleton (`.sk`) | proof blocks, subtle shimmer |
| Banner | soft tint + **3px color rule on the left** |
| Popover (`.menu`) | ink border + `--shadow-pop` (the only shadow) |

## 5. The masthead shell (replaces the sidebar)

```
row 1 · dateline   FRIDAY, JUNE 12, 2026 · Chan Min · Beijing Chapter      EN 🔔 ☾
row 2 · masthead   ⟡ The Fin AI  COMMUNITY · THE LIVING RECORD       ◈ 460 STR (CM)
row 3 · sections   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (2.5px ink rule)
                   FRONT PAGE  MY TASKS  PROJECTS  PEOPLE  DIRECTORY   GUIDE SETTINGS
                   ──────────────────────────────── (1px ink rule)
```

- Sections are small-caps; the active one carries a **3px vermillion rule**.
- Row 3 is sticky; rows 1–2 scroll away (the paper folds).
- The STR figure sits in the right margin of the masthead, set in gold —
  consistent with “gold = STR only”.
- Full-width content column (max 1180px), no side rail.

## 6. Uniformity enforcement

- All global elements live in app.css; pages may only *compose* them.
- Component-local `border-radius` literals were swept to `var(--r-*)`
  (49 files) — geometry cannot drift per-component.
- `/styleguide` renders every element in both editions and is the acceptance
  reference for any new UI.
- Adding a new visual variant requires adding it to app.css **and**
  /styleguide in the same commit, or it doesn’t exist.

## 7. Known follow-ups

- A few page-local styles still carry old hex fallbacks (e.g. `#6a7cff` blues
  in NeedPost/ProjectTeam fallback values) — they only show if a token is
  missing, but should be swept to tokens in the M5 cull.
- Home’s avatar disc is filled (page-local); should adopt the engraved
  monogram.
- The IA changes of redesign-v2 (§4) are unaffected and still pending M2–M5.
