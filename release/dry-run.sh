#!/usr/bin/env bash
# Proves release/build-release.sh's control flow against the fake toolchain:
# it refuses to run without its inputs, fails loudly on archive/export/upload
# errors, and only reports success when an .ipa exists. No Swift, no Apple
# account — this says nothing about signing itself.
#
#   bash release/dry-run.sh          # expect: all 7 scenarios OK
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="${TMPDIR:-/tmp}/dinner-release-dry-run-$$"; mkdir -p "$WORK"
FAKE="$WORK/faketools"; mkdir -p "$FAKE"
cp "$ROOT/native-validation/dry-run/faketools/"* "$FAKE/"
# The metadata-failure fixture below exists only for that scenario. Other
# fake archives still have no plist, as before. Supply predictable values
# without depending on the host having Apple's plutil installed.
cat > "$FAKE/plutil" <<'PLUTIL'
#!/usr/bin/env bash
case "$2" in
  CFBundleIdentifier) printf '%s\n' "$DT_BUNDLE_ID";;
  CFBundleShortVersionString) printf '%s\n' '0.9';;
  CFBundleVersion) printf '%s\n' "$DT_BUILD";;
  *) exit 1;;
esac
PLUTIL
chmod +x "$FAKE"/*
bad=0
good_env=(ASC_KEY_ID=FAKEKEYID ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000 ASC_KEY_P8="-----BEGIN PRIVATE KEY-----
fake
-----END PRIVATE KEY-----" APPLE_TEAM_ID=ABCDE12345 DT_BUNDLE_ID=com.fake.dinnertogether DT_VERSION=1.0 DT_BUILD=7)
run_case() { # name expect_rc expect_failures expect_ipa env...
  local name="$1" e_rc="$2" e_fail="$3" e_ipa="$4"; shift 4
  local R="$WORK/$name"; rm -rf "$R"; mkdir -p "$R"
  if [ "$name" = "metadata-fails" ]; then
    mkdir -p "$R/DinnerTogether.xcarchive/Products/Applications/DinnerTogether.app"
    # A wrong version plus an omitted compliance declaration exercise both
    # metadata failures; the missing declaration also works on Linux hosts
    # without PlistBuddy. The fake archive preserves this fixture.
    cat > "$R/DinnerTogether.xcarchive/Products/Applications/DinnerTogether.app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>0.9</string></dict></plist>
PLIST
  fi
  ( export PATH="$FAKE:$PATH"; env "$@" bash "$ROOT/release/build-release.sh" "$R" >/dev/null 2>&1; echo $? > "$R/rc" )
  local rc failures ipa keys
  rc=$(cat "$R/rc"); failures=$(sed -n 's/^RELEASE_FAILURES=//p' "$R/status.txt" 2>/dev/null | head -1)
  ipa=$(find "$R/export" -name '*.ipa' 2>/dev/null | wc -l | tr -d ' ')
  keys=$(find "$R" -name 'AuthKey_*.p8' 2>/dev/null | wc -l | tr -d ' ')
  local got="rc=$rc failures=${failures:-?} ipa=$ipa keyfiles-left=$keys"
  local want="rc=$e_rc failures=$e_fail ipa=$e_ipa keyfiles-left=0"
  if [ "$got" = "$want" ]; then printf 'OK   %-18s %s\n' "$name" "$got"; else printf 'FAIL %-18s got: %s\n%-23s want: %s\n' "$name" "$got" "" "$want"; bad=$((bad+1)); fi
  if [ "$name" = "metadata-fails" ]; then
    if grep -q "archived CFBundleShortVersionString is '0.9'" "$R/SUMMARY.md" &&
       [ ! -e "$R/20-export.log" ] && [ ! -e "$R/30-upload.log" ]; then
      echo "OK   metadata guard: wrong version reported; export and upload never attempted"
    else
      echo "FAIL metadata guard: expected wrong version and no export/upload attempts"; bad=$((bad+1))
    fi
  fi
}
#        name             rc fail ipa env
run_case build-only        0  0    1   "${good_env[@]}" DT_SUBMIT=0
run_case build-and-upload  0  0    1   "${good_env[@]}" DT_SUBMIT=1
run_case missing-secrets   1  1    0   DT_VERSION=1.0 DT_BUILD=7
run_case placeholder-id    1  1    0   "${good_env[@]}" DT_BUNDLE_ID=com.example.dinnertogether
run_case archive-fails     1  1    0   "${good_env[@]}" FAKE_ARCHIVE_RC=65
run_case upload-fails      1  1    1   "${good_env[@]}" DT_SUBMIT=1 FAKE_UPLOAD_RC=70
run_case metadata-fails    1  2    0   "${good_env[@]}" DT_SUBMIT=1
rm -rf "$WORK"
if [ "$bad" -eq 0 ]; then echo "PASS: 7 release dry-run scenarios (fake toolchain; no signing exercised)."; else echo "FAIL: $bad scenario(s)"; exit 1; fi
