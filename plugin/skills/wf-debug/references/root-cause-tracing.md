# Root-cause tracing

Bugs often show up far from where they start: a corrupt reading displayed by the UI, a wrong value written
to config, a timeout in a comms layer. The instinct is to fix where the error appears. That treats the
symptom. Trace backward until you find the original trigger, then fix there.

## Process
1. **Observe the symptom.** Exact message, value, state, file:line.
   `Alarm limit shown as 0 after config reload`
2. **Find the immediate cause.** Which code directly produces it?
   `AlarmPanel::render()` reads `limits.high` which is 0.
3. **Ask what called this, with what value.** Walk up the call chain.
   `render()` <- `onConfigChanged()` <- `ConfigStore::reload()` <- `SyncChannel::onMessage()`
4. **Keep tracing up.** At each level note the value passed and whether it is already wrong.
   `ConfigStore::reload()` receives a partial message; missing keys default to 0.
5. **Find the original trigger.** The first place a correct value becomes incorrect, or a wrong assumption
   is made. Fix there (here: partial messages should be rejected or merged, not defaulted).
6. **Consider defence in depth** after the source fix: validate at the boundary that let it through
   (here: `AlarmPanel` should never show a limit outside the allowed range). Only if the design allows it.

## When you cannot trace by reading
Add temporary instrumentation just before the failing operation:
- log inputs, the relevant state, thread id, timestamps, and a stack trace if the platform offers one;
- in tests, write to stderr (loggers are often silenced); include enough context to tell runs apart;
- run once, read the output, then remove the instrumentation.

## Multi-component systems (device <-> host, driver -> service -> UI, build -> sign -> package)
For each boundary, log what enters and what leaves, and check that configuration and environment propagate.
Run once. The evidence shows **which** boundary turns good into bad. Investigate only that component.

## Intermittent failures
- Count: how often, under what load, on which hardware/firmware.
- Replace arbitrary sleeps/timeouts in tests with waiting on the actual condition (poll with a deadline).
- Suspect shared state, ordering, and lifetimes across threads; log thread ids and sequence numbers.

## When it is genuinely external
If the investigation shows the cause is truly outside the code (hardware fault, external service, timing
outside spec): write down what you checked, implement explicit handling (retry, timeout, clear error),
add logging for next time, and record it in decisions.md. Make sure the investigation was complete first.
