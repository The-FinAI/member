# Handoff — community.thefin.ai

For the next agent (or person) picking this repo up. Last updated **2026-09-19**.
Read this, then `AGENTS.md` for the short rules, then the last three retros at the
bottom of [`usability-sim.md`](usability-sim.md).

---

## 1. What this is

The membership and project system of **The Fin AI** research community, live at
<https://community.thefin.ai>. The owner and final decision-maker is the
**President** (Jimin Huang).

Since 2026-08-23 the product **is one page, `/market`**. `/` redirects there.
The only other routes that matter are `/login` and `/admin` (the President's door
for settlement; the other `/admin/*` consoles predate the market and are legacy).

The model is two-sided:

- **Working groups** own **projects**. A project posts **seats**: first author,
  authors, and resource needs.
- **Chapters** hold **people**. A person brings **hours** (monthly capacity),
  **skills**, and **resources** (GPU, funding, API credits, datasets…).
- They meet when a person takes a seat. Either hours or a resource can earn
  authorship, under any role (first / co-corresponding / last / author).
- Contributions accrue **STR** (1 hour = 10 STR; resources by valuation). STR is
  nominal until the President settles a project.

Governance **v0.3**: permissions are suspended — any signed-in member can edit
anything on `/market`. Settlement and minting stay President-only. The full
permission story is in [`architecture.md`](architecture.md) (see its v0.3 section).

**Meeting view** (`▶ Meeting` on `/market`) is the screen officers share in their
weekly meetings: *Board → a group's agenda → one item per screen*, with `← / →`
and `Esc`. Two lanes on one spine: working groups walk **projects**, chapters walk
**people** (fill capacity, skills and resources, then seat them on open seats).

## 2. Stack and where things are

SvelteKit 2 · Svelte 5 runes · `adapter-static` → GitHub Pages · Supabase
(Postgres 17, PostgREST, GoTrue, edge functions, Resend for mail).

| Path | What it is |
|---|---|
| `src/routes/market/+page.svelte` | The whole product: data load, project rows, member column, all mutations |
| `src/lib/Meeting.svelte` | Meeting view: board, agendas, project focus, both lanes, add-project/member sheets |
| `src/lib/PersonFocus.svelte` | Meeting view's person screen (capacity, skills, resources, seats to take) |
| `src/lib/PersonPick.svelte` | Type-to-search person picker |
| `src/lib/mock-supabase.ts` | In-memory model of the database and every RPC the UI calls (mock mode) |
| `src/lib/messages.ts`, `i18n.ts` | Translations. The English string is the key; zh/ja/fr tables; missing → English |
| `supabase/migrations/` | **The** schema history. ~100 files. Everything goes through here |
| `supabase/tests/` | `rpc_smoke.sql` (drives every RPC), `e2e_seed.sql` + `e2e_reset.sql` (real-DB e2e world) |
| `tests/e2e/market.spec.ts` | The e2e suite (M1–M22), runs in both lanes |
| `tests/e2e/_shots.spec.ts` | Documentation screenshots, skipped unless `SHOTS=1` |
| `static/meeting/*.png` | Public screenshots (mock data only — this repo and site are public) |
| `scripts/sync-venues.mjs` | Weekly venue deadline/notification scraper |
| `scripts/e2e-db-setup.mjs` | CI helper: mints JWTs, creates test users for the real-DB lane |
| `docs/usability-sim.md` | Retros: every time a real user found what the tests missed, and why |

**Legacy, don't build on:** the `*.sql` files in the repo root (pre-migration era,
superseded by `supabase/migrations/`), most of `docs/` dated June 2026 (planning
history), and `src/routes/admin/*` other than the settle flow.

## 3. Run and test

```bash
npm install
npx vite dev --mode mock        # seeded in-memory world, no backend needed (.env.mock)
npx playwright test             # mock lane, ~45s, expect "22 passed, 1 skipped"
SHOTS=1 npx playwright test _shots   # regenerate static/meeting/*.png
```

CI (`.github/workflows/`), all on push to `main`:

| Workflow | What it proves |
|---|---|
| `deploy.yml` | Builds and publishes to GitHub Pages |
| `e2e-db.yml` | **Real-DB lane**: dumps the live schema into a vanilla Postgres 17 + GoTrue + PostgREST behind nginx, seeds `e2e_seed.sql`, resets it before every test, runs the same Playwright suite serially with `E2E_DB=1` |
| `schema-smoke.yml` | Only when `supabase/**` changes: replays pending migrations on a dump of prod and drives every RPC as a signed-in member |
| `sync-venues.yml` | Mondays 06:00 UTC: refreshes venue deadlines and notification dates |

The **mock lane is local only** — CI runs the real-DB lane. Run the mock lane
yourself before pushing.

**Reading test results honestly.** Use `set -o pipefail` or no pipe at all.
`npx playwright test | tail` reports *tail's* exit code, which is always 0 — that
produced false greens here once. A result counts when playwright's own exit code
is 0 **and** the literal `N passed` line is in front of you.

## 4. How changes reach production

- **Code**: push to `main` → deploy + real-DB e2e (+ schema smoke). All green or
  it isn't done.
- **Schema and data**: a new file in `supabase/migrations/` named after the last
  timestamp. **Data migrations are guarded**: every block starts with
  `if not exists (select 1 from <table> where id = '<uuid>') then return; end if;`
  so it no-ops on the schema-only CI clones and runs for real on prod. Push → CI
  validates → **the President runs `supabase db push` himself.**
- **Agents never hold the database password** and never write to production
  directly. If a connection string with a password appears in a conversation, do
  not use it; point out that it should be rotated.
- **Reading production is fine**: read-only SQL through the Supabase Management
  API query endpoint, authenticated with the operator's own `supabase login`.
  Never mutate through it.
- **Email** goes out only when the President says to, per send. Pattern: a one-off
  edge function using the `RESEND_API_KEY` secret, sender
  `The Fin AI <community@thefin.ai>`; invoke once; then delete the function and
  its local folder.
- **GitHub issues**: comment on them; never close them.

## 5. Data model — the parts that bite

- `org_unit.kind` is `chapter` or `working_group`. `member.home_unit_id` points to
  a **chapter**; `project.org_unit_id` points to a **working group**.
- `member.kind = 'card'` means no login yet; a member is registered once
  `auth_user_id` is set. Cards created from OpenReview imports carry a placeholder
  address `<slug>@pending.thefin.ai` — OpenReview masks other people's emails;
  never guess a real one. There is **no RPC to edit a member's email** yet.
- `project_slot.slot_kind`: `leader` (first-author seat), `work_labor`,
  `work_resource`. The slot's `authorship` is the role of the *opening*.
- `work_commitment` is a **monthly ledger** — one row per (slot, member,
  `year_month`), upserted. The live amount is the **latest month**; STR nominal
  accrues across all months. Summing months in the UI made hour edits only ever
  grow — don't.
- `monthly_amount`'s unit depends on the slot: hours for `leader`/`work_labor`,
  the resource type's unit for `work_resource`. A person's capacity
  (`member.monthly_hours`) is **hours only**; resource commitments never count
  against it.
- The seated author's role lives on **`work_commitment.authorship`**
  (`seat_set_role` stamps all of a member's rows on a project). Slots are shared
  and people hold several commitments, so the slot's role is only a fallback.
- `assign()` only accepts a `work_resource` seat from someone who **holds** a
  resource of that type. The UI records the resource for them first.
- `org_unit_officer (org_unit_id, member_id, role, started_on, ended_on)` keeps
  history; ending a term sets `ended_on`, it doesn't delete the row.
- Reference migrations for common surgery:
  `20260824090000_merge_yi_han.sql` (merge duplicate members: repoint every
  foreign key found in `pg_constraint`, then delete) and
  `20260918010000_merge_mm_into_agent.sql` (merge working groups).

## 6. Frontend conventions that exist for a reason

- **Never read `$state` inside a data-loading `$effect`** — it self-tracks and
  loops forever (this froze the whole page once). Use a plain `let` flag.
- **Form drafts are plain objects**, not `$state`: a reactive draft re-renders the
  row and closes the open `<details>` the user is typing in.
- **Optimistic edits**: mutate locally, call the RPC through `run()`, which
  reloads on error (that reload is the rollback).
- **Track the focused item by id, not index** — lists re-sort after edits.
- **A class name is either a utility or a modifier, never both.** `.dim` was both
  a fixed full-screen overlay and a row modifier; every in-review row became a
  white veil over the page.
- Global `app.css` defines `.card`, `.row`, `.tile`, `.chip` and `button`; scoped
  component classes win on specificity but inherit whatever they don't override.
- Realtime: one schema-wide `postgres_changes` channel, 600ms debounce, triggers
  `load()`. Tests use `ensureOpen()` because a background reload can collapse an
  open `<details>` between two clicks.

## 7. Why tests missed things — and how not to repeat it

- **The mock is our model of the world.** Each time it was looser than Postgres, a
  bug shipped: a typeless value where Postgres wanted a uuid; append instead of
  upsert on the monthly ledger; no resource-holder check in `assign`. When you
  touch an RPC in the mock, copy the SQL's validation, not just its happy path.
- **Seeds must cover every state the UI branches on** — stage (including *Under
  review* and *Hold*), a member with no capacity, a resource contributor — not
  just every feature. The `.dim` bug hid for a day because no seeded project was
  in review; production had almost nothing else.
- **A bug that only reproduces in production**: open the site signed in and read
  the live DOM — computed styles, which stylesheet rules `element.matches()` —
  before theorising from screenshots. Two screenshot-based fixes were wrong first.
- **Every user-found bug gets a regression test and a retro** in
  `usability-sim.md` answering "why did our tests miss it?".

## 8. Runbooks

**Importing authors from OpenReview (each ARR cycle).** Author lists of
double-blind submissions are visible only to their authors, so this runs in a
browser session where the President is signed in to openreview.net: fetch
`api2.openreview.net/notes?content.authorids=<his profile id>` from the page with
`credentials: 'include'`, filter to the cycle's invitations. Build a table of
paper → project and author → member for him to confirm (position 1 = first
author, last = last author, the rest authors; curated roles already on a project
win over position). Non-members become cards in the chapter matching their
verified OpenReview affiliation, with a placeholder email and
`links.openreview`. Everything lands through a guarded migration. Match names
**as token sets** — "Yi Han" and "Han Yi" are the same person and once became two.

**Venue dates.** `sync-venues.mjs` takes deadlines from ccfddl and scrapes each
conference's own site for the notification date; ARR is special-cased from its
official cycle table. Run locally for a dry run; CI writes with the service key.

**Announcing a change to officers.** Current officers:
`org_unit_officer where ended_on is null`. Screenshots from
`SHOTS=1 npx playwright test _shots` (mock data, safe to host publicly) are served
from `community.thefin.ai/meeting/*.png` and can be embedded in the email.

## 9. State on 2026-09-19

- Migrations applied through **`20260918010000`**; nothing pending.
- Working groups: **Agent** (leaders Yupeng Cao, Haohang Li, Yangyang Yu —
  Multilingual & Multimodal was merged into it on 2026-09-18), Information
  Extraction & Retrieval, Misinformation, Model. Chapters: North America, Europe,
  Asia-Pacific.
- Mock lane: 22 passed, 1 skipped. Real-DB lane and schema smoke green on `main`.
- Shipped in the last month: the one-page market, the meeting view with its
  working-group and chapter lanes, the person screen (capacity, skills,
  resources, seats to take), resource contributions as authorship, the monthly
  ledger fix, three OpenReview imports.

## 10. Open items

- **Roster data is thin.** Most members have no monthly capacity and most are
  unregistered cards; many projects still have an open first-author seat. Chapter
  chairs are backfilling — the chapter lane of the meeting view is the tool.
  Measure it fresh; don't trust numbers written down anywhere, including here.
- **No way to edit a member's email.** Placeholder `@pending.thefin.ai` addresses
  can't be replaced from the UI. Needs a small RPC migration plus a field on the
  member row and person screen.
- **Yangyang Yu** (new Agent leader) has not signed in yet.
- **The new Agent leaders haven't been briefed.** The 2026-09-13 officer
  announcement went out before the merge and lists the old leaders.
- **The mock lane isn't in CI.** A fast CI job for it would catch UI regressions
  before the slower real-DB lane.
- `messages.ts` produces duplicate-key warnings in the ja/fr tables — harmless,
  worth a cleanup.
