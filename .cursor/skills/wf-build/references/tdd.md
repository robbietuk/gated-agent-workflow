# Test-first rules for locked tests (wf-build step a)

Core principle: if you did not watch the test fail, you do not know it tests the right thing.

## The iron law
No production code for this slice before its tests exist and fail for the right reason.
Wrote code first? Delete it (do not keep it "as reference") and start from the tests.

## Writing each test
- One behaviour per test, named for the behaviour: `rejects_dose_above_limit`, not `test1`.
- Use the outline's exact values (limits, units, messages, timeouts).
- Before writing it, name the production change that would make it fail. If you cannot, the test
  asserts nothing useful.
- Assert on real behaviour and outputs, not on mock calls. Mock only true boundaries (hardware, clock,
  network) and understand the side effects of what you mock.
- Keep test-only helpers in test code, never in production classes.

## Watch it fail (mandatory)
Run the focused test command and confirm, for each test:
- it **fails** (an assertion), it does not **error** (typo, missing include, wrong path);
- the failure message is the one you expect ("expected 10, got 12"; "function returned OK, expected
  ERR_LIMIT");
- it fails because the behaviour is missing.

| What you see | What to do |
|---|---|
| Test passes already | It tests existing behaviour. Change the test until it fails for the new behaviour. |
| Test errors / does not compile | Fix the test, or add the minimal compiling stub (returns a wrong value), re-run. |
| Fails for the wrong reason | Fix the test, re-run. Lock only when every test fails correctly. |

## Green
Write the simplest production code that passes. No options, flags or extensibility the slice does not ask
for. Then run the project's full `TEST_CMD`, not only your file: a green file is not a green suite. Any
failure you see, including ones you did not cause, goes in your summary by name.

## Refactor
Only while green. Remove duplication, improve names. Do not add behaviour. Re-run after each change.

## Rationalizations to reject
| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks; the test takes a minute. |
| "I'll test after" | Tests written after pass immediately and prove nothing. |
| "Already checked manually" | Not repeatable, not recorded, not evidence. |
| "The test is wrong, I'll tweak it" | After the lock commit, that is `/wf-escalate`, never an edit. |
