# Glossary — DSL, Variables, Shared Procedures, Invariants

This file is the vocabulary for every agent-flow skill. The main session
must `Read` it before executing any agent-flow skill. Skill procedure
sections are written in the pseudo-code DSL defined here; this file is the
single authority for what each primitive, variable, shared procedure, and
invariant number means.

## 1. How to read a DSL block

- A DSL block is an **ordered list of instructions to follow**, not
  executable code. Execute the steps in order unless a branch says
  otherwise.
- `name(args)` expands to a **primitive** (section 2) or a **shared
  procedure** (section 4) defined in this file.
- `if <condition>:` guards the indented steps below it.
- `match <expr>:` with arms written `value -> action` selects exactly one
  arm.
- A comment `# INV-n` marks the step as constrained by that invariant
  (section 5). The invariant's full text lives only in this file; skills
  cite the number and never restate the rule.
- **Closed-world rule**: if no branch applies, or a precondition cannot be
  determined, do not invent routing — `halt` and present the situation to
  the user.
- Prose carries content (user-facing copy, artifact formats, rationale);
  DSL blocks carry control flow.

## 2. Primitives

| Primitive | Meaning |
|---|---|
| `dispatch(agent, briefing, opts?)` | Call the Agent tool with `subagent_type: "agent-flow:worker"` or `"agent-flow:reviewer"`. The briefing must contain the five role-briefing elements: (a) the role for this dispatch; (b) the **absolute paths** of the reference files to `Read` first (expand `${CLAUDE_PLUGIN_ROOT}/references/<name>.md` before dispatch — subagents and worktrees cannot resolve plugin-relative paths); (c) input artifact paths; (d) the artifact path to write; (e) the output format required (for `reviewer`: the JSON contract in `references/quality-loop.md`) plus round info (`$round`/`$maxRounds`). For a dispatch that works inside a ticket worktree, the briefing additionally names the **absolute worktree path** and instructs the subagent to `cd` there first. `# INV-13` |
| `make_worktree(ticket)` | `run("git worktree add -b ticket/<id> .agent-flow/worktrees/<id> flow/$unit")`. The main session creates every ticket worktree itself and therefore knows its path without waiting for any notification. `# INV-13` |
| `drop_worktree(ticket)` | `run("git worktree remove <path>")` (add `--force` if needed), then delete the ticket branch once merged. Worktrees are never left behind. |
| `parallel(dispatches)` | Issue all listed dispatches in the same turn so they run concurrently. `# INV-4` |
| `resume(agent_id, message)` | Continue a previously dispatched agent via `SendMessage` with its `agentId`, preserving its context and worktree. `# INV-3` |
| `read_state()` / `write_state(fields)` | Read / update `state.json` following `references/state-management.md`. `# INV-1` |
| `gate(phase)` | Approval-gate ritual: (1) confirm the phase's quality loop has passed; (2) read the artifact and present it to the user; (3) explicitly request approval and wait; (4) on approval — write `gates.<phase>`, `commit("flow(<unit>): <phase> passed review")`, continue; (5) on a concrete revision request — dispatch the author to revise and re-present (does not count toward loop rounds, `# INV-7`); (6) on a request to redo an earlier phase — treat as a user-initiated waterfall fallback: run `fallback(toPhase, reason)` with the reason marked "user-initiated". |
| `fallback(toPhase, reason)` | Waterfall fallback ritual. Expands to the fallback procedure defined in the orchestrate skill (FB record, revocation, redo, re-approval, replay downstream in order). `# INV-6` When a phase skill runs standalone, only the record-and-revoke steps are executed, then `halt` telling the user to run `/agent-flow:<toPhase>` — cross-phase replay belongs to orchestrate. `# INV-11` |
| `escalate(rootCause, details)` | ESC ritual: assign `ESC-<n>`; atomic dual write to `decisions.md` and `state.json.escalations` with `resolvedAt: null` `# INV-12`; set the loop's `qualityLoops.<key>.status = "escalated"` (skip when no loop key exists, e.g. Wrap); present the ESC to the user and wait for a ruling; then backfill both records and act on the ruling. |
| `ask(question)` | Ask the user and wait for the answer. |
| `halt(message)` | Stop the procedure and present the message/state to the user. Default action under the closed-world rule. |
| `commit(message)` | `git commit` on the unit branch. |
| `run(command)` | Execute a shell command via Bash. |

## 3. Variables

| Variable | Meaning |
|---|---|
| `$unit` | The work unit name, `<YYYY-MM-DD>-<slug>`, also the directory name under `.agent-flow/changes/`. |
| `$ARGUMENTS` | The raw arguments the user passed when invoking the skill. |
| `$round` / `$maxRounds` | Current round / round cap of the quality loop in progress. |
| `$verdict` / `$findings` | Parsed from the reviewer's JSON reply (`references/quality-loop.md`). |
| `$agent_id` | The `agentId` in a dispatch's launch result, used to `resume` that subagent. |
| `$worktree_path` | `.agent-flow/worktrees/<ticket-id>` — decided by the main session when it runs `make_worktree`, not reported back by the platform. |

## 4. Shared procedures

### `resolve_unit()`

Determine which work unit the skill operates on:

```
if current branch is flow/<unit-name> and .agent-flow/changes/<unit-name>/ exists:
  return <unit-name>
if .agent-flow/changes/ has exactly one subdirectory:
  return that subdirectory name
ask("Which work unit should this run on?")
```

### `create_unit($request)`

```
name $unit as <YYYY-MM-DD>-<slug>   # slug: 2-4 English keywords, kebab-case;
                                    # same-day collision appends an increasing suffix
run("mkdir -p .agent-flow/changes/$unit")
write ".agent-flow/.gitignore" with the single line "worktrees/"
                                    # keeps ticket worktrees out of the project's
                                    # index without touching any project config
                                    # `# INV-13`
write_state(initial)                # schemaVersion: 2, currentPhase: "explore",
                                    # phases: all 7 keys "pending",
                                    # gates: explore/spec/review = {"approvedAt": null, "approvedBy": null},
                                    # qualityLoops: {}, tickets: {}, fallbacks: [], escalations: [],
                                    # branch: {"unit": "flow/$unit", "baseRef": "main"}
run("git checkout -b flow/$unit main")
```

Build needs no preflight: `make_worktree` names the source branch
explicitly, so nothing about the project's configuration or the currently
checked-out branch can change where a ticket worktree forks from.

### `standard_loop(key, author_briefing, reviewer_briefing, maxRounds=3)`

The standard quality loop (routing detail: `references/quality-loop.md`):

```
dispatch(worker, author_briefing)
loop:
  dispatch(reviewer, reviewer_briefing + {$round, $maxRounds})
  match $verdict:                                   # INV-5, INV-6
    "pass"   -> write_state(qualityLoops.<key>.status = "passed"); return
    "reject" ->
      if every blocking finding has targetPhase == current phase:
        if $round == $maxRounds:
          escalate("round-limit", $findings); return
        # in-phase return to the author:
        #   Build ticket -> resume($agent_id, $findings)   # INV-3
        #   other phases -> dispatch(worker, revision briefing + all findings)
        increment rounds
      else:
        fallback(earliest targetPhase among blocking findings, $findings)
        return
```

## 5. Invariants (INV-1 – INV-13)

Cross-phase hard rules. Exceptions to an invariant may only be written
inside that invariant's own entry. The "Source" column records the design
decisions each rule traces back to.

| # | Invariant | Source |
|---|---|---|
| INV-1 | `state.json` is written only by the main session driving the flow; subagents never write it. | Q21, Q30 |
| INV-2 | Test contract: once the TDD quality loop passes, ticket test files must not be modified by the `worker`; a test suspected faulty is routed as a finding with `targetPhase: "tdd"` and falls back to TDD. | Q10, R2, R3 |
| INV-3 | A review fix for an in-flight Build ticket is a `SendMessage` resume of the same `agentId` whenever that agent is still addressable — it keeps the context the agent already built. A fresh dispatch pointed at the same worktree path is a legitimate fallback and loses no work, because the main session owns the worktree's lifetime, not the agent. Either way the fix happens **in the ticket's existing worktree**; never create a second worktree for the same ticket. | research 07 Test A, research 13 §2, R3, R12 |
| INV-4 | At most 20 concurrent subagents; dispatch in batches beyond that. | research 02 §3.1 |
| INV-5 | Loop round caps: standard 3, Review 5. `qualityLoops.review.rounds` is a persistent budget preserved across waterfall fallbacks — revocation never resets it. Exceeding a cap → ESC (`round-limit`). | Q4, Q29 |
| INV-6 | Waterfall fallback: when any blocking finding's `targetPhase` is earlier than the current phase, automatically fall back to the **earliest** such phase and redo; downstream phases and gates are revoked per the orchestrate skill's fallback procedure (Build→TDD is a partial fallback that preserves unaffected tickets) and replayed in order. Three accumulated fallbacks to the same target phase → ESC (`fallback-limit`). | R3 |
| INV-7 | A user's revision request at an approval gate does not count toward loop rounds. | inherited |
| INV-8 | Three approval gates: Explore, Spec, Review. A gate revoked by a fallback must be re-approved after the redo. | R2, R3 |
| INV-9 | Wrap is execute-verify: any failed step → ESC (`wrap-failure`); no retry, no automatic rollback. | Q25, S12 |
| INV-10 | Every review is an independent dispatch of `reviewer` made directly by the main session; subagents never nest dispatches; parallel reviewers cannot see each other's work; triage never trusts self-reported severity. | research 04 |
| INV-11 | Standalone phase-skill invocation: stop with a hint when preconditions are unmet; never auto-continue to the next phase when done. | Q2, S8, S9 |
| INV-12 | FB/ESC records are an atomic dual write: the `decisions.md` entry and the corresponding `state.json` array element are written together, never just one. | Q31, R3 |
| INV-13 | Ticket worktrees are created by the main session with `make_worktree`, always forked from `flow/$unit` by name, always at `.agent-flow/worktrees/<ticket-id>`, and always removed once the ticket is merged. The Agent tool's `isolation` parameter is never used. `.agent-flow/.gitignore` must contain `worktrees/` before the first worktree is created — without it `git add -A` commits the worktree as an embedded repository. | research 12, research 13, R12 |
