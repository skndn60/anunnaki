# Quality Risk Register

**Purpose:** standing tripwires for quality degradation. Read this at the start of every session. It exists because the user does not read these documents — so this file is my continuity, and **reporting to the user happens in conversation, not here.** A finding that only exists in a doc has not been delivered.

**Division of labour (user's standing instruction, 2026-09-26):** the user describes *functionality* and steers the *quality parameter*. I build within the architectural boundaries in `AGENTS.md`. If work is heading somewhere that will degrade overall quality, I say so **unprompted**, before it is baked in — including when the drift is mine.

---

## Baseline — measured 2026-09-26

| # | Tripwire | Baseline | Direction that worries us | Status |
|---|---|---|---|---|
| 1 | Unchecked `try? context.save()` | **274** / 71 files | any increase | open, Tier 1 queued |
| 2 | `try?` on `fetch` | 409 | — | **do not "fix"** — idiomatic |
| 3 | Build warnings (clean rebuild) | **424** (272 dead-code) | any increase | open |
| 4 | Confirmed dead code | 2 files / ~154 LOC | any increase | open |
| 5 | UI share of codebase | **71%** (44,167 / 62,418 LOC) | rising | open |
| 6 | MeCore test:LOC ratio | 0.67 (12,156 / 18,251) | falling | healthy |
| 7 | `@Model` count / migration files | 60 / 20 | models added without a migration test | open |
| 8 | `Migration.*` calls per launch | ~70, all unconditional | growing | see `TODO.md` |
| 9 | New `@Model` properties that are non-optional | 0 | any occurrence | **hard stop** |
| 10 | Destructive / data-losing migrations | 0 | any occurrence | **hard stop** |

## Escalation rules

- **Hard stop (#9, #10):** violates the "database is sacred" constraint. Do not perform; report immediately, even mid-task.
- **Warn before writing (any tripwire moving against us):** report the trend, the cause, and the cheapest correction. Then continue on functional work unless told otherwise.
- **Report on trend, not snapshot.** A good snapshot with a bad trajectory is the case that gets missed — the 2026-09-26 filter field is exactly that: metrics fine, *process* drifting (a feature shipped that was never asked for).

## Process tripwires — drift in how I work, not just in the code

- [ ] Shipping a feature the user did not request → say so first.
- [ ] View-layer code growing faster than `MeCore` → flag before adding.
- [ ] Closing a critique/audit document without having asked it every question. `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` was marked ✅ resolved while error handling had never been examined — that retirement was premature and is why #1 went unflagged for months.
- [ ] Rating the app from a snapshot without separating code quality from dataset fill rate (they are different projects; conflating them misleads the user).

## Known limitations of this register

- Readings are point-in-time snapshots taken when a tripwire was last examined. A stale baseline is worse than none — **re-baseline the row when it is checked, and say when it was last measured.**
- 2026-09-26: tripwire #1 sat undetected through many sessions and was only found because the user asked a general question. Passive vigilance is demonstrably insufficient; the check has to be deliberate.
