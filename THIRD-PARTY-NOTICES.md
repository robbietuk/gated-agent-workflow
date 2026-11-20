# Third-party notices

This kit adapts material from the following project. Adapted files were rewritten for Cursor (skills in
`.cursor/skills`, subagents in `.cursor/agents`), for this kit's artifacts in `.workflow/<id>/`, its gates
and iteration limits, vertical slices with requirement IDs, locked tests and the escalate path. Superpowers'
own scripts, visual companion server, worktree skill dependencies and `docs/superpowers` paths were removed.

## obra/superpowers v7.0.2

- Source: https://github.com/obra/superpowers
- License: MIT (full text below)
- Copyright (c) 2025 Jesse Vincent

| Kit file | Adapted from (superpowers skill) |
|---|---|
| `.cursor/skills/wf-start/SKILL.md` | brainstorming (question style only) |
| `.cursor/skills/wf-brainstorm/SKILL.md` | brainstorming |
| `.cursor/skills/wf-plan/SKILL.md` | writing-plans |
| `.cursor/skills/wf-build/SKILL.md` | subagent-driven-development, test-driven-development, verification-before-completion |
| `.cursor/skills/wf-build/references/tdd.md` | test-driven-development |
| `.cursor/skills/wf-build/references/review-loop.md` | subagent-driven-development (references/fix-loop.md, task-reviewer-prompt.md) |
| `.cursor/skills/wf-build/references/verification.md` | verification-before-completion |
| `.cursor/skills/wf-debug/SKILL.md` | systematic-debugging, test-driven-development |
| `.cursor/skills/wf-debug/references/root-cause-tracing.md` | systematic-debugging (root-cause-tracing.md) |
| `.cursor/skills/wf-escalate/SKILL.md` | finishing-a-development-branch (git safety rules) |
| `.cursor/skills/wf-pr/SKILL.md`, `references/branch-review.md` | requesting-code-review (code-reviewer.md), subagent-driven-development (references/final-review.md), finishing-a-development-branch |
| `.cursor/agents/slice-reviewer.md` | subagent-driven-development (task-reviewer-prompt.md) |
| `.cursor/agents/lens-reviewer.md` | requesting-code-review (code-reviewer.md) |

Not derived from superpowers: `wf-research`, `researcher`, `finding-verifier`, the stop hook and its test,
`workflow.env`, the rule file and the `.workflow/templates/`.

### MIT License text

```
MIT License

Copyright (c) 2025 Jesse Vincent

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Other acknowledgements (ideas, no code copied)

- HumanLayer's research-plan-implement (RPI/CRISPY) practice and its lessons on short design/outline artifacts and
  keeping research free of intent.
- Cursor documentation for the hooks (`hooks.json` version 1, `stop` hook with `followup_message` and
  `loop_count`), skills (`.cursor/skills`) and subagents (`.cursor/agents`) formats.
