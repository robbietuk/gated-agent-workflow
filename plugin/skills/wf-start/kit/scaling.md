# Scaling research and review to the size of the work

One source of truth for how many subagents to run and how deep they go. Read by `/wf-research`, `/wf-build`
and `/wf-pr`. Thresholds live in `.workflow/config.env`; change them there, not here.

A three-line fix does not need five reviewers, and a 10,000-line branch is not safely reviewed by one.
Size the work first, then pick the plan from the tables below. Always say which tier you chose and why, in
one line, in the show-me or the PR description (for example "Review: tier S, 2 reviewers, 1 risk bump").

## 1. Measure

**Diff size** (review): run `git diff --shortstat <base>` and `git diff --name-only <base>` where `<base>` is
the slice's `Base SHA` (slice review) or `MERGE_BASE` (branch review). Count **changed files** and
**changed lines** (insertions + deletions). Leave out lockfiles, generated code, vendored code, snapshots
and binary assets, and say what you left out.

**Risk** (review): the slice's `Risk flag`, the req / hazard IDs in scope, and what the diff touches. Treat as
**high risk** any of: risk flag `high`; hazard IDs in scope; changes to threading, locking, timing or
interrupt code; alarm, limit or safety-related logic; config schema or persisted data formats; public or
device-facing interfaces.

**Breadth** (research): the number of questions in `questions.md` and the number of distinct code areas they
touch (a top-level module, component or service counts as one area).

## 2. Pick the tier

| Tier | Changed lines | Changed files | Typical case |
|---|---|---|---|
| **XS** | up to `TIER_XS_LINES` (50) | up to 2 | typo, one-line fix, a constant |
| **S** | up to `TIER_S_LINES` (400) | up to 10 | a normal slice, a small change, most bug fixes |
| **M** | up to `TIER_M_LINES` (2,000) | up to 40 | a whole feature branch of a few slices |
| **L** | more than M | more than 40 | a large branch, a cross-cutting change |

Use whichever of lines or files gives the **larger** tier. **High risk moves the tier up one step**
(XS becomes S, and so on; L stays L). Never move a tier down for a deadline.

## 3. Slice review plan (`/wf-build`, step c)

| Tier | Reviewers | Depth |
|---|---|---|
| XS | 1 `slice-reviewer`, `MODE=light` | Stage 1 in full; stage 2 limited to the diff lines; no extra files opened unless a named risk needs it |
| S | 1 `slice-reviewer`, `MODE=full` | Both stages as written in the agent |
| M | 2 in parallel: `slice-reviewer MODE=spec` and `slice-reviewer MODE=quality` | Each goes deep on one stage; merge the two verdicts (any ESCALATE wins, then any FIX) |
| L | Stop before reviewing | A slice this big is a planning problem: tell the user and recommend `/wf-escalate` to split it (replan). Review as M only if the user says to go on |

A high-risk slice at any tier also gets **one `lens-reviewer`** for its main risk (for example
`LENS=concurrency`), run alongside the slice review. Fix rounds stay capped at `MAX_REVIEW_ROUNDS`.

## 4. Branch review plan (`/wf-pr`, step b)

| Tier | Lens reviewers | Verifier |
|---|---|---|
| XS | 1 `lens-reviewer` with `LENS=all` (every lens, briefly) | Not needed: the reviewer must give a failure scenario for each finding, and you check each one yourself |
| S | 2: `LENS=safety-hazard,error-handling,concurrency` and `LENS=compatibility-config,traceability-tests` | Run `finding-verifier` if there are more than 3 findings |
| M | 5, one per lens | `finding-verifier` always |
| L | 5 lenses × file groups: split the changed files into groups of about `TIER_M_LINES` changed lines along module boundaries, one reviewer per lens per group, up to `MAX_REVIEW_AGENTS` (12) in total; plus 1 `lens-reviewer LENS=integration` that reads the design and every changed interface across groups | `finding-verifier` always; run it per group if the findings are many |

Rules for every tier:
- If hazard IDs are in scope, a dedicated `safety-hazard` reviewer always runs, whatever the tier.
- A lens that cannot apply (no threads anywhere in the diff, say) may be dropped: say so.
- When the L plan would need more than `MAX_REVIEW_AGENTS`, merge the smallest groups first; never drop
  the safety-hazard or integration reviewer. Tell the user the branch is large and suggest splitting the PR.
- Fix rounds stay capped at `MAX_PR_FIX_ROUNDS` whatever the tier. Re-reviews after a fix use only the
  reviewers that raised findings, scoped to the fix diff (usually tier XS or S).

## 5. Research plan (`/wf-research`, and `/wf-debug` when it researches)

| Questions | Areas | Researchers |
|---|---|---|
| up to 5 | 1 | 1 `researcher` |
| up to 15 | up to 2 | 1 `researcher`; 2 in parallel if the areas are unrelated |
| more than 15, or 3+ areas | 3+ | 1 per area, up to `MAX_RESEARCHERS` (4), each with a disjoint subset of the questions |

Every researcher still sees only its questions, never the spec. A small change with no questions skips
research. More than about 25 questions usually means the spec is too broad: say so before researching.

## 6. Why it scales this way

- Each subagent starts with a fresh context and reads the code itself, so each one costs tokens. More
  reviewers buy coverage on large diffs, but on a tiny diff they repeat each other.
- Narrow reviewers find more than one broad reviewer once a diff is too big to hold at once, which is why
  M and L split by lens and L also splits by files.
- The integration reviewer exists because splitting by files hides cross-group problems, the same reason
  the branch review exists at all.
