---
name: wf-pr
description: PR loop of the agentic workflow. Use when the user runs /wf-pr after all slices are done (PHASE=pr). Writes pr-description.md, runs a whole-branch review with parallel lens-reviewer subagents and a finding-verifier, fixes NIT/IMPORTANT findings (max 2 rounds), escalates BLOCKERs, then hands the branch to the user for their code read. Never merges or pushes unless the user asks.
---

# wf-pr: describe, review the whole branch, hand over

Slice reviews were scoped gates. This is the one broad look at the whole branch against the design,
through the lenses that matter for device software, before a human reads it.

## Preconditions
- Read `.workflow/active.env`, `.workflow/config.env`, `outline.md` (every slice `done`), `design.md` (or
  `spec.md` / `bug-report.md`), `decisions.md`, `locked-tests.txt`. Set `PHASE=pr`. Name this chat for this stage (rule: **Chat titles**).
- Any slice not `done`: stop, "Run `/wf-build`."
- Base branch: from the user or the branch's upstream; if unsure, ask once.
  `MERGE_BASE=$(git merge-base <base> HEAD)`.
- **Fresh evidence:** run `BUILD_CMD` and `TEST_CMD` now (the stop hook is silent in this phase) and check
  `git diff --name-only <LOCK_SHA> -- <locked files>` is empty. Red? Stop: report it, and `/wf-escalate`
  if it is not a trivial fix.
- **CI checks:** refresh `.workflow/ci-checks.md` if the CI files changed (see `.workflow/kit/ci-procedure.md`), then
  run `CI_CMD` if set, otherwise every check marked "runs locally", on the whole branch. Failures become
  findings for step b (fix within the PR fix rounds; plan-level ones escalate). Never silence a check.
  Record checks run, results and CI-only checks in the PR description's test evidence.

## a. PR description
Fill `$WORK_DIR/pr-description.md` from `.workflow/kit/templates/pr-description.md`: summary, req/hazard IDs
-> slice -> tests table, changes, test evidence (command, counts, commit, date), decisions summarised from
`decisions.md`, known risks and follow-ups, reviewer guide. Facts only; every claim backed by the run above.

## b. Branch code review
Read `references/branch-review.md` for the dispatch prompts and ranking rules.
0. **Size the review.** Measure the branch diff against `MERGE_BASE` and its risk, pick the tier and the
   review plan from `.workflow/kit/scaling.md` (sections 1, 2 and 4), and tell the user in one line
   before dispatching ("tier M: 5 lens reviewers + verifier"). Record it in the PR description.
1. Invoke the planned **`lens-reviewer` subagents in parallel**: from one combined reviewer (`LENS=all`,
   tier XS) up to one per lens per file group plus an integration reviewer (tier L, at most
   `MAX_REVIEW_AGENTS`). Each prompt is self-contained: lens(es), file group if any, MERGE_BASE, HEAD,
   artifact paths, the req/hazard IDs, parked Minor notes from outline.md, the CI check results and the path
   `.workflow/ci-checks.md`. A dedicated
   `safety-hazard` reviewer always runs when hazard IDs are in scope.
2. Invoke the **`finding-verifier`** subagent with all lens findings verbatim when the tier calls for it
   (S with more than 3 findings, M, L). Keep only its KEPT list. At tier XS, check each finding yourself.
3. Act on the ranked findings:
   - **NIT:** fix.
   - **IMPORTANT:** fix. One fix round = fix all open IMPORTANT/NIT findings, re-run `BUILD_CMD` +
     `TEST_CMD`, then re-run only the lenses that raised them, scoped to the fix diff. Count rounds in
     `pr-description.md` ("PR fix rounds: n/2"). Still open after `MAX_PR_FIX_ROUNDS` (2): `/wf-escalate`
     (reason "PR-fix cap").
   - **BLOCKER:** do not fix in the PR loop. `/wf-escalate` (reason "branch review BLOCKER").
   - Any fix that would touch a locked test, or change the design or outline, is a BLOCKER.
4. Commit review fixes locally as separate commits: `fix(review): <what> [<req IDs>]`. Update the
   "Branch review" section of the PR description with what was fixed and what is open.

## c. The user's code read
Hand over: the PR description path, `git log --oneline MERGE_BASE..HEAD`, `git diff --stat MERGE_BASE`,
the fresh test evidence, the review summary (fixed / open), and where to start reading. Then **stop and
wait**. The user:
- **Approves** -> dated `decisions.md` entry "PR approved for submission". Offer the next steps (push the
  branch, open the PR with pr-description.md as the body) and do them **only if the user asks**.
  `PHASE` stays `pr`; the work item is complete.
- **Sends back nits** -> fix them in the PR (verify, commit, show again). These do not count as rounds.
- **Sends back anything bigger** -> `/wf-escalate` (reason "code read").

## End of every invocation
Say where things stand (review status, rounds used, open findings) and the next step: wait for code read,
`/wf-pr` again after fixes, or `/wf-escalate`.

## Never
- Merge, push, force-push, rebase or open a PR without the user asking for that action.
- Claim "ready" without a fresh green run in this turn.
- Downgrade a BLOCKER to keep the loop going, or drop a finding silently.

Adapted from obra/superpowers requesting-code-review, subagent-driven-development (final review) and
finishing-a-development-branch (MIT).
