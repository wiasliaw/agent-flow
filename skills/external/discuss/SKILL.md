---
name: discuss
description: >-
  Runs a Socratic dialogue with you to pin down intent before any spec or
  code gets written, then asks for your approval before moving on.
---

# Discuss

Discuss is the starting point of the agent-flow pipeline: a Socratic
dialogue that pins down what you actually want before any Explore, Spec, or
code work happens. It is one of the four approval gates (Discuss, Spec,
Ticket, Review) — nothing proceeds to Explore until you approve the intent
summary this phase produces.

**Main-session exception**: the dialogue itself (both the divergent and the
convergent stage below) must be conducted directly by the main session, not
delegated to a subagent. This is the one deliberate exception to "the main
session only orchestrates, subagents do the work" — a forked-out subagent
cannot hold a multi-turn, real-time back-and-forth with you. The exception
is scoped narrowly to the conversation and writing the summary; independent
review of that summary is still delegated to the `agent-flow:intent-reviewer`
subagent.

## 1. Preconditions

Discuss has no preceding-phase artifact dependency — it is the pipeline's
starting point, so there is nothing to check before beginning.

You can reach this phase in one of two ways:

- **Driven by `/agent-flow:orchestrate`**: the orchestrator has already
  created the work unit (directory, `state.json`, unit branch). Skip
  straight to "2. Procedure" below.
- **Invoked directly as `/agent-flow:discuss`** (without `orchestrate`):
  this skill must decide for itself whether a target work unit already
  exists:
  - If your message does not name an existing work unit, or the current
    git branch is not any `flow/<unit-name>`: treat this as creating a
    **new** work unit. Run the same creation procedure `orchestrate` would
    run (see "2a. Creating a new work unit" below).
  - If you do name an existing work unit **and** that unit's `discuss.md`
    already exists and has already passed the Discuss approval gate:
    **refuse to re-run the dialogue.** Report back: "This unit's Discuss has
    already been approved. If you want to change it, explicitly ask to
    'modify the approved Discuss summary.'" Do not silently re-enter the
    divergent/convergent dialogue — re-running the same-named command must
    never accidentally overwrite an already-approved artifact. If you later
    explicitly ask to modify the approved Discuss summary, this skill
    re-enters the divergent/convergent dialogue, re-runs the full quality
    loop and gate approval on completion, and appends a trace entry to
    `changes/<unit>/decisions.md` (root-cause classification: "user-initiated
    modification" — this is not a standard ESC escalation and is not pushed
    into `state.json.escalations`).

### 2a. Creating a new work unit (standalone invocation only)

When invoked standalone and no existing unit applies, this skill performs
the same work-unit creation procedure that `orchestrate` performs, since no
`orchestrate` session is running to do it:

1. Decide `<unit-name>`: `<YYYY-MM-DD>-<slug>` — today's date, plus a slug
   derived from the core intent of the request: take the 2-4 English words
   that best represent the feature's subject (translating the key terms
   first if the request was described in Chinese), lowercase, hyphen-joined
   (kebab-case), stripped of punctuation and filler words (`the`/`a`/`for`,
   etc.). If the same slug already exists for today, append an incrementing
   suffix (`-2`, `-3`, …).
2. Create `.agent-flow/changes/<unit-name>/`.
3. Initialize `state.json`: `schemaVersion: 1`, `unit: <unit-name>`,
   `createdAt`/`updatedAt` set to now, `currentPhase: "discuss"`, all eight
   `phases.<phase>` set to `{"status": "pending"}`, all four
   `gates.<phase>` set to `{"approvedAt": null, "approvedBy": null}`,
   `qualityLoops: {}`, `tickets: {}`, `escalations: []`, and
   `branch: {"unit": "flow/<unit-name>", "baseRef": "main"}`.
4. Check out the unit branch: `git checkout -b flow/<unit-name> main`.

Because no `orchestrate` session is running, this skill itself takes on the
minimal role of the single writer of `state.json` for the duration of this
phase — writing to `state.json` is never delegated to a subagent.

## 2. Procedure

1. **Divergent stage (open-ended)**: the main session asks you open-ended
   questions directly — e.g., "What's the pain point with the current
   behavior?", "Is there an existing mechanism we should build on?" — with
   no fixed set of options, encouraging you to freely describe intent, pain
   points, and constraints. The main session records each round of Q&A.
   There is no fixed number of rounds; the main session keeps asking until
   it judges the intent is clear enough to move on. The test for "clear
   enough": can the main session now pose concrete decision points as
   yes/no or option-based (1/2/3) questions? If not yet, keep asking
   open-ended questions.

2. **Convergent stage (option-based)**: for each key decision point that
   surfaced during the divergent stage, the main session asks one
   option-based question at a time, each with suggested options — e.g.,
   "How long should the reset link stay valid? 1. 15 minutes 2. 1 hour
   3. 24 hours." You answer each question in turn.

3. **Produce the intent summary**: the main session organizes the divergent
   and convergent content into the structured summary defined in "3.
   Artifact" below, and writes it to `changes/<unit>/discuss.md`.

4. **Dispatch the review**: `orchestrate` (or this skill itself, when
   invoked standalone) uses the Agent tool to dispatch
   `agent-flow:intent-reviewer`, passing the path to
   `changes/<unit>/discuss.md` and the current round info
   (`round` / `maxRounds: 3`).

5. **Read the review verdict**, parsed per the `quality-loop` internal
   skill's JSON contract:
   - `"pass"`: proceed to "4. Approval gate" below.
   - `"reject"`: for Discuss specifically, every finding's `rootCause` will
     always be `"implementation-issue"` — Discuss has not been approved yet,
     so there is no earlier approved artifact that could be the root cause;
     Discuss is the very first gate this unit ever reaches. This is a
     Discuss-specific special case (other phases' reviewers still make a
     full `rootCause` judgment); the dispatch prompt to `intent-reviewer`
     should say this explicitly so it never produces a meaningless
     `approved-artifact` verdict. Based on the findings, the main session
     asks you targeted follow-up questions (returning to the divergent or
     convergent stage, whichever the finding calls for), revises the
     summary, and returns to step 4.

6. **Round cap — 3 rounds**: if round 3 is still `"reject"`, this does not
   silently stop the phase. It still goes through the standard escalation
   write (append an `## ESC-<n>` entry to `changes/<unit>/decisions.md` and
   push a matching entry to `state.json.escalations`, keeping the same
   auditability as every other phase), but the *presentation* to you is
   merged with the approval gate rather than treated as a separate
   interruption: when the intent summary is presented for approval (see "4.
   Approval gate"), it is presented together with a "Pending items" section
   quoting that ESC's content. Your approval response then also serves as
   your decision on those pending items — this reflects Discuss's nature as
   the phase right before its own approval gate, so there is no reason to
   interrupt you twice.

## 3. Artifact

`changes/<unit>/discuss.md`, with exactly these three sections:

```markdown
# Discuss: <unit-name>

## Divergent Stage Notes

<round-by-round record of open-ended questions and your answers>

## Convergent Stage Options and Answers

### Q1: <option-based question>
**Options**: 1. ... 2. ... 3. ... (with a suggested choice)
**Answer**: <your choice and any elaboration>

(repeat this format for every convergent-stage question)

## Intent Summary

<the organized description of intent, for intent-reviewer to review and for
you to approve>
```

## 4. Approval gate

Once the quality loop passes (or round 3 is reached — see step 6 above):

1. Present the full "Intent Summary" section (and, if round 3 was reached
   without passing, the "Pending items" section described above).
2. Ask explicitly: "Here's my understanding of your intent: <summary>. Do
   you approve moving into Explore?"
3. **If you approve**: write
   `state.json.gates.discuss = {"approvedAt": <now>, "approvedBy": "user"}`,
   commit with message `flow(<unit>): discuss passed review`. From this
   point `discuss.md` is an approved artifact — it cannot be overturned by
   any agent on its own (it follows the same non-reversal principle applied
   to every other approved artifact).
4. **If you ask for changes instead**: this goes back to the revision flow
   in step 5 above. It does not count toward the standard loop's round
   count, because this is you intervening directly, not a reviewer
   rejection.

## 5. Standalone invocation behavior

- **Precondition**: none — Discuss is the pipeline's starting point, so a
  standalone `/agent-flow:discuss` call never needs to check whether any
  earlier phase's artifact exists.
- **After completion**: this skill does **not** automatically continue into
  Explore. Continuation logic belongs to `orchestrate`, not to any single
  phase skill. Once you approve the gate, you may additionally be told
  something like: "Intent approved. Continue with `/agent-flow:explore`, or
  hand off to `/agent-flow:orchestrate` to drive the rest automatically."
  That suggestion is advisory text only — it has no effect on
  `state.json`'s correctness; the gate's approved state reads the same
  regardless of whether `explore` is invoked manually afterward or picked up
  by `orchestrate`.
