# State Management — `.agent-flow/changes/<unit>/state.json`

This file defines how `state.json` must be read and written. It is read by
the main session — the only writer of this file.

## 1. Schema version check

Before doing anything else with a `state.json`, read `schemaVersion` and
confirm it equals **2**. If it does not, stop immediately and report to the
user. Do not migrate or reinterpret the file — no automatic migration logic
exists.

## 2. Field reference

### Top-level fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `schemaVersion` | integer | yes | Always `2` for this schema version. |
| `unit` | string | yes | Work unit name, `<YYYY-MM-DD>-<slug>`; matches the containing directory name. |
| `createdAt` / `updatedAt` | string | yes | ISO 8601. `createdAt` set once at unit creation; `updatedAt` on every write. |
| `currentPhase` | string enum | yes | `"explore"` \| `"prototype"` \| `"spec"` \| `"tdd"` \| `"build"` \| `"review"` \| `"wrap"`. |
| `phases` | object | yes | Keys fixed to the seven phase names; values below. |
| `gates` | object | yes | Keys fixed to `"explore"` / `"spec"` / `"review"`; values below. |
| `qualityLoops` | object | yes (may be `{}`) | See below. |
| `tickets` | object | yes (may be `{}`) | See below. |
| `fallbacks` | array | yes (may be `[]`) | See below. |
| `escalations` | array | yes (may be `[]`) | See below. |
| `branch` | object | yes | `{"unit": "flow/<unit-name>", "baseRef": "main"}`. |

### `phases.<phase>`

- `status`: `"pending"` \| `"in_progress"` \| `"done"` \| `"skipped"`.
  `"skipped"` is legal only for `prototype` and must carry a `reason`
  sub-field.
- `artifact`: relative path to the phase's main artifact, set when `status`
  is `"done"`.
- On a waterfall fallback, revoked downstream phases reset to `"pending"`
  and the fallback target itself becomes `"in_progress"` — except a partial
  Build→TDD fallback, where `build` stays `"in_progress"` (see the
  orchestrate skill's fallback procedure).

### `gates.<phase>`

- `approvedAt` / `approvedBy`: both `null` until approved.
- When a fallback revokes a gate, both fields reset to `null` (the object
  shape is preserved). The prior approval is recorded in the corresponding
  FB entry of `decisions.md`; `state.json` keeps no historical values.

### `qualityLoops.<key>`

- Key: a phase name (`explore` / `prototype` / `spec` / `tdd` / `review`)
  or `build:<ticket-id>` (Build runs one loop per ticket).
- Value: `rounds`, `maxRounds` (standard 3, Review 5), `status`
  (`"in_progress"` \| `"passed"` \| `"escalated"`).
- On a waterfall fallback, the keys of revoked downstream phases are
  removed — with two exceptions: the `review` key is never removed (its
  `rounds` is a persistent five-round budget kept across fallbacks; only
  its `status` resets to `"in_progress"`), and in a partial Build→TDD
  fallback the `build:<id>` keys of unaffected tickets are kept.

### `tickets.<id>`

- `status`, `dependsOn`, `requirementRefs` — mirrored from the ticket
  file's frontmatter, which is the authoritative source. `status` uses the
  same six-value enum as the frontmatter: `draft` / `ready` / `in_build` /
  `in_review` / `merged` / `escalated`.

### `fallbacks[]` — one element per waterfall fallback event

| Field | Type | Notes |
|---|---|---|
| `id` | string | `"FB-<n>"`, increasing within the unit; shared link key with the `## FB-<n>` section in `decisions.md`. |
| `fromPhase` | string | The phase whose review triggered the fallback. |
| `toPhase` | string | The fallback target phase (where the root cause lies). |
| `reason` | string | One-line summary. |
| `round` | integer | The `fromPhase` loop round at trigger time. |
| `raisedAt` | string | ISO 8601. A fallback executes immediately; there is no `resolvedAt`. |

### `escalations[]`

| Field | Type | Notes |
|---|---|---|
| `id` | string | `"ESC-<n>"`, increasing within the unit (numbered independently from FB). |
| `phase` | string | Triggering phase; all seven phase names are legal. |
| `ticket` | string \| null | Ticket id when raised from a Build ticket. |
| `rootCause` | string enum | `"round-limit"` (loop rounds exceeded) \| `"fallback-limit"` (accumulated fallbacks to the same target reached the cap) \| `"wrap-failure"` (a Wrap execute-verify step failed). |
| `raisedAt` / `resolvedAt` | string \| null | `resolvedAt` stays `null` until the user rules. |

## 3. When to write

- Unit creation: initialize the whole file.
- Phase status changes (start, done, skipped) and `currentPhase` moves.
- Gate approval — and gate revocation during a waterfall fallback.
- Every completed quality-loop round (`rounds` / `status`).
- Ticket frontmatter changes: mirror into `tickets.<id>` as soon as the
  change is read.
- FB / ESC events: atomic dual write together with the `decisions.md`
  entry (never just one of the two).
- Every write updates `updatedAt`.

## 4. Single writer

Only the main session driving the flow (orchestrate, or the phase skill's
session when invoked standalone) writes this file. Subagents never write
it.

## 5. How to write

Read the whole file, modify, then overwrite the whole file. Always re-read
the latest content immediately before writing — especially important while
multiple Build tickets are in flight.
