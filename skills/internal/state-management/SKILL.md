---
name: state-management
description: >-
  Load this before any read or write to
  .agent-flow/changes/<unit>/state.json — keeps phase status, gate status,
  loop rounds, and ticket status consistent with the schema.
user-invocable: false
---

# State Management

This skill defines how `.agent-flow/changes/<unit>/state.json` must be read
and written. It is loaded by `orchestrate`, the only role that ever writes
this file.

## 1. Schema version check

Before doing anything else with a `state.json` file, read its
`schemaVersion` field and confirm it equals the current version defined by
this skill: **1**.

If `schemaVersion` does not equal `1`, stop immediately and report this to
the user. Do not attempt to migrate or reinterpret the file — this skill
does not define any automatic migration logic for schema version mismatches.

## 2. Field reference

The table below is the authoritative field-by-field reference for
`state.json`. Anyone loading this skill to read or write the file must
follow these semantics exactly.

### Top-level fields

| Field | Type | Notes |
|---|---|---|
| `schemaVersion` | integer | Always `1` for this schema version. |
| `unit` | string | The work unit name, format `<YYYY-MM-DD>-<slug>` (e.g. `2026-09-04-auth`). Matches the containing directory name. |
| `createdAt` | string | ISO 8601 timestamp; set once when the unit is created, never changed afterward. |
| `updatedAt` | string | ISO 8601 timestamp; updated every time `orchestrate` writes this file. |
| `currentPhase` | string enum | The phase key currently active: `"discuss"` \| `"explore"` \| `"prototype"` \| `"spec"` \| `"ticket"` \| `"dev"` \| `"review"` \| `"wrap"`. |
| `phases` | object | See "`phases` object" below. |
| `gates` | object | See "`gates` object" below. |
| `qualityLoops` | object | See "`qualityLoops` object" below. Can be an empty object `{}`. |
| `tickets` | object | See "`tickets` object" below. Empty object `{}` until the Ticket phase produces tickets. |
| `escalations` | array | See "`escalations` array" below. Can be an empty array. |
| `branch` | object | See "`branch` object" below. |

### `phases` object

Keyed by the same eight phase names as `currentPhase`. Each value has:

| Sub-field | Type | Notes |
|---|---|---|
| `status` | string enum | `"pending"` (not started) \| `"in_progress"` (active, including while a quality loop is running or escalated) \| `"done"` (quality loop passed, and — for gate phases — user-approved) \| `"skipped"` (explicitly skipped). |
| `artifact` | string \| null | Relative path (relative to `changes/<unit>/`) to the phase's main artifact, e.g. `"discuss.md"`, `"tickets/"`. Should be set when `status` is `"done"`. |
| `reason` | string | Only present when `status` is `"skipped"`. Currently the only phase that legitimately uses `"skipped"` is `prototype` (skipped when Explore leaves no open technical question). |

While a phase is escalated (waiting on a user decision from a quality loop),
`phases.<phase>.status` stays `"in_progress"` — escalation state lives in
`qualityLoops.<key>.status` and `escalations`, not in `phases.<phase>.status`.

### `gates` object

Keyed by exactly the four commitment-point phases: `"discuss"`, `"spec"`,
`"ticket"`, `"review"` (`explore`, `prototype`, `dev`, and `wrap` are not
commitment points and have no entry here). Each value has:

| Sub-field | Type | Notes |
|---|---|---|
| `approvedAt` | string \| null | ISO 8601 timestamp; `null` until the user approves the gate. |
| `approvedBy` | string \| null | `"user"` once approved; `null` until then. |

### `qualityLoops` object

Keyed by `<phase>` for single-pass phases (e.g. `"spec"`), or by
`<phase>:<ticket-id>` for the Dev phase, which runs one loop per ticket
(e.g. `"dev:TICKET-002"`). Each value has:

| Sub-field | Type | Notes |
|---|---|---|
| `rounds` | integer | Rounds completed so far. |
| `maxRounds` | integer | The loop's round limit: `3` for the standard loop (all phases except Review), `5` for the Review heavy loop. |
| `status` | string enum | `"in_progress"` (loop still running) \| `"passed"` (review passed) \| `"escalated"` (round limit reached, or an `approved-artifact` root cause was found — loop is stopped, waiting on a user decision). |

### `tickets` object

Keyed by ticket id (e.g. `"TICKET-001"`). Each value mirrors the
corresponding ticket file's frontmatter — **the ticket frontmatter is the
authoritative source, this is only a mirror**:

| Sub-field | Type | Notes |
|---|---|---|
| `status` | string enum | Mirrors the ticket frontmatter `status` field (`draft` / `approved` / `in_dev` / `in_review` / `merged` / `escalated`). |
| `dependsOn` | array\<string\> | Mirrors the ticket frontmatter `dependsOn` field. Not authoritative. |
| `requirementRefs` | array\<string\> | Mirrors the ticket frontmatter `requirementRefs` field (EARS requirement numbers the ticket implements). Not authoritative. |

### `escalations` array

Each element records one escalation event, and corresponds one-to-one with
an `## ESC-<n>` entry in `decisions.md` (see the `quality-loop` skill for the
full escalation trace format):

| Field | Type | Notes |
|---|---|---|
| `id` | string | `"ESC-<n>"`, `n` incrementing within the work unit; shared with the matching `decisions.md` heading. |
| `phase` | string | The phase that raised the escalation. Any of the eight phase names, including `"wrap"`. |
| `ticket` | string \| null | The ticket id if the escalation came from a Dev-phase ticket; `null` otherwise. |
| `rootCause` | string enum | `"approved-artifact"` (root cause is in an already-approved artifact) \| `"round-limit-exceeded"` (implementation issue, but the loop's round limit was reached). |
| `targetArtifact` | string enum \| null | Required when `rootCause` is `"approved-artifact"`: `"discuss"` \| `"spec"` \| `"ticket"`. `null` when `rootCause` is `"round-limit-exceeded"`. |
| `raisedAt` | string | ISO 8601 timestamp, set when the escalation is raised. |
| `resolvedAt` | string \| null | ISO 8601 timestamp; `null` until the user's decision is recorded. |

### `branch` object

| Sub-field | Type | Notes |
|---|---|---|
| `unit` | string | The unit branch name, format `"flow/<unit-name>"`. |
| `baseRef` | string | The branch the unit branch was forked from (currently always `"main"`). |

### Example

```json
{
  "schemaVersion": 1,
  "unit": "2026-09-04-auth",
  "createdAt": "2026-09-04T10:00:00+08:00",
  "updatedAt": "2026-09-04T12:30:00+08:00",
  "currentPhase": "dev",
  "phases": {
    "discuss":   { "status": "done", "artifact": "discuss.md" },
    "explore":   { "status": "done", "artifact": "explore.md" },
    "prototype": { "status": "skipped", "reason": "no open technical question" },
    "spec":      { "status": "done", "artifact": "spec-delta.md" },
    "ticket":    { "status": "done", "artifact": "tickets/" },
    "dev":       { "status": "in_progress" },
    "review":    { "status": "pending" },
    "wrap":      { "status": "pending" }
  },
  "gates": {
    "discuss": { "approvedAt": "2026-09-04T10:20:00+08:00", "approvedBy": "user" },
    "spec":    { "approvedAt": "2026-09-04T11:10:00+08:00", "approvedBy": "user" },
    "ticket":  { "approvedAt": "2026-09-04T11:40:00+08:00", "approvedBy": "user" },
    "review":  { "approvedAt": null, "approvedBy": null }
  },
  "qualityLoops": {
    "spec": { "rounds": 1, "maxRounds": 3, "status": "passed" },
    "dev:TICKET-002": { "rounds": 2, "maxRounds": 3, "status": "in_progress" }
  },
  "tickets": {
    "TICKET-001": { "status": "merged", "dependsOn": [], "requirementRefs": ["1.1"] },
    "TICKET-002": { "status": "in_review", "dependsOn": ["TICKET-001"], "requirementRefs": ["1.2", "2.1"] }
  },
  "escalations": [
    {
      "id": "ESC-1",
      "phase": "dev",
      "ticket": "TICKET-002",
      "rootCause": "approved-artifact",
      "targetArtifact": "spec",
      "raisedAt": "2026-09-04T13:00:00+08:00",
      "resolvedAt": null
    }
  ],
  "branch": { "unit": "flow/2026-09-04-auth", "baseRef": "main" }
}
```

## 3. When to write

`state.json` is written only by `orchestrate`, and only at these moments:

- **Work unit creation** (Discuss phase start): initialize the entire
  `state.json` skeleton.
- **Every phase status transition** (`pending → in_progress → done` or
  `pending → in_progress → skipped`).
- **Every gate approval**: write into `gates.<phase>` when the user approves
  a commitment point.
- **Every quality loop round** (pass or reject): update the corresponding
  `qualityLoops.<key>` entry.
- **Every time a ticket's markdown frontmatter change is observed**:
  overwrite the matching `tickets.<id>` fields to mirror it. The ticket
  frontmatter is the source of truth; `state.json` is written *after*
  observing a change, not at the instant the change happens — a brief
  window of inconsistency is acceptable as long as it is resolved before the
  next read.
- **Every time an ESC entry is appended to `decisions.md`**: append a
  matching element to the `escalations` array in the same operation.

## 4. Single-writer principle

Only `orchestrate` reads and writes `state.json`. No role agent reads or
writes this file directly: ticket dependency information is authoritative
in ticket frontmatter, and loop round numbers are told to role agents
directly in their dispatch prompts by the orchestrator.

## 5. How to write

Always write the entire file: read the current contents, apply the change
in memory, then overwrite the whole file. Do not attempt partial/in-place
patches — this minimizes the risk of corrupting the file's structure.

Because Dev phase can have multiple tickets in flight in parallel (raising
the frequency of `state.json` updates), `orchestrate` must re-read the
current file contents immediately before each write, to avoid overwriting
the file with stale in-memory state.
