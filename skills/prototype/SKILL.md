---
name: prototype
description: >-
  Answers open technical questions with throwaway experiments, capturing
  the question, approach, and evidence — never the code itself.
---

# Prototype

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

## 1. Preconditions

```
resolve_unit()
if gates.explore.approvedAt == null:
  halt("Explore must be approved first — run /agent-flow:explore.")
if open technical questions list in explore.md is empty:
  if driven by orchestrate:
    write_state(phases.prototype = {"status": "skipped",
                "reason": "no open technical question"})
    skip the whole phase
  else:
    # standalone force-run is allowed: the empty-list skip is an
    # orchestrate auto-continue shortcut, not a hard ban — the user may
    # have a question the list did not capture
    proceed
```

## 2. Procedure

```
1. dispatch(worker, role: prototyper; no reference files;
            pass the open questions list; require:
            - throwaway experiment code for each question, written ONLY
              under changes/$unit/prototype/ — NEVER into production
              paths (core prohibition)
            - actually run the experiments and capture evidence
              (output, logs, measurements)
            - produce changes/$unit/prototype.md with the four elements:
              question / approach / evidence / conclusion)
2. dispatch(reviewer, refs: quality-loop.md; round $round/$maxRounds=3;
            actually re-run the prototype/ experiments: is each question
            truly answered, is the evidence reproducible, was anything
            written outside prototype/)
3. match $verdict:
     "pass" -> write_state(phases.prototype = "done")
               commit("flow(<unit>): prototype passed review")
               auto-continue to Spec (orchestrate-driven)
     "reject", targetPhase == "prototype"
            -> re-dispatch worker with findings; rounds += 1; cap 3;
               over cap -> escalate("round-limit", findings)
     "reject", targetPhase == "explore"
            -> fallback("explore", findings)
               # misread intent led the experiments astray; Explore is
               # redone, re-approved, then this phase replays
```

## 3. Artifact and production-code discipline

`prototype.md` has four sections (question / approach / evidence /
conclusion); the experiment code itself lives in `changes/<unit>/prototype/`
and is committed with the unit. Three rules:

1. Experiment code exists only under `changes/<unit>/prototype/`.
2. The final "zero production dependency on `prototype/`" check belongs to
   the Review phase's compliance lens; this phase's reviewer only checks
   that the code written this round is not referenced from production
   paths.
3. Wrap archives `prototype/` with the unit as-is — no further
   integration.

## 4. Gate

None. Loop pass auto-continues to Spec.

## 5. Standalone invocation

Preconditions unmet → stop with a hint. Never auto-continue when done
`# INV-11`; you may hint: "Continue with `/agent-flow:spec`."
