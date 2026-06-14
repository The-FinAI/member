#!/bin/bash
# Replies for the 2026-06-14 wave (#16–#35). Run from repo root: bash scripts/comment-issues-0614.sh
# GitHub posting is gated to a human in this workflow — review wording, then run.
set -e

# --- The framing reply, on the two "stop changing things" issues (#25, #30) ---
FRAMING="Thank you — and please keep them coming. A quick note on *why* you're seeing the interface move so often, because it's intentional, not churn for its own sake.

This system is being built by continuous iteration: we ship a change, you (and other members) react, we digest the reactions, and after each pass we check which suggestions are now absorbed and which are still open. Your steady stream of suggestions is the **input** to that loop — the most useful thing you can do is keep proposing, exactly as you have been. We don't expect to arrive at the right design in one shot; we expect to converge on it by doing this repeatedly.

Two concrete commitments from this round:

1. **We now treat every issue you file as a permanent test case.** Each one is added to our simulated usability runs (three roles, no hints), and for each we also ask *why our own simulation didn't catch it first* — so the class of problem gets found automatically next time, not just this instance. (#24 back-button, #32 assignment errors, #26 save, #33/#35 confirm-and-undo all exposed real gaps in how we were testing; those gaps are now closed in the test protocol.)
2. **For consequential actions we're adding the safety you asked for** — confirm before status changes and role assignments, a visible way to undo/remove afterwards, and clearer save/error feedback. These are corrections, not redesigns.

So: you should feel free to keep suggesting without worrying that you're 'causing' rework — the iteration is the method. We'll keep a running note of which of your points are digested in each release."

gh issue comment 30 --body "$FRAMING"
gh issue comment 25 --body "Replying to the broader point on #30 — short version: the frequent change is the development method, not thrash, and your suggestions are the signal that drives it. Please keep filing them. Details on #30."

# --- Real bugs: acknowledge with the cause we found ---
gh issue comment 24 --body "Confirmed, and it's our fault: the landing page redirects \`/\` → \`/projects\`, which breaks the browser Back button (Back lands on \`/\`, which immediately forwards again). Fixing the redirect so Back behaves normally. Thanks for catching it — our simulated tests never pressed the browser Back button, which is now part of the protocol."

gh issue comment 32 --body "Two real problems here, both being fixed: (1) the error should name *which* requirement is missing (e.g. 'needs HCI · Lead; candidate has HCI · Independent'), not just 'does not meet requirements'; (2) a candidate who genuinely qualifies for a Lead/First-author seat should be assignable. Could you confirm the member + the role you were trying to fill so we verify the exact case? Our test seeds always matched, so the failing path was never exercised — that's fixed in the test plan now."

gh issue comment 26 --body "Understood. Availability currently saves automatically the moment you change the number, with no explicit button — which is exactly why it feels like nothing happened. We'll add a clear Save action and a confirmation so the save is visible. (This was a real blind spot: our tests treated auto-save as success; a person reasonably distrusts a save they didn't trigger.)"

gh issue comment 27 --body "Trying to reproduce — on the current build clicking the STR balance does navigate to /wallet and render it. If you still see the URL change without the page changing, could you tell us your role/account and whether a hard refresh fixes it? Want to make sure we fix the real cause and not just the case we can see."

gh issue comment 16 --body "Could you say which page this screenshot is from? The crop doesn't show the surface, and we want to fix the right one. If it's a lower-half-blank, note whether scrolling or a refresh restores it — that helps us tell a layout bug from a render glitch."

# --- Confirm + undo cluster: one coherent reply across #33/#34/#35 ---
gh issue comment 35 --body "Agreed — status changes (and other state-changing admin actions) should ask before committing. Adding a confirm step: 'Change <project> status to <status>?' before it applies. Grouping this with #33 (assignment confirm + undo) and #34 (the create⇒edit/undo/delete symmetry) as one focused safety pass — no UI restructuring."

gh issue comment 33 --body "Yes. Assigning a role — especially First Author — should confirm first and be removable/replaceable afterwards. Building: a confirm dialog on assign, and a remove/replace control on each seated person. Tracked together with #35 and the #34 audit."

gh issue comment 34 --body "We'll do this audit as written, and *without* redesigning the UI during it. The core rule — every create/claim/assign/post must also have a reachable edit, undo, remove or delete — is now an explicit acceptance criterion in our test protocol (previously we only tested the forward path, never the reverse, which is precisely why #33/#35/#26 slipped through). We'll post the three-role lifecycle table (Chapter Officer / WG Leader / First Author × create/view/edit/save/undo/delete) when it's done."

# --- Design decisions (acknowledge; pending product call) ---
gh issue comment 17 --body "Noted. We just reworked the dark ('night') edition's colors; rather than delete it we'd like one more pass at contrast. If specific text is still hard to read, a screenshot of that spot would help us target it. If it stays unreadable we'll consider removing the toggle."
gh issue comment 21 --body "Real inconsistency: the legacy Craftsman/Master badge scale and the current Learning/Independent/Lead skill levels are two parallel systems with no defined relationship. We'll pick one authoritative scale and either map or retire the legacy badges. Thanks — this only shows on the member profile, which our main-flow tests skipped."
gh issue comment 18 --body "Agreed on removing the duplicated bottom nav links. On the 'free time' card — it's meant to be a one-tap shortcut into staffing, but if it reads as redundant next to the roster we'll rethink its placement. Folding into the next incremental pass."
gh issue comment 19 --body "Fair — that arrow has no label. It indicates a suggested skill-level raise earned from the record. We'll either add a tooltip/label or replace it with explicit text so its meaning isn't a guess."
gh issue comment 22 --body "This is being addressed: 'People' is becoming the plain member roster, and the matching/staffing workflow moves into the project where the need lives — so the two labels stop overlapping. Live after the next deploy; let us know if the split still reads wrong once it's up."
gh issue comment 23 --body "Looks like seed/title data rather than something you set — we'll check why that position is assigned and correct it. Thanks for flagging."
gh issue comment 28 --body "Agreed — the guide should be organized by the actual roles (Chapter Officer / WG Leader / First Author) and their permissions, not high-level actions. Restructuring it that way, and (per #29) adding a check that the guide and the live UI stay in sync after each change."
gh issue comment 29 --body "Adopted as a standing check: after each change we verify the guide still matches what the UI does. It's now an assertion in our test protocol (guide role-section ↔ reachable, matching surface)."

echo "All 2026-06-14 comments posted."
