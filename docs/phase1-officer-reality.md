# Phase-1, from the officer's chair (the correction)

*This corrects `north-star.md`. That doc designed the **STR economy**. But the only person
using the product in phase 1 is an **officer acting as a proxy** for members who can't log
in. Designed from *their* lived task — not the system's model — the framing changes.*

---

## Who actually logs in (phase 1)

A grad student / lab member made **chapter secretary** or **group lead**. Not a product
person. Their job is concrete and mundane:

1. **Register my people** — who they are, what they're good at, hours/month.
2. **Staff them onto projects** — put the right person on the right work.
3. **When a paper lands, make sure credit reaches them.**

They do **not** care about: their own STR, "nominal vs liquid", mining, token mechanics,
"settle/harvest". For a *proxy*, their own balance is ≈0 and meaningless. They care about
**other people (their team) and the projects.**

## The mistake we made

We built the home around **"your STR"** (a claimable ring, a mining metaphor). That's the
**economy's** point of view, not the officer's. The officer is a **staffing coordinator**,
so the product they need is a **staffing board** — STR is background accounting that only
surfaces when it becomes real (settlement; and the member's own wallet in P2).

## What the officer's home should be

A **roster ⟷ projects allocation board**, not an STR cockpit.

**Chapter officer ("I steward people"):**
```
My team (8)                          Projects to staff
─ Zhang Wei   NLP·Adv  20h  ▓▓░ 14/20   ─ XBRL Tagging   needs: Writing(Adv)×2, 1 filled
─ Li Hua      Audit    10h  ░░░  0/10    ─ MoE Post-train needs: GPU 200h, RLHF
─ + Add someone                          ─ …
            ⟶ assign Li Hua to XBRL Tagging (10h)
```
- Each person: skills · monthly hours · **how much is allocated vs free** (the one number
  an officer scans for).
- Each project: **what it still needs** · who's already on.
- The one action: **assign a person to a project**, with hours. (This is "seat", but never
  called that.)

**Group lead ("I steward projects"):**
```
My projects
─ XBRL Tagging   Active   team 3/5   needs: Writing×2     [staff] [post a need]
─ Audit-LLM      Finished → distribute credit             [credit the team]
```
- Each project: staffing (on / still needed) · stage · the one stage-action
  (staff → post need → **finish & credit the team**).

STR shows up only as a quiet "credit so far" number on a person/project — never the hero.

## The operational vocabulary (what an officer would actually say)

| System / economy word (drop from the officer UI) | What the officer says |
|---|---|
| Need / open_need / slot | **a role / "needs a [skill]"** |
| Seat / bind / commit | **Assign · Add to project** |
| Contribution (valued in STR) | **hours/month** (e.g. "10h on XBRL") |
| nominal / liquid STR (as a hero) | **credit** (quiet); STR stays the unit, not the headline |
| Settle | **Finish & credit the team** |
| Forge / mint | **Add** |

Keep `STR / nominal / liquid` as the *underlying ledger* — correct and visible in the
wallet and at settlement — but the **officer's day-to-day language is people, projects,
hours, assign, credit.**

## What this changes in the build

1. **Replace the STR "cockpit"** on the officer home with the **staffing board** above
   (team with free-hours + projects with open roles + assign).
2. **The officer never sees "your claimable STR" as the headline.** The wallet still has
   it; the home doesn't lead with it.
3. **Relabel the actions** to operational verbs (Assign, not Seat; "needs Writing", not
   "Need: work_labor"; "Finish & credit", not "Settle").
4. **STR becomes legible only where it's real**: a person's accrued credit, a project's
   pool at settlement, the member's wallet (P2).

## The phase split, stated plainly

- **Phase 1 = a staffing tool for officers.** Hero = my team & my projects. STR = quiet
  background ledger.
- **Phase 2 = a contribution wallet for members.** Hero = *my* contribution & *my* STR.
  Same data, opposite point of view.

Build the officer staffing board now; the member STR view is the *other mode* of the same
shell, switched on in P2.

---

*HCI test, restated for phase 1: would a lab coordinator who's never read this doc look at
the home and know "these are my people, these are the projects, here's who I put where"?
If the first thing they see is their own STR, we've pointed the product at the wrong person.*
