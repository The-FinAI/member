# Role-based lifecycle audit (issue #34)

The rule under test (from #34): **every object a role can create / claim / assign /
post must also have a reachable way to view, edit, save, and undo / remove / delete.**
Audited against the actual RPCs and UI in the deployed build, not intentions.

Legend: ✅ present · ⚠️ partial / indirect · ❌ missing (gap).
Roles: **CO** = Chapter Officer · **WGL** = Working-Group Leader · **FA** = First Author.

---

## 1. Chapter Officer — stewards people, capacity, staffing

| Object | Create / Claim | View | Edit / Save | Undo / Remove / Delete | Confirm on risk | Error feedback |
|--------|----------------|------|-------------|------------------------|-----------------|----------------|
| **Person (card)** | ✅ Add a person (People) | ✅ roster + profile | ✅ name/email (`set_member_email`) | ❌ **no remove/archive of a card** | n/a | ✅ toast |
| **Skill on a person** | ✅ add skill | ✅ | ✅ one-tap level (`person_skill_set`) | ✅ remove (set level → none) | low-stakes | ✅ |
| **Capacity (hours)** | ✅ set | ✅ x/y per month | ✅ explicit **Save** (#26) | ✅ edit again | low-stakes | ✅ toast |
| **Assignment (seat a person on a need)** | ✅ assign (matcher) | ✅ team list | ✅ re-assign | ✅ **Remove** on team (`unassign`, #33) | ✅ confirm; FA flagged | ✅ toast + named skill-gap (#32) |

**CO gap:** a person card added in error cannot be removed or archived.

## 2. Working-Group Leader — stewards projects

| Object | Create / Claim | View | Edit / Save | Undo / Remove / Delete | Confirm on risk | Error feedback |
|--------|----------------|------|-------------|------------------------|-----------------|----------------|
| **Project** | ✅ create / claim | ✅ ledger + detail | ✅ name, summary, venue, group (`project_set_*`) | ❌ **no delete/archive** (only Hold) | ✅ status change + Finish confirm (#35) | ✅ toast |
| **Project status** | — | ✅ pipeline | ✅ advance/hold/resume | ⚠️ Hold↔Resume reversible; **Finished has no undo** (by design — gated by confirm) | ✅ confirm (Finished = danger) | ✅ toast |
| **Task** | ✅ add | ✅ board | ✅ owner/status/notes (`task_update`) | ✅ delete (`task_remove`) | low-stakes | ✅ toast |
| **Need (role/slot)** | ✅ post | ✅ Open needs | ✅ edit while unfilled (`need_update`) | ❌ **no delete/close of a need** | n/a | ✅ |
| **Draft links** | ✅ add | ✅ | ⚠️ remove + re-add (no in-place edit) | ✅ remove (`project_link_remove`) | low-stakes | ✅ |
| **Meetings** | ✅ schedule | ✅ | ⚠️ remove + re-add | ✅ remove (`project_meeting_remove`) | low-stakes | ✅ |
| **Settlement** | ✅ draft + submit | ✅ | ✅ weights before submit | ⚠️ submit is final (review-gated) | ✅ confirm (Finish) | ✅ |

**WGL gaps:** (a) a project cannot be deleted/archived — a test or mistaken project lingers (Hold is the only soft state); (b) a need posted in error cannot be removed, only edited; (c) links/meetings edit-by-replace rather than in place.

## 3. First Author — the project lead (a seat, matched like any need)

The FA is seated into the leader slot; on their own project they have the WGL record
powers above (task board, links, meetings, needs, status) via `can_edit_project`.

| Object | Create/Claim | View | Edit/Save | Undo/Remove | Notes |
|--------|--------------|------|-----------|-------------|-------|
| **First-author seat** | ✅ matched into it | ✅ shown on project | — | ✅ freed via team **Remove** (`unassign`) or `release_claim` | reopens as a need |
| **Own project record** | ⚠️ claims, doesn't create | ✅ | ✅ same as WGL | ✅ task/link/meeting/assignment removes | inherits project gaps above |

**FA note:** FA powers ride on `can_edit_project`; the same project-level gaps (no delete, no need-removal) apply.

---

## Summary — the three gaps to the #34 rule

The create→undo rule holds everywhere **except** three create paths that have no delete:

1. **Person card** — addable, not removable/archivable. *(CO)*
2. **Project** — creatable, not deletable/archivable; only Hold. *(WGL/FA)*
3. **Need / slot** — postable + editable, not deletable/closable. *(WGL/FA)*

Plus two soft edges: **links/meetings** edit-by-replace (cosmetic), and **Finished/settlement**
are intentionally one-way but now gated by an explicit confirm.

### Recommended fixes (each a small, focused RPC + control, no redesign)
- `member_archive(p_member)` → an "Archive card" action on the person profile (soft-delete, keeps history).
- `project_archive(p_project)` (or delete when empty) → an "Archive / delete project" action, confirm-gated.
- `slot_close(p_slot)` → a "Remove need" control on Open needs (only while unfilled), confirm-gated.

These three close the rule completely. None changes navigation or layout.
