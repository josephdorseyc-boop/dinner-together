# Running the native tests without Xcode

`Package.swift` at the project root is a Swift Package Manager harness. It
compiles the **real** `Models.swift`, `Scheduling.swift`, `DinnerCatalog.swift`
and `SessionStore.swift` (no copies) together with the **real**
`DinnerTogetherTests/DinnerTogetherTests.swift`, and runs all 61 XCTest
methods in 12 classes. That is actual Swift execution of the engine and the
store — a step the JavaScript model cannot provide.

**Executed:** Agent 1 ran this harness on r4 (59/59, after the two Linux
fixes now included as A1-1/A1-2) and on the pristine r6 tree: **61/61, 0
failures, all 12 classes, first try** (Swift 6.0.3, Ubuntu 24.04). That is
the complete current suite.

What it does not cover: the SwiftUI views (`CookingView`, `Sheets`,
`PlanView`, `ContentView`, `Theme`), `TimerCenter`, and the real
`NotificationManager` (UserNotifications). Those still need Xcode and a
device or simulator.

## Run it

macOS with Xcode 16 command-line tools (or any Swift 6.0+ toolchain):

```
cd DinnerTogether-RecoveryCandidate-v028
swift test
swift test --filter RecoveryNoticeTests     # one class
swift test --filter RecoveryStoreTests
```

Linux, or any machine with Docker:

```
cd DinnerTogether-RecoveryCandidate-v028
docker run --rm -v "$PWD":/src -w /src swift:6.0 swift test
```

A `.build/` directory appears next to the project; delete it freely. Keep
opening `DinnerTogether.xcodeproj` as before — Xcode ignores `Package.swift`.

## How it stays honest

- No source is duplicated. The package's `sources:` list points at the app's
  own files, so what runs is what ships.
- `DinnerTogether/EngineTestSupport.swift` replaces `Notifications.swift`
  inside the harness only: the `NotificationService` protocol is copied
  verbatim and `NotificationManager` is inert. Every test injects
  `MockNotifications`, so the real manager is never constructed in tests on
  any platform. **Do not add this file to the Xcode target** (it would
  collide with `Notifications.swift`).
- On Linux only, `EngineSupport/SwiftUIShim` provides a module named
  `SwiftUI` containing just `ObservableObject` and `@Published`, so
  `SessionStore.swift`'s `import SwiftUI` resolves. On macOS the real
  framework is used.

## First-run watch items (written on Linux without a toolchain; unexecuted)

1. **Swift 6.0+ required.** On Linux, `URL.documentsDirectory` does not exist
   even in Swift 6.0.3 (confirmed by Agent 1); `EngineTestSupport.swift`
   provides a Linux-only stand-in that tests never evaluate. If a future
   toolchain adds the real member, delete the stand-in.
2. **`@MainActor` test classes on Linux.** Linux test discovery generates
   synchronous thunks, so every test method that touches the `@MainActor`
   store must be `async` (confirmed by Agent 1; all are, since r6). A new
   synchronous store test will fail to compile on Linux — make it `async`.
3. **Target named `SwiftUI` (Linux only).** If SwiftPM refuses the module
   name, rename the shim target and add `import SwiftUI`→shim mapping via
   `-Xswiftc -module-alias SwiftUI=SwiftUIShim` instead. Not expected.
4. **Timing-sensitive tests.** `testNoStaleReminderAfter*DuringPendingAuth`
   and `testIndependentStartsKeepBothReminders` use real sleeps
   (0.02–0.3 s); on a slow CI runner they could flake. They are the
   baseline's tests, unchanged.
5. **Locale.** `Scheduling.formatTime` uses the short time style; the tests
   only check step titles and phrases ("late to start", "check the food"),
   never formatted times, so locale differences shouldn't matter.

Record the toolchain (`swift --version`), platform, and the per-class pass
or fail list in `RECOVERY_HANDOFF.md` §3 when this has run.
