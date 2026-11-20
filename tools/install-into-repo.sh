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
  echo '  {"command": "bash .cursor/hooks/stop-gate.sh", "loop_limit": 20, "timeout": 600}'
else
  cat > "$DEST/.cursor/hooks.json" <<'JSON'
{
  "version": 1,
  "hooks": {
    "stop": [
      { "command": "bash .cursor/hooks/stop-gate.sh", "loop_limit": 20, "timeout": 600 }
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
elif [ -f "$DEST/.cursor/workflow.env" ]; then
  # Upgrade from the older copy-in layout: keep every value, add settings it lacks.
  cp "$DEST/.cursor/workflow.env" "$DEST/.workflow/config.env"
  ADDED=""
  while IFS= read -r line; do
    key="${line%%=*}"
    case "$line" in [A-Z]*=*) ;; *) continue ;; esac
    grep -q "^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}${key}=" "$DEST/.workflow/config.env" && continue
    printf '%s\n' "$line" >> "$DEST/.workflow/config.env"; ADDED="$ADDED $key"
  done < "$KIT/config.env"
  echo "Upgraded: settings moved from .cursor/workflow.env to .workflow/config.env${ADDED:+ (added:$ADDED)}."
  echo "These old files are no longer used and can be deleted:"
  for f in .cursor/workflow.env .cursor/workflow-scaling.md .cursor/ci-checks.md .workflow/templates; do
    [ -e "$DEST/$f" ] && echo "  $f"
  done
else
  cp "$KIT/config.env" "$DEST/.workflow/config.env"
fi

echo "Installed into $DEST:"
echo "  .cursor/skills ($(ls -d "$SRC"/skills/*/ | wc -l | tr -d ' ')), .cursor/agents ($(ls "$SRC"/agents/*.md | wc -l | tr -d ' ')), .cursor/rules, .cursor/hooks(.json)"
echo "  .workflow/config.env and .workflow/kit/"
echo "Add to .gitignore: .workflow/active.env, .workflow/*/last-run.log, .workflow/*/.stop-runs"
echo "Next: set BUILD_CMD, TEST_CMD (and CI_CMD if you have one) in .workflow/config.env,"
echo "run 'bash .cursor/hooks/test-stop-gate.sh', reload Cursor and type /wf-start."
