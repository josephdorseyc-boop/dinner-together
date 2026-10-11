# Release build — 2026-10-11 23:38 UTC

Version 1.0 (4) · bundle com.josephdorsey.dinnertogether · team V37QFJ2Q53 · submit=1

## Environment
```
ProductName:		macOS
ProductVersion:		15.7.9
BuildVersion:		24G830
Xcode 16.4
Build version 16F6
```

## Archive (Release, generic iOS device, cloud signing)
- ✅ xcodebuild archive (exit 0) — `10-archive.log`
  - CFBundleIdentifier = com.josephdorsey.dinnertogether
  - CFBundleShortVersionString = 1.0
  - CFBundleVersion = 4
  - ITSAppUsesNonExemptEncryption = false

## Export (.ipa)
- ✅ exported `DinnerTogether.ipa` (696K) — `20-export.log`

## Upload to App Store Connect
- ❌ upload failed — `30-upload.log` (most common: no App Store Connect app record exists yet for com.josephdorsey.dinnertogether — create it under My Apps first; or a build with CFBundleVersion 4 was already uploaded)
    error: exportArchive Validation failed. SDK version issue. This app was built with the iOS 18.5 SDK. All iOS and iPadOS apps must be built with the iOS 26 SDK or later, included in Xcode 26 or later, in order to be uploaded to App Store Connect or submitted for distribution. (ID: 9b8e5bfb-2c09-4e5a-ad16-361e3e9c0e50).

**Result: 1 release step(s) failed.**
