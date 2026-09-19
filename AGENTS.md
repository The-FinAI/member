# AGENTS.md — community.thefin.ai

Membership and project system of The Fin AI research community. The product is
one page, `src/routes/market/+page.svelte` (plus `src/lib/Meeting.svelte` for the
meeting view). **Start with [`docs/HANDOFF.md`](docs/HANDOFF.md)** — current
state, data model, runbooks, open items.

## Commands

```bash
npx vite dev --mode mock     # local app on a seeded in-memory world (.env.mock)
npx playwright test          # mock lane — expect "22 passed, 1 skipped"
```

CI on push to `main`: deploy to GitHub Pages, real-database e2e lane
(`e2e-db.yml`), and schema smoke when `supabase/**` changes. The mock lane is
local only: run it before you push.

## Rules

1. **Schema and data change only through `supabase/migrations/`.** Data
   migrations are guarded (return early when their target rows don't exist) so
   they no-op on CI's schema-only clones. After CI is green, the President runs
   `supabase db push`. Agents never write to production directly.
2. **Never handle database passwords.** If one is pasted into a conversation, do
   not use it; say it should be rotated. Read-only SQL against production is fine
   through the Supabase Management API with the operator's own CLI login.
3. **Test results count only on playwright's own exit code plus the literal
   `N passed` line.** `playwright … | tail` reports tail's exit code (always 0).
4. **Keep the mock as strict as Postgres.** When an RPC changes, mirror its
   validation in `src/lib/mock-supabase.ts` — every mock-looser-than-SQL gap here
   shipped a bug.
5. **Seeds cover states, not just features** (Under review / Hold projects, a
   member with no capacity, a resource contributor). Add the state that triggers
   a bug to the seed together with its regression test.
6. **Every user-reported bug gets a regression test and a retro** at the bottom of
   `docs/usability-sim.md`: why didn't the tests catch it?
7. **Svelte 5 traps:** never read `$state` inside a data-loading `$effect` (infinite
   loop); form drafts are plain objects, not `$state`; track focused items by id,
   not index; a CSS class is a utility or a modifier, never both.
8. **This repo and the site's `static/` are public.** No secrets, no member emails,
   no real member data in screenshots (use mock data: `SHOTS=1 npx playwright test _shots`).
9. **Email is sent only on the President's explicit go-ahead**, per send (one-off
   edge function with `RESEND_API_KEY`, deleted after use).
10. **GitHub issues: comment, never close.**

Commit to `main` in small steps with clear messages; each push deploys.
