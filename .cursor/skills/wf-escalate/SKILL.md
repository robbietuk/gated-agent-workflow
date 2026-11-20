---
name: wf-escalate
description: Escalation path of the agentic workflow. Use when the user runs /wf-escalate, or when a loop limit is hit (stop-hook cap, review-round cap, PR-fix cap), a reviewer reports a plan issue, a locked test looks wrong, or the user rejects work at show-me, branch review or code read. Stops work, proposes a revert the user must confirm, logs a dated decision, and routes back to brainstorm or plan.
---

# wf-escalate: stop, learn, re-route

Escalation is the normal, designed exit from a loop that is not converging. It is not a failure. Its job is
to stop the churn, keep what was learned, and send the work back to the person who owns the "what".

## 1. Stop
- Make no further changes to product code or tests from this point.
- Set `PHASE=escalated` in `.workflow/active.env` **first** (this silences the stop hook).
- Read `active.env`, `outline.md` (current slice block: Base SHA, Lock SHA, status, review rounds),
  `decisions.md`, and `$WORK_DIR/last-run.log` if present.

## 2. State the trigger and the evidence
One of: `stop-hook cap` | `review-round cap` | `PR-fix cap` | `plan issue from review` | `locked test wrong`
| `show-me` | `branch review BLOCKER` | `code read` | `other (user)`.
Give the user, in under 15 lines: what was being attempted, what happened (failing test names and the key
error lines, open review findings, or the user's objection), what was tried in each run/round, and your
best reading of **why** it did not converge, separating evidence from opinion.

## 3. Propose how to undo the slice (the user confirms)
Show `git status --short` and `git log --oneline <Base SHA>..HEAD`. Then propose, without running, the
smallest safe option, for example:
- **Keep everything, change nothing** (route back with the code in place) - often right for `show-me`.
- **Discard uncommitted slice changes, keep the locked tests:** `git stash push -u -m "wf-escalate <SLICE>"`
  (recoverable) or `git restore --staged --worktree -- <files>`.
- **Back to before the slice, including its lock commit:** `git branch wf-backup/<slug>-<SLICE>` then
  `git reset --hard <Base SHA>`.
- **Undo already-shared commits:** `git revert <sha>...` (never rewrite pushed history).

Rules:
- **Never run a destructive git command** (`reset --hard`, `checkout -- .`, `restore`, `clean`,
  `branch -D`, `push --force`, `rebase`, `stash drop`) unless the user confirms that exact command in
  this conversation. Always offer a backup branch or stash first.
- Show the full command you will run; run only what was confirmed; show the result.
- If the locked tests themselves are reverted, remove their lines from `locked-tests.txt` and clear
  `LOCK_SHA` in active.env. Otherwise keep them: they still define done.

## 4. Log the decision
Append to `$WORK_DIR/decisions.md`, using the template's fields:
```
## <YYYY-MM-DD> - Escalation: <SLICE or stage> - <trigger>
- Trigger: <trigger>
- Context: <slice, stage, runs/rounds used>
- What we learned: <facts with evidence: file:line, test output, findings>
- Decision: <what the user decided; revert option taken>
- Affected req / hazard IDs: <IDs>
- Route: /wf-brainstorm (rethink) | /wf-plan (replan)
```
Mark the slice `Status: escalated` in outline.md with a pointer to the entry, and set the outline's
`Status: draft` so `/wf-build` cannot resume until the replanned outline is approved again.

## 5. Route (the user decides)
Recommend one, with a one-line reason, and let the user choose:
- **Rethink -> brainstorm:** the design, an approach, a requirement or a hazard mitigation is wrong, or
  the fix keeps revealing new coupling. Set `PHASE=brainstorm`. Ask: "Continue with `/wf-brainstorm` now?"
- **Replan -> plan:** the design holds but a slice is too big, mis-ordered, has wrong acceptance criteria or
  a wrong locked test. Set `PHASE=plan`. Ask: "Continue with `/wf-plan` now?"
- **Spec is wrong:** suggest editing `spec.md` with the user first, then `/wf-brainstorm`.

## Never
- Keep coding "just to try one thing" after escalating.
- Edit a locked test to make a problem go away.
- Run destructive git without the user's explicit confirmation of that command.
- Push, merge or delete remote branches.

Safety rules for git adapted from obra/superpowers finishing-a-development-branch (MIT).
