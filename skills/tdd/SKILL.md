---
name: tdd
description: >-
  Splits the approved spec into verifiable tickets, each shipped with a
  real, currently-failing test that becomes the build contract once the
  review loop passes.
---

# TDD

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

## 1. Preconditions

```
resolve_unit()
if changes/$unit/spec-delta.md missing or gates.spec.approvedAt == null:
  halt("Run /agent-flow:spec first.")
```

## 2. Procedure

```
1. resolve_unit(); read the approved spec-delta.md
2. dispatch(worker, role: test author; refs: sdd-guide.md, tdd-guide.md)
   first round: target = all tickets
   redo round (after a waterfall fallback): DIFF JUDGMENT first —
     compare current spec-delta.md against existing tickets (partial
     fallback: the affected set was already marked by the fallback
     procedure — use it directly); classify each revised requirement:
       test behavior changed  -> affected tickets reset status -> "draft", redo
       ticket-data-only fix (only dependsOn / requirementRefs /
       description; test files untouched)
                              -> edit frontmatter/body in place; do NOT
                                 turn "draft"; keep status ("merged" stays
                                 "merged")
     only "draft" tickets are redone; all others keep their existing
     tests and evidence
   for each ticket being (re)done:
     - split logically independent, verifiable units by requirement
       number; requirementRefs maps to one or more numbers
     - write real, executable test code into the project's own test
       tree (section 3), actually RUN it, and verify by situation:
         missing implementation (first round; or a redo-round case that
         runs red): confirm red for the right reason — the feature is
         unimplemented; a test that cannot run counts as unfinished
         coverage backfill (redo round only: implementation exists and
         the new case runs green — typical when Review found behavior
         correct but untested): green is legal, but attach FALSIFIABILITY
         EVIDENCE, perturbing ONLY a throwaway copy — official tree
         untouched: create a temp copy from HEAD (e.g. git worktree add
         to a temp dir, copying this round's uncommitted test files in),
         perturb the relevant implementation in the copy (e.g. invert
         the boundary condition), confirm the new case turns red; remove
         the copy (git worktree remove --force or equivalent); confirm
         the case is green in the official tree; record
         "perturbation -> red in copy -> green in tree" in the ticket
     - fill dependsOn by the criterion: "B depends on A if starting B
       before A completes would make B unverifiable in isolation or
       force mocking an interface of A that does not exist yet"
     - id format TICKET-<3 digits>; initial status: draft
3. dispatch(reviewer, ONE review for the whole ticket batch;
            refs: tdd-guide.md, quality-loop.md; round $round/$maxRounds=3)
   review criteria BY TICKET STATUS:
     "draft" (first round: all; redo round: the affected set):
       - tests actually run: independent re-run, no syntax/env errors
       - true red for the right reason: the failure must be the test
         framework's ASSERTION failure; module-load errors, syntax
         errors, runner startup failures, timeouts = "fake red
         (environment error), not a valid test"
       - red-criterion granularity = cases added or modified THIS round:
         for a previously "merged" ticket whose tests were revised, only
         new/modified cases must be red — unmodified existing cases
         staying green is expected, not a reject; first round (no
         implementation) = all cases red
       - coverage backfill: a new/modified case green because the
         implementation already satisfies it is NOT a reject — verify
         the ticket's falsifiability evidence instead: the reviewer
         builds its OWN throwaway copy, reproduces the same
         perturbation, confirms red in the copy and green in the
         official tree (official tree read-only throughout); before
         verifying, record a tree baseline (git status --porcelain plus
         diffs/hashes of relevant files — the tree already holds the
         pending uncommitted test and ticket changes; a clean tree is
         NOT required); after verifying, compare against the baseline to
         confirm NO NEW changes relative to before verification (pending
         changes stay as-is) and confirm its own copy is removed
         (git worktree list shows no leftover); missing evidence, or the
         case staying green after perturbation (tautological test) =
         reject
       - requirementRefs exist in spec-delta.md and match semantically
     "merged" (redo rounds only): implementation merged, green expected —
       red criterion does NOT apply; instead check the test files were
       not modified without authorization (contract integrity, git diff
       against unit-branch history) and dependency/numbering consistency
       with this round's revised tickets
     "ready" (unaffected in a redo round, no implementation yet): keeps
       its existing red tests — the red criterion holds by construction;
       just confirm this round's revisions did not touch it; no rewrite
     "in_build"/"in_review" (parked in-flight tickets from a partial
       fallback): check contract integrity like "merged"; red criterion
       does not apply
   output ONE verdict covering the whole batch (not one per ticket)
4. match $verdict:
     "pass" -> step 5
     "reject", all blocking targetPhase == "tdd"
            -> return the batch to the worker to fix the named tickets;
               counts toward qualityLoops.tdd.rounds; cap 3; over cap ->
               escalate("round-limit", findings)
     "reject", any blocking targetPhase in {"spec","prototype","explore"}
            -> fallback(earliest such phase, findings)
               # e.g. a requirement is self-contradictory or untestable
5. loop passed (replaces a gate):
     all "draft" tickets status -> "ready" (other statuses unchanged)
     phases.tdd = "done", artifact: "tickets/"
     mirror tickets.<id> into state.json
     # TEST CONTRACT NOW IN FORCE (INV-2): the Build worker must not
     # modify test files; a faulty test goes back to TDD by waterfall
     # fallback (references/tdd-guide.md §2)
     commit("flow(<unit>): tdd passed review")
     auto-continue to Build (orchestrate-driven)
```

## 3. Test file locations

Tests go into the project's existing test tree (follow its conventions;
if none exists, use the language/framework community convention) — never
into `.agent-flow/`. Tests must be part of the real test suite so Build
can turn them green and Wrap's full-suite check can see them. The
ticket's `testFiles` records the paths (relative to the project root).

## 4. Gate

None. Loop pass puts the contract in force and auto-continues — no user
approval stop. The same holds when TDD is redone after a waterfall
fallback: re-passing the loop re-activates the contract.

## 5. Standalone invocation

- `spec-delta.md` missing or unapproved: stop and hint to finish
  `/agent-flow:spec` first.
- Never auto-continue to Build when done `# INV-11`.
