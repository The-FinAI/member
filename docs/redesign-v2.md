# Redesign v2 — one grammar, three desks, the seam up front

*2026-06-12. Successor to `redesign-hci.md` (v1) and `PRD-final.md`. The domain
model is settled and does not change here: six nouns (Person · Project · Need ·
Task · Milestone · STR), bipartite org (Chapter holds people, Working Group
holds projects, they meet at the Need), behavioral skill levels, labor-as-
resource, custody, quiet STR. This document redesigns what sits on top of it:
the information architecture, the element system, and the interaction grammar.*

---

## 0. Why redesign again

v1 was designed from principles. Since then we have something better than
principles: **evidence**. Three cold usability tests (WG officer, chapter
officer, admin — no instructions, real persistence), seven field issues from a
real officer (Carolyn), and a full inventory of every route, component and
interaction in the codebase. v2 is designed from that evidence.

The verdict of the evidence, in one line: **the model is right, the visual
language is right, and the grammar between them is broken.** Every tester
understood their job within a minute; every tester was then slowed down by the
same handful of structural faults — none of which are domain-model faults.

What stays untouched: the Direction-C light editorial visual language (every
survey and tester called it the strongest part), the database schema, the RPC
layer, the six nouns.

---

## 1. The evidence, compressed

**From the three cold tests:**
- The **matcher is the product**. Both officers called assign-by-free-hours the
  single most convincing thing — and both nearly missed it behind faint chevron
  rows on a secondary panel.
- **Cards lie.** All three testers concluded "the app is half-broken" because
  cards looked clickable but opened a side drawer they didn't expect (or a
  stray backdrop click dismissed). The fix (href + › handle) confirmed the rule:
  people expect *pages*.
- **STR is noise to officers.** All three flagged the omnipresent
  accruing/settled counters as "a problem I didn't ask about." The PRD said
  quiet; the implementation drifted loud (sidebar chip + My header + Home).
- **"My tasks" is dead for officers** — the first WORK nav item, empty for the
  app's only real Phase-1 users.
- **Two people lists** (People vs Directory) with different behaviors confused
  everyone who touched both.
- **Vocabulary leaks**: card, forge, steward, mint, accruing — internal RPC
  words surfacing in UI copy.
- **Notifications overpromise**: "someone updated work that touches you" lands
  on a generic board with nothing highlighted.

**From the field issues (#9–#15):** officers need to *edit in place* (needs,
capacity), need *remaining/total* not just totals, need *exits* on every form,
need approvals *they can find* (#12: an officer hunting for where to approve a
request), and need the manual in their language. All now patched — but each was
a symptom of a missing grammar rule, not a one-off bug.

**From the code inventory:**
- ~20 routes are redirects or stubs; a parallel deprecated generation
  (CardBinder, SlotBoard, Matcher, MatchConsole, SlotSeater, ForgeCard,
  MemberCard, CommitChip, ProjectSlotCard, Leaderboard) is still in the tree.
- **5 card implementations, 4 form patterns, 5 list patterns, 3 modal
  patterns.** Success is communicated 3 ways, errors 3 ways, loading 2 ways;
  there is no toast, no undo, no confirmation pattern at all.
- InlineField — the best edit primitive in the codebase — is used in exactly
  2 places.

---

## 2. Diagnosis — eight structural faults

1. **Noun-shelf IA, job-shaped users.** Nav says Projects/People/My/Directory;
   users arrive with jobs ("staff this need", "run this paper", "keep my roster
   current"). Home bridges, the nav doesn't.
2. **One noun, two surfaces.** People vs Directory; entity pages vs entity
   drawers. Same thing, two homes, two behaviors.
3. **The seam is buried.** Matching — the one-gesture core of the whole model —
   is a collapsible panel on a secondary page with no deep-linkable state.
4. **Role-blind shell.** Identical nav for member, two officer types and admin;
   the first WORK item is empty for officers; approvals are findable only by
   admins (#12).
5. **STR louder than specified.** Drifted from "legible but quiet" to
   three-surfaces-always-on.
6. **No interaction grammar.** Each feature rolls its own create/edit/feedback/
   loading/empty pattern; the 12 DoD rules exist on paper, not as primitives.
7. **Vocabulary leakage.** The forge/mint/card layer was supposed to be
   internal; it talks to users.
8. **Two generations of code coexist.** The deprecated officer-console
   generation confuses every grep, every bundle, every future contributor.

---

## 3. The grammar — twelve rules, enforced by primitives

These supersede the v1 DoD list. Each rule maps to a primitive, so following
the grammar is the path of least resistance, not a discipline.

1. **A noun is a page; a verb is a button.** Every entity (person, project,
   chapter, working group) has exactly one canonical page. Nothing opens in a
   drawer. *CardDrawer is deleted.*
2. **Land on the row, not the page.** Every Home/notification item deep-links
   to the exact row, pre-expanded and highlighted (`?need=…`, `?task=…`).
3. **Editable looks editable.** Hover shows the pen; read-only never grows a
   cursor. (InlineField everywhere.)
4. **One primary action per view**, top-right of the page header.
5. **Create = inline expandable form**, Submit + Cancel side by side at the
   *bottom* (where the user's eye is when they finish typing — issue #11).
6. **Single field = InlineField.** Enter/blur commits, Esc cancels, error stays
   inline with the field.
7. **Every write is optimistic** and confirmed by a toast; destructive writes
   get an undo-toast instead of a confirm dialog; failures revert + toast.
8. **Disabled is explained.** Every disabled control has a tooltip: why, and
   what unblocks it. (The "Finish" button lesson.)
9. **Loading is a skeleton** of the shape to come. Never bare "Loading…".
10. **Empty states teach**: one sentence of what belongs here + the one button
    that fills it.
11. **Numbers wear units, fractions mean remaining/total.** `7/10 h/mo` —
    everywhere, the same order (issues #10/#14).
12. **The UI speaks the six nouns.** forge → submit, mint → create, card →
    person (managed), steward → manage, accruing → "building up". Internal
    verbs never surface.

---

## 4. Information architecture v2

### 4.1 The shell — role-shaped, not role-locked

The nav adapts to your hats, but every item is a *preset lens on a canonical
surface*, never a separate console (the lesson of the dead `/officer` pages).

```
WORK                              who sees it
  Home                            everyone        triage: what needs you
  My chapter                      chapter officer → /people?mine=1 (match desk pinned)
  My projects                     WG officer      → /projects?mine=1
  My work                         everyone        → /my  (tasks I own + waiting-on-me)
  Review · N                      anyone w/ queue → /review (scope-filtered approvals)

COMMUNITY
  Projects                        everyone
  People                          everyone
  Chapters & Groups               everyone        → unit pages (no more drawer)
  Skills                          everyone        → the catalog, read view
  Guide                           everyone

FOOTER
  Wallet (word only — no live number)  ·  Account  ·  Settings (admin caps)
```

Key moves:
- **"My chapter" / "My projects"** are deep links with state, not new pages.
  The nav speaks the job; the surface stays canonical.
- **`/review` is new and shared.** One approvals surface: unit applications for
  *my* units, over-capacity commitments for *my* people, settlements for *my*
  projects; admins see everything. This is the structural fix for issue #12 —
  an officer should never hunt through `/admin/forge-queue` route names.
- **STR retreats to the Wallet.** The sidebar chip loses its live number; the
  My-header ledger moves to /wallet; Home keeps only the "needs settlement"
  action item. (PRD compliance restored.)

### 4.2 Route map v2

| Route | Status | Notes |
|---|---|---|
| `/` | keep, sharpen | triage items deep-link to exact rows (rule 2) |
| `/my` | reshape → **My work** | tasks I own + needs awaiting my action per hat; wallet ledger leaves |
| `/projects`, `/projects/[id]` | keep | `?mine=1` lens; create-form per rule 5 |
| `/people` | keep, promote | **absorbs Directory's People tab**; match desk becomes the hero panel, URL-stateful (`?need=…`, `?person=…`) |
| `/members/[id]` | keep | one person page (self-view = first-person copy; managed = ✎ editable) |
| `/units/[id]` | **resurrect as page** | about · officers · roster/portfolio · join; replaces unit drawer |
| `/skills` | **new (read view)** | the skill tree + who holds what; admin editing stays in Settings |
| `/review` | **new (shared)** | scope-filtered approvals; `/admin/forge-queue` content folds in |
| `/wallet` | keep | the *only* STR surface; gains the ledger from /my |
| `/community` | **delete** | People tab → /people; Chapters/WGs → /units/[id] index; Badges → /skills |
| `/guide`, `/str`, `/login` | keep | |
| `/admin/*` | keep consoles, fix names | guessable slugs: `/admin/officers`, `/admin/skills`, `/admin/economy`, `/admin/projects`, `/admin/announcements`; review moves out to `/review` |
| ~20 redirect/stub routes | **delete files** | redirects kept only where bookmarks plausibly exist (`/officer`, `/community`) |

### 4.3 Component kill list

Delete: CardDrawer, ForgeCard, Matcher, MatchConsole, SlotSeater, CardBinder,
SlotBoard, MemberCard, CommitChip, ProjectSlotCard, Leaderboard, StartHere,
GettingStarted, Hint, LaunchBanner (after import check), UnitDrawerBody
(becomes the unit page body).

Survivors promoted to the primitive set (§5): EntityCard (link-only),
InlineField, TaskBoard (→ EditableTable), SkillCapacity, MatchBoard (→ Match
desk), NeedPost (→ InlineForm pattern), ProjectTeam, SettlementForm,
NotificationInbox, Medal, CountUp, AdminConsole, LookupEditor.

---

## 5. The element system

One set of primitives, each owning one grammar rule. Everything on every page
is composed from these — no more bespoke variants.

**Layout**
- `Page` — breadcrumb · title · subtitle · one primary action (rule 4). Every
  route starts with it.
- `Panel` — the section card (today's `.card stack` formalized: header, count,
  optional header-action).
- `Tabs` — URL-keyed (`?tab=`), arrow-key navigable.

**Display**
- `EntityCard` — link-only (`href` required), right-edge › handle. The only
  grid card.
- `Row` — the only list row: leading identity, middle facts, trailing
  actions-on-hover. (Team rows, need rows, ledger rows, queue rows — all this.)
- `Chip`, `StatusDot`, `LevelDots` (●◐○ + label, colorblind-safe),
  `CapacityBar` (red-before-block), `Stepper` (status pipeline), `Metric`,
  `Medal`.

**Edit**
- `InlineField` — single value (rules 3, 6). Spread to every editable field.
- `InlineForm` — expandable create form, Submit+Cancel at bottom (rule 5).
  NeedPost generalized; the create-project form becomes one.
- `EditableTable` — TaskBoard generalized: inline cell pickers, optimistic,
  per-row hover actions.
- `Picker` — person / skill+level / resource-type select, one implementation.

**Feedback**
- `Toast` — success · error · **undo** (rule 7). One global outlet, top of the
  content column. The codebase currently has zero of these.
- `EmptyState` — sentence + the one button (rule 10).
- `Skeleton` — card / row / table shapes (rule 9).
- Spinner-in-button stays (`.spin`).

The visual tokens (Direction C palette, Inter/JetBrains Mono, radius, shadows,
motion) are untouched — this is structure, not paint.

---

## 6. Surface-by-surface

**Home** — stays the triage router, with two upgrades: (a) every item carries a
deep link that lands highlighted on the exact row (rule 2); (b) items are
grouped by hat when you wear several ("As Beijing Chapter officer · As M&M
leader"). "All clear" state teaches the next non-urgent action instead of going
blank.

**My work (`/my`)** — three groups, only the non-empty ones render:
*Tasks I own* (kanban, unchanged) · *Waiting on me* (approvals preview, links
to /review) · *My commitments* (where my hours go, with remaining/total). The
STR ledger leaves for /wallet; a single quiet line ("Settled STR this month:
+120 → Wallet") remains.

**Projects (`/projects`)** — grid of EntityCards (already link-only). The
create form becomes an InlineForm. `?mine=1` lens for the nav's "My projects".
Hall of fame collapses to a footer Row list.

**Project page** — already strong post-fixes; changes: Page header (primary
action = the *next* lifecycle verb: Post a role → Advance → Finish → Settle —
one button that always knows what's next, rule 4 + the Finish lesson);
Draft & links + Meetings as Panels with teaching EmptyStates; History gets
actor+time always (already fixed in mock; verify live).

**People (`/people`)** — becomes the community's people home (Directory's
People tab folds in):
- Hero: **the Match desk** (officer-only render). Two directions: *by need*
  (default — ranked candidates, capacity bars, Assign) and *by person* (pick a
  free person → the needs they qualify for). URL-stateful: `?need=x` /
  `?person=y` arrive pre-expanded — Home items and notifications land here.
- Below: the roster grid (EntityCards, `x/y h/mo` capacity, "time not set"),
  search, `mine` filter persisted per-user.
- Officer-only Add-a-person InlineForm.

**Person page (`/members/[id]`)** — structure stays (Overview · Skills &
capacity · Projects · Resources); changes: self-view copy is first-person
("You can give 10 h/mo"); managed view shows the ✎ editable cue (done); every
fact Row gains hover-edit where permitted; "request a change" affordance for
members on fields they can't edit directly (issue #10b).

**Unit page (`/units/[id]`)** — new, replaces the drawer: identity header
(kind chip, officers as person Rows) · *Chapter:* roster grid + free-time
summary · *WG:* project EntityCards + open-needs Rows · Join/Apply as the
primary action for non-members · InlineField editing for its officers.

**Skills (`/skills`)** — read view of the tree: domain groups, leaf skills as
Rows (who holds it at what level, evidence counts). Award/level-change actions
appear only for those with the capability. Admin tree/rate editing stays in
Settings.

**Review (`/review`)** — the shared approvals desk. Queue of Rows grouped by
kind (applications · over-capacity · settlements · skill submissions), each
with inline Approve / Decline + a one-line consequence ("approving grants
20 h/mo against Beijing's pool"). Scope = your hats; admins see all. Badge
count in the nav. Approving toasts with undo (rule 7).

**Wallet** — unchanged visually; gains the ledger that left /my and is now the
*only* place STR numbers render large.

**Settings (`/admin`)** — consoles unchanged (they tested well), but: slugs
renamed to match their labels, review content moved out to /review, all tables
get the Toast/EmptyState/Skeleton primitives, copy de-jargoned (rule 12).

**Guide** — content stands (now 4 languages); add per-hat quick-start cards at
the top ("You run a chapter → 3 steps") linking into the lenses.

---

## 7. The three golden flows (acceptance tests for v2)

Each must complete from a cold login in ≤3 clicks from Home, with every write
confirmed by a toast and surviving reload. These become the standing subagent
usability scripts.

**Chapter officer — staff a need:**
Home "2 needs match your people" → lands on /people with the need expanded →
Assign (capacity bar live) → toast "Assigned Wang Fang · 10h [Undo]" → need
fill count updates everywhere.

**WG officer — run the paper to settlement:**
Home "ml-Tagging: 2 unowned tasks" → project page, rows highlighted → set
owners inline → primary button walks Advance → Finish → Settle → split sheet →
toast → wallet shows settled.

**Admin — govern without hunting:**
Home "3 items in review" → /review → approve with undo → Settings consoles for
config — never more than one guess deep (slugs match labels).

---

## 8. Vocabulary pass (rule 12)

| internal / current | UI says |
|---|---|
| forge / mint | submit / create |
| card (member-card) | person *(managed badge: "managed by officer")* |
| steward (verb) | manage |
| accruing | building up *(wallet keeps "accruing" with its tooltip)* |
| claim (leader) | take the first-author seat |
| org unit | chapter / working group (never "unit" alone) |
| slot | need *(leader slot = first-author seat)* |
| guild | skills |

One sweep across UI strings + the four language packs.

---

## 9. Migration plan — six steps, each shippable

The order minimizes risk: primitives first (invisible), then structure, then
the cull.

- **M0 — Primitives.** Toast/undo · EmptyState · Skeleton · Page · Row ·
  InlineForm · EditableTable extraction. Retrofit nothing yet; just make them
  exist. *(No user-visible change.)*
- **M1 — Feedback retrofit.** Every existing write goes through Toast; every
  list gets EmptyState/Skeleton; disabled controls get explanations. *(Grammar
  rules 7–10 land everywhere at once.)*
- **M2 — Shell.** Role-shaped nav with lenses; STR retreat to Wallet; /my →
  My work. *(Faults 1, 4, 5.)*
- **M3 — The seam.** Match desk hero + URL state; Home/notification deep links
  land on rows. *(Faults 2-deep-link, 3.)*
- **M4 — Pages for everything.** /units/[id] page, /skills, /review (folding
  forge-queue), delete /community + CardDrawer. *(Faults 2, 4-approvals.)*
- **M5 — The cull + vocabulary.** Delete the deprecated component generation
  and redirect routes; vocabulary sweep across 4 languages; admin slug rename.
- **Then:** re-run the three cold-test subagents (golden flows §7) and compare
  against this round's reports.

Each step is a deployable commit batch; M0–M1 carry zero regression risk.

---

## 10. What v2 deliberately does *not* do

- **No domain-model change.** Six nouns, two logics, quiet STR — all PRD-final.
- **No visual redesign.** Direction C tokens, type, motion stay; every survey
  and tester rated them the strongest asset.
- **No prose editor.** The writing stays in Overleaf et al. (decided earlier);
  Draft & links + honest copy is the answer.
- **No member-facing buildout** beyond first-person copy and request-a-change —
  Phase 1 is officers-first; the member experience grows when members log in.
