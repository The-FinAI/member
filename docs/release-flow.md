# Staged release flow

Ship a release to a small **preview** group first (they look it over), then to
**everyone**. One page, two buttons, no spam risk.

## Pieces
- **`/admin/release`** — compose subject + body, see recipient counts, send each stage.
- **`announce-release`** edge function (`supabase/functions/announce-release`) — sends via Resend to whatever `release_recipients(audience)` returns.
- **`release_recipients(audience)`** RPC (migration `20260615020000`) — returns the email list; the `manage_members` gate is in its WHERE clause, so an unauthorised caller gets an empty list and nothing is sent.
- **`member.is_release_reviewer`** — the preview group is whoever is flagged.

## One-time setup
1. `supabase db push` (brings `release_recipients` + `is_release_reviewer`).
2. `supabase functions deploy announce-release` (it reuses the existing `RESEND_API_KEY`, `INVITE_FROM`, `SITE_URL` secrets).
3. Flag the preview reviewers:
   ```sql
   update member set is_release_reviewer = true
   where email in ('zhuoranlu34@gmail.com', '<yuechen-email>');
   ```

## Each release
1. Open **Settings → Release notes** (`/admin/release`).
2. Edit the subject/body (it's prefilled with the current notes; blank lines → paragraphs, `- ` lines → bullets).
3. **Stage 1 — Send preview** → emails only the flagged reviewers. Wait for their OK.
4. **Stage 2 — Send to everyone** → emails every member with an address (confirm-gated, marked danger).

The counts on each button (`· N`) show how many will receive it before you click.
