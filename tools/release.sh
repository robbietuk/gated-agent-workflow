#!/usr/bin/env bash
# release.sh - set the kit's version everywhere it is recorded, then run the checks.
#
# Installed copies only update when this number changes: Claude Code keeps its cached copy until
# the version in plugin.json changes, and /wf-start offers to refresh a repo's .workflow/kit/ when
# kit/VERSION changes. So bump it on every release.
#
# Usage: make release VERSION=1.2.0     (or: bash tools/release.sh 1.2.0)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NEW="${1:-}"
if ! printf '%s' "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "usage: make release VERSION=X.Y.Z" >&2
  exit 2
fi
OLD="$(tr -d '[:space:]' < plugin/skills/wf-start/kit/VERSION)"
if [ "$NEW" = "$OLD" ]; then
  echo "version is already $OLD; pick a higher one" >&2
  exit 2
fi

python3 - "$NEW" <<'EOF'
import json, sys
new = sys.argv[1]
def update(path, setter):
    with open(path) as f:
        data = json.load(f)
    setter(data)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
update('plugin/.cursor-plugin/plugin.json', lambda d: d.__setitem__('version', new))
update('plugin/.claude-plugin/plugin.json', lambda d: d.__setitem__('version', new))
update('.cursor-plugin/marketplace.json', lambda d: d.setdefault('metadata', {}).__setitem__('version', new))
EOF
printf '%s\n' "$NEW" > plugin/skills/wf-start/kit/VERSION

echo "Version $OLD -> $NEW in both plugin.json files, .cursor-plugin/marketplace.json and kit/VERSION."
bash tools/ci.sh
echo
echo "Next: commit (chore(release): v$NEW), open a PR, merge, then tag v$NEW on main."
