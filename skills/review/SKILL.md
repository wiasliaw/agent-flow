---
name: review
description: >-
  Runs a multi-perspective audit of the whole unit against its spec and
  tickets, auto-fixing or falling back on blocking findings, then asks for
  your approval before wrap-up.
---

# Review

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

## 1. Preconditions

```
resolve_unit()
if any ticket status != "merged":
  halt("Finish Build first — every ticket must be merged; an unruled
        escalated ticket also blocks Review.")
```

## 2. Procedure (heavy loop, `qualityLoops.review`, cap 5)

```
1. resolve_unit(); confirm preconditions
2. run("git diff main...flow/$unit") -> write to a temp file
   (e.g. changes/$unit/.review-diff-round-<k>.txt; not a formal artifact)
3. in ONE turn, dispatch three reviewer lenses in parallel  # INV-10
   (lens mode; each refs: quality-loop.md; the compliance lens also
    refs: sdd-guide.md; prompts pass only the diff file and
    spec-delta.md / tickets/ paths; mutually invisible):
     gap lens          -> find gaps: requirements with no implementation,
                          tickets with no tests, missing aspects
     edge-case lens    -> find untested boundaries: boundary values,
                          bad input, concurrency/timing; may actually
                          execute to verify
     spec-compliance lens
                       -> check every ADDED/MODIFIED/REMOVED item landed;
                          AND check production paths have ZERO dependency
                          on changes/$unit/prototype/ (violation =
                          blocking)
   each lens outputs the raw-finding layer (reportedSeverity advisory)
4. land the three reports as files, then
   dispatch(reviewer, triage mode; refs: quality-loop.md;
            re-verify EVERY finding first-hand — never trust
            reportedSeverity; output the ruling layer: verdict /
            severity / targetPhase / sourceFindingIds; maxRounds: 5)
5. main session aggregates the rulings into changes/$unit/review.md
   (section 4 format)
6. auto-disposition of blocking findings:
   match blocking findings:
     any targetPhase in {"explore","prototype","spec","tdd"}
        -> fallback(earliest targetPhase, findings)
           # redo, re-approve, replay downstream, then return to step 2.
           # qualityLoops.review.rounds is KEPT across the fallback
           # (INV-5) and increments on top of the preserved value — the
           # five-round cap accumulates across fallbacks
     only targetPhase == "build"
        -> fix mechanism (section 3): ONE brand-new worker handles all
           such findings, merge, then back to step 2 for a full round
           (3 lenses + triage); rounds += 1
     none
        -> gate (section 5)
7. round 5 reached with blocking findings unresolved
        -> escalate("round-limit", findings); stop auto-rerunning;
           follow the user's instruction
```

## 3. Build-finding fix mechanism

No in-flight `worker` exists at Review (everything is merged), so:

```
1. confirm flow/$unit is checked out (contains all merges)
2. make_worktree(review-fix-$round); dispatch(worker, BRAND-NEW,
   pass the ABSOLUTE worktree path with an instruction to cd there first)
   # forked from flow/$unit by name # INV-13
3. prompt cites the review.md section path and lists ALL of this round's
   targetPhase "build" blocking findings; one worktree handles them in
   sequence (not one worktree per finding)
4. worker fixes, confirms the relevant tests green, commits once
5. merge into the unit branch (the build skill's merge rules: --no-ff,
   remove the worktree immediately)
6. back to procedure step 2 for the next full Review round — no extra
   standalone review is stacked on: the next round's 3 lenses + triage
   IS the verification of the fix
```

## 4. Artifact — `changes/<unit>/review.md`

```markdown
# Review: <unit-name>

## Summary
- Review round: <k>/5
- Blocking this round: <N> (auto-disposed: <fixed | fell back to <phase>>)
- Non-blocking: <M>

## Blocking findings

### R1: <one-line summary>
- Severity: blocking
- Location: <file path>
- Description: …
- targetPhase: <build | tdd | spec | prototype | explore>
- Disposition: <round <k> worker fix | round <k> fallback to <phase> (see FB-<n>) | pending>
- Source lens: <gap | edge-case | spec-compliance>

## Non-blocking findings

### R2: <one-line summary>
(same fields; Disposition: deferred with awareness)

## Prototype zero-dependency check (spec-compliance lens)
- Result: <pass | violations found: file path list>
```

## 5. Gate

`gate("review")` — approval requires this round to have no blocking
finding (the auto-disposition converges, or ESC at the 5-round cap).
Present `review.md`: the round (`<k>/5`), the auto-disposition history,
and the remaining non-blocking findings, then ask: "The non-blocking
items above are deferred with awareness. Approve entering Wrap?" On
approval: write `gates.review`, commit; auto-continue to Wrap
(orchestrate-driven). If the user asks for extra fixes: route by nature —
section 3, or a user-initiated fallback (does not count rounds,
`# INV-7`).

## 6. Standalone invocation

- Tickets not all `merged`: stop and hint to finish Build.
- A waterfall fallback during auto-disposition: records and revocation,
  then stop and hint the user to call the target phase skill; the
  `build` fix dispatch crosses no phase and runs as usual.
- Never auto-continue to Wrap after approval `# INV-11`.
