# TDD Guide — Red-Before-Green, Test Contract, Rebuttal Table

This file defines the TDD contract used across the TDD and Build phases:
the red-before-green rule and its redo-round exceptions, the test
contract, the rationalization rebuttal table, and the Build role's
boundary of responsibility.

## 1. Red-before-green rule

Every test produced for a ticket in the TDD phase must be real, executable
test code — not a stub or a description of a test.

- The `worker` (TDD author role) must actually run the test and confirm
  the result is red: the test fails because the feature is not implemented
  yet, not because of a syntax error or an environment problem.
- The `reviewer` must independently re-run the same test and confirm the
  same red result before approving.

**Redo-round exception** (after a waterfall fallback to TDD): the red
criterion applies only to **test cases added or modified in this round**.

- Unmodified existing cases on `draft` tickets whose implementation is
  already merged are expected to stay green.
- `merged` / `ready` / untouched tickets, and ticket-data-only fixes
  (dependencies, numbering, description — test files untouched), are not
  subject to the red criterion. Instead, check contract integrity (test
  files not modified without authorization) and dependency/numbering
  consistency.

**Coverage-backfill scenario**: when an added or modified case is
immediately green because the existing implementation already satisfies
it, substitute **fallibility evidence** for the red result. The
perturbation runs **only in a throwaway copy — the official working tree
is never touched**:

1. In a throwaway copy (a `git worktree` in a temp directory, or
   equivalent), perturb the relevant implementation.
2. Confirm the case turns red in the copy.
3. Clean up the copy.
4. Confirm the case is green in the official tree.

The author attaches the execution record. The reviewer reproduces the
evidence independently in a copy it creates itself, compares against a
baseline recorded before verification to confirm the official tree has
**no new changes relative to before the verification** (pending
uncommitted test and ticket changes stay as they are — a clean tree is not
required), and confirms its own copy has been cleaned up with nothing left
behind.

## 2. Test contract

Once the **TDD quality loop passes**, the ticket's test files become the
contract.

- The Build `worker` must not modify them. If it suspects a test file is
  wrong, it must **not** edit the test directly: it stops work on that
  part of the implementation and flags the suspected problem explicitly in
  its report. The main session then routes it by the waterfall rules —
  an **automatic fallback to TDD** (affected tickets reset to `draft` and
  re-run the TDD loop), not an escalation to the user.
- The `reviewer` must use `git diff` to check the ticket's test files
  against their initial commit. Any modification found is always ruled
  `targetPhase: "tdd"` (the test-contract special case in
  `references/quality-loop.md`) — never treated as an ordinary
  implementation issue of the current phase.

## 3. Rationalization rebuttal table

The table below lists common ways an author or reviewer might try to shortcut
the red-before-green rule or the test contract, and the standard rebuttal to
each.

| Common rationalization | Rebuttal |
|---|---|
| "This test is too simple, no need to actually run it." | A test with no actual execution record doesn't count; the `reviewer` accepts only reproducible execution evidence. |
| "Skip this one for now, add the test later." | The definition of the TDD phase is "tests before implementation"; without a test written first, there is no ticket eligible to enter the Build phase. |
| "I tested it manually and the result was correct." | Manual testing is not reproducible evidence; the reviewer must be able to re-run the same test themselves and get the same result. |
| "This test looks wrong — I'll just fix it myself, it's faster." | This violates the test contract; work must stop and the suspected problem be flagged so the main session falls back to TDD — never self-modified. |
| "The test failure is an environment problem, not a missing feature." | Environment problems must first be ruled out (confirm the test framework runs other tests normally) before claiming this is a valid red or green result. |
| "This edge case doesn't matter, skip it." | The scope of a ticket's tests is determined by what passed the TDD quality loop; the `worker` may not narrow it unilaterally. |
| "This is already covered somewhere else, no need to re-run it." | The `reviewer` must re-run this ticket's tests on every review; a claim that it was "tested elsewhere" is not accepted. |
| "Let's finish the feature first and add tests at the end." | This violates the red-before-green rule; implementation must not start before a red failure has been observed. |
| "Deleting and rewriting this test wastes code that's already written." | The test contract does not yield to implementation cost; if a test really is wrong, the correct path is to flag it for a fallback to TDD, not to bypass it. |
| "The reviewer should understand my intent without checking line by line." | The reviewer's job is a literal, line-by-line check, not guessing intent; anything glossed over counts as a failed review. |

## 4. Build role's boundary of responsibility

The Build `worker`'s only job is to turn tests already confirmed red into
green. It does not re-verify that "the test was once red" — that
verification was already completed in the TDD phase. After turning the
tests green, the `worker` commits once inside its own worktree.
