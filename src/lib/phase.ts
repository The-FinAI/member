// ---------------------------------------------------------------------------
// Rollout phase gate.
//
// Phase 1 is OFFICERS ONLY: ordinary researchers are not invited yet. Officers
// forge cards (identity + skills + resources) for the people who work under
// them and claim their chapter's projects. The member self-service surfaces —
// paid Guild role-card requests, the first-run onboarding checklist, and member
// invites — are hidden until Phase 2.
//
// To switch the member economy on, set PHASE to 2. Everything gated on PHASE2
// (the self-service Guild request, GettingStarted, the Invite Members admin
// tile) lights up at once; nothing else needs to change.
//
// Project bonds (leader/join stake) intentionally stay live in Phase 1.
// ---------------------------------------------------------------------------
export const PHASE = 1;

/** True once the member self-service economy is open (Phase 2+). */
export const PHASE2 = PHASE >= 2;
