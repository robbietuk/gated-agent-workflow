---
name: wf-research
description: Research stage of the agentic workflow. Use when the user runs /wf-research after /wf-start. Sends ONLY questions.md to the read-only researcher subagent and writes research.md (facts with file:line references, no opinions).
---

# wf-research: facts about the code as it is today

Research answers "how does it work now?" so the brainstorm can answer "what should change?" Keeping the
two apart stops the solution from bending the facts.

## Preconditions
- Read `.workflow/active.env`. Need `WORK_DIR` and a non-empty `$WORK_DIR/questions.md`.
- If `questions.md` is missing or empty, say so and offer to draft it from the spec (same rules as
  /wf-start step 5), then show it to the user before continuing.
- Set `PHASE=research`.

## 1. Delegate to the researcher subagent
Invoke the `researcher` subagent (`/researcher`). It starts with a fresh context and sees only what you
put in its prompt. The prompt contains **only**:
- the path `$WORK_DIR/questions.md` (and its text pasted verbatim, in case it cannot read files outside
  its prompt), and
- the instruction: "Answer every question with facts and file:line references. No opinions, no
  recommendations. Return the full research.md text."

Do **not** pass the spec, bug report, design, outline, ticket text or your own theory. Do not hint at the
solution in your wording.

**Scale to the question set.** Count the questions and the distinct code areas they touch, then pick the
number of researchers from `.workflow/kit/scaling.md` section 5: one researcher for a narrow set, up to
`MAX_RESEARCHERS` in parallel (one per area, disjoint questions) for a broad one. Tell the user the plan in
one line before dispatching, e.g. "12 questions across 2 unrelated areas: 2 researchers".

## 2. Check and save
- Write the result to `$WORK_DIR/research.md` (merge parallel results under one header, keep the
  question numbers).
- Spot-check three or more `file:line` references by opening them. If a reference is wrong, fix it or
  mark the answer `Unverified`.
- Remove opinions and suggestions if any slipped in ("we should", "better to"). Research is facts only.
- List `Not found` answers at the top so the user sees the gaps.

## 3. Report to the user
In five lines or fewer: the most important findings, the gaps, and anything surprising that may change
the spec (a constraint, a conflict, an existing feature that already does part of it). If something would
change the spec, ask the user whether to update `spec.md` before moving on.

## 4. Hand off
- **feature:** set `PHASE=brainstorm`. Ask: "Continue with `/wf-brainstorm` now?"
- **small:** set `PHASE=plan`. Ask: "Continue with `/wf-plan` now?"
- **bug** (research used during debugging): set nothing; "Back to `/wf-debug`."

## Never
- Let the researcher see the spec or design.
- Add your own recommendations to research.md.
- Edit product code or tests.

Approach follows HumanLayer's research-plan-implement practice (research isolated from intent).
