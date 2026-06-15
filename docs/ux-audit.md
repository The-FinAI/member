# UX audit (issue #37)

Audited against modern SaaS / collaboration-tool standards. Each finding is
**Problem · Why · Fix (smallest) · Severity** (Critical / High / Medium / Low).
No redesign — smallest fix that resolves the issue. Several items from earlier
issues are already fixed and noted as such so this reads as a complete pass.

Surfaces covered: top nav, Projects (ledger + detail), People, Member profile,
Directory, Wallet, admin console, forms, feedback, empty states, mobile, i18n.

---

## 1. Navigation — "Where am I / what can I do / how do I get back"

**N1 · "Settings" in the top nav opens the admin console, not personal settings.**
- *Why:* "Settings" universally means *my* preferences; here it's `/admin` (officers/economy/announcements). A user looking for profile/notification settings is misled; a non-admin may see little.
- *Fix:* Rename the nav item to **"Admin"** (show only to users with an admin capability). Put any personal preferences under the account menu.
- *Severity:* **Medium**

**N2 · No breadcrumbs / back affordance on most deep pages.**
- *Why:* Project detail, admin sub-pages, wallet give no "where am I in the hierarchy" or one-click parent. The member profile has breadcrumbs; nothing else does.
- *Fix:* Add the existing `Breadcrumbs` component to project detail and admin sub-pages (Admin / section / page). Browser Back already fixed (#24).
- *Severity:* **Low–Medium**

**N3 · Notifications bell was invisible.** ✅ Fixed (#39) — now a bordered button matching its neighbours.

**N4 · Reaching your own profile is non-obvious.**
- *Why:* The only path to "my profile/portfolio" is the avatar menu; nothing is labelled "My profile."
- *Fix:* Add a labelled "My profile" item in the account menu (the avatar already opens it — just ensure the label exists).
- *Severity:* **Low**

## 2. Information architecture & terminology

**I1 · "Forge" jargon leaks into the UI.** *(Forge queue, Forge badge, ForgeCard…)*
- *Why:* "Forge" is internal metaphor, not a user word; "Forge queue" doesn't say what it queues.
- *Fix:* Rename user-facing strings: **"Forge queue" → "Review queue"**, "Forge badge"/"Forge officer" → "Award…/Invite…". (Code identifiers can stay.)
- *Severity:* **Medium**

**I2 · "People" vs "Directory" overlap.** ✅ Addressed (#22) — People is the roster; matching moved into projects.

**I3 · Two competency scales.** ✅ Fixed (#21) — one scale (Learning/Independent/Lead).

**I4 · "STR" / "Stater" appear before they're explained.**
- *Why:* New users see "STR" in the masthead with no inline definition; "Stater" still appears in one email/footer.
- *Fix:* Tooltip on the masthead STR figure linking to the guide's STR section; replace stray "Stater" with "STR".
- *Severity:* **Low**

## 3. Forms, feedback & the edit lifecycle

**F1 · Inconsistent save model: hours need Save, skills save on tap, resources go through review.**
- *Why:* Three different mental models in one card. A user can't predict whether an edit is saved/pending. (Hours Save = #26; resources have approval_status; skill taps commit silently.)
- *Fix:* Unify under the review lifecycle being built for #40 B (Save → Submit for Review → Pending/Approved/Rejected), with the *same* status chip on every editable field.
- *Severity:* **High** (this is the core of #40)

**F2 · Capacity shown two different ways / values.** ✅ Fixed (#40 A) — single Available-time source; Labor split out (#40 C).

**F3 · Write feedback.** ✅ Largely fixed — global toasts on assign/status/save/settle (#20/#31), confirms on consequential actions (#33/#35).

**F4 · Status-changing actions confirm; reversible ones don't.** ✅ Implemented (#35/#33) — Finish/assign/status confirm; Hold/Resume stay one-click.

## 4. Empty states & first run

**E1 · A brand-new officer lands on a near-empty ledger with no first step.**
- *Why:* If "What needs you" is empty and there are no projects, the page reads as broken rather than "start here."
- *Fix:* When the ledger is empty, show a one-line first-run card: "No projects yet — Start a project, or add people on People." (Buttons already exist; just the empty-state copy.)
- *Severity:* **Low–Medium**

**E2 · Wallet with no member record is a dead end.**
- *Why:* "No member record linked to this account yet." with no next step.
- *Fix:* Add a line + link: "Ask your chapter officer to link your card" / link to the guide.
- *Severity:* **Low**

## 5. Internationalisation

**C1 · Mixed-language UI in non-English locales.**
- *Why:* Some strings have no translation key and fall back to English mid-page — e.g. the "What needs you" sub-lines ("Open a project and assign them to a need", "Someone updated work that touches you") and the ledger facts ("needs", "team") render English even in 中文. Looks unfinished to Chinese/JP/FR users.
- *Fix:* Add the missing keys to `messages.ts` for the triage sub-lines and the ledger fact labels; sweep for untranslated `$t()` source strings.
- *Severity:* **Medium**

## 6. Mobile

**M1 · Project row title/badge overlap + masthead wrap.** ✅ Fixed (#36) — row stacks, brand on one line.
**M2 · Audit other dense surfaces at 375px** (settlement table, admin tables) — *Low*; tables should scroll-x rather than squish. Fix: `overflow-x:auto` wrapper on wide tables.

## 7. Consistency & status visibility

**S1 · Review status not visible for skills/hours.** → the #40 B lifecycle gives every editable field a Pending/Approved chip. **High**.
**S2 · Icon system unified.** ✅ (earlier) — one monoline set, no emoji mishmash.
**S3 · Project archive / need removal / person archive now exist.** ✅ (#34).

---

## Severity roll-up
- **High:** F1 / S1 — the edit-and-review lifecycle (this *is* #40 B; the single most-felt gap).
- **Medium:** N1 (Settings→Admin), I1 (Forge→Review), C1 (i18n fallback), E1 (empty first-run).
- **Low:** N2 (breadcrumbs), N4 (My profile label), I4 (STR tooltip), E2 (wallet dead-end), M2 (wide tables).

## Suggested order (smallest-fix first, no redesign)
1. i18n sweep (C1) and Forge→Review rename (I1) — pure string changes, high visibility.
2. Settings→Admin label (N1), empty-state copy (E1/E2), STR tooltip (I4), My-profile label (N4).
3. Breadcrumbs on detail/admin (N2), wide-table scroll (M2).
4. The edit-review lifecycle (F1/S1) = #40 B — the one structural piece.
