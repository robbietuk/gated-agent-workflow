---
name: wf-build
description: Per-slice build loop of the agentic workflow. Use when the user runs /wf-build after the outline is approved (PHASE=plan with an approved outline, or PHASE=build). For the current slice - lock failing tests (red), implement until the stop hook's build+tests pass (green), run the fresh slice-reviewer subagent (spec then quality, max 3 fix rounds), then a show-me checkpoint; commit only after the user approves.
---

# wf-build: one slice, test-first, reviewed, shown

Tests decide when a slice is done. You write them first, watch them fail, lock them, and then change only
production code until they pass.

## Preconditions
- Read `.workflow/active.env` (`WORK_DIR`, `TRACK`, `PHASE`, `SLICE`, `LOCK_SHA`), `.workflow/config.env`,
  `outline.md` (must be `approved`), `design.md` or `spec.md` / `bug-report.md`, `decisions.md`.
- `PHASE` must be `build`, or `plan` with `outline.md` marked `approved`. Anything else: say which command
  comes first and stop. Do not change `PHASE` yet.
- Baseline (first slice only): run `TEST_CMD` once before writing anything. If tests other than this work
  item's locked tests already fail, stop and tell the user: a red baseline would burn the stop-hook budget.
- `TEST_CMD` must be set. If empty, ask the user for it and stop.
- Only now, with the checks above passed, set `PHASE=build` if it was `plan` (in build phase the stop hook
  runs the tests after every turn, so a stop for a red baseline or a missing `TEST_CMD` must happen first).
- `SLICE` = first slice in outline.md whose status is not `done`. Update `SLICE` in active.env.
- Working tree clean (`git status --porcelain`) apart from `.workflow/`. If not, ask the user.
- Record `Base SHA` (`git rev-parse HEAD`) in the slice block and set `Status: implementing` or keep
  `tests-locked`.

## a. Lock failing tests (skip if the slice is already `tests-locked`, e.g. from /wf-debug)
Read `references/tdd.md` the first time in a session.
1. Write the tests listed in the slice's `Tests to write`, one per acceptance criterion, using the exact
   values from the outline. Real code, no mocks unless unavoidable. Tests only: no production code yet.
2. Run them (focused command). **Watch them fail.** Each must fail for the expected reason (behaviour
   missing), not a typo, import or compile error. A test that passes now proves nothing: fix the test.
   If production code must exist to compile (C++/C#), add the minimal stub that compiles and still fails.
3. Commit only the tests (and stubs): `git commit -m "test(<SLICE>): lock failing tests [<req IDs>]"`.
4. `LOCK_SHA=$(git rev-parse HEAD)` into active.env and the slice block. Append the test file paths
   (one per line, repo-relative) to `$WORK_DIR/locked-tests.txt`. Earlier slices' files stay listed.
5. Set slice `Status: tests-locked`. Carry straight on to step b in the same turn.

## b. Implement (green)
- Write the minimal production code that makes the locked tests pass. Stay inside the slice: no extra
  features, no drive-by refactors. Follow the patterns named in design.md.
- Never edit, delete, skip, or weaken a file in `locked-tests.txt`. If a locked test looks wrong, stop and
  run `/wf-escalate` (reason "locked test wrong"). You may add *extra* tests in new files.
- When you end your turn the **stop hook** runs `BUILD_CMD` + `TEST_CMD`. On failure it sends you the
  output as the next message: read it, find the cause (use `/wf-debug` discipline: root cause before
  fixes; no shotgun changes), fix the code. It allows `MAX_STOP_RUNS` (5) runs; at the cap it tells you
  to run `/wf-escalate` with reason "stop-hook cap". Do that. Never keep going past it.
- Before claiming green, run `TEST_CMD` yourself and read the result (see references/verification.md).
- Refactor only while green.
- **CI checks:** make sure `.workflow/ci-checks.md` exists and is current (`.workflow/kit/ci-procedure.md` says how to
  find the repo's checks: `CI_CMD`, Makefile targets such as `make ci`, `.github/workflows/`). Run the fast
  local checks for the files this slice touched (format, lint, static analysis, tests outside `TEST_CMD`)
  and fix what fails. Never silence a check. Then set slice `Status: reviewing`.

## c. Two-stage review by a fresh subagent
Read `references/review-loop.md` before the first review and before **every** fix round.
0. **Size the review.** Measure the slice diff against `Base SHA` and its risk, pick the tier and the review
   plan from `.workflow/kit/scaling.md` (sections 1-3), and record it in the slice `Notes`
   ("Review: tier S, 1 reviewer"). Tier XS: one light review. Tier M: separate spec and quality reviewers.
   Tier L: stop, the slice is too big; recommend `/wf-escalate` to split it. High risk: add one
   `lens-reviewer` for the main risk.
1. Invoke the planned `slice-reviewer` subagent(s) (`/slice-reviewer`) with everything they need in the
   prompt: `MODE`, the slice block, binding constraints from the design, `Base SHA`, `LOCK_SHA`, the locked
   files, your one-paragraph summary, the latest test output, the CI checks you ran with their results,
   and the path `.workflow/ci-checks.md`. Never your conversation history.
2. Verdict **APPROVED** -> step d.
3. Verdict **FIX** (code issues) -> increment `Review rounds: n/3` in outline.md, fix the Critical and
   Important code findings, re-run tests, re-run a fresh reviewer scoped to the findings. Minor findings
   go in the slice `Notes`.
4. Verdict **ESCALATE** (plan issue), or still not approved after `MAX_REVIEW_ROUNDS` (3) rounds ->
   `/wf-escalate` (reason "plan issue from review" or "review-round cap").

## d. Show-me checkpoint (the user decides)
Set slice `Status: show-me`. Show the user, then **stop and wait**:
- What the slice does, in two or three sentences, and which acceptance criteria / req IDs it covers.
- How to run or see it (command, test, device steps).
- `git diff --stat <Base SHA>` and the key hunks worth reading.
- Test evidence: the command and the pass/fail counts from a fresh run this turn, the CI checks run and their
  results (and which checks are CI only), plus "locked tests unchanged" (`git diff --name-only $LOCK_SHA -- <locked files>` is empty).
- Review tier and plan used ("tier S, 1 reviewer"), review rounds used, and any parked Minor findings.

User replies:
- **Approve** -> commit the slice: `git add` the slice's files, `git commit -m "feat(<SLICE>): <goal>
  [<req IDs>]"` (`fix(...)` for bugs). Set `Status: done`. Next slice: set `SLICE` to it in active.env,
  ask "Continue with <next slice> now?" (if this chat is long or the slice was large, recommend a new chat and
  `/wf-build` instead), and on a yes start again at the Preconditions. No slices left -> set `PHASE=pr`, then
  ask: "Recommended: start a new chat and run `/wf-pr` (it reviews the whole branch from files). Or continue
  here now?"
- **Change something small within the slice** -> do it, re-verify, show again.
- **Not what I meant / plan is wrong** -> `/wf-escalate` (reason "show-me").

## End of every invocation
Tell the user where you are (slice, status, rounds used), recommend where to run the next step (see the
hand-off table in the workflow rule), then ask whether to continue: the next slice, `/wf-pr`, or
`/wf-escalate`. Continue only on a yes.

## Never
- Write production code before the slice's tests fail for the right reason.
- Edit or loosen a locked test, or `git commit --no-verify` around a failing suite.
- Commit the slice before the user approves at show-me. Push or merge at all.
- Fix a plan issue by improvising a new plan.

Adapted from obra/superpowers subagent-driven-development, test-driven-development and
verification-before-completion (MIT).
