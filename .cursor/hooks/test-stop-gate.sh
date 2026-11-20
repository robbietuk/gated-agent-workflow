#!/usr/bin/env bash
# test-stop-gate.sh - self-test for .cursor/hooks/stop-gate.sh
#
# Builds a throwaway git repo in a temp dir, drops the hook in, and feeds it the
# same stdin JSON Cursor sends. Checks each scenario and that every non-empty
# output is valid JSON with a "followup_message" string (python3 json.loads).
#
# Usage: bash .cursor/hooks/test-stop-gate.sh     (from anywhere; needs bash, git, python3)

set -u

HOOK_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stop-gate.sh"
[ -f "$HOOK_SRC" ] || { echo "cannot find $HOOK_SRC"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required for JSON validation"; exit 2; }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t stopgate)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 2

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL  $1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }

# ---- fixture repo ----------------------------------------------------------
git init -q .
git config user.email "test@example.invalid"
git config user.name "stop-gate test"
git config commit.gpgsign false
mkdir -p .cursor/hooks tests src .workflow/2026-01-01-demo
cp "$HOOK_SRC" .cursor/hooks/stop-gate.sh
chmod +x .cursor/hooks/stop-gate.sh

# Fake test runner: passes iff src/state says "pass". Prints awkward characters on failure.
cat > run-tests.sh <<'EOF'
#!/usr/bin/env bash
if [ "$(cat src/state 2>/dev/null)" = "pass" ]; then echo "all 3 tests passed"; exit 0; fi
for i in $(seq 1 60); do echo "noise line $i"; done
printf 'FAILED test_dose_limit: expected "10" got \\"12\\"\ttab\r\n'
printf 'ansi \033[31mRED\033[0m bell \007 done\n'
echo "TEST_TAIL_MARKER"
exit 1
EOF
chmod +x run-tests.sh
echo "fail" > src/state
echo 'def test_dose_limit(): assert False' > tests/test_dose.py

cat > .cursor/workflow.env <<'EOF'
BUILD_CMD="true"
TEST_CMD="./run-tests.sh"
MAX_STOP_RUNS=5
EOF

git add -A && git commit -qm "test(S1): lock failing tests"
LOCK="$(git rev-parse HEAD)"
echo "tests/test_dose.py" > .workflow/2026-01-01-demo/locked-tests.txt

write_active() { # $1 = PHASE, $2 = LOCK_SHA (optional)
  cat > .workflow/active.env <<EOF
WORK_DIR=.workflow/2026-01-01-demo
TRACK=feature
PHASE=$1
SLICE=S1
LOCK_SHA=${2:-}
EOF
}

run_hook() { # $1 = status, $2 = loop_count ; pretty-printed JSON on purpose
  printf '{\n  "conversation_id": "abc",\n  "generation_id": "g1",\n  "status": "%s",\n  "loop_count": %s,\n  "workspace_roots": ["%s"]\n}\n' \
    "$1" "$2" "$TMP" | bash .cursor/hooks/stop-gate.sh
}

valid_json() { # stdin -> prints followup_message, exits non-zero if invalid
  python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); m=d["followup_message"]; assert isinstance(m,str) and m; sys.stdout.write(m)'
}

expect_silent() { # $1 name, $2 output
  if [ -z "$2" ]; then ok "$1"; else bad "$1" "expected no output, got: $(printf '%s' "$2" | head -c 200)"; fi
}

expect_followup() { # $1 name, $2 output, $3.. required substrings
  local name="$1" out="$2" msg; shift 2
  if [ -z "$out" ]; then bad "$name" "expected followup JSON, got nothing"; return; fi
  if ! msg="$(printf '%s' "$out" | valid_json 2>&1)"; then bad "$name" "invalid JSON: $msg"; return; fi
  local s
  for s in "$@"; do
    case "$msg" in *"$s"*) ;; *) bad "$name" "message missing: $s"; return ;; esac
  done
  ok "$name (valid JSON)"
}

# ---- scenarios -------------------------------------------------------------
OUT="$(run_hook completed 0)"
expect_silent "no active.env -> silent" "$OUT"

write_active plan "$LOCK"
OUT="$(run_hook completed 0)"
expect_silent "PHASE=plan (not build) -> silent" "$OUT"

write_active build "$LOCK"
OUT="$(run_hook aborted 0)"
expect_silent "PHASE=build, status=aborted -> silent" "$OUT"

echo "pass" > src/state
OUT="$(run_hook completed 0)"
expect_silent "build phase, tests passing -> silent" "$OUT"
if [ -f .workflow/2026-01-01-demo/last-run.log ] && grep -q "all 3 tests passed" .workflow/2026-01-01-demo/last-run.log; then
  ok "passing run saved to WORK_DIR/last-run.log"
else
  bad "passing run saved to WORK_DIR/last-run.log"
fi

echo "fail" > src/state
OUT="$(run_hook completed 0)"
expect_followup "failing tests, loop_count=0 -> retry followup" "$OUT" \
  "run 1 of 5" "Fix the code, not the tests." "TEST_TAIL_MARKER" 'expected "10"'
MSG="$(printf '%s' "$OUT" | valid_json 2>/dev/null)"
case "$MSG" in *"noise line 1"$'\n'*) bad "followup carries only the last ~40 lines" ;; *) ok "followup carries only the last ~40 lines" ;; esac
case "$MSG" in *$'\033'*|*$'\007'*|*$'\r'*) bad "control characters stripped" ;; *) ok "control characters stripped" ;; esac
if grep -q "noise line 1$" .workflow/2026-01-01-demo/last-run.log; then ok "full failing output in last-run.log"; else bad "full failing output in last-run.log"; fi

OUT="$(run_hook completed 3)"
expect_followup "failing tests, loop_count=3 -> still retry (run 4 of 5)" "$OUT" "run 4 of 5"

OUT="$(run_hook completed 4)"
expect_followup "failing tests, loop_count=4 -> cap reached, escalate" "$OUT" \
  "cap reached" "/wf-escalate" "stop-hook cap" "Stop changing code"

sed 's/MAX_STOP_RUNS=5/MAX_STOP_RUNS=2/' .cursor/workflow.env > .cursor/workflow.env.tmp && mv .cursor/workflow.env.tmp .cursor/workflow.env
OUT="$(run_hook completed 1)"
expect_followup "MAX_STOP_RUNS=2 honoured (cap at loop_count=1)" "$OUT" "stop-hook cap"
sed 's/MAX_STOP_RUNS=2/MAX_STOP_RUNS=5/' .cursor/workflow.env > .cursor/workflow.env.tmp && mv .cursor/workflow.env.tmp .cursor/workflow.env

sed 's/BUILD_CMD="true"/BUILD_CMD="echo compile error >\&2; exit 3"/' .cursor/workflow.env > .cursor/workflow.env.tmp && mv .cursor/workflow.env.tmp .cursor/workflow.env
echo "pass" > src/state
OUT="$(run_hook completed 0)"
expect_followup "build failure reported before tests" "$OUT" "Failed step: build" "compile error"
sed 's/BUILD_CMD=.*/BUILD_CMD="true"/' .cursor/workflow.env > .cursor/workflow.env.tmp && mv .cursor/workflow.env.tmp .cursor/workflow.env

# Locked test edited but not committed.
echo 'def test_dose_limit(): assert True  # loosened' > tests/test_dose.py
OUT="$(run_hook completed 0)"
expect_followup "locked test edited (uncommitted) -> restore message" "$OUT" \
  "tests/test_dose.py" "git checkout $LOCK -- tests/test_dose.py" "/wf-escalate"

# Locked test edited and committed.
git add tests/test_dose.py && git commit -qm "oops"
OUT="$(run_hook completed 0)"
expect_followup "locked test edited (committed) -> restore message" "$OUT" "git checkout $LOCK -- tests/test_dose.py"

# Restore as instructed -> gate runs tests again and passes.
git checkout -q "$LOCK" -- tests/test_dose.py
OUT="$(run_hook completed 0)"
expect_silent "after restore + passing tests -> silent" "$OUT"

write_active build "deadbeefdeadbeef"
OUT="$(run_hook completed 0)"
expect_followup "bad LOCK_SHA -> stop and tell user" "$OUT" "not a commit"

write_active build ""
sed 's/^BUILD_CMD=.*/BUILD_CMD=""/; s/^TEST_CMD=.*/TEST_CMD=""/' .cursor/workflow.env > .cursor/workflow.env.tmp && mv .cursor/workflow.env.tmp .cursor/workflow.env
OUT="$(run_hook completed 0)"
expect_followup "no BUILD_CMD/TEST_CMD configured -> ask user" "$OUT" "BUILD_CMD and TEST_CMD"

echo
echo "stop-gate tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
