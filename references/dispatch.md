# Dispatch — Parallel Dispatch Rules and Worktree Lifecycle

This file defines the general rules for dispatching `worker` / `reviewer`
subagents, and the lifecycle of Build ticket worktrees. Reader: the main
session (the dispatcher). Subagents never need this file — they only work
inside dispatches that already exist.

## Parallel dispatch — general rules

1. **Land output in files; pass only lightweight references.** Dispatch
   prompts pass file paths, never pasted file contents. A finished
   subagent returns only a conclusion summary plus the paths it read and
   wrote — reviewers return the JSON contract of
   `references/quality-loop.md`.
2. **Scale parallelism to complexity.** A single well-defined question:
   exactly 1 subagent. The Review phase's multi-perspective review: exactly
   3 lenses, fixed by design. Independent sub-items: one subagent per
   item, split so that investigation scopes do not overlap — non-overlap
   is the criterion for how finely to split.
3. **20-concurrency cap and batching.** At most 20 concurrent subagents;
   if a wave would exceed 20, dispatch the first 20 and dispatch the
   remainder as slots free up.
4. **No nested dispatch.** A dispatched subagent never uses the Agent tool
   to spawn further subagents. Any role that must stay independent of the
   author is always dispatched directly by the main session, one level,
   never through an intermediary.
5. **Parallel reviews stay mutually invisible.** Never smuggle another
   reviewer's preliminary opinion into a dispatch prompt.

## Worktree lifecycle (Build)

The main session owns every ticket worktree from creation to removal. The
Agent tool's `isolation` parameter is **never** used (INV-13).

6. **Creation.** Before dispatching a ticket, the main session runs
   `git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/<unit>`.
   Naming the source branch is what guarantees the worktree forks from the
   unit branch tip, so tickets stack incrementally. Nothing about the
   project's settings or the currently checked-out branch can change that
   — which is why Build has no preflight step and asks the user to
   configure nothing.
7. **Keeping worktrees out of the index.** `.agent-flow/.gitignore` must
   contain the line `worktrees/`, written when `.agent-flow/` is first
   created. Without it, `git add -A` on the unit branch commits the
   worktree as an embedded git repository. The file lives inside
   agent-flow's own directory, so the project's own `.gitignore` is never
   touched.
8. **Telling the subagent where to work.** The dispatch is an ordinary one
   — no special parameters. The briefing carries the **absolute** worktree
   path and instructs the subagent to `cd` there before doing anything.
   Each subagent has its own shell, so parallel tickets never interfere.
9. **Fixing a ticket after review.** Prefer a `SendMessage` resume of the
   original `agentId`, issued by the main session itself: the agent keeps
   the understanding it already built. Never delegate the resume to an
   intermediary subagent — resume completion notifications reach only the
   main session, so an intermediary would wait forever. If that agent is
   no longer addressable, dispatch a fresh one pointed at the same
   worktree path; the work is on disk and nothing is lost (INV-3). What is
   forbidden either way is creating a second worktree for the same ticket.
10. **Wave scheduling.** Compute the set of tickets whose `dependsOn` are
    all `merged`; create that wave's worktrees and issue its dispatches in
    one turn; after the wave's tickets are merged, compute the next wave.
11. **Clean up immediately after merge.** Once a ticket is merged into the
    unit branch, run `git worktree remove <path>` (add `--force` if it has
    leftover changes) and delete the `ticket/<id>` branch. Nothing cleans
    up on its own. Build and Review never share a worktree.
