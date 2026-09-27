# Quality Risk Register

**Purpose:** standing tripwires for quality degradation, plus the protocol that keeps them honest. This file exists because the user does not read it — so it is my continuity, and **reporting to the user happens in conversation, not here.** A finding that only exists in this file has not been delivered.

**Division of labour (user's standing instruction, 2026-09-26):** the user describes *functionality* and steers the *quality parameter*. I build within the architectural boundaries in `AGENTS.md`. If work is heading somewhere that will degrade overall quality, I say so **unprompted**, before it is baked in — including when the drift is mine.

---

## The protocol

Five rules. They exist because the previous arrangement — "read this at the start of every session" — was passive, and passive vigilance demonstrably failed: tripwire #1 sat undetected through months of sessions and was only found because the user asked a general question.

**1. Measure, don't recall.** Never write a number in the table below from memory. Run `./scripts/quality-check.sh` and paste its output. It measures every row that a text scan can decide, and names the four it cannot. Where the two disagree, the script wins and the table is wrong.

**2. Cadence.** Run the script at the start of any session that touches `Sources/`. A full re-read of this file — including the MANUAL rows and the self-audit in rule 5 — happens every ~10 working sessions, or immediately after any incident, any reverted change, or any session that felt harder to verify than usual. The MANUAL rows (#3, #4, #9, #10) are judgement calls and are worthless unless actually performed; skipping them silently is the failure mode this cadence exists to prevent.

**3. Deliver in-session, with the work.** A tripwire that moves is reported in the same message as the work it affected — cause, direction, and the cheapest correction — before or alongside delivering the change. Never deferred to this file, never batched for a later summary. If a gate regresses, that is stated even when the underlying change is good news otherwise.

**4. Re-baseline or mark stale.** Every row carries a measured-on date. On each check, a row either gets a fresh number or gets marked `STALE`. A stale row is worse than an absent one, because it looks authoritative. Never leave a row's number silently out of date, and never lower a baseline to make a regression disappear — a baseline moves only when the *direction of the codebase legitimately changed*, and then the reasoning goes in this file.

**5. Audit the list, not just the numbers.** Every ~10 sessions, ask: **what class of defect is not on this list at all?** A register that only measures what it already knows about is a mirror, not a check. The concrete precedent: `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` was marked "all resolved" while error handling had never been in its scope, so tripwire #1 had no owner for months. Closing a critique without asking it every question is a process tripwire (below), not a documentation detail.

---

## Baseline — measured 2026-09-27

| # | Tripwire | Baseline | Measured by | Worsening direction | Status |
|---|---|---|---|---|---|
| 1 | Unchecked `try?` on a save | **0** (was 274 / 71 files) | script + `testNoUncheckedTrySaveInSources` | any increase | **closed** |
| 2 | `try?` on `fetch` | **409** | script | — | **do not "fix"** — idiomatic |
| 3 | Build warnings (clean rebuild) | **424** (272 dead-code) | MANUAL — clean build | any increase | open, flat since 09-26 |
| 4 | Confirmed dead code | 2 files / ~154 LOC | MANUAL | any increase | open |
| 5 | UI share of codebase | **70%** (44,223 / 62,541 LOC) | script | rising | open, flat |
| 6 | MeCore test:LOC ratio | **0.66** (12,252 / 18,318) | script | falling | healthy |
| 7 | `@Model` count / migration files | **60 / 20** | script | a model added without a migration | open |
| 8 | `Migration.*` calls per launch | **103** (SeedRunner 88 + SeedData 15), all unconditional | script | growing | open, see `TODO.md` |
| 9 | New `@Model` properties that are non-optional | 0 | MANUAL — diff each new model | any occurrence | **hard stop** |
| 10 | Destructive / data-losing migrations | 0 | MANUAL — read each new migration | any occurrence | **hard stop** |

Rows 1, 5, 6 and the direction of 2 are gated by `scripts/quality-check.sh` (exit 1 on regression). Rows 7 and 8 are reported, not gated — a model count or a migration count is not itself a defect. Rows 3, 4, 9, 10 need judgement and are never automated.

## Escalation rules

- **Hard stop (#9, #10):** violates the "database is sacred" constraint. Do not perform; report immediately, even mid-task.
- **Warn before writing (any tripwire moving against us):** report the trend, the cause, and the cheapest correction. Then continue on functional work unless told otherwise.
- **Report on trend, not snapshot.** A good snapshot with a bad trajectory is the case that gets missed — the 2026-09-26 filter field is exactly that: metrics fine, *process* drifting (a feature shipped that was never asked for).

## Process tripwires — drift in how I work, not just in the code

- [ ] Shipping a feature the user did not request → say so first.
- [ ] View-layer code growing faster than `MeCore` → flag before adding.
- [ ] Closing a critique/audit document without having asked it every question. `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` was marked ✅ resolved while error handling had never been examined — that retirement was premature and is why #1 went unflagged for months.
- [ ] Rating the app from a snapshot without separating code quality from dataset fill rate (they are different projects; conflating them misleads the user).
- [ ] **Ending a session with commitments made only in conversation.** A follow-up list that lives in a chat and not in `TODO.md` will be forgotten, and re-deriving it costs the user a session. If I say "the other two are X and Y", they go in `TODO.md` before the session ends.

## Known limitations of this register

- Readings are point-in-time snapshots. A stale baseline is worse than none — re-baseline or mark stale (rule 4).
- 2026-09-26: tripwire #1 sat undetected through many sessions and was only found because the user asked a general question. Passive vigilance is demonstrably insufficient; the check has to be deliberate.
- 2026-09-27: #1 is now the only tripwire that **cannot regress silently** — it is a test, not a habit. That is the pattern the other nine should move toward. A number in a table only gets checked when someone remembers to check it; a script or a test gets checked because something breaks.
- 2026-09-27, scope correction: the TODO estimated Tier 1 (MeCore/Store) at "~40 sites". The measured figure was **119 across 26 files**, 94 of them in `Migration*.swift`. Estimates are not measurements — size work from the script, not from a prose estimate.
- **This register cannot see defects that have no metric.** Everything in the table is a quantity. The 2026-09-26 filter field passed every tripwire — the metrics were fine and the *process* had drifted. Rule 5 exists because of that case, and it is the weakest rule here: it depends on me choosing to ask the question, which is exactly the thing that failed.
