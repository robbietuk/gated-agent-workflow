---
name: wf-start
description: Start a new piece of work in the agentic workflow. Use when the user runs /wf-start or asks to begin a feature, bug fix or small change. Triages the track, creates the .workflow/<date>-<slug>/ folder, co-writes spec.md or bug-report.md with the user, drafts questions.md, and names the next command.
---

# wf-start: triage, work folder, spec

You and the user decide **what** gets built. You write nothing but workflow artifacts in this skill:
no product code, no tests, no design.

## 1. Check for active work
Read `.workflow/active.env` if it exists. If it points at a work item, tell the user which one
(`WORK_DIR`, `PHASE`) and ask: start the new item (the old folder stays as it is and can be resumed by
pointing `active.env` back at it) or continue the old one? Wait for the answer.

## 2. Triage the track
Pick one from the user's request, say which and why in one line, and let them override:

| Track | When | Flow |
|---|---|---|
| **feature** | new or changed behaviour worth designing | spec -> research -> brainstorm -> plan -> build -> PR |
| **bug** | existing behaviour is wrong | bug report -> /wf-debug (reproduce, locked regression test, root cause) -> build -> PR |
| **small** | about an hour, 1-3 files, no new behaviour worth designing | spec -> one-slice outline -> build -> PR |

If it is unclear (for example "it's a bug but the fix changes behaviour"), ask **one** question and wait.

## 3. Create the work folder
- Slug: 2-5 lowercase words joined by hyphens from the title. Date: today, `YYYY-MM-DD`.
- `WORK_DIR=.workflow/<YYYY-MM-DD>-<slug>` (append `-2` if it exists).
- Copy from `.workflow/templates/`: feature/small -> `spec.md`; bug -> `bug-report.md`. Always copy
  `decisions.md`. Create an empty `questions.md`. Other artifacts are created by later skills.
- Write `.workflow/active.env` (overwrite) exactly as plain lines:
  ```
  WORK_DIR=.workflow/<YYYY-MM-DD>-<slug>
  TRACK=feature|bug|small
  PHASE=start
  SLICE=
  LOCK_SHA=
  ```
- Suggest a branch name (`feature/<slug>` or `bugfix/<slug>`). Create it only if the user says yes.

## 4. Co-write the spec (or bug report) with the user
Ask **one question at a time**, each built on the last answer. Prefer a concrete proposal they can correct
over an open menu. Never ask what the repo or their message already answers; look first.
- **Spec:** what, why, "done when" (observable, testable statements with req IDs), out of scope, constraints.
- **Bug report:** observed, expected, steps to reproduce, environment / device / firmware, severity,
  linked requirement and hazard IDs. Leave the Investigation section for /wf-debug.
- Ask for requirement / hazard IDs explicitly; regulated work needs traceability. "None yet" is a valid answer.
- Write the file as you go. When it is complete, show it and ask "Anything wrong or missing?" Revise until
  the user approves. Record the approval as a dated entry in `decisions.md`.

## 5. Draft questions.md
From the approved spec/bug report, write 5-15 **factual questions about the current code** that the design
or fix will depend on. Rules (the researcher sees only this file):
- Ask about what exists, never about what to build. Bad: "How should we add retry?" Good: "Where are
  serial-port writes issued and how are write errors handled today?"
- Do not leak the plan or solution. Name components, behaviours, files, symbols, data flows, tests, config.
- One question per line, numbered. Show the list to the user; they may add or cut questions.
- Small change: 0-5 questions is fine; research is optional.

## 6. Hand off
Set `PHASE` in `.workflow/active.env`, then tell the user exactly:
- **feature:** `PHASE=research`. Ask: "Continue with `/wf-research` now?"
- **bug:** `PHASE=research`. Ask: "Continue with `/wf-debug` now?"
- **small:** `PHASE=plan`. Ask: "Continue with `/wf-plan` now? (one-slice outline). Optional first: `/wf-research`."

## Never
- Write product code or tests here.
- Ask several questions in one message.
- Put solution ideas in `questions.md`.

Question style adapted from obra/superpowers brainstorming (MIT).
