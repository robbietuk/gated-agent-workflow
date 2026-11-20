# Evidence before claims

No completion claim without fresh verification evidence from this turn.

Before saying anything is done, fixed, passing or ready:
1. **Identify** the command that proves it (`TEST_CMD`, a focused test, `BUILD_CMD`, `git diff --name-only`).
2. **Run** it fully, now. A previous run, a subagent's report or the stop hook's silence earlier is not enough.
3. **Read** the output: exit code, failure count, warnings.
4. **State** the result with the evidence (command + counts). If it does not confirm the claim, state the
   actual status.

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | test command output, 0 failures | "should pass", earlier run |
| Build succeeds | build command exit 0 | linter clean |
| Bug fixed | the regression test that failed now passes | code changed |
| Regression test works | red then green observed | it passes once |
| Locked tests untouched | `git diff --name-only $LOCK_SHA -- <files>` empty | "I didn't touch them" |
| Subagent did X | the diff shows X | the subagent says so |
| Slice meets criteria | each AC checked against code + test | tests green |

Red flags: "should", "probably", "seems to", "Done!" before running anything.
