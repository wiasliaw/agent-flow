---
name: tdd-guide
description: >-
  Load this when writing, reviewing, or implementing a ticket's tests —
  the red-before-green rule, the no-editing-approved-tests contract, and
  the rationalization rebuttal table.
user-invocable: false
---

# TDD Guide

Loaded by: `ticket-writer`, `ticket-reviewer`, `dev-worker`, `dev-reviewer`.

## 1. Red-before-green rule

Every test produced for a ticket in the Ticket phase must be real, executable
test code — not a stub or a description of a test.

- `ticket-writer` must actually run the test and confirm the result is red:
  the test fails because the feature is not implemented yet, not because of
  a syntax error or an environment problem.
- `ticket-reviewer` must independently re-run the same test and confirm the
  same red result before approving.

## 2. Test contract (no editing approved tests)

Once the Ticket gate is approved, the ticket's test files become an
immutable contract.

- If `dev-worker` suspects a test file is wrong, it must **not** edit the
  test directly. It must stop work on that part of the implementation and
  flag the suspected problem explicitly in its report, so the orchestrator
  can route it as a root cause in an approved artifact and escalate it to
  the user for a decision.
- `dev-reviewer` must use `git diff` to check the ticket's test files
  against their initial commit. Any modification found must be judged as an
  `approved-artifact` root cause — it must never be auto-returned to the
  author as an ordinary implementation issue.

## 3. Rationalization rebuttal table

The table below lists common ways an author or reviewer might try to shortcut
the red-before-green rule or the test contract, and the standard rebuttal to
each.

| Common rationalization | Rebuttal |
|---|---|
| "This test is too simple, no need to actually run it." | A test with no actual execution record doesn't count; `ticket-reviewer`/`dev-reviewer` accept only reproducible execution evidence. |
| "Skip this one for now, add the test later." | The definition of the Ticket phase is "tests before implementation" (per PROMPT); without a test written first, there is no ticket eligible to enter the Dev phase. |
| "I tested it manually and the result was correct." | Manual testing is not reproducible evidence; the reviewer must be able to re-run the same test themselves and get the same result. |
| "This test looks wrong — I'll just fix it myself, it's faster." | This violates the Q10 test contract; work must stop and be escalated, never self-modified. |
| "The test failure is an environment problem, not a missing feature." | Environment problems must first be ruled out (confirm the test framework runs other tests normally) before claiming this is a valid red or green result. |
| "This edge case doesn't matter, skip it." | The scope of a ticket's tests is determined by what was approved in the Ticket phase; `dev-worker` may not narrow it unilaterally. |
| "This is already covered somewhere else, no need to re-run it." | `dev-reviewer` must re-run this ticket's tests on every review; a claim that it was "tested elsewhere" is not accepted. |
| "Let's finish the feature first and add tests at the end." | This violates the red-before-green rule; implementation must not start before a red failure has been observed. |
| "Deleting and rewriting this test wastes code that's already written." | The test contract does not yield to implementation cost; if a test really is wrong, the correct path is to escalate, not to bypass it. |
| "The reviewer should understand my intent without checking line by line." | The reviewer's job is a literal, line-by-line check, not guessing intent; anything glossed over counts as a failed review. |

## 4. `dev-worker`'s boundary of responsibility

`dev-worker`'s only job is to turn a test already confirmed red into green.
It does not re-verify that "the test was once red" — that verification was
already completed in the Ticket phase. After turning the test green,
`dev-worker` commits once inside its own worktree.
