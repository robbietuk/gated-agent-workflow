---
name: wf-debug
description: Bug track of the agentic workflow, and root-cause discipline for any failure. Use when the user runs /wf-debug after /wf-start on a bug - reproduce, lock a failing regression test, find the root cause with evidence, get the user's approval of root cause and fix approach, then hand to /wf-build. Also use mid-build when a failure's cause is not obvious.
---

# wf-debug: no fix without a root cause

Symptom fixes are failures that have not shown up yet. Find out **what** is wrong and **why** before any
production code changes, and prove it with a test that fails today.

## Two modes
- **Bug track** (`TRACK=bug`, `PHASE` research or plan): run steps 1-6 below.
- **Mid-build** (`PHASE=build`): apply steps 3-4 to the failure in front of you, do not change `PHASE`,
  then return to /wf-build. Three failed fix attempts in a slice -> stop and `/wf-escalate`.

## 1. Read and reproduce (PHASE=research)
- Read `.workflow/active.env`, `bug-report.md`, `decisions.md`. Set `PHASE=research`.
- Read error messages, logs and stack traces completely; note file:line and codes.
- Reproduce with the report's steps. Record exact commands/inputs and how often it happens.
  Cannot reproduce? Gather more data (logs, config, firmware version); ask the user one question at a time.
  Do not guess.
- Check recent changes: `git log` / `git diff` around the affected area, config and dependency changes.
- Factual questions about unfamiliar code: put them in `questions.md` and use the `researcher` subagent
  (questions only, no theory), or read the code yourself.

## 2. Lock a failing regression test
- Write the smallest automated test that reproduces the **observed** behaviour and asserts the
  **expected** behaviour from the bug report. Name it after the behaviour and reference the bug/req ID.
- Run it and **watch it fail** for the bug's reason (not a typo or setup error). If it passes, it does not
  reproduce the bug: rework it.
- If the bug cannot be captured in an automated test (timing on hardware, say), tell the user, propose the
  closest automated proxy plus a scripted manual check, and get agreement before continuing.
- Commit only the test: `git commit -m "test(S1): lock failing regression test [<bug/req IDs>]"`.
- In active.env set `SLICE=S1`, `LOCK_SHA=$(git rev-parse HEAD)`. Append the test file path(s) to
  `$WORK_DIR/locked-tests.txt`. Fill "Regression test" in bug-report.md.

## 3. Root cause investigation
Read `references/root-cause-tracing.md` when the error surfaces deep in a call chain or across components.
- **Trace backward** from the symptom to where the bad value or state first appears. Fix at the source.
- **Multi-component** (driver -> service -> UI, firmware <-> host): add temporary instrumentation at each
  boundary, run once, find the layer where good input becomes bad output. Remove it afterwards.
- **Compare** with similar code that works; list every difference, however small.
- **One hypothesis at a time:** "X is the root cause because Y". Test it with the smallest change or
  probe. Wrong? Undo it and form a new one. Never stack fixes.
- Say "I don't understand X" when you don't. Ask, or research more.

## 4. Evidence
Root cause is established only when you can show: the exact file:line, the mechanism, and evidence (log,
debugger state, probe output, the regression test failing for exactly that reason). Record it in the
bug-report "Investigation" section. 95% of "no root cause, it's environmental" is incomplete investigation.

## 5. Approval gate (PHASE=plan)
Set `PHASE=plan`. Present to the user, briefly: root cause with evidence, proposed fix approach (one or two
sentences, smallest fix at the source), files likely touched, risks, and affected req/hazard IDs. Ask:
approve, change, or rethink?
- **Design flaw** (each fix would reveal new coupling elsewhere; the fix needs new behaviour or an
  architecture change; the requirement itself is wrong): say so, add a dated `decisions.md` entry, set
  `PHASE=brainstorm`, then ask: "Continue with `/wf-brainstorm` now?" The locked test stays.
- **Fix needs more than one slice:** set `PHASE=plan`, then ask: "Continue with `/wf-plan` now?" (S1 keeps the locked test.)

## 6. Hand off (on approval)
- Copy `.workflow/templates/outline.md` to `$WORK_DIR/outline.md` with one slice **S1**: goal = the fix,
  req IDs, acceptance criteria (regression test passes + no other test regresses + anything the user
  added), tests = the locked regression test, files likely touched, risk flag, `Status: tests-locked`,
  `Lock SHA` filled, `Review rounds: 0/3`. Mark outline `approved <date>`.
- Dated `decisions.md` entry: root cause, approved fix approach, req/hazard IDs.
- Keep `PHASE=plan` (`/wf-build` switches it to `build` when it starts; setting it here would make the
  stop hook fire on the still-failing regression test at the end of this turn). Tell the user:
  Ask: "Continue with `/wf-build` now?"

## Red flags: stop and go back to step 3
"Quick fix for now", "just try changing X", several changes before one test run, "it's probably X",
proposing fixes before tracing the data flow, "one more fix attempt" after two failed ones.

Adapted from obra/superpowers systematic-debugging and test-driven-development (MIT).
