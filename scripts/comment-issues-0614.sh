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
gh issue comment 24 --body "Fixed — it was our fault: the landing page JS-redirected \`/\` → \`/projects\`, so Back landed on \`/\` and bounced forward again. \`/\` (and \`/opportunities\`) now redirect at load time, before they become history entries, so Back returns to the real previous page. The internal links that pointed at \`/\` were repointed too. Thanks for catching it — our simulated tests never pressed the browser Back button, which is now part of the protocol. Live after the next deploy."

gh issue comment 32 --body "Fixed — root cause was that the candidate list and the seating gate checked DIFFERENT competency scales: the matcher ranks by the current Learning/Independent/Lead skill, but seating enforced the legacy Craftsman/Master badge table — so someone could look assignable yet be rejected. Seating now uses the same Learning/Independent/Lead scale the matcher shows, so a qualified candidate (incl. Lead / First Author) can actually be seated, and if a requirement isn't met the error now NAMES it (e.g. 'requires HCI · Lead'). This also resolves the enforcement half of #21. Live after the next deploy — if you can still name the member + role that failed, we'll re-verify that exact case."

gh issue comment 26 --body "Fixed — availability no longer saves silently. The hours field now shows an explicit Save button the moment you change it (Enter also saves), and a confirmation toast appears once it's stored. (Real blind spot: our tests treated auto-save as success; a person reasonably distrusts a save they didn't trigger — that's corrected in the test protocol too.) Live after the next deploy."

gh issue comment 27 --body "Trying to reproduce — on the current build clicking the STR balance does navigate to /wallet and render it. If you still see the URL change without the page changing, could you tell us your role/account and whether a hard refresh fixes it? Want to make sure we fix the real cause and not just the case we can see."

gh issue comment 16 --body "Could you say which page this screenshot is from? The crop doesn't show the surface, and we want to fix the right one. If it's a lower-half-blank, note whether scrolling or a refresh restores it — that helps us tell a layout bug from a render glitch."

# --- Confirm + undo cluster: one coherent reply across #33/#34/#35 ---
gh issue comment 35 --body "Fixed — changing a project's status now asks first: 'Change <project> status to <status>?', and the irreversible step (submitting a project as Finished → settlement) shows a stronger warning. Reversible toggles (Hold / Resume) stay one-click since the opposite button undoes them. Live after the next deploy."

gh issue comment 33 --body "Fixed — assigning a role now confirms before it commits (First Author is flagged as high-impact), and every seated person has a Remove control on the project team that frees their seat and reopens the need. So an assignment can be undone/replaced, not just made. Live after the next deploy."

gh issue comment 34 --body "Done as written, without redesigning the UI. The core rule — every create/claim/assign/post must also have a reachable undo/remove — is now enforced in code (a new unassign() backs the team Remove control) and is an explicit acceptance criterion in our test protocol (we previously only tested the forward path, which is why #33/#35/#26 slipped through). Full three-role lifecycle table (Chapter Officer / WG Leader / First Author × create/view/edit/save/undo/delete) to follow."

# --- Design decisions (acknowledge; pending product call) ---
gh issue comment 17 --body "We reworked the dark ('night') edition's palette and just lifted the dimmer text a notch for readability, rather than delete the toggle. If a specific spot is still hard to read, a screenshot of it would let us target that exact contrast. Live after the next deploy."
gh issue comment 21 --body "Half fixed, half a pending product call. The concrete bug — that the two scales (legacy Craftsman/Master badges vs current Learning/Independent/Lead) disagreed and broke assignment — is fixed: Learning/Independent/Lead is now the single authoritative scale and the one enforced when seating people (see #32). The remaining question is purely about DISPLAY: whether to retire the legacy badges entirely or keep them as a separate 'past recognition' label. We'll decide that deliberately rather than rush it. Thanks — these badges only show on the member profile, which our main-flow tests skipped."
gh issue comment 18 --body "The duplicated bottom navigation should already be gone: the old Home page (which carried those bottom links) was folded into a 'What needs you' strip at the top of Projects, so there's now one nav (the top bar). Please confirm once the next deploy is up. On the 'free time' card — it's a one-tap shortcut into staffing; if it still reads as redundant next to the roster we'll rethink its placement."
gh issue comment 19 --body "Fair — that arrow has no label. It indicates a suggested skill-level raise earned from the record. We'll either add a tooltip/label or replace it with explicit text so its meaning isn't a guess."
gh issue comment 22 --body "This is being addressed: 'People' is becoming the plain member roster, and the matching/staffing workflow moves into the project where the need lives — so the two labels stop overlapping. Live after the next deploy; let us know if the split still reads wrong once it's up."
gh issue comment 23 --body "Looks like seed/title data rather than something you set — we'll check why that position is assigned and correct it. Thanks for flagging."
gh issue comment 28 --body "Agreed — the guide should be organized by the actual roles (Chapter Officer / WG Leader / First Author) and their permissions, not high-level actions. Restructuring it that way, and (per #29) adding a check that the guide and the live UI stay in sync after each change."
gh issue comment 29 --body "Adopted as a standing check: after each change we verify the guide still matches what the UI does. It's now an assertion in our test protocol (guide role-section ↔ reachable, matching surface)."

echo "All 2026-06-14 comments posted."
