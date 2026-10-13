#!/usr/bin/env bash
# Archive, sign and (optionally) upload Dinner, Together to App Store Connect
# from a Mac with Xcode — on GitHub's macOS runners, no local Mac involved.
#
# Signing is Xcode "cloud signing": with an App Store Connect API key
# (Admin role) and -allowProvisioningUpdates, xcodebuild registers the App ID,
# creates a cloud-managed Apple Distribution certificate and the App Store
# provisioning profile itself. No .p12, no profile files in the repo.
#
#   bash release/build-release.sh <out-dir>
#
# Required environment:
#   ASC_KEY_ID        App Store Connect API key ID            (e.g. 2X9R4HXF34)
#   ASC_ISSUER_ID     API key issuer ID (UUID)
#   ASC_KEY_P8        the .p8 private key CONTENTS (multi-line)
#   APPLE_TEAM_ID     10-character Team ID
#   DT_BUNDLE_ID      bundle identifier registered to the app (e.g. com.yourname.dinnertogether)
#   DT_VERSION        CFBundleShortVersionString shown in the App Store (e.g. 1.0)
#   DT_BUILD          CFBundleVersion — must increase with every upload (e.g. the run number)
# Optional:
#   DT_SUBMIT=1       after exporting the .ipa, upload it to App Store Connect (TestFlight)
#
# Produces in <out-dir>: DinnerTogether.xcarchive, export/DinnerTogether.ipa,
# *.log, SUMMARY.md, status.txt (RELEASE_FAILURES=n). Exit 1 on any failure.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/release/out}"
mkdir -p "$OUT"
SUMMARY="$OUT/SUMMARY.md"; : > "$SUMMARY"
FAILURES=0
note() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
fail() { FAILURES=$((FAILURES+1)); note "- ❌ $*"; }
finish() {
  printf 'RELEASE_FAILURES=%s\n' "$FAILURES" > "$OUT/status.txt"
  if [ "$FAILURES" -eq 0 ]; then note ""; note "**Result: release steps passed.**"; exit 0
  else note ""; note "**Result: $FAILURES release step(s) failed.**"; exit 1; fi
}

note "# Release build — $(date -u '+%Y-%m-%d %H:%M UTC')"
note ""

# ------------------------------------------------------------- inputs
missing=()
for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 APPLE_TEAM_ID DT_BUNDLE_ID DT_VERSION DT_BUILD; do
  [ -n "${!v:-}" ] || missing+=("$v")
done
if [ "${#missing[@]}" -gt 0 ]; then
  fail "missing required settings: ${missing[*]} (repository secrets / workflow inputs)"
  finish
fi
case "$DT_BUNDLE_ID" in
  com.example.*) fail "DT_BUNDLE_ID is still the placeholder ($DT_BUNDLE_ID) — set the real identifier"; finish;;
esac
note "Version $DT_VERSION ($DT_BUILD) · bundle $DT_BUNDLE_ID · team $APPLE_TEAM_ID · submit=${DT_SUBMIT:-0}"
note ""

KEYDIR="$OUT/private_keys"; mkdir -p "$KEYDIR"; chmod 700 "$KEYDIR"
KEYFILE="$KEYDIR/AuthKey_$ASC_KEY_ID.p8"
# umask first: the redirect creates the file before chmod runs, so without
# this the key is briefly readable at the default mode.
( umask 077; printf '%s\n' "$ASC_KEY_P8" > "$KEYFILE" ); chmod 600 "$KEYFILE"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEYFILE"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")
cleanup() { rm -rf "$KEYDIR"; }
trap cleanup EXIT

# ------------------------------------------------------------- environment
{ sw_vers; xcodebuild -version; } > "$OUT/environment.txt" 2>&1 || true
note "## Environment"; note '```'; cat "$OUT/environment.txt" | tee -a "$SUMMARY" >/dev/null; note '```'; note ""

# ------------------------------------------------------------- archive
ARCHIVE="$OUT/DinnerTogether.xcarchive"
LOG="$OUT/10-archive.log"
note "## Archive (Release, generic iOS device, cloud signing)"
xcodebuild archive \
  -project "$ROOT/DinnerTogether.xcodeproj" -scheme DinnerTogether -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  "${AUTH[@]}" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  DT_APP_BUNDLE_ID="$DT_BUNDLE_ID" \
  MARKETING_VERSION="$DT_VERSION" \
  CURRENT_PROJECT_VERSION="$DT_BUILD" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  > "$LOG" 2>&1; rc=$?
# The archive is deliberately unsigned. Left to itself, an automatic-signing
# archive asks Apple for an *iOS App Development* profile, which the portal
# refuses to generate for a team with no registered devices ("Your team has no
# devices from which to generate a provisioning profile" — release run 2), and
# overriding the identity to Apple Distribution is rejected as a conflict with
# automatic signing (run 3). The export step below re-signs the archive with
# the cloud-managed Apple Distribution certificate and the App Store profile,
# which need no devices — and that signature is the only one that ships.
if [ $rc -eq 0 ] && [ -d "$ARCHIVE/Products/Applications/DinnerTogether.app" ]; then
  note "- ✅ xcodebuild archive (exit 0) — \`$(basename "$LOG")\`"
else
  fail "xcodebuild archive failed (exit $rc) — \`$(basename "$LOG")\`"
  grep -E 'error:|error ' "$LOG" | head -20 | sed 's/^/    /' | tee -a "$SUMMARY"
  finish
fi
# What did we actually sign? Record it so nobody has to trust the inputs.
PLIST="$ARCHIVE/Products/Applications/DinnerTogether.app/Info.plist"
if command -v plutil >/dev/null 2>&1 && [ -f "$PLIST" ]; then
  for k in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion; do
    v=$(plutil -extract "$k" raw -o - "$PLIST" 2>/dev/null || echo '?')
    note "  - $k = $v"
    case "$k:$v" in
      CFBundleIdentifier:"$DT_BUNDLE_ID"|CFBundleShortVersionString:"$DT_VERSION"|CFBundleVersion:"$DT_BUILD") ;;
      *) fail "archived $k is '$v', expected the requested value";;
    esac
  done
  # The export-compliance declaration must survive Xcode's Info.plist
  # synthesis: if INFOPLIST_KEY_ITSAppUsesNonExemptEncryption were silently
  # dropped from the generated plist, every TestFlight build would stall at
  # "Missing Compliance" until someone clears it by hand.
  enc=$(/usr/libexec/PlistBuddy -c "Print :ITSAppUsesNonExemptEncryption" "$PLIST" 2>/dev/null || echo MISSING)
  note "  - ITSAppUsesNonExemptEncryption = $enc"
  [ "$enc" = "false" ] || fail "archived ITSAppUsesNonExemptEncryption is '$enc', want 'false' — expect per-upload compliance clearing"
fi
note ""

# ------------------------------------------------------------- export (.ipa kept as an artifact)
export_with() { # destination label log
  local destination="$1" label="$2" log="$3"
  local plist="$OUT/ExportOptions-$label.plist"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>$destination</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>$APPLE_TEAM_ID</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$plist" \
    -exportPath "$OUT/$label" "${AUTH[@]}" > "$log" 2>&1
}

note "## Export (.ipa)"
LOG="$OUT/20-export.log"
if export_with export export "$LOG" && IPA=$(find "$OUT/export" -name '*.ipa' | head -1) && [ -n "$IPA" ]; then
  note "- ✅ exported \`$(basename "$IPA")\` ($(du -h "$IPA" | cut -f1)) — \`$(basename "$LOG")\`"
else
  fail "export failed — \`$(basename "$LOG")\`"
  grep -E 'error:|error ' "$LOG" | head -20 | sed 's/^/    /' | tee -a "$SUMMARY"
  finish
fi
note ""

# ------------------------------------------------------------- upload (TestFlight / App Store Connect)
note "## Upload to App Store Connect"
if [ "${DT_SUBMIT:-0}" = "1" ]; then
  LOG="$OUT/30-upload.log"
  if export_with upload upload "$LOG"; then
    note "- ✅ uploaded build $DT_VERSION ($DT_BUILD) to App Store Connect — it appears in TestFlight after Apple's processing (usually 5–30 min) — \`$(basename "$LOG")\`"
  else
    fail "upload failed — \`$(basename "$LOG")\` (most common: no App Store Connect app record exists yet for $DT_BUNDLE_ID — create it under My Apps first; or a build with CFBundleVersion $DT_BUILD was already uploaded)"
    grep -E 'error:|error |Error' "$LOG" | head -20 | sed 's/^/    /' | tee -a "$SUMMARY"
  fi
else
  note "- ⏭ not requested (DT_SUBMIT=0): the .ipa is in the artifact; rerun with submit=true to upload"
fi
finish
