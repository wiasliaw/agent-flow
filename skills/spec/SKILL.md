---
name: spec
description: >-
  Turns the approved findings into an EARS-format delta spec, numbered for
  traceability, and asks for your approval before tests get written.
---

# Spec

Before executing, `Read` `${CLAUDE_PLUGIN_ROOT}/references/glossary.md` —
all DSL vocabulary and `INV-n` numbers resolve there.

## 1. Preconditions

```
resolve_unit()
if changes/$unit/explore.md missing or gates.explore.approvedAt == null:
  halt("Run /agent-flow:explore first.")   # no auto-run, no skip syntax
if phases.prototype.status == "done":
  include prototype.md as input
# validity is judged by phase STATUS, not file existence: when prototype
# is "skipped", a leftover prototype.md (stale draft after a fallback)
# is NOT valid input
```

## 2. Procedure

```
1. resolve_unit(); confirm preconditions
2. dispatch(worker, role: spec author; refs: sdd-guide.md;
            inputs: explore.md, (phases.prototype == "done") prototype.md,
            and .agent-flow/specs/<domain>/spec.md paths;
            write changes/$unit/spec-delta.md)
3. dispatch(reviewer, refs: sdd-guide.md, quality-loop.md;
            round $round/$maxRounds=3;
            check: EARS sentences correct; numbering contiguous, no
            conflicts; ADDED/MODIFIED/REMOVED classification true to the
            main spec; content matches the conclusions of explore.md
            (and prototype.md when phases.prototype == "done"); no new
            scope the investigation never mentioned)
4. match $verdict:
     "pass" -> gate (section 4)
     "reject", all blocking targetPhase == "spec"
            -> re-dispatch worker with findings; rounds += 1; cap 3;
               over cap -> escalate("round-limit", findings)
     "reject", any blocking targetPhase in {"explore", "prototype"}
            -> fallback(earliest such phase, findings)
               # e.g. misleading intent summary, wrong experiment conclusion
```

## 3. Artifact — `changes/<unit>/spec-delta.md`

```markdown
---
unit: 2026-09-10-password-reset
domain: auth
---

## ADDED Requirements

### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a reset link valid for 1 hour.

### 1.2 WHEN the reset link is used after expiry THE SYSTEM SHALL reject the
request and prompt the user to request a new link.

## MODIFIED Requirements

(omit when greenfield or no existing requirement changed — never write an
empty section)

## REMOVED Requirements

(same)
```

- `domain`: the Wrap merge target. The `worker` picks it from the existing
  `.agent-flow/specs/` domains; if none fits, it coins a new kebab-case
  domain name.
- Numbering is `<main>.<sub>`, the same format as ticket
  `requirementRefs`; MODIFIED/REMOVED keep the original number; REMOVED
  carries a one-line reason.

## 4. Gate

`gate("spec")`. Present the full `spec-delta.md` and ask for approval to
enter TDD. On approval: write `gates.spec`, commit; `spec-delta.md`
becomes the approved artifact. A user revision request goes back to the
`worker` (does not count rounds, `# INV-7`).

## 5. Standalone invocation

- `explore.md` missing or unapproved: stop and hint to run
  `/agent-flow:explore` first — no auto-run, no skip syntax.
- Never auto-continue to TDD after approval `# INV-11`.
