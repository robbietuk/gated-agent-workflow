---
name: wf-plan
description: Planning loop of the agentic workflow. Use when the user runs /wf-plan after design approval (feature) or after /wf-start (small change). Drafts outline.md as vertical slices with req IDs, acceptance criteria, tests to write, files likely touched and risk flags; revises with the user until approved, then hands off to /wf-build (which switches PHASE to build).
---

# wf-plan: vertical slices the user approves

The outline is the set of decisions the implementer cannot make alone: which slices, in which order,
proven by which tests. It is not the code. A plan longer than the code it describes has written the code.

## Preconditions
Read `.workflow/active.env`, then `design.md` (feature), or `spec.md` (small), or `bug-report.md` (bug,
when /wf-debug sends you here for a multi-slice fix), plus `research.md` and `decisions.md` if present.
- Feature without an approved design.md: stop, "Run `/wf-brainstorm` first."
- Set `PHASE=plan`.

## 1. Slice it
Copy `.workflow/templates/outline.md` to `$WORK_DIR/outline.md` and fill it.
- **Vertical slices:** each slice delivers one end-to-end, observable piece of behaviour (through every
  layer it needs), not a layer ("all the models", "all the UI"). Each can be tested and reviewed alone.
- **Right-size:** one slice = one test cycle worth a fresh reviewer's gate, typically 1-5 files and
  reviewable in one sitting. Fold scaffolding/config into the slice that needs it.
- **Order:** riskiest or most-depended-on first; mark `Depends on`.
- **Small change track:** exactly one slice (S1). If it will not fit in one, tell the user it is not a
  small change and suggest the feature track.

## 2. Per slice, fill every field
- `Req IDs`: every spec "done when" / req / hazard ID must land on at least one slice.
- `Acceptance criteria`: Given/When/Then, observable, using the spec's exact values (limits, units, text).
- `Tests to write`: test file and test name per criterion; these become the slice's **locked tests**, so
  they must be specific enough to write before the code and to fail without it.
- `Files likely touched`, `Risk flag` (low/med/high with the reason: safety, concurrency, config, compat).
- `Status: todo`, `Review rounds: 0/<MAX_REVIEW_ROUNDS>` (from `.cursor/workflow.env`, default 3).

## 3. Self-review before showing it
1. **Coverage:** every spec item and design risk/hazard maps to a slice and a test. List gaps.
2. **Decides something:** no "TBD", "handle edge cases", "add validation", "write tests for the above".
3. **Consistency:** names, types and signatures match across slices and the design.
4. **Unhappy paths:** for each slice, the most likely bad input or failure the spec implies but does not
   state has a criterion and a test (or an explicit "out of scope").
5. **Proportion:** outline shorter than the code it describes; signatures and test names, not bodies.
Fix inline.

## 4. Planning loop with the user
Show the slice table and the riskiest slice in full. Ask about gaps and real choices **one question at a
time** (ordering, scope of a slice, a value the spec does not pin). Increment `Planning rounds` each time
you revise. Responses:
- **Approve** -> step 5.
- **Revise** -> change outline.md, show the diff, ask again. More than 3 rounds: say so and suggest
  revisiting `spec.md`.
- **Rework** (the design is wrong) -> append a dated entry to `decisions.md`, set `PHASE=brainstorm`,
  Ask: "Continue with `/wf-brainstorm` now?"

## 5. Hand off (on approval only)
- Outline `Status: approved <date>`; dated entry in `decisions.md`.
- In `.workflow/active.env`: keep `PHASE=plan`, set `SLICE=S1`, `LOCK_SHA=` (empty until wf-build locks
  tests; on the bug track keep the LOCK_SHA from /wf-debug and keep S1 as `tests-locked`). Do **not** set
  `PHASE=build` here: `/wf-build` does that when it starts, so the stop hook never fires at the end of a
  planning turn.
- Ask: "Continue with `/wf-build` now? It starts with S1; once it starts, the stop hook runs build +
  tests after every agent turn."

## Never
- Write product code or tests in this skill.
- Leave a req ID without a slice, or a slice without tests.
- Approve the outline on the user's behalf.

Adapted from obra/superpowers writing-plans (MIT).
