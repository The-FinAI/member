# User stories — test scenarios for the rebuilt flows

*Concrete, step-by-step scenarios to test the new architecture. Each has a persona, steps, and the
expected result. Use these for live verification after `db push` (real logic) and for local UI
screenshot review (rendering/vocabulary/layout). "✅ expect" = what should happen.*

Personas (Phase-1, officers as proxies):
- **Chen** — Chapter officer (stewards people).
- **Wang** — WG officer (stewards projects) + leads a project.
- **Li** — a member/card (no login in P1; appears as a person).
- **Admin** — President.

---

## US-1 — Chen registers a person and sets their skills (People + skills)
1. Chen opens **People** → clicks **＋ Add a person** → name "Li", email, affiliation → **Add**.
   ✅ Li appears in the roster.
2. Chen opens Li's card → **Skills** section → adds skill "Annotation" → taps **Independent** → sets **Capacity** 20h.
   ✅ skill shows `Annotation · Independent` with evidence `0 tasks · 0 shipped`; capacity bar = 20h.
3. ✅ No badge tree / certification queue in the main flow; "Certified badges" is a collapsed legacy block.

## US-2 — Wang creates & forms a project (Projects + matching seam)
1. Wang opens **Projects** → **Start a project** → name "ml-Tagging", type, proposal link → **Create project**.
   ✅ project created (free), appears with status; first-author seat is **open**.
2. Wang opens the project → **Open needs** → **＋ Post a role** → Skill "Annotation", level Independent, 10h, ×1 → **Post role**.
   ✅ "Posted · N people qualify"; the need shows in Open needs.
3. ✅ The page shows **Task board · Team · Open needs · First author: open — match on People** — no old slot/seat UI.

## US-3 — Chen matches Li onto the role (the seam, on People)
1. Chen opens **People** → "Match people to needs" → picks the **Annotation** need.
   ✅ ranked candidates show: Li `Independent · 0 tasks · 6h free`, capacity bar, grade dot.
2. Chen sets hours 6 → **Assign**.
   ✅ Li seated; need filled count ticks; capacity bar fills; Li gets a **notification** "assigned to ml-Tagging".
3. Over-capacity guard: try assigning more than free hours.
   ✅ bar turns red, **Assign disabled**, reason shown.

## US-4 — First author is matched like a need (leader = need)
1. On People matching, pick the **First author** need (a `leader` slot).
   ✅ it appears as a need ("First author · leader"); candidates ranked by capacity (no skill requirement).
2. Assign someone with writing hours.
   ✅ they become first author; the project's "First author: open" flips to their name.

## US-5 — Resource need (not just hours)
1. Wang posts a need → toggle **Resource** → type "GPU", quantity → **Post role**.
2. On People matching, pick the GPU need.
   ✅ candidates = people who **hold a GPU resource**, ranked by **remaining quota** (unit-aware), not skill.
3. Assign → consumes that resource's monthly quota; over-quota blocked.

## US-6 — Run the living record (task board replaces the doc)
1. Wang opens the project → **Task board** → adds a task "Confirm EN taxonomy", type Annotation, owner Li, status Doing.
   ✅ row added inline, optimistic (no full reload); Li notified "given a task".
2. A coverage group (e.g. "XBRL Coverage" with EN/JP rows, states Confirmed/Checking).
   ✅ renders as a grouped checklist.
3. Li opens **My tasks**.
   ✅ sees "Confirm EN taxonomy" under Doing, across all projects; can flip state.

## US-7 — Home is a router ("what needs you")
1. Wang signs in → **Home**.
   ✅ a triage list: "N tasks need an owner", "open needs on your projects", and (if a led project is finished) "Settle {name}". No mining cockpit, no STR hero.
2. Chen's Home → "N people have free time" → People; pending reviews if reviewer.

## US-8 — Finish & settle (STR appears only here)
1. Wang advances the project to Finished (pipeline / Finish).
2. Opens **Settlement** → weights default to logged hours → **fairness summary** ("shares total 100%"); a big-contributor/tiny-share is flagged.
3. Submit → review → STR paid.
   ✅ contributors' **Wallet** shows accruing → settled; Home no longer lists it as needing settlement.

## US-9 — Wallet & vocabulary (economy quiet & legible)
1. Open **Wallet**.
   ✅ "Your STR" = Settled + Accruing split; "How you earn STR" loop; **no** stake/bond/net-worth wording.
2. Across Home / Projects / People / task board: **no** words *slot · forge · nominal · stake · guild · harvest · Mint done*. (Finish, Accruing, Assign, Need, Task instead.)

## US-10 — Directory (browse, no leaderboard)
1. Open **Directory** → tabs People / Chapters / Working Groups / Badges.
   ✅ browse-only; **no** Standing/Leaderboard ranking; people sorted alphabetically.

## US-11 — Notifications
1. After being assigned / given a task, the **🔔 bell** shows an unread count.
   ✅ opening it lists the events; clicking marks read + navigates to the project.

---

### What local UI review CAN check (no DB): rendering, layout, vocabulary, navigation, empty states, the
5-surface IA, old-structure leftovers.
### What needs a live `db push` to verify: the RPC logic — match ranking, capacity hard-gate, leader
minting, assign→notify, settlement payout, person_skill backfill from badges.
