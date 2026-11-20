# Bug: <short title>

- **Work item:** <YYYY-MM-DD>-<slug>
- **Track:** bug
- **Reported by / date:** <name>, <YYYY-MM-DD>
- **Ticket:** <link or ID>
- **Severity:** critical | major | minor | cosmetic
- **Linked requirement / hazard IDs:** <e.g. SRS-210, HAZ-012>  (or "none")

## Observed
<What actually happens. Exact error text, log lines, screenshots.>

## Expected
<What should happen, and which requirement says so.>

## Steps to reproduce
1. <step>
2. <step>
3. <step>
- **Reproducible:** always | intermittent (<n> of <m>) | not yet

## Environment
- **Device / instrument:** <model, hardware rev>
- **Firmware / software version:** <version, build>
- **Configuration:** <relevant settings>
- **Host / OS / toolchain:** <if relevant>

## Impact
<Who is affected, safety relevance, workaround if any.>

## Investigation (filled by /wf-debug)
- **Regression test:** <path::name>, locked at <LOCK_SHA>, fails with: <message>
- **Root cause (with evidence):** <file:line, what is wrong, how we know>
- **Proposed fix approach:** <one or two sentences>
- **Design flaw?** no | yes -> /wf-brainstorm
- **User approved root cause + fix approach:** <date>
