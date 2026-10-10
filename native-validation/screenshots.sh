#!/usr/bin/env bash
# Simulator screenshots of the cooking screen in seeded recovery states.
# Needs the app built by run-native-pass.sh (reads <results>/devices.env).
#
#   bash native-validation/screenshots.sh [results-dir]
#
# For each scenario × device × appearance it: writes the seeded session into
# the app's Documents, launches with the DEBUG launch options
# (-dt-open-cooking -dt-inert-reminders), confirms the app is still running,
# and captures a PNG into <results>/screenshots/<device>/<scenario>-<appearance>.png.
# Static states only — no taps (the review sheet needs a UI test; see README).
#
# Exit status is non-zero when the required set could not be produced: no app
# build, no simulator, install failure, app not running at capture time, or
# fewer screenshots than expected. It appends to SUMMARY.md and status.txt.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="${1:-$ROOT/native-validation/results}"
BUNDLE="com.example.dinnertogether"
SETTLE="${SHOT_SETTLE_SECONDS:-4}"   # seconds to let the screen settle after launch
SHOTS="$RESULTS/screenshots"
SEEDS="$RESULTS/seeds"
LOG="$RESULTS/40-screenshots.log"
SUMMARY="$RESULTS/SUMMARY.md"
STATUS="$RESULTS/status.txt"
mkdir -p "$SHOTS" "$SEEDS"
: > "$LOG"
FAILURES=0
say()  { printf '%s\n' "$*" | tee -a "$LOG"; }
fail() { say "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
finish() {
  local count
  count=$(find "$SHOTS" -name '*.png' -size +0 2>/dev/null | wc -l | tr -d ' ')
  {
    echo ""
    echo "## Screenshots (required: $EXPECTED_SHOTS, got $count)"
    if [ "$FAILURES" -eq 0 ] && [ "$count" -ge "$EXPECTED_SHOTS" ]; then
      echo "- ✅ $count PNG(s) under \`screenshots/\` — expectations per scenario in \`screenshots/EXPECTATIONS.tsv\`"
    else
      echo "- ❌ screenshot pass incomplete: $FAILURES failure(s), $count of $EXPECTED_SHOTS required PNG(s). See \`40-screenshots.log\`."
      grep '^FAIL:' "$LOG" | head -20 | sed 's/^/  - /'
    fi
    find "$SHOTS" -name '*.png' | sed "s|$SHOTS/|  - |" | sort
  } >> "$SUMMARY"
  local prior=0
  [ -f "$STATUS" ] && prior=$(sed -n 's/^REQUIRED_FAILURES=//p' "$STATUS" | head -1)
  local add=0; { [ "$FAILURES" -gt 0 ] || [ "$count" -lt "$EXPECTED_SHOTS" ]; } && add=1
  printf 'REQUIRED_FAILURES=%s\nSCREENSHOT_FAILURES=%s\nSCREENSHOTS=%s\nSCREENSHOTS_EXPECTED=%s\n' \
    "$(( ${prior:-0} + add ))" "$FAILURES" "$count" "$EXPECTED_SHOTS" > "$STATUS"
  say "done: $count screenshots, $FAILURES failures"
  [ "$add" -eq 0 ]
}

# shellcheck disable=SC1091
[ -f "$RESULTS/devices.env" ] && source "$RESULTS/devices.env"

# Seeds are regenerated right before each launch so relative times hold.
seed_names() { python3 "$ROOT/native-validation/seed-sessions.py" "$SEEDS" | cut -f1; }
SCENARIOS=()   # bash 3.2-compatible (macOS /bin/bash): no mapfile
while IFS= read -r line; do SCENARIOS+=("$line"); done < <(seed_names)
python3 "$ROOT/native-validation/seed-sessions.py" "$SEEDS" > "$SHOTS/EXPECTATIONS.tsv"
[ "${#SCENARIOS[@]}" -gt 0 ] || { fail "seed-sessions.py produced no scenarios"; EXPECTED_SHOTS=1; finish; exit $?; }

DEVICES=0
[ -n "${IPHONE_UDID:-}" ] && DEVICES=$((DEVICES + 1))
[ -n "${IPAD_UDID:-}" ]   && DEVICES=$((DEVICES + 1))
# Required set: every scenario in light and dark on every present device
# (large-text shots are a bonus and not counted). Two devices are required.
EXPECTED_SHOTS=$(( ${#SCENARIOS[@]} * 2 * 2 ))
[ "$DEVICES" -eq 2 ] || fail "expected an iPhone and an iPad simulator, found $DEVICES (devices.env)"

if [ -z "${APP_PATH:-}" ] || [ ! -d "${APP_PATH:-/nonexistent}" ]; then
  fail "no simulator app build (APP_PATH); run run-native-pass.sh first"
  finish; exit $?
fi

app_running() { # udid → 0 if the app process is alive in the simulator
  local list
  list=$(xcrun simctl spawn "$1" launchctl list 2>/dev/null) || return 0   # can't tell: don't judge
  printf '%s' "$list" | grep -q 'UIKitApplication:' || return 0          # unknown format: don't judge
  printf '%s' "$list" | grep -q "UIKitApplication:$BUNDLE"
}

launch_args_for() { # scenario → launch arguments
  # "tonight-*" scenarios photograph the planning screen; everything else
  # opens straight on Cooking.
  case "$1" in tonight-*) printf '%s' "-dt-inert-reminders";; *) printf '%s' "-dt-open-cooking -dt-inert-reminders";; esac
}

capture() { # udid out.png label [scenario]
  local udid="$1" out="$2" label="$3" scenario="${4:-}"
  local args; args=$(launch_args_for "$scenario")
  # shellcheck disable=SC2086
  xcrun simctl launch "$udid" "$BUNDLE" $args >> "$LOG" 2>&1 \
    || { fail "$label: launch failed"; return; }
  sleep "$SETTLE"
  if ! app_running "$udid"; then fail "$label: app is not running ${SETTLE}s after launch (crash?)"; return; fi
  if xcrun simctl io "$udid" screenshot "$out" >> "$LOG" 2>&1 && [ -s "$out" ]; then
    say "shot ${out#$SHOTS/}"
  else
    fail "$label: screenshot not written"
  fi
  xcrun simctl terminate "$udid" "$BUNDLE" >> "$LOG" 2>&1 || true
}

shoot_device() { # label udid
  local label="$1" udid="$2"
  [ -n "$udid" ] || { fail "$label: no simulator"; return; }
  local dir="$SHOTS/$label"; mkdir -p "$dir"
  say "== $label ($udid)"
  xcrun simctl boot "$udid" >> "$LOG" 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >> "$LOG" 2>&1 || true
  xcrun simctl install "$udid" "$APP_PATH" >> "$LOG" 2>&1 || { fail "$label: install failed"; return; }
  # Launch once so the data container exists, then stop it.
  xcrun simctl launch "$udid" "$BUNDLE" -dt-inert-reminders >> "$LOG" 2>&1 || true
  sleep "$SETTLE"
  xcrun simctl terminate "$udid" "$BUNDLE" >> "$LOG" 2>&1 || true
  local container
  container="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data 2>>"$LOG" || true)"
  [ -n "$container" ] || { fail "$label: no data container"; return; }
  mkdir -p "$container/Documents"

  for appearance in light dark; do
    if ! xcrun simctl ui "$udid" appearance "$appearance" >> "$LOG" 2>&1; then
      fail "$label: could not set required $appearance appearance"
      continue
    fi
    for scenario in "${SCENARIOS[@]}"; do
      python3 "$ROOT/native-validation/seed-sessions.py" "$SEEDS" > /dev/null   # fresh "now"
      cp "$SEEDS/$scenario.json" "$container/Documents/dinner-together-v2.json"
      capture "$udid" "$dir/$scenario-$appearance.png" "$label/$scenario-$appearance" "$scenario"
    done
  done

  # Bonus: one large-text pass in light mode (Dynamic Type accessibility size).
  if xcrun simctl ui "$udid" content_size accessibility-large >> "$LOG" 2>&1; then
    xcrun simctl ui "$udid" appearance light >> "$LOG" 2>&1 || true
    for scenario in late-prep expired-timer; do
      python3 "$ROOT/native-validation/seed-sessions.py" "$SEEDS" > /dev/null
      cp "$SEEDS/$scenario.json" "$container/Documents/dinner-together-v2.json"
      local before=$FAILURES
      capture "$udid" "$dir/$scenario-ax-large-text.png" "$label/$scenario-ax-large-text (bonus)" "$scenario"
      FAILURES=$before   # bonus shots never count as required failures
    done
    xcrun simctl ui "$udid" content_size large >> "$LOG" 2>&1 || true
  else
    say "$label: content_size not supported by this simctl; skipped large-text pass (bonus)"
  fi
  xcrun simctl shutdown "$udid" >> "$LOG" 2>&1 || true
}

shoot_device iphone "${IPHONE_UDID:-}"
shoot_device ipad   "${IPAD_UDID:-}"
finish
