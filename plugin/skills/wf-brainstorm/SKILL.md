---
name: wf-brainstorm
description: Brainstorm loop of the agentic workflow. Use when the user runs /wf-brainstorm (after /wf-research, or when an escalation or bug root cause says "rethink"). One question at a time, 2-3 approaches with trade-offs, then a short design.md the user approves. Approval leads to /wf-plan.
---

# wf-brainstorm: agree the design before anything is built

You are good at building, and you build what you believe the user wants. That belief is usually thinner
than it feels. This loop finds out what they actually want, and why, then writes it down short enough to
be read in full.

<HARD-GATE>
No product code, scaffolding, test files or dependency changes until the user approves `design.md`.
Reading code and research is fine.
</HARD-GATE>

## Preconditions
Read `.workflow/active.env`, `spec.md` (or `bug-report.md`), `research.md`, `decisions.md`, and the
code that research points to. Set `PHASE=brainstorm`. If you arrived from an escalation, read the latest
`decisions.md` entry first: it says what failed and what must change.

## 1. Play back what you know (first message, ~200 words)
Echo the request in your own words: what, for whom, why. Add what research shows that bears on it (how
it works today, what the change touches). Flag anything that changes the ask: a constraint, a conflict,
a cheaper path, a hazard. End with one line inviting corrections, then **one** question: the open point
whose answer would change the design most.

## 2. The conversation: one question at a time
- Ask only when the answer changes what gets built and neither spec nor code answers it. Otherwise state
  your call and your reason as a proposal they can correct.
- One question per message. Build each on their last answer or on something in the code.
- Ground to cover (territory, not a script): goals, non-goals, anti-goals; success; current state;
  hazards and failure behaviour; compatibility with existing devices, data, configs; what must not change.
- Play back each settled part in a few lines before moving on. Mark your own fills as "(my call)".

## 3. Lay out 2-3 approaches (a message of its own)
Generate several real alternatives, drop the weak ones (including any that fight the "why" or that the
existing code rules out), and sketch the two or three that remain concretely, grounded in the actual code
(files, classes, patterns from research.md). For each: how it works, what it costs, what it risks.
Recommend one, say why, and ask which way to go. If there is genuinely one sensible way, say so and why
the others do not fit.

## 4. Write design.md (~200 lines max)
Copy `.workflow/kit/templates/design.md` to `$WORK_DIR/design.md` and fill it: current state, desired end
state, approaches considered, decision, patterns to follow (file:line), interfaces, requirement
traceability, risks and hazards, open questions. Short and decisive: a capable engineer could write the
outline from it without asking. Agent decisions are labelled "(agent's call)" so the user can check them.
Before showing it, self-check: every "done when" item in the spec maps to something in the design; no
TBDs; no section contradicts another; under ~200 lines.

## 5. Review loop with the user
Show the design (or a summary plus the path). Ask: approve, or what to change? Revise and repeat. There is
no round limit here because the user is in the loop, but if the design keeps moving after three rounds, say
so and suggest revisiting `spec.md`.

## 6. Hand off (on approval only)
- Set `Status: approved <date>` in design.md and append a dated entry to `decisions.md` (decision,
  approach chosen, req IDs affected).
- Set `PHASE=plan`. Ask: "Continue with `/wf-plan` now?"

## Red flags
| Thought | Reality |
|---|---|
| "I'll offer a menu of what they might want" | Ask them to describe it first; options steer. |
| "I'll fill in sensible defaults" | Fine, but say them out loud as your call. |
| "They said 'sounds good', so the design is approved" | Approval covers what they saw. Show design.md. |
| "Small enough to just start coding" | Use the small-change track via /wf-start, or get design approval. |

Adapted from obra/superpowers brainstorming (MIT).
