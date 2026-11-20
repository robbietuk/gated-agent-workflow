#!/usr/bin/env bash
# stop-gate.sh - Cursor "stop" hook for the agentic workflow kit.
#
# Runs after every agent turn. Does nothing unless a work item is in the build
# phase. In build phase it:
#   1. refuses edits to locked tests (asks the agent to restore them),
#   2. runs BUILD_CMD then TEST_CMD (from .cursor/workflow.env),
#   3. on failure, auto-submits a follow-up telling the agent to fix the code,
#   4. after MAX_STOP_RUNS failing runs, tells the agent to stop and /wf-escalate.
#
# Input  (stdin): JSON from Cursor, e.g. {"status":"completed","loop_count":0,...}
# Output (stdout): nothing, or {"followup_message":"..."}. Always exits 0.
# Dependencies: bash, git, sed, grep, awk, tr. No jq.

set -u

INPUT="$(cat 2>/dev/null || true)"
FLAT="$(printf '%s' "$INPUT" | tr -d '\r\n')"

STATUS="$(printf '%s' "$FLAT" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([A-Za-z_]*\)".*/\1/p')"
LOOP_COUNT="$(printf '%s' "$FLAT" | sed -n 's/.*"loop_count"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')"
case "$LOOP_COUNT" in ''|*[!0-9]*) LOOP_COUNT=0 ;; esac

# Project hooks run from the project root; be defensive anyway.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

ACTIVE=".workflow/active.env"
[ -f "$ACTIVE" ] || exit 0

# Read KEY=VALUE from active.env without executing it.
active_get() {
  sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$1=//p" "$ACTIVE" | tail -n 1 \
    | sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

PHASE="$(active_get PHASE)"
[ "$PHASE" = "build" ] || exit 0
[ "$STATUS" = "completed" ] || exit 0

WORK_DIR="$(active_get WORK_DIR)"
SLICE="$(active_get SLICE)"
LOCK_SHA="$(active_get LOCK_SHA)"
[ -n "$WORK_DIR" ] || WORK_DIR=".workflow"
mkdir -p "$WORK_DIR" 2>/dev/null || true

BUILD_CMD=""
TEST_CMD=""
MAX_STOP_RUNS=""
# shellcheck disable=SC1091
[ -f ".cursor/workflow.env" ] && . ".cursor/workflow.env"
case "${MAX_STOP_RUNS:-}" in ''|*[!0-9]*) MAX_STOP_RUNS=5 ;; esac
[ "$MAX_STOP_RUNS" -ge 1 ] || MAX_STOP_RUNS=1

ESC="$(printf '\033')"

# Print {"followup_message": <$1 as a JSON string>} on stdout.
emit() {
  local cleaned
  cleaned="$(printf '%s' "$1" \
    | sed "s/${ESC}\[[0-9;?]*[A-Za-z]//g" \
    | LC_ALL=C tr -d '\000-\010\013-\037\177')"
  if command -v iconv >/dev/null 2>&1; then
    cleaned="$(printf '%s' "$cleaned" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null || printf '%s' "$cleaned")"
  fi
  printf '%s' "$cleaned" | awk '
    BEGIN { ORS = ""; printf "{\"followup_message\":\"" }
    {
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t")
      if (NR > 1) printf "\\n"
      printf "%s", $0
    }
    END { print "\"}\n" }'
}

RUN_NO=$((LOOP_COUNT + 1))
SLICE_LABEL="${SLICE:-current slice}"

# 1. Locked tests must not change (committed or uncommitted).
LOCK_LIST="$WORK_DIR/locked-tests.txt"
if [ -n "$LOCK_SHA" ] && [ -f "$LOCK_LIST" ]; then
  LOCKED=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$line" in ''|'#'*) continue ;; esac
    LOCKED+=("$line")
  done < "$LOCK_LIST"
  if [ "${#LOCKED[@]}" -gt 0 ]; then
    if ! git rev-parse -q --verify "${LOCK_SHA}^{commit}" >/dev/null 2>&1; then
      emit "stop-gate: LOCK_SHA=${LOCK_SHA} in .workflow/active.env is not a commit in this repo, so locked tests cannot be checked. Stop and tell the user; do not edit tests. Fix active.env (LOCK_SHA = the 'test(<slice>): lock failing tests' commit) or run /wf-escalate."
      exit 0
    fi
    CHANGED="$(git diff --name-only "$LOCK_SHA" -- "${LOCKED[@]}" 2>&1)"
    if [ -n "$CHANGED" ]; then
      FILES="$(printf '%s ' "${LOCKED[@]}")"
      emit "Locked tests were modified for ${SLICE_LABEL}:
${CHANGED}

Locked tests define done; they must not be edited. Restore them now:
  git checkout ${LOCK_SHA} -- ${FILES% }
Then fix the production code, not the tests. If a locked test itself seems wrong, stop and run /wf-escalate (do not edit or loosen the test)."
      exit 0
    fi
  fi
fi

# 2. Build, then test. Full output goes to last-run.log.
LOG="$WORK_DIR/last-run.log"
{
  echo "# stop-gate run ${RUN_NO} of ${MAX_STOP_RUNS} | slice ${SLICE_LABEL} | $(date '+%Y-%m-%d %H:%M:%S')"
} > "$LOG" 2>/dev/null || LOG="$(mktemp)"

if [ -z "$BUILD_CMD" ] && [ -z "$TEST_CMD" ]; then
  emit "stop-gate: PHASE=build but BUILD_CMD and TEST_CMD are both empty in .cursor/workflow.env. Ask the user to set them; do not continue the slice without a test command."
  exit 0
fi

RC=0
FAILED_STEP=""
if [ -n "$BUILD_CMD" ]; then
  echo "\$ $BUILD_CMD" >> "$LOG"
  bash -c "$BUILD_CMD" >> "$LOG" 2>&1 </dev/null
  RC=$?
  [ "$RC" -ne 0 ] && FAILED_STEP="build"
fi
if [ "$RC" -eq 0 ] && [ -n "$TEST_CMD" ]; then
  echo "\$ $TEST_CMD" >> "$LOG"
  bash -c "$TEST_CMD" >> "$LOG" 2>&1 </dev/null
  RC=$?
  [ "$RC" -ne 0 ] && FAILED_STEP="tests"
fi
echo "# exit ${RC}" >> "$LOG"

[ "$RC" -eq 0 ] && exit 0

TAIL="$(tail -n 40 "$LOG")"

# 3. Failing: retry or escalate.
if [ "$LOOP_COUNT" -lt $((MAX_STOP_RUNS - 1)) ]; then
  emit "Build/tests failing (run ${RUN_NO} of ${MAX_STOP_RUNS}). Fix the code, not the tests.
Failed step: ${FAILED_STEP} (exit ${RC}). Full log: ${LOG}
Last 40 lines:
${TAIL}"
else
  emit "Stop-hook cap reached: build/tests still failing after ${RUN_NO} of ${MAX_STOP_RUNS} runs on ${SLICE_LABEL}. Stop changing code now. Run /wf-escalate with reason \"stop-hook cap\" and include what you tried and the failure below.
Failed step: ${FAILED_STEP} (exit ${RC}). Full log: ${LOG}
Last 40 lines:
${TAIL}"
fi
exit 0
