# Quality Loop — Review Contract and Waterfall Routing

This file defines the quality-loop contract shared by every phase: the two
loop tiers, the reviewer's JSON output contract, and how the main session
routes a verdict — including the waterfall fallback. Readers: the main
session (routing), and the `reviewer` on every review dispatch (output
contract). It is self-contained: a `reviewer` given only this file can
produce a correct reply.

## 1. Two loop tiers

- **Standard loop** — Explore, Prototype, Spec, TDD, and Build (per
  ticket): a single independent `reviewer` per round, capped at **3
  rounds**.
- **Heavy loop** — Review phase only: three `reviewer` lenses in parallel,
  then one `reviewer` triage, capped at **5 rounds**.

## 2. Review procedure

The reviewer receives artifact paths and judges independently — never
swayed by how confident the author's report sounds; key claims must be
re-verified first-hand. It replies with the JSON contract in section 6.
The main session routes on `verdict` and `findings[].targetPhase`.

## 3. Waterfall routing

Routing is driven **only by blocking findings**; non-blocking findings
never affect routing — they are picked up alongside in-phase revisions or
presented for awareness at the next approval gate.

- All blocking findings have `targetPhase` == the current phase → in-phase
  return to the author (Build: `SendMessage` resume; other phases:
  re-dispatch the author with **all** findings, non-blocking included);
  the round count increments.
- Any blocking finding has a `targetPhase` earlier than the current phase
  → **automatic fallback** to the **earliest** such phase: the main
  session executes the fallback procedure defined in the orchestrate skill
  (FB record, revocation, redo, re-approval, downstream replay) — without
  asking the user and without escalating. The remaining blocking findings
  are naturally covered by the downstream replay.
- Round cap reached (standard 3, heavy 5) → ESC with
  `rootCause: "round-limit"`.
- Accumulated fallbacks to the same target phase reach 3 → the third
  fallback is not executed; ESC with `rootCause: "fallback-limit"`.

## 4. Test-contract special case

A ticket test file that has been modified, or a test judged faulty, is
always routed `targetPhase: "tdd"` — never treated as an implementation
issue of the current phase.

## 5. First-phase special case

Explore is the first phase: its findings always carry
`targetPhase: "explore"` (there is no earlier phase to fall back to).

## 6. Reviewer output JSON contract

### Standard loop

```json
{
  "schemaVersion": 2,
  "phase": "tdd",
  "unit": "2026-09-10-auth",
  "target": { "artifact": "changes/2026-09-10-auth/tickets/", "ticketId": null },
  "round": 2,
  "maxRounds": 3,
  "verdict": "reject",
  "findings": [
    {
      "id": "F1",
      "severity": "blocking",
      "targetPhase": "tdd",
      "location": "changes/2026-09-10-auth/tickets/TICKET-002.md",
      "description": "Test asserts against a mock that is never configured.",
      "evidence": "Ran `npm test TICKET-002.spec.ts`; failure is a TypeError, not the expected assertion failure."
    }
  ]
}
```

- `verdict`: `"pass" | "reject"`. **`reject` if and only if at least one
  blocking finding exists** — with only non-blocking findings the verdict
  must be `"pass"` (findings still listed, for revision reference and gate
  awareness). This guarantees the routing rules in section 3 always have
  exactly one applicable branch.
- `severity`: `"blocking" | "non-blocking"`.
- `targetPhase`: one of the seven phase names; only the current phase or
  an earlier one is legal.

### Heavy loop (Review phase) — two layers

**(a) Lens raw findings** — each of the three parallel lenses outputs
findings only: no `verdict`, no `targetPhase`, and `severity` is renamed
`reportedSeverity` (advisory only; triage does not trust it):

```json
{
  "schemaVersion": 2,
  "phase": "review",
  "lens": "<lens-id from the dispatch prompt>",
  "findings": [
    {
      "id": "F1",
      "reportedSeverity": "blocking",
      "location": "…",
      "description": "…",
      "evidence": "…"
    }
  ]
}
```

**(b) Triage ruling** — same shape as the standard contract, with
`maxRounds` fixed at 5 and one extra per-finding field
`sourceFindingIds` (format `"<lens>:<id>"`), linking each ruled finding to
the raw findings it came from. Triage re-verifies every finding itself
before ruling on `severity` and `targetPhase`.

## 7. FB / ESC record formats

Numbering (`FB-<n>`, `ESC-<n>`) is assigned by the main session,
increasing within the unit; reviewers never assign numbers. Each record is
an atomic dual write: the `decisions.md` entry below plus the matching
`state.json` array element (see `references/state-management.md`).

**FB entry (waterfall fallback):**

```markdown
## FB-<n>: <one-line summary>
- Trigger: <fromPhase> (review round <k>/<max>)
- Fell back to: <toPhase>
- Reason: <finding summary and root-cause reasoning>
- Revoked scope: <phases reset; gates revoked with their original approval times>
- Time: <ISO 8601>
```

**ESC entry (escalation to the user):**

```markdown
## ESC-<n>: <one-line summary>
- Phase / round: <phase> (round <k>/<max>; for Wrap: "Wrap (no rounds, execute-verify loop)")
- Root cause class: <round-limit | fallback-limit | wrap-failure>
- Details: …
- User ruling: … (left empty / marked "pending" until ruled)
- Ruling time: …
```

After the user rules, the main session backfills both the markdown fields
and `state.json.escalations[].resolvedAt`.
