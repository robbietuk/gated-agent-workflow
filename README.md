# Agentic workflow for Cursor

**[Open the docs site: guide, slides and cheat sheet](https://robbietuk.github.io/gated-agent-workflow/)**

Skills, subagents, a stop hook and templates that turn a manual research -> plan -> implement -> review
routine in [Cursor](https://cursor.com) into a gated, mostly agentic workflow for software features and bug
fixes. Built for regulated (medical-device) software, where traceability and human sign-off matter.

![Feature track: you approve at each gate; the agent builds between them](docs/media/image1.png)

- **Docs site:** [robbietuk.github.io/gated-agent-workflow](https://robbietuk.github.io/gated-agent-workflow/) - the guide, slides and cheat sheet as web pages (sources in [`docs/`](docs)).
- **Guide:** [docs/guide/index.html](docs/guide/index.html) (Markdown source: [docs/guide.md](docs/guide.md)) - tracks, walkthroughs, gates, limits, setup, FAQ.
- **Slides:** [docs/slides/index.html](docs/slides/index.html) - 17 slides with speaker notes; arrow keys to move.
- **Cheat sheet:** [docs/cheatsheet.html](docs/cheatsheet.html) - one printable page with every command.
- **Kit:** one plugin in [`plugin/`](plugin) for both Cursor and Claude Code: install it from this repo as a marketplace, as a local plugin, or copy it into a repo with [`tools/install-into-repo.sh`](tools/install-into-repo.sh). See [Install](#install).

> Status: the formats follow Cursor's documentation (Cursor 2.4+), and the stop hook has a self-test
> (`bash plugin/hooks/test-stop-gate.sh`), but the kit has not yet been exercised end to end inside Cursor.
> Try it on a small change first and open an issue with what you find.

---

### Checks
`make ci` runs the stop-hook self-test, the session-start and installer checks (including the upgrade from
the older `.cursor/` layout), the manifest and version checks and, if Claude Code is installed,
`claude plugin validate`. GitHub Actions runs it on every pull request.

### Editing the docs
The docs site is plain HTML in [`docs/`](docs). The guide's source is [`docs/guide.md`](docs/guide.md); the slides'
sources are in [`docs/src/slides/`](docs/src/slides) (one HTML file per slide). After editing either, run
`python3 tools/build_docs.py` (needs `pandoc`) to regenerate `docs/guide/index.html` and `docs/slides/index.html`.
The cheat sheet ([`docs/cheatsheet.html`](docs/cheatsheet.html)) is edited directly; use its Print button to save a PDF.

---

## About the kit

A drop-in set of Cursor skills, subagents, a stop hook and templates that turns a manual
research -> plan -> implement -> review routine into a gated, mostly agentic workflow. The rule is
**manual where you think, agentic where it builds**: you own the *what* (spec, design, outline, final code
read); the agent owns the *how* (research, implement, test, self-review); **tests decide when a slice is
done**. Every stage writes a short artifact into `.workflow/<date>-<slug>/`, every loop has an iteration
limit, and every limit ends in an explicit escalation back to you, which suits regulated work where
traceability matters.

```
             you                        agent                          you
  /wf-start ------> spec.md + questions.md
                         |
  /wf-research           +--> researcher (sees questions ONLY) --> research.md
                         |
  /wf-brainstorm    <---- one question at a time, 2-3 approaches ----> design.md   [you approve]
                         |
  /wf-plan          <---- vertical slices + req IDs + tests ---------> outline.md  [you approve]
                         |
  /wf-build   per slice: lock failing tests -> implement (stop hook: build+test, max 5)
                         -> slice-reviewer (spec, then quality; max 3 rounds)
                         -> show-me ----------------------------------> [you approve] -> commit
                         |
  /wf-pr            pr-description.md -> lens-reviewers (1 to 12, scaled to the diff) -> finding-verifier
                         -> fix NIT/IMPORTANT (max 2 rounds) ----------> your code read
                         |
  /wf-escalate  <--- any limit hit / plan issue / you say no:
                     revert (you confirm) -> decisions.md -> back to /wf-brainstorm or /wf-plan

  Bug track:   /wf-start -> /wf-debug (reproduce, lock regression test, root cause) [you approve] -> /wf-build -> /wf-pr
  Small change: /wf-start -> /wf-plan (one slice) [you approve] -> /wf-build -> /wf-pr
```

## What is in the kit

The kit is one plugin in [`plugin/`](plugin) that works in both Cursor and Claude Code:

| Path in `plugin/` | What it is |
|---|---|
| `.cursor-plugin/plugin.json` | Plugin manifest (name, version, author) |
| `skills/wf-start` ... `wf-pr` | Eight skills, invoked as `/wf-start`, `/wf-research`, `/wf-brainstorm`, `/wf-plan`, `/wf-build`, `/wf-debug`, `/wf-pr`, `/wf-escalate` |
| `agents/` | Read-only subagents (in Claude Code they cannot write or edit files, but can run Bash, so read-only there rests on their instructions): `researcher`, `slice-reviewer`, `lens-reviewer`, `finding-verifier` |
| `.claude-plugin/plugin.json` | The same plugin's manifest for Claude Code |
| `hooks/stop-gate.sh` | Stop hook (Cursor and Claude Code): in build phase, guards locked tests and runs build + tests after every agent turn |
| `hooks/cursor-hooks.json`, `hooks/hooks.json` | Hook registration for Cursor and for Claude Code (`hooks.json` also adds the guardrails at session start) |
| `hooks/session-start.sh` | Claude Code only: adds the rule file's guardrails to each session |
| `hooks/test-stop-gate.sh` | Self-test for the hook (temp git repo, all scenarios, JSON validation) |
| `rules/agentic-workflow.mdc` | Always-on guardrails (repo setup, locked tests, limits, hand-offs, escalate, no merge/push) |
| `skills/wf-start/kit/` | Per-repo files that `/wf-start` sets up in `.workflow/` on first use: `config.env`, `scaling.md`, `ci-procedure.md`, `templates/` |

The repo root also has `.cursor-plugin/marketplace.json` and `.claude-plugin/marketplace.json`, which let Cursor
and Claude Code add this repository as a marketplace containing the plugin.

In each repo that uses it, the workflow keeps:

| Path | What it is |
|---|---|
| `.workflow/config.env` | Your build/test/CI commands, the iteration limits and the size thresholds |
| `.workflow/kit/scaling.md` | How many researchers and reviewers to run, scaled to the size and risk of the work |
| `.workflow/kit/ci-procedure.md` | How the skills find and run the repo's own CI checks (`make ci`, `.github/workflows/`, ...) |
| `.workflow/kit/templates/` | `spec.md`, `bug-report.md`, `design.md`, `outline.md`, `decisions.md`, `pr-description.md` |
| `.workflow/ci-checks.md` | The repo's CI checks, found on first use |

## Requirements

- **Cursor 2.4 or later.** Skills, custom subagents and the improved `stop` hook arrived in 2.4
  (January 2026). On an older version the `/wf-*` skills and subagents will not appear.
- Hooks run only in a **trusted workspace**, and an enterprise admin can restrict hooks, skills or
  subagents. If `/wf` shows nothing or the hook never fires, check those settings first.
- `bash` and `git` on the PATH Cursor uses (the stop hook is a bash script).
- Installing as a plugin needs a Cursor version with plugins (2.5 or later). On Enterprise, an admin may
  need to allow team marketplaces or local plugins.

## Install

Pick one of four ways (A-C for Cursor, D for Claude Code). All give you the same skills.

### A. Team marketplace (recommended for a team)
1. In the Cursor dashboard, go to **Plugins & MCPs**, click **Add Marketplace**, choose **Import from Repo** and
   paste `https://github.com/robbietuk/gated-agent-workflow` (or your fork, or an internal mirror).
2. In Cursor, open **Customize**, find **gated-agent-workflow** and click **Install** (project or user scope).

### B. Local plugin (just you, no admin needed unless your organisation blocks local plugins)
1. Clone this repo, then copy or link its `plugin/` folder to `~/.cursor/plugins/local/gated-agent-workflow`:
   `ln -s "$PWD/plugin" ~/.cursor/plugins/local/gated-agent-workflow`
2. Restart Cursor or run **Developer: Reload Window**.

### C. Copy into a repo (no plugins at all)
`bash tools/install-into-repo.sh /path/to/your/repo` copies the skills, subagents, rule and hook into its
`.cursor/` and sets up `.workflow/`. Run it again to update; it never overwrites `.workflow/config.env` or an
existing `.cursor/hooks.json`.

### D. Claude Code
The same `plugin/` folder is also a Claude Code plugin (it passes `claude plugin validate`). In Claude Code:
```
/plugin marketplace add robbietuk/gated-agent-workflow
/plugin install gated-agent-workflow@gated-agent-workflow
```
Claude Code namespaces plugin skills, so `/wf-start` is typed as `/gated-agent-workflow:wf-start` (and so on
for every skill). Claude Code has no always-on rules, so a `SessionStart` hook adds the guardrails to every
session, along with how the kit's names map (`/wf-x`, the subagents, "new chat" = `/clear`). The stop hook
is the same script as in Cursor. Install the plugin in Cursor or in Claude Code on a machine, not both
installs of the same kit in one tool.

### Upgrading from the older `.cursor/` copy-in layout
Before installing the plugin, remove the old copy so its skills and stop hook do not run alongside it:
`.cursor/skills/wf-*`, this kit's `.cursor/agents/*.md`, `.cursor/rules/agentic-workflow.mdc`,
`.cursor/hooks/stop-gate.sh` and the stop entry in `.cursor/hooks.json`. Then run `/wf-start`: it moves your
settings from `.cursor/workflow.env` to `.workflow/config.env`. (`tools/install-into-repo.sh` does the same
move for copy installs.) Afterwards `.cursor/workflow.env`, `.cursor/workflow-scaling.md`,
`.cursor/ci-checks.md` and `.workflow/templates/` can be deleted.

### Then, in each repo
1. Type `/wf-start`. On first use it sets the repo up: it creates `.workflow/config.env` and `.workflow/kit/`
   and asks for your commands: `TEST_CMD` (required), `BUILD_CMD` (optional) and `CI_CMD` (for example
   `make ci`, if you have one). Examples: `BUILD_CMD="cmake --build build -j"` /
   `TEST_CMD="ctest --test-dir build --output-on-failure"`, or `TEST_CMD="dotnet test"`, or `TEST_CMD="pytest -q"`.
2. Commit `.workflow/config.env`, `.workflow/kit/` and `.workflow/ci-checks.md` so the team shares them.
   Decide whether work folders are committed (a traceability record) or ignored; either way ignore the local
   state:
   ```
   .workflow/active.env
   .workflow/*/last-run.log
   .workflow/*/.stop-runs
   ```
3. Check the hook on your machine: `bash plugin/hooks/test-stop-gate.sh` from this repo (or
   `bash .cursor/hooks/test-stop-gate.sh` after a copy install). All lines should say PASS.

**After a plugin update,** `/wf-start` notices the new version and offers to refresh `.workflow/kit/`. It
never overwrites `.workflow/config.env`; it lists any new settings and offers to add them.

**Not yet verified live:** neither install has run in a real Cursor or Claude Code session yet. Cursor runs a
plugin's stop hook from the workspace root, so the hook is started as `bash "${CURSOR_PLUGIN_ROOT}/hooks/stop-gate.sh"`.
If it does not fire from a plugin install (`last-run.log` in the work folder never updates during
`/wf-build`), use install option C for now (tracked in issues #1 and #6).

**Windows:** the hook is a bash script. Cursor must be able to run it with bash: install Git for Windows
(Git Bash) or use WSL, and make sure `bash` is on the PATH Cursor sees. The skills and subagents work
without the hook, but then nothing enforces the implement-loop limit or locked tests automatically.

**Before the first `/wf-build`,** make sure the existing test suite is green. In build phase the hook runs
the suite after every turn; a suite that is already red would burn the run budget.

## Quick start

### Feature
```
/wf-start        describe the feature; answer one question at a time; approve spec.md and questions.md
/wf-research     agent researches the code (researcher sees only questions.md) -> research.md
/wf-brainstorm   pick one of 2-3 approaches; approve design.md (~200 lines)
/wf-plan         approve outline.md (vertical slices with req IDs and tests)
/wf-build        per slice: tests locked, implemented, reviewed, shown to you -> approve -> commit
/wf-build        ...repeat for each slice
/wf-pr           PR description + whole-branch review; you do the final code read
```

### Bug
```
/wf-start        triage as bug; fill bug-report.md (observed, expected, steps, device/firmware, severity, IDs)
/wf-debug        reproduce, lock a failing regression test, root cause with evidence -> you approve fix approach
/wf-build        one slice: implement the fix until the locked test passes; review; show-me; commit
/wf-pr           PR description + branch review; your code read
```
If the root cause is a design flaw, `/wf-debug` sends you to `/wf-brainstorm` instead.

### Small change (about an hour, 1-3 files, no new behaviour worth designing)
```
/wf-start        triage as small; short spec.md
/wf-plan         one-slice outline -> approve
/wf-build        lock tests, implement, review, show-me, commit
/wf-pr
```

### Moving between stages
Every `/wf-*` command ends by asking **"Continue with `/wf-<next>` now?"**. Say yes and it carries on in the
same chat; say no and run the next command later (or in a fresh chat). It never moves on without a yes.
It also recommends where to run it: continue in the same chat through spec, research, brainstorm and plan;
start a **new chat** for `/wf-build` and for `/wf-pr` (and for later slices once a chat gets long). Every
stage reads its inputs from `.workflow/`, so a new chat loses nothing and keeps the context small.

### When something goes wrong
`/wf-escalate` at any time. The agent runs it itself when a limit is hit. It stops work, proposes how to
undo the slice (you confirm any git command), logs a dated entry in `decisions.md`, and routes back to
`/wf-brainstorm` (rethink) or `/wf-plan` (replan).

## Where artifacts live

```
.workflow/
  active.env                      # WORK_DIR, TRACK, PHASE, SLICE, LOCK_SHA for the current work item
  config.env                      # your commands, limits and thresholds
  kit/                            # scaling.md, ci-procedure.md, templates/ (set up by /wf-start)
  ci-checks.md                    # the repo's CI checks, found on first use
  2026-11-20-alarm-limit-sync/    # one folder per work item: <YYYY-MM-DD>-<slug>
    spec.md | bug-report.md       # what, why, done (you + agent)
    questions.md                  # factual questions for the researcher
    research.md                   # facts with file:line refs, no opinions
    design.md                     # approved design (~200 lines)
    outline.md                    # slices, acceptance criteria, status, review-round counters
    decisions.md                  # dated decisions and escalations
    locked-tests.txt              # test files that must not change after their lock commit
    last-run.log                  # last stop-hook build+test output
    pr-description.md             # PR body
```

`PHASE` is one of `start | research | brainstorm | plan | build | pr | escalated`. The stop hook only acts
when `PHASE=build`, which `/wf-build` sets when it starts (planning and debugging hand off with
`PHASE=plan`, so the hook never fires at the end of a planning or debugging turn).

## Limits

| Loop | Limit | On limit | Enforced by |
|---|---|---|---|
| Implement (stop hook build+test runs) | 5 runs (`MAX_STOP_RUNS`) | `/wf-escalate` "stop-hook cap" | hook (`loop_count`) |
| Slice review -> fix | 3 rounds (`MAX_REVIEW_ROUNDS`) | `/wf-escalate` | wf-build skill (counter in outline.md) |
| PR fix -> re-run | 2 rounds (`MAX_PR_FIX_ROUNDS`) | `/wf-escalate` | wf-pr skill |
| Brainstorm, planning | none (you are in the loop) | more than 3 planning rounds: revisit the spec | you |

Never: keep going past a limit, or edit/loosen a locked test. The hook detects locked-test edits
(committed or not) against `LOCK_SHA` and tells the agent to restore them.

## How it enforces things

- **Locked tests.** `/wf-build` (or `/wf-debug` for bugs) writes the slice's tests first, runs them, confirms
  they fail for the right reason, commits `test(<slice>): lock failing tests`, records `LOCK_SHA` in
  `active.env` and the files in `locked-tests.txt`. After that the hook rejects any change to those files.
- **Stop hook.** After each agent turn in build phase: locked-test check, then `BUILD_CMD` and `TEST_CMD`.
  Pass: silent. Fail: auto-submits "Build/tests failing (run N of 5). Fix the code, not the tests." with the
  last 40 lines of output. On the 5th failing run: "stop changing code; run /wf-escalate". Cursor's own
  `loop_limit: 20` is only a backstop above that. `loop_count` counts the hook's own follow-ups in an agent run;
  if you step in with a message, counting may start over, so treat the cap as "how long the agent may churn
  on its own" and keep an eye on the slice counters in `outline.md`.
- **Fresh reviewers.** Subagents start with a clean context and are read-only; the skills pass them
  everything they need explicitly.

## Tuning

- **Limits:** change the numbers in `.workflow/config.env`. The hook enforces `MAX_STOP_RUNS` itself; Cursor's
  `loop_limit` (20 in the plugin) is only a backstop, so keep `MAX_STOP_RUNS` below 20.
- **Slow suites:** point `TEST_CMD` at a fast subset (e.g. the module's tests) and let `/wf-pr` run the full
  suite. The hook has 600 seconds for build plus tests; if it is killed, both tools treat that as a pass, so keep
  the commands well under that or raise `timeout` in the hooks config.
- **Models:** subagents use `model: inherit`. Set a specific model in the agent frontmatter if you want
  cheaper research or a stronger reviewer.
- **CI checks:** set `CI_CMD` in `.workflow/config.env` if the repo has one local entry point (for example
  `CI_CMD="make ci"`). Otherwise the skills read the `Makefile`, `.github/workflows/` and other CI config,
  write what they find to `.workflow/ci-checks.md`, and run the checks that can run locally: the fast ones
  before each show-me, all of them before the PR. Reviewers also read the pipeline: they flag changes that
  would fail a CI-only job, tests CI would not pick up, and weakened checks.
- **Review and research depth:** the number of subagents scales with the work. A diff is sized into tiers
  XS / S / M / L by changed lines and files (`TIER_XS_LINES`, `TIER_S_LINES`, `TIER_M_LINES` in
  `.workflow/config.env`), high risk moves it up a tier, and `.workflow/kit/scaling.md` maps each tier to
  a plan: one light reviewer for a few lines, up to `MAX_REVIEW_AGENTS` reviewers split by lens and file
  group for a large branch. Research scales by question count and code areas, up to `MAX_RESEARCHERS`.
- **Lenses:** edit `plugin/agents/lens-reviewer.md` and `plugin/skills/wf-pr/references/branch-review.md` to add or
  change lenses (e.g. cybersecurity, performance).
- **Templates:** edit `.workflow/kit/templates/` to match your SRS / hazard-analysis IDs and PR template.
- **Auto-invocation:** the skills allow model invocation with precise descriptions. To make a skill run
  only when typed, add `disable-model-invocation: true` to its frontmatter.

## Credits

- Brainstorming, planning, build loop, TDD, debugging and review skills are adapted from
  [obra/superpowers](https://github.com/obra/superpowers) v7.0.2 (MIT, Copyright (c) 2025 Jesse Vincent).
  See `THIRD-PARTY-NOTICES.md` for the license and the file-by-file mapping.
- Research-plan-implement flow and short design/outline artifacts follow HumanLayer's RPI/CRISPY lessons.
- Hook, skill and subagent formats follow the Cursor documentation (`hooks.json` v1, `stop` hook with
  `followup_message` and `loop_count`, skills in `.cursor/skills`, subagents in `.cursor/agents`).
