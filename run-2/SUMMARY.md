# Release build — 2026-10-11 23:34 UTC

Version 1.0 (2) · bundle com.josephdorsey.dinnertogether · team V37QFJ2Q53 · submit=1

## Environment
```
ProductName:		macOS
ProductVersion:		15.7.9
BuildVersion:		24G830
Xcode 16.4
Build version 16F6
```

## Archive (Release, generic iOS device, cloud signing)
- ❌ xcodebuild archive failed (exit 65) — `10-archive.log`
    /Users/runner/work/dinner-together/dinner-together/DinnerTogether.xcodeproj: error: Communication with Apple failed: Your team has no devices from which to generate a provisioning profile. Connect a device to use or manually add device IDs in Certificates, Identifiers & Profiles. https://developer.apple.com/account/ (in target 'DinnerTogether' from project 'DinnerTogether')
    /Users/runner/work/dinner-together/dinner-together/DinnerTogether.xcodeproj: error: No profiles for 'com.josephdorsey.dinnertogether' were found: Xcode couldn't find any iOS App Development provisioning profiles matching 'com.josephdorsey.dinnertogether'. (in target 'DinnerTogether' from project 'DinnerTogether')

**Result: 1 release step(s) failed.**
