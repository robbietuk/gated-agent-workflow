#!/usr/bin/env bash
# ci.sh - checks for this repo: run with `make ci` (needs bash, git, python3; uses `claude` if installed).
#   1. stop hook self-test
#   2. session-start hook output
#   3. tools/install-into-repo.sh: fresh install, re-run, upgrade from the older .cursor/ layout
#   4. manifests are valid JSON and every version string matches
#   5. `claude plugin validate` for the plugin and the marketplace (skipped if claude is not installed)
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 2
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 1. Stop hook
if bash plugin/hooks/test-stop-gate.sh > "$TMP/hook.log" 2>&1; then ok "stop hook self-test ($(tail -1 "$TMP/hook.log"))"
else bad "stop hook self-test" "$(grep FAIL "$TMP/hook.log" | head -5)"; fi

# 2. Session start
OUT="$(echo '{}' | CLAUDE_PROJECT_DIR="$TMP" bash plugin/hooks/session-start.sh)"
case "$OUT" in *"/gated-agent-workflow:wf-"*) ok "session-start maps skill names" ;; *) bad "session-start maps skill names" ;; esac
case "$OUT" in *"# Agentic workflow guardrails"*) ok "session-start includes the rules" ;; *) bad "session-start includes the rules" ;; esac
case "$OUT" in *"alwaysApply"*) bad "session-start strips the rule frontmatter" ;; *) ok "session-start strips the rule frontmatter" ;; esac

# Every skill names its chat when its stage starts (rule: Chat titles).
MISSING=""
for f in plugin/skills/*/SKILL.md; do grep -q 'Chat titles' "$f" || MISSING="$MISSING $f"; done
[ -z "$MISSING" ] && ok "every skill names its chat" || bad "every skill names its chat" "missing in:$MISSING"
grep -q '^- \*\*Chat titles\.\*\*' plugin/rules/agentic-workflow.mdc && ok "rule defines chat titles" || bad "rule defines chat titles"
case "$OUT" in *"/rename <title>"*) ok "session-start maps chat naming to /rename" ;; *) bad "session-start maps chat naming to /rename" ;; esac

# 3. Copy installer
R="$TMP/fresh repo"; mkdir -p "$R" && git -C "$R" init -q
if bash tools/install-into-repo.sh "$R" > "$TMP/inst.log" 2>&1; then ok "installer runs"; else bad "installer runs" "$(tail -3 "$TMP/inst.log")"; fi
for f in .cursor/hooks.json .cursor/hooks/stop-gate.sh .cursor/rules/agentic-workflow.mdc .cursor/agents/researcher.md \
         .cursor/skills/wf-start/SKILL.md .cursor/skills/wf-start/kit/VERSION .workflow/config.env \
         .workflow/kit/VERSION .workflow/kit/scaling.md .workflow/kit/ci-procedure.md .workflow/kit/templates/spec.md; do
  [ -e "$R/$f" ] || bad "installer creates $f"
done
[ "$FAIL" -eq 0 ] && ok "installer creates the expected files"
python3 -m json.tool "$R/.cursor/hooks.json" >/dev/null 2>&1 && ok "installer hooks.json is valid JSON" || bad "installer hooks.json is valid JSON"
echo 'TEST_CMD="my tests"' >> "$R/.workflow/config.env"
bash tools/install-into-repo.sh "$R" > /dev/null 2>&1 || bad "installer re-run exits 0"
grep -q 'TEST_CMD="my tests"' "$R/.workflow/config.env" && ok "re-running keeps .workflow/config.env" || bad "re-running keeps .workflow/config.env"

U="$TMP/old repo"; mkdir -p "$U/.cursor" "$U/.workflow/templates" && git -C "$U" init -q
printf 'BUILD_CMD="make"\nTEST_CMD="make test"\nMAX_STOP_RUNS=3\n' > "$U/.cursor/workflow.env"
OUTU="$(bash tools/install-into-repo.sh "$U" 2>&1)"
grep -q '^TEST_CMD="make test"' "$U/.workflow/config.env" && grep -q '^MAX_STOP_RUNS=3' "$U/.workflow/config.env" \
  && ok "upgrade keeps settings from .cursor/workflow.env" || bad "upgrade keeps settings from .cursor/workflow.env"
grep -q '^MAX_REVIEW_ROUNDS=' "$U/.workflow/config.env" && ok "upgrade adds missing settings" || bad "upgrade adds missing settings"
case "$OUTU" in *".cursor/workflow.env"*".workflow/templates"*) ok "upgrade lists old files to delete" ;; *) bad "upgrade lists old files to delete" ;; esac

# 4. Manifests and versions
for f in plugin/.cursor-plugin/plugin.json plugin/.claude-plugin/plugin.json .cursor-plugin/marketplace.json \
         .claude-plugin/marketplace.json plugin/hooks/hooks.json plugin/hooks/cursor-hooks.json; do
  python3 -m json.tool "$f" >/dev/null 2>&1 || bad "$f is valid JSON"
done
V="$(tr -d '[:space:]' < plugin/skills/wf-start/kit/VERSION)"
VS="$(python3 - <<'EOF'
import json
print(json.load(open('plugin/.cursor-plugin/plugin.json'))['version'],
      json.load(open('plugin/.claude-plugin/plugin.json'))['version'],
      json.load(open('.cursor-plugin/marketplace.json')).get('metadata',{}).get('version',''))
EOF
)"
[ "$VS" = "$V $V $V" ] && ok "versions match ($V)" || bad "versions match" "kit/VERSION=$V; cursor, claude, marketplace: $VS"

# 5. Claude Code validator
if command -v claude >/dev/null 2>&1; then
  claude plugin validate ./plugin > "$TMP/v1.log" 2>&1 && ok "claude plugin validate ./plugin" || bad "claude plugin validate ./plugin" "$(tail -5 "$TMP/v1.log")"
  claude plugin validate . > "$TMP/v2.log" 2>&1 && ok "claude plugin validate (marketplace)" || bad "claude plugin validate (marketplace)" "$(tail -5 "$TMP/v2.log")"
else
  echo "SKIP  claude plugin validate (claude not installed)"
fi

echo
echo "ci: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
