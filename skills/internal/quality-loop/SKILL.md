---
name: quality-loop
description: >-
  Load this whenever a reviewer needs to report a verdict, or the
  orchestrator needs to route one — the two-tier loop, the two-way
  routing rule, round limits, and the ESC trace format.
user-invocable: false
---

# Quality Loop

This skill defines the shared review-and-routing contract used across every
phase's quality loop: how a reviewer subagent reports its verdict, how the
orchestrator routes a rejection, round limits, and the escalation (ESC)
trace format.

**Who loads this**: every phase's reviewer subagent (`intent-reviewer`,
`explore-reviewer`, `prototype-reviewer`, `spec-reviewer`, `ticket-reviewer`,
`dev-reviewer`, `review-gap-hunter`, `review-edge-case-hunter`,
`review-spec-compliance-auditor`, `review-triage`), and `orchestrate` itself
when it reads a review result and decides how to route it. `wrap-verifier`
does **not** load this skill — Wrap's execute-verify loop uses a different
reporting format that this skill's "send back to original author" verdict
shape does not fit.

## 1. Two-tier loop selection

- **Standard loop**: Discuss, Explore, Prototype, Spec, Ticket, and Dev (per
  ticket). A single independent reviewer reviews the artifact; on rejection
  the loop sends the artifact back to the original author to fix; the loop
  is capped at **3 rounds**; exceeding the cap escalates to the user.
- **Heavy loop**: Review only. Three independent reviewer subagents gather
  findings in parallel, then `review-triage` independently verifies and
  performs root-cause routing on those findings; the loop is capped at
  **5 rounds**; exceeding the cap escalates to the user.

## 2. Review procedure

A reviewer receives file paths to the author's artifact and judges it
independently — it must not be swayed by the author's framing or by how
confident the author's own description sounds. It reports its verdict using
the standardized JSON format defined in rule 7.

The orchestrator routes based on the reviewer's `verdict`:

- `"pass"` — the phase (or ticket, in Dev) is complete; the orchestrator
  writes `state.json`'s corresponding `qualityLoops.<key>.status = "passed"`.
- `"reject"` — the orchestrator routes based on each finding's `rootCause`
  (see rule 3).

## 3. Two-way routing rule for rejections

Rejections are routed into exactly two categories (not a four-way BMAD-style
triage):

- **`implementation-issue`**: the problem is inside this phase's
  not-yet-approved artifact. The loop automatically sends it back to the
  original author subagent to fix (in the standard loop: either re-dispatch
  or resume, depending on the role — for Dev phase's `dev-worker`, the
  orchestrator must resume the same agent ID via `SendMessage`, per the
  `using-worktree` skill, never re-dispatch). This counts toward that loop's
  round count.
- **`approved-artifact`**: the root cause lies in an already-approved
  artifact (the Discuss summary, a Spec delta, or a Ticket and its tests).
  The loop always halts and escalates to the user; no agent may overturn an
  already-approved artifact on its own.

**Special case — the Review heavy loop does not use the automatic-routing
part of this rule.** `review-triage` still outputs a `rootCause`
classification per finding (the `findings[].rootCause` field is unchanged),
but in Review that classification does **not** drive automatic
send-back-to-fix and does **not** drive automatic escalation. Instead, all
findings from the three parallel review teams and from `review-triage`
— regardless of `rootCause` — are aggregated into `review.md` and presented
to the user at the Review approval gate. If the user approves fixing an
`implementation-issue` finding, the orchestrator dispatches a **brand-new**
(not resumed) `dev-worker` to apply the fix. If the user wants an
`approved-artifact` finding fixed, that goes through the "user actively
edits an approved artifact" mechanism instead of this rule's automatic
escalation path. This special case applies only to Review; the other six
standard-loop phases (Discuss, Explore, Prototype, Spec, Ticket, Dev) keep
the automatic routing behavior described above.

## 4. Test-contract routing special case

If any reviewer discovers that a ticket's test file itself has been
modified — regardless of who modified it — that finding's `rootCause` must
always be classified as `approved-artifact` (with
`escalation.targetArtifact: "ticket"`). It must never be treated as an
ordinary implementation issue eligible for automatic send-back-to-fix.

## 5. Round limit and what happens when it is exceeded

When a loop reaches its cap (3 for standard loops, 5 for the Review heavy
loop), it does **not** automatically switch to a different model or to a
brand-new author subagent for another attempt. It always escalates to the
user for a decision, and the orchestrator writes `"escalated"` into that
loop's `state.json` `qualityLoops.<key>.status`.

## 6. ESC trace format

Every escalation is written as an entry appended to
`changes/<unit>/decisions.md`:

```markdown
## ESC-<n>: <one-line summary>
- Phase / round: <phase> (round <k>/<max>)
- Triggering roles: <author-role> vs <reviewer-role>
- Root cause: <implementation issue | root cause in an approved artifact: Discuss/Spec/Ticket>
- Details: ...
- User decision: ...
- Decision time: ...
```

At the same time, append one entry to the `state.json.escalations` array
(fields `id`, `phase`, `ticket` (if applicable), `rootCause`, `raisedAt`,
`resolvedAt` — field definitions are in the `state-management` skill). The
`<n>` in the ESC id is assigned by the orchestrator, incrementing from the
number of ESC entries that already exist in the unit; a reviewer never
assigns its own ESC id.

## 7. Reviewer output format contract

Every reviewer subagent (including the three parallel Review teams and
`review-triage`) reports its output as JSON (chosen over YAML for the same
reason `state.json` itself is JSON: the orchestrator needs to parse it
mechanically, and JSON is the least ambiguous choice).

### Standard-loop reviewers

Applies to `intent-reviewer`, `explore-reviewer`, `prototype-reviewer`,
`spec-reviewer`, `ticket-reviewer`, and `dev-reviewer`:

```json
{
  "schemaVersion": 1,
  "role": "ticket-reviewer",
  "phase": "ticket",
  "unit": "2026-09-04-auth",
  "target": {
    "artifact": "changes/2026-09-04-auth/tickets/TICKET-002.md",
    "ticketId": "TICKET-002"
  },
  "round": 2,
  "maxRounds": 3,
  "verdict": "reject",
  "findings": [
    {
      "id": "F1",
      "severity": "blocking",
      "location": "changes/2026-09-04-auth/tickets/TICKET-002.md",
      "description": "Test asserts against a mock that is never configured.",
      "evidence": "Ran `npm test TICKET-002.spec.ts`; failure is a TypeError, not the expected assertion failure.",
      "rootCause": "implementation-issue"
    }
  ],
  "escalation": null
}
```

Field notes:

- `verdict`: `"pass" | "reject"`.
- `target`: the artifact under review. `ticketId` is only needed for
  Dev/Ticket-related roles; other roles omit this field.
- `round` / `maxRounds`: semantically aligned with
  `state.json.qualityLoops.<key>.rounds` / `maxRounds`. The reviewer fills
  this field based on the round number the orchestrator told it at dispatch
  time; the orchestrator then updates `state.json` from it. The two are
  semantically consistent but are not the same piece of data —
  `state.json` is persistent state, while this is a single review report.
- `findings[].severity`: `"blocking" | "non-blocking"` — this reuses the
  binary vocabulary already used elsewhere in the product's journey copy,
  rather than inventing a three-tier high/medium/low scale, to avoid
  introducing inconsistent terminology.
- `findings[].rootCause`: `"implementation-issue" | "approved-artifact"`.
- `escalation`: required whenever `verdict = "reject"` and any finding's
  `rootCause` is `"approved-artifact"`. Format:

  ```json
  { "targetArtifact": "spec", "reason": "Requirement 1.2 conflicts with 1.4." }
  ```

  `targetArtifact` legal values: `"discuss" | "spec" | "ticket"` (matching
  the root-cause options in the ESC template). The ESC id and the write to
  `decisions.md` are handled by the orchestrator — a reviewer never fills in
  an ESC id.

### Review heavy loop (two layers)

**(a) The three parallel review teams** (`review-gap-hunter`,
`review-edge-case-hunter`, `review-spec-compliance-auditor`) report **raw
findings only** — no `verdict`, no `rootCause` (classification is
`review-triage`'s job; the parallel teams do not make root-cause
judgments). `severity` is renamed `reportedSeverity` to signal that it is
reference-only, not a final determination:

```json
{
  "schemaVersion": 1,
  "role": "review-gap-hunter",
  "phase": "review",
  "unit": "2026-09-04-auth",
  "round": 1,
  "findings": [
    {
      "id": "G1",
      "location": "src/auth/reset.ts",
      "description": "No rate limiting on password-reset requests.",
      "evidence": "Grep of src/auth/reset.ts shows no throttling logic; spec-delta.md requirement 1.3 requires it.",
      "reportedSeverity": "blocking"
    }
  ]
}
```

**(b) `review-triage`'s verdict output** reuses the standard-loop schema
shape (`verdict` / `findings[].severity` / `findings[].rootCause` /
`escalation` have the same meaning as above), plus one extra field,
`findings[].sourceFindingIds`, which points back to the original findings
(across the three parallel teams) the verdict is based on — format
`"<role>:<id>"`. `maxRounds` is fixed at 5 for Review:

```json
{
  "schemaVersion": 1,
  "role": "review-triage",
  "phase": "review",
  "unit": "2026-09-04-auth",
  "round": 1,
  "maxRounds": 5,
  "verdict": "reject",
  "findings": [
    {
      "id": "T1",
      "sourceFindingIds": ["review-gap-hunter:G1"],
      "severity": "blocking",
      "location": "src/auth/reset.ts",
      "description": "Confirmed: no rate limiting implemented despite spec-delta.md requirement 1.3.",
      "evidence": "Re-read src/auth/reset.ts and spec-delta.md directly; requirement 1.3 explicitly requires throttling.",
      "rootCause": "implementation-issue"
    }
  ],
  "escalation": null
}
```

Rationale for this two-layer design: the three parallel teams do not see
each other's findings or conclusions. If each of them directly output a
"final verdict" shape (including `rootCause`), that would produce three
potentially contradictory verdicts, and would also undermine the rule that
a reviewer's self-reported severity should not be trusted at face value.
The raw-finding layer is therefore deliberately simpler than the
standard-loop shape (no `verdict`, no `rootCause`), converging the act of
"reaching a verdict" onto a single role, `review-triage`. `review-triage`'s
verdict output then directly reuses the standard-loop schema shape so that
the orchestrator's parsing logic can share the same code path for
`verdict` / `findings[].rootCause` / `escalation` — only the Review role's
output carries the extra `sourceFindingIds` field.
