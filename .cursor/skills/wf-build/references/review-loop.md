# Slice review loop (wf-build step c). Re-read before every fix round.

## Dispatch
Invoke `slice-reviewer` with a self-contained prompt (it has a fresh context and cannot see this chat). The
number of reviewers and their `MODE` come from the tier you picked (`.cursor/workflow-scaling.md` section 3):
```
MODE=<light | full | spec | quality>
Review slice <SLICE> of work item <WORK_DIR>.
Slice block (verbatim from outline.md):
<paste>
Binding constraints from design.md / spec.md (verbatim; exact values):
<paste>
BASE_SHA=<Base SHA>   HEAD=working tree   LOCK_SHA=<LOCK_SHA>
Locked tests: <paths from locked-tests.txt for this slice>
Implementer summary: <one paragraph; what changed, any doubts>
Latest test run: <command> -> <counts>; full log at <WORK_DIR>/last-run.log
CI checks run: <check -> result, each>; CI checks list: .workflow/ci-checks.md
```
Do not pre-judge findings ("do not flag X", "at most Minor"). Do not ask it to re-run the suite.

## Handle the verdict
- **APPROVED** -> show-me.
- **FIX** -> one fix round:
  1. Increment `Review rounds: n/<MAX_REVIEW_ROUNDS>` in the slice block **before** fixing.
  2. Fix every Critical and Important **code** finding. Minor -> slice `Notes` (they go to the PR review).
  3. Re-run the focused tests and `TEST_CMD`; keep the output.
  4. Dispatch a **fresh** `slice-reviewer` (`MODE=light` unless the fix diff is itself tier S or larger), scoped: the original findings list, the slice block, and the
     fix diff (`git diff` since the last review). It answers ADDRESSED / NOT ADDRESSED per finding and
     flags new breakage in the fix diff only.
- **ESCALATE** (any finding of kind *plan*: the outline, design, an acceptance criterion or a locked test is
  wrong or contradictory) -> `/wf-escalate` now. Do not count it as a round and do not try to fix it.

## The cap
After `MAX_REVIEW_ROUNDS` (default 3) fix rounds with Critical/Important findings still open, stop.
Run `/wf-escalate` with reason "review-round cap", listing open findings and what each round tried.
Past the cap, more rounds do not converge: the failure is structural.

## Disagreeing with a finding
If you believe a finding is wrong, do not silently drop it. Say why with evidence (code, test) in the
next re-review prompt, and let the reviewer rule. If still disputed at show-me, show both sides to the user.

## Rationalizations to reject
| Excuse | Reality |
|---|---|
| "Close enough on spec compliance" | Spec gaps mean not done. Fix or escalate. |
| "The fix was tiny, skip the re-review" | Unreviewed fixes are how regressions land. |
| "One more round will do it" | The cap is the cap. Escalate. |
| "I'll fix the outline myself so the finding goes away" | That is a plan change: `/wf-escalate`. |
