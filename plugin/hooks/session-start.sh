#!/usr/bin/env bash
# session-start.sh - Claude Code SessionStart hook for the gated agent workflow plugin.
# Claude Code has no always-on rules, so this adds the guardrails from rules/agentic-workflow.mdc
# to the session's context. The full rules go in only for repos that use the workflow (a
# .workflow/ folder); other repos get a two-line pointer, to save tokens.
# Output: plain text on stdout (Claude Code adds it as context). Always exits 0.
set -u
cat >/dev/null 2>&1 || true   # discard the JSON input
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULE="${HERE}/../rules/agentic-workflow.mdc"
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ ! -d "${PROJ}/.workflow" ]; then
  echo "The gated-agent-workflow plugin is installed. Its skills are /wf-start, /wf-research, /wf-brainstorm, /wf-plan, /wf-build, /wf-debug, /wf-pr and /wf-escalate."
  echo "This repo has no .workflow/ folder yet; /wf-start sets it up when the user wants to use the workflow."
  exit 0
fi
[ -f "$RULE" ] || exit 0
echo "The gated-agent-workflow plugin is installed and this repo uses it (.workflow/). Its guardrails follow."
echo "In Claude Code, 'start a new chat' in these rules and skills means running /clear (or opening a new session); all state is on disk."
echo
# Strip the .mdc frontmatter.
awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$RULE"
exit 0
