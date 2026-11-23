#!/usr/bin/env bash
# session-start.sh - Claude Code SessionStart hook for the gated agent workflow plugin.
# Claude Code has no always-on rules (Cursor loads rules/agentic-workflow.mdc itself), so this adds the
# same guardrails to every session, plus how the kit's Cursor-style names map to Claude Code.
# Output: plain text on stdout (Claude Code adds it as context). Always exits 0.
set -u
cat >/dev/null 2>&1 || true   # discard the JSON input
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULE="${HERE}/../rules/agentic-workflow.mdc"

echo "The gated-agent-workflow plugin is installed. In Claude Code its names map as follows:"
echo "- A skill written as /wf-<name> (for example /wf-start, /wf-escalate) is the /gated-agent-workflow:wf-<name> skill."
echo "- A subagent written as /researcher, /slice-reviewer, /lens-reviewer or /finding-verifier is the gated-agent-workflow:<name> subagent, started with the Agent tool."
echo "- 'Start a new chat' means /clear or a new session; all workflow state is on disk in .workflow/."
echo "- Claude Code has no chat-rename tool: where the rules say to name the chat, print 'Name this chat: /rename <title>' for the user to run."
echo
[ -f "$RULE" ] || exit 0
# The rule file without its .mdc frontmatter.
awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$RULE"
exit 0
