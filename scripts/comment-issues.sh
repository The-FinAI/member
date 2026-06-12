#!/bin/bash
# Post fix-notes on the GitHub issues we just resolved (run from repo root).
# Approved wording — see session 2026-06-12. Close them after deploy + db push.
set -e

gh issue comment 9 --body "Fixed — open needs now have an ✎ edit button on the project's Open needs list: you can change the skill / level / resource type / hours / headcount in place instead of deleting and re-posting. Needs that already have people committed are locked until they're released (so accruals stay consistent). Will be live after the next deploy."

gh issue comment 10 --body "Fixed — available time now shows as remaining/total per month (e.g. 3/8 h/mo) on both the member card and the People roster. People who never set hours show 'time not set' instead of nothing.

For the second part ('can only request a badge change, not a work-time change') — could you say which member hit this? On your own profile the monthly hours are directly editable; if it was an unclaimed member-card, the chapter officer edits it from the card's Skills & capacity section."

gh issue comment 11 --body "Fixed — the create-project form now has a Cancel button next to Create, so you can back out from the bottom of the form without scrolling up."

gh issue comment 14 --body "Fixed together with #10 — available time now displays as x/y per month (x = hours free now, y = total monthly hours) everywhere, and members with no declared hours show 'time not set'."

gh issue comment 15 --body "Fixed — the Guide is now fully translated (中文 / 日本語 / Français) and follows the language switcher, with terms consistent with the rest of the app."

gh issue comment 13 --body "Could you say which page this screenshot is from? It doesn't look like the create-project form from #11 — once we know the surface we'll add the exit/close affordance there too."

echo "All comments posted."
