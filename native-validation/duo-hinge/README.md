# duo-hinge (vendored, test infrastructure only)

Opens or closes the **iPhone Duo simulator's** hinge from the Mac, the way
Device Hub's pose buttons do. Xcode 27.1 has no `simctl`/XCTest command for this,
and rotating (`XCUIDevice`, `devicectl … orientation`) does nothing for the
inner display.

- Source: https://github.com/tosbaha/duo-fold-control, `tools/duo-hinge.m`
  at commit `6207cc8` (2026-10-10). Copied verbatim. MIT, see `LICENSE`.
  A1 found it (issue #15, October 15). A3 read the whole file before vendoring
  it: it looks up the booted simulator through CoreSimulator, opens the
  simulator's HID XPC service, and sends one hinge-angle event. It makes no
  network calls, writes no files, and reads only `DEVELOPER_DIR`.
- Uses **private SPI** (CoreSimulator `SimDevice lookup:error:`, libxpc
  `*_4sim`). An Xcode or simulator runtime update can break it. It runs on the
  CI Mac only and is never part of the app.
- Built and run by `run-native-pass.sh` when `DT_DUO_HINGE` is set
  (`closed` 0° cover display 466 × 678 · `half` 130° · `flat` 180° inner
  display, app window 951 × 669 per the tool's author):

  ```
  clang -fobjc-arc -framework Foundation -o build/duo-hinge native-validation/duo-hinge/duo-hinge.m
  build/duo-hinge -d <UDID> flat
  xcrun simctl io <UDID> screenshot --display=3 inner.png   # the inner screen
  ```

The state stays across app launches until the simulator is rebooted or the
hinge is set again.
