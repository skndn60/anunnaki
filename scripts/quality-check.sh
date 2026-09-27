#!/bin/bash
# Quality tripwire check — the measurement behind docs/QUALITY_RISKS.md.
#
# Every number in the register's baseline table that *can* be measured is measured
# here, so a baseline is never recalled from memory. Run it at the start of a
# session and paste the output into the register when a row is re-baselined.
#
#   ./scripts/quality-check.sh          report, exit 1 if a gate regressed
#   ./scripts/quality-check.sh --quiet  report only hard-gate rows
#
# Rows marked MANUAL cannot be decided by a text scan and need a human/agent
# judgement each time they are checked: a grep cannot tell an additive migration
# from a destructive one.

set -uo pipefail
cd "$(dirname "$0")/.."

# Tripwire number -> baseline. Update alongside docs/QUALITY_RISKS.md.
MAX_UNCHECKED_SAVES=0          # #1  hard gate: enforced by a test too
MAX_WARNINGS=424               # #3  MANUAL to measure (clean build)
MAX_UI_SHARE_PCT=72            # #5  Sources/Me as % of Sources
MIN_TEST_LOC_RATIO=60          # #6  Tests/MeCoreTests LOC per 100 MeCore LOC
BASELINE_MIGRATION_FILES=20    # #7
BASELINE_MIGRATION_CALLS=103   # #8  SeedRunner 88 + SeedData 15

fail=0
row() { printf '  %-4s %-34s %10s   %s\n' "$1" "$2" "$3" "$4"; }
check() { # name current baseline direction -> prints row, sets fail on regression
  local name="$1" cur="$2" base="$3" dir="$4" verdict="ok"
  if [ "$dir" = "max" ] && [ "$cur" -gt "$base" ]; then verdict="REGRESSED"; fail=1
  elif [ "$dir" = "min" ] && [ "$cur" -lt "$base" ]; then verdict="REGRESSED"; fail=1
  fi
  row "$5" "$name" "$cur" "base $base / $dir — $verdict"
}

loc() { find "$1" -name '*.swift' -exec cat {} + | wc -l | tr -d ' '; }

echo "Quality tripwires — measured $(date +%Y-%m-%d)"
echo
echo "  #    tripwire                          current   note"

# 1 — the silent-save defect class. Also enforced by
# MeCoreTests.testNoUncheckedTrySaveInSources, so a regression fails `swift test`.
unchecked=$(grep -rEc 'try\?[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*\.[[:space:]]*save[[:space:]]*\(' \
  --include='*.swift' Sources 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
check "unchecked try? saves" "$unchecked" "$MAX_UNCHECKED_SAVES" max "#1"
row "#1b" "  (test-enforced, not script-gated)" "-" "MeCoreTests.testNoUncheckedTrySaveInSources"

# 2 — informational only. `?? []` degradation on a read is correct; this row
# exists so a drop is noticed, and must never be "fixed".
fetches=$(grep -roE 'try\?[^;]*\.fetch\(' --include='*.swift' Sources 2>/dev/null | wc -l | tr -d ' ')
row "#2" "try? on fetch (idiomatic)" "$fetches" "base 409 — do NOT fix"

# 5 — UI share of the codebase.
me=$(loc Sources/Me); total=$(loc Sources)
share=$(( me * 100 / total ))
check "UI share of Sources (%)" "$share" "$MAX_UI_SHARE_PCT" max "#5"

# 6 — test density in MeCore, as tests-LOC per 100 MeCore-LOC.
core=$(loc Sources/MeCore); tests=$(loc Tests/MeCoreTests)
ratio=$(( tests * 100 / core ))
check "MeCore test LOC per 100 LOC" "$ratio" "$MIN_TEST_LOC_RATIO" min "#6"

# 7 — @Model declarations. The risk is a model added without a migration, not
# the raw count, so this row is reported, not gated.
models=$(awk '/@Model/{getline; if ($0 ~ /class [A-Z]/) n++} END {print n+0}' $(find Sources -name '*.swift'))
migfiles=$(ls Sources/MeCore/Store/Migration*.swift 2>/dev/null | wc -l | tr -d ' ')
row "#7" "@Model classes / migration files" "$models / $migfiles" "base $BASELINE_MIGRATION_FILES files — report only"

# 8 — unconditional work on every launch.
runner=$(grep -cE '^[[:space:]]+Migration\.[a-zA-Z]+\(context' Sources/Me/Views/SeedRunner.swift)
seeddata=$(grep -cE 'Migration\.[a-zA-Z]+\(context' Sources/MeCore/Store/SeedData.swift)
calls=$(( runner + seeddata ))
row "#8" "Migration.* calls per launch" "$calls" "base $BASELINE_MIGRATION_CALLS (SeedRunner $runner + SeedData $seeddata) — report only"

echo
echo "  #    MANUAL — needs judgement, not a text scan"
row "#3" "build warnings (clean rebuild)" "-" "base 424 — measure with a clean build"
row "#4" "confirmed dead code" "-" "base 2 files / ~154 LOC"
row "#9" "non-optional new @Model props" "-" "base 0 — HARD STOP, diff each new model"
row "#10" "destructive / data-losing migrations" "-" "base 0 — HARD STOP, read each new migration"

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: a gate regressed. Report it in-session before continuing (see QUALITY_RISKS.md)."
  exit 1
fi
echo "RESULT: no gate regressed. Report any movement in the register's rows to the user in-session —"
echo "        a finding that only exists in this file has not been delivered."
