# Running the repository's own CI checks

The repository's CI pipeline already says what "passing" means here: formatters, linters, static analysis,
warnings-as-errors builds, unit and integration tests, coverage thresholds, sanitizers. The workflow runs
those same checks locally before work is shown or handed over, and reviewers read the pipeline as part of
review. Read by `/wf-build`, `/wf-pr`, `slice-reviewer` and `lens-reviewer`.

## 1. Find the checks (once per repository, refreshed when CI changes)

If `CI_CMD` is set in `.cursor/workflow.env` (for example `make ci`), that is the local entry point: read
what it runs, then go to step 2. Otherwise look, in this order, and stop at the first that defines the
pipeline (later ones may still add checks):

| Where | What to read |
|---|---|
| `Makefile` / `GNUmakefile` / `*.mk` | targets named `ci`, `check`, `lint`, `test`, `verify`, `static`, `format`, and what they call |
| `.github/workflows/*.yml` | every job that runs on `pull_request` or `push`: its `run:` steps and the actions it uses (for example clang-format, clang-tidy, cppcheck, pytest, coverage upload with a threshold) |
| `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml`, `.circleci/config.yml`, `bitbucket-pipelines.yml` | stages and their scripts |
| `.pre-commit-config.yaml` | hooks (formatters and linters) |
| `CMakePresets.json`, `tox.ini`, `noxfile.py`, `package.json` scripts, `pyproject.toml` | test presets, sessions and scripts the CI calls |

Write what you find to `.workflow/ci-checks.md` (repository-wide, shared by every work item):

```
# CI checks
Source: <files read>   CI files last changed: <git log -1 --format=%h -- <those files>>
| Check | Local command | Runs locally? | Time | Notes |
|---|---|---|---|---|
| Format | make format-check | yes | ~5 s | clang-format, fails on diff |
| Static analysis | make tidy | yes | ~3 min | clang-tidy, warnings are errors |
| Unit tests | ctest --preset unit | yes | ~1 min | same as TEST_CMD |
| HIL tests | (CI only) | no: needs hardware runner | | job hil-tests |
```

Mark a check **CI only** when it needs secrets, special runners, hardware or services you cannot reach,
and say why. Never invent a command: if a step only makes sense inside the CI runner, it is CI only.
Refresh the file when the CI files' last commit differs from the one recorded.

## 2. When to run what

| Stage | Run |
|---|---|
| `/wf-build`, before show-me | The fast local checks (format, lint, static analysis on the changed files, the tests `TEST_CMD` does not cover) for the files this slice touched. Skip the slow ones; they run at `/wf-pr`. |
| `/wf-pr`, before the branch review | `CI_CMD` if set, otherwise every check marked "runs locally", on the whole branch. |

Failures are findings like any other: fix them in the slice (they count toward the slice's review rounds)
or in the PR fix rounds. A failure that would need the design, the outline or a locked test to change is a
plan issue: `/wf-escalate`. Never silence a check, add a suppression, lower a threshold or skip a test to
get green without the user agreeing, and log any such agreement in `decisions.md`.

## 3. What to report

Show the checks run, their results and the time taken in the show-me and in the PR description's "Test
evidence". List the CI-only checks there too, so the user knows what the real pipeline still has to prove.

## 4. What reviewers look for in the pipeline

- Would the change fail a CI check the local run could not cover (a stricter compiler flag, another
  platform or toolchain in the matrix, a coverage threshold, a CI-only job)?
- Do new tests, test directories or modules actually get picked up by the CI configuration?
- Does the change touch the CI configuration itself? Then review it as code: weakened checks, removed
  jobs, new `continue-on-error`, `|| true`, skipped tests or lowered thresholds are findings.
- Are new dependencies, tools or generated files handled by the pipeline (caching, install steps, lockfiles)?
