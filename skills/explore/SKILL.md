---
name: explore
description: >-
  Runs a Socratic dialogue to pin down intent while investigating the
  codebase and external options for feasibility, then asks for your
  approval before anything gets specified.
---

# Explore

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

The dialogue happens in the main session itself (never delegated);
investigation and review are dispatched as usual.

## 1. Preconditions

Explore is the start of the flow — no upstream phase dependency.

```
if driven by orchestrate:
  unit already exists; go to section 2
else:                                     # standalone /agent-flow:explore
  resolve_unit()
  if no unit exists: create_unit($ARGUMENTS)
  if gates.explore.approvedAt != null:
    halt("Explore is already approved for this unit. To change the
          approved Explore artifact, say so explicitly — that is a
          user-initiated fallback.")      # re-run refusal; see orchestrate
```

## 2. Procedure

```
1. divergent dialogue: main session asks open-ended questions about
   intent, pain points, constraints — until concrete convergent
   questions can be formed
2. dispatch(worker, role: investigator; no reference files;
            investigate BOTH internal (existing code, tests, deps,
            architecture conventions) AND external (technology options,
            official docs, known limits);
            write findings into the Investigation section of
            changes/$unit/explore.md with evidence — file paths or links)
   # dialogue and investigation may interleave; findings feed the
   # convergent questions
3. convergent Q&A: main session asks option-style questions one at a
   time, each with a recommendation; user answers each
4. main session completes explore.md (section 3 format): intent summary
   + open technical questions list
5. dispatch(reviewer, refs: quality-loop.md; round $round/$maxRounds=3;
            check: summary faithfully covers the convergent answers
            (no reviewer inference mixed in); investigation conclusions
            carry verifiable evidence (spot-check allowed); the open
            questions list is sound and complete — omissions would
            wrongly skip Prototype)
6. match $verdict:
     "pass"   -> gate (section 4)
     "reject" -> targetPhase is always "explore" (first-phase rule,
                 references/quality-loop.md §5): ask the user follow-ups
                 or re-dispatch worker per findings, revise, back to
                 step 5; rounds += 1
7. if round 3 still fails:
     escalate("round-limit", findings) — but present it merged with the
     gate: list the unresolved items as "items to confirm" alongside the
     summary; the user's approval reply doubles as the ruling on them
```

## 3. Artifact — `changes/<unit>/explore.md`

```markdown
# Explore: <unit-name>

## Intent

### Divergent record
<open-ended Q&A, round by round>

### Convergent Q&A
#### Q1: <option-style question>
**Options**: 1. … 2. … 3. … (with recommendation)
**Answer**: <user's choice and additions>

### Intent summary
<consolidated intent description>

## Investigation

### Internal findings
<existing code / tests / dependencies / conventions, with file-path evidence>

### External findings
<technology options / official docs / known limits, with source links>

## Open technical questions

- <concrete technical question answerable only by experiment>
(if none, write "None" — the direct basis for skipping Prototype)
```

## 4. Gate

`gate("explore")`. Present: intent summary + key investigation
conclusions + open questions (+ round-3 items to confirm, if any). On
approval: write `gates.explore`,
`commit("flow(<unit>): explore passed review")`; `explore.md` becomes the
approved artifact. Driven by orchestrate: open questions non-empty →
Prototype; empty → Spec.

## 5. Standalone invocation

No preconditions. Never auto-continue after approval `# INV-11`; you may
hint: "Approved. Continue with `/agent-flow:prototype` (open questions
exist) or `/agent-flow:spec` (none)."
