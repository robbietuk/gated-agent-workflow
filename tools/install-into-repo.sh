#!/usr/bin/env bash
# install-into-repo.sh - install the workflow into a repo by copying files (no Cursor plugin).
#
# Use this when you cannot install plugins (for example an Enterprise admin has not allowed them) or
# want the kit committed inside the repo. Running it again updates the kit; it never overwrites your
# .workflow/config.env or an existing .cursor/hooks.json.
#
# Usage: bash tools/install-into-repo.sh /path/to/your/repo
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugin" && pwd)"
DEST="${1:-}"
if [ -z "$DEST" ] || [ ! -d "$DEST" ]; then
  echo "usage: bash tools/install-into-repo.sh /path/to/your/repo" >&2
  exit 2
fi
DEST="$(cd "$DEST" && pwd)"

mkdir -p "$DEST/.cursor/skills" "$DEST/.cursor/agents" "$DEST/.cursor/rules" "$DEST/.cursor/hooks" "$DEST/.workflow/kit"

# Skills, subagents, rule and hook script (updated on every run).
for d in "$SRC"/skills/*/; do
  name="$(basename "$d")"
  rm -rf "$DEST/.cursor/skills/$name"
  cp -R "$d" "$DEST/.cursor/skills/$name"
done
cp "$SRC"/agents/*.md "$DEST/.cursor/agents/"
cp "$SRC"/rules/*.mdc "$DEST/.cursor/rules/"
cp "$SRC/hooks/stop-gate.sh" "$SRC/hooks/test-stop-gate.sh" "$DEST/.cursor/hooks/"
chmod +x "$DEST/.cursor/hooks/"*.sh

# Hook registration: project hooks run from the repo root.
if [ -f "$DEST/.cursor/hooks.json" ]; then
  echo "note: $DEST/.cursor/hooks.json exists; not changed. Make sure it has this stop hook:"
  echo '  {"command": "bash .cursor/hooks/stop-gate.sh", "loop_limit": 6, "timeout": 600}'
else
  cat > "$DEST/.cursor/hooks.json" <<'JSON'
{
  "version": 1,
  "hooks": {
    "stop": [
      { "command": "bash .cursor/hooks/stop-gate.sh", "loop_limit": 6, "timeout": 600 }
    ]
  }
}
JSON
fi

# Per-repo kit files (what /wf-start sets up in a plugin install).
KIT="$SRC/skills/wf-start/kit"
rm -rf "$DEST/.workflow/kit/templates"
cp -R "$KIT/templates" "$DEST/.workflow/kit/templates"
cp "$KIT/scaling.md" "$KIT/ci-procedure.md" "$KIT/VERSION" "$DEST/.workflow/kit/"
if [ -f "$DEST/.workflow/config.env" ]; then
  echo "note: $DEST/.workflow/config.env exists; not changed. New settings, if any, are in $KIT/config.env."
else
  cp "$KIT/config.env" "$DEST/.workflow/config.env"
fi

echo "Installed into $DEST:"
echo "  .cursor/skills (8), .cursor/agents (4), .cursor/rules, .cursor/hooks(.json)"
echo "  .workflow/config.env and .workflow/kit/"
echo "Next: set BUILD_CMD, TEST_CMD (and CI_CMD if you have one) in .workflow/config.env,"
echo "run 'bash .cursor/hooks/test-stop-gate.sh', reload Cursor and type /wf-start."
