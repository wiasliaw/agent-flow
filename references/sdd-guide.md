# SDD Guide — EARS, Delta Spec, Backlinks, Main-Spec Merge

This file defines the spec-driven-development (SDD) format contract used
across the Spec, TDD, Review, and Wrap phases: the EARS sentence pattern
for requirement text, the delta-spec ADDED/MODIFIED/REMOVED contract, the
requirement backlink field on tickets, and the rules for merging a delta
into the main spec.

## 1. EARS sentence pattern

Every requirement's body must be written using the EARS pattern:

```
WHEN <event/condition> THE SYSTEM SHALL <expected behavior>
```

Every requirement must carry a number in `<main>.<sub>` format (e.g. `1.1`,
`1.2`).

## 2. Delta spec syntax (ADDED / MODIFIED / REMOVED)

A `spec-delta.md` file describes changes relative to the main spec using up
to three sections:

```markdown
## ADDED Requirements
### 1.1 WHEN a user requests a password reset THE SYSTEM SHALL send a
reset link valid for 1 hour.

## MODIFIED Requirements
### 2.3 WHEN ... (original number, new content)

## REMOVED Requirements
### 3.1 (original number, with a one-line reason for removal)
```

- **ADDED Requirements**: new requirements, each with a new number.
- **MODIFIED Requirements**: an existing requirement, keyed by its original
  number, with fully rewritten content.
- **REMOVED Requirements**: an existing requirement, keyed by its original
  number, with a one-line explanation of why it is being removed.

**Greenfield case**: if the domain has no main spec yet, `spec-delta.md`
contains only the `## ADDED Requirements` section. The `MODIFIED
Requirements` and `REMOVED Requirements` sections are omitted entirely —
do not write them out as empty sections.

## 3. Requirement backlink on tickets

Every ticket's frontmatter must include a `requirementRefs` field: a YAML
array of requirement numbers, e.g.:

```yaml
requirementRefs: ["1.1", "2.3"]
```

This field name matches `state.json.tickets.<id>.requirementRefs` exactly
(see `references/state-management.md`); the main session mirrors this
field into `state.json` whenever it reads a change to the ticket's
frontmatter.

- Every ticket must reference at least one requirement number.
- Test cases produced in the TDD phase should also note the corresponding
  requirement number in the test file's comments or description, so a
  human can trace the test back to its requirement.

## 4. Merging a delta into the main spec (Wrap phase)

This is performed by the `worker` in its wrap-executor role. The main spec
is stored per domain at `.agent-flow/specs/<domain>/spec.md`.
Domain-splitting granularity is project-defined; this file does not
prescribe how domains are split.

- **ADDED**: append each requirement to the corresponding domain's
  `spec.md` (create the file if it doesn't exist yet).
- **MODIFIED**: find the existing entry in the main spec by its number and
  overwrite its entire content.
- **REMOVED**: delete the entry from the main spec by its number.

After merging, the main spec must remain internally consistent within its
own domain directory: requirement numbers must not collide within the same
domain. Global renumbering across domains is not required.

## 5. Reviewer's additional checks

The `reviewer` (Spec review, and the Review phase's spec-compliance lens)
must additionally verify:

- Whether the EARS sentence pattern is used correctly.
- Whether requirement numbers are contiguous and free of conflicts.
- Whether the ADDED/MODIFIED/REMOVED classification matches reality — for
  example, a requirement marked `MODIFIED` when the main spec actually has
  no existing entry under that number must be judged a misclassification.
