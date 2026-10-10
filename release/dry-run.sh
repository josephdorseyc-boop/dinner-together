#!/usr/bin/env bash
# Proves release/build-release.sh's control flow against the fake toolchain:
# it refuses to run without its inputs, fails loudly on archive/export/upload
# errors, and only reports success when an .ipa exists. No Swift, no Apple
# account — this says nothing about signing itself.
#
#   bash release/dry-run.sh          # expect: all 6 scenarios OK
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
FAKE="$ROOT/native-validation/dry-run/faketools"
WORK="${TMPDIR:-/tmp}/dinner-release-dry-run-$$"; mkdir -p "$WORK"
chmod +x "$FAKE"/*
bad=0
good_env=(ASC_KEY_ID=FAKEKEYID ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000 ASC_KEY_P8="-----BEGIN PRIVATE KEY-----
fake
-----END PRIVATE KEY-----" APPLE_TEAM_ID=ABCDE12345 DT_BUNDLE_ID=com.fake.dinnertogether DT_VERSION=1.0 DT_BUILD=7)
run_case() { # name expect_rc expect_failures expect_ipa env...
  local name="$1" e_rc="$2" e_fail="$3" e_ipa="$4"; shift 4
  local R="$WORK/$name"; rm -rf "$R"; mkdir -p "$R"
  ( export PATH="$FAKE:$PATH"; env "$@" bash "$ROOT/release/build-release.sh" "$R" >/dev/null 2>&1; echo $? > "$R/rc" )
  local rc failures ipa keys
  rc=$(cat "$R/rc"); failures=$(sed -n 's/^RELEASE_FAILURES=//p' "$R/status.txt" 2>/dev/null | head -1)
  ipa=$(find "$R/export" -name '*.ipa' 2>/dev/null | wc -l | tr -d ' ')
  keys=$(find "$R" -name 'AuthKey_*.p8' 2>/dev/null | wc -l | tr -d ' ')
  local got="rc=$rc failures=${failures:-?} ipa=$ipa keyfiles-left=$keys"
  local want="rc=$e_rc failures=$e_fail ipa=$e_ipa keyfiles-left=0"
  if [ "$got" = "$want" ]; then printf 'OK   %-18s %s\n' "$name" "$got"; else printf 'FAIL %-18s got: %s\n%-23s want: %s\n' "$name" "$got" "" "$want"; bad=$((bad+1)); fi
}
#        name             rc fail ipa env
run_case build-only        0  0    1   "${good_env[@]}" DT_SUBMIT=0
run_case build-and-upload  0  0    1   "${good_env[@]}" DT_SUBMIT=1
run_case missing-secrets   1  1    0   DT_VERSION=1.0 DT_BUILD=7
run_case placeholder-id    1  1    0   "${good_env[@]}" DT_BUNDLE_ID=com.example.dinnertogether
run_case archive-fails     1  1    0   "${good_env[@]}" FAKE_ARCHIVE_RC=65
run_case upload-fails      1  1    1   "${good_env[@]}" DT_SUBMIT=1 FAKE_UPLOAD_RC=70
rm -rf "$WORK"
if [ "$bad" -eq 0 ]; then echo "PASS: 6 release dry-run scenarios (fake toolchain; no signing exercised)."; else echo "FAIL: $bad scenario(s)"; exit 1; fi
