---
name: parallel-dispatch
description: >-
  Load this before fanning out multiple read-only subagents at once —
  file-based handoff, complexity-based parallelism, and the 20-subagent
  batching rule.
user-invocable: false
---

# parallel-dispatch

This skill defines the general rules for dispatching multiple read-only
review/research subagents at once. It is loaded by the dispatcher itself
(`orchestrate`), never by the subagents it dispatches — for example, when the
Review phase fans out `review-gap-hunter`, `review-edge-case-hunter`, and
`review-spec-compliance-auditor` in parallel, or whenever any phase needs
multiple independent, read-only viewpoints on the same material. The three
parallel review teams and `review-triage` do not spawn any further subagent
layer beneath themselves, so they never need to load this skill.

## Rules

1. **Land output in files; pass only lightweight references.**
   Any single round of read-only parallel dispatch must pass file paths in
   the prompt, never paste full file contents inline. When a subagent
   finishes, it must return only a conclusion summary plus the paths of the
   files it read or wrote — not the raw content itself. This keeps the
   dispatcher's context free of large, duplicated payloads.

2. **Scale parallelism to task complexity — do not split more finely than
   necessary.**
   - **Single, well-defined question** (e.g., checking whether one
     requirement has a corresponding implementation): use exactly 1
     subagent. Do not split it further.
   - **Multi-perspective review** (e.g., the Review phase's three
     independent review angles): always use exactly 3 parallel subagents.
     This count is fixed by design and does not scale up or down with
     complexity.
   - **Independent sub-items** (e.g., multiple files or modules that each
     need a separate read-only investigation): scale the number of parallel
     subagents to the number of independent items, not to "however finely
     it can be split." Each subagent's investigation scope must not overlap
     with another's — that non-overlap is the criterion for how finely to
     split.

3. **20-subagent concurrency cap and batching rule** (shared with
   `using-worktree` — defined here once, referenced there, not duplicated).
   The Agent tool supports at most 20 concurrent subagents by default. If a
   single wave of dispatch would exceed 20, dispatch the first 20
   immediately, then queue the remainder and dispatch them as slots free up.

4. **Never let a dispatched subagent re-dispatch its own reviewers.**
   A read-only subagent launched by `parallel-dispatch` must not use the
   Agent tool to spawn another layer of review subagents beneath itself.
   Any dispatch of a role that must stay independent of the author is always
   performed directly by the orchestrator, one level, never delegated
   through an intermediary subagent.

5. **No shared context between parallel subagents — each judges
   independently.**
   Subagents dispatched in parallel for review or research never see each
   other's process or conclusions. This is the default behavior of
   (non-fork) subagents and requires no extra configuration. However, the
   orchestrator must not smuggle "another role's preliminary opinion" into
   any one subagent's dispatch prompt — doing so would compromise the
   independence this isolation is meant to guarantee.
