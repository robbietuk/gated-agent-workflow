# <PR title: imperative, <= 72 chars>

## Summary
<Two or three sentences: what changed and why, in user/device terms.>

- **Work item:** .workflow/<YYYY-MM-DD>-<slug>/
- **Track:** feature | bug | small change
- **Ticket:** <link or ID>

## Requirements and hazards covered
| Req / hazard ID | Slice | Tests |
|---|---|---|

## Changes
- <component>: <what changed>

## Test evidence
- **Command:** `<TEST_CMD>`
- **Result:** <N passed, 0 failed> on commit <sha>, <date>
- **CI checks (local):** <`CI_CMD` or each check from .workflow/ci-checks.md -> result, time>
- **CI-only checks still to prove in the pipeline:** <list, or "none">
- **Locked tests:** <list from locked-tests.txt> - unchanged since their lock commits
- **Manual / bench verification:** <device, firmware, what was checked> (or "none")

## Decisions
<Summarised from decisions.md: date - decision - why.>

## Branch review
- **Review plan:** tier <XS / S / M / L> (<N> changed files, <N> changed lines<, risk bump: why>) - <reviewers run, e.g. 5 lens reviewers + verifier>
- **Lenses run:** <safety/hazard, concurrency, error handling, compatibility/config, traceability + test adequacy, integration>
- **Fixed:** <NIT / IMPORTANT findings fixed, with commit>
- **Open:** <none, or what and why>

## Known risks and follow-ups
- <risk / limitation / follow-up ticket>

## Reviewer guide
<Where to start reading, what deserves the closest look.>
