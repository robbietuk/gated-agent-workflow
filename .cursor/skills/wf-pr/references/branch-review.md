# Branch review: prompts and ranking (wf-pr step b)

Subagents start with a fresh context. Each prompt must carry everything the reviewer needs; never paste
this conversation. Hand over paths and SHAs rather than large pasted diffs.

## lens-reviewer prompt (as many as the tier plan says, run in parallel)
How many reviewers, which lenses each covers and whether files are split into groups comes from
`.cursor/workflow-scaling.md` section 4.
```
LENS=<safety-hazard | concurrency | error-handling | compatibility-config | traceability-tests | integration | all,
      or a comma-separated list>
FILES=<all changed files, or this reviewer's file group (tier L)>
Work item: <WORK_DIR>
MERGE_BASE=<sha>  HEAD=<sha>
Read first: <WORK_DIR>/design.md (or spec.md / bug-report.md), <WORK_DIR>/outline.md,
            <WORK_DIR>/decisions.md, <WORK_DIR>/locked-tests.txt
Req / hazard IDs in scope: <list>
CI checks: .workflow/ci-checks.md; local results this run: <check -> result, each>; CI-only checks: <list>
Parked Minor findings from slice reviews (triage whether any must be fixed before merge):
<list from outline.md slice Notes, or "none">
Review the whole branch diff through your lens only. Every finding needs a concrete failure scenario.
```

## finding-verifier prompt
```
MERGE_BASE=<sha>  HEAD=<sha>
Design/spec: <path>   Outline: <path>
Findings from lens reviewers (verbatim, grouped by lens):
<paste all>
Keep only findings with a concrete, reachable failure scenario backed by the code. Rank BLOCKER /
IMPORTANT / NIT. Drop or merge the rest with reasons.
```

## Ranking (finding-verifier decides; these are the definitions)
| Rank | Meaning | Action in wf-pr |
|---|---|---|
| BLOCKER | unsafe or wrong on a realistic path; needs a design/outline change; touches a locked test | `/wf-escalate` |
| IMPORTANT | real defect or test gap on a req/hazard ID, fixable in code | fix; max 2 rounds |
| NIT | local, no behaviour risk | fix |

## Fix round mechanics
1. Record `FIX_BASE=$(git rev-parse HEAD)`.
2. Fix every open IMPORTANT and NIT finding. No new features, no unrelated cleanups.
3. Run `BUILD_CMD` and `TEST_CMD`; read the output; check locked tests unchanged.
4. Commit `fix(review): ...`.
5. Re-run only the lenses that raised findings, scoped: pass the open findings and `FIX_BASE..HEAD`. They
   answer ADDRESSED / NOT ADDRESSED and flag new breakage in the fix diff only. New observations outside
   the fix diff go to "Known risks and follow-ups", not into the loop.
6. Increment "PR fix rounds: n/2".

## Receiving findings
Verify each against the code before acting. If a kept finding is wrong, say why with evidence (code, test)
and show both sides to the user at code read. Never discard silently, never agree performatively.

## Rationalizations to reject
| Excuse | Reality |
|---|---|
| "Slice reviews already passed, skip the branch review" | Slice reviews cannot see cross-slice and whole-branch issues. |
| "It's a BLOCKER but the fix is small" | BLOCKERs change the plan or safety story: escalate, let the user decide. |
| "Tests passed in the last slice" | Run them now. Evidence from this turn only. |
