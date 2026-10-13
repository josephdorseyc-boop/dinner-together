// swift-tools-version:5.9
//
// Engine + store test harness — lets `swift test` run the real scheduling
// engine, the session store, and the canonical XCTest file WITHOUT Xcode:
//
//   macOS (Xcode 16 command-line tools or later):  swift test
//   Linux / Docker:  docker run --rm -v "$PWD":/src -w /src swift:6.0 swift test
//
// This does not replace the Xcode project. Keep opening
// DinnerTogether.xcodeproj as before; Xcode ignores this file. What the
// harness compiles is exactly the app's Models.swift, Scheduling.swift,
// DinnerCatalog.swift, SessionStore.swift, RecipeImporter.swift and
// RecipeLibrary.swift (no copies), plus every file in DinnerTogetherTests/. The SwiftUI views,
// TimerCenter and the UserNotifications-backed NotificationManager are not
// compiled here; they stay Xcode-only. See ENGINE_TESTS.md.
//
// Written on Linux without a Swift toolchain available — see ENGINE_TESTS.md
// for the specific things to check the first time it runs.
import PackageDescription

#if os(Linux)
// SessionStore.swift says `import SwiftUI` for ObservableObject/@Published.
// On Linux a two-type stand-in module provides just those.
let shimTargets: [Target] = [
    .target(name: "SwiftUI", path: "EngineSupport/SwiftUIShim"),
]
let engineDependencies: [Target.Dependency] = ["SwiftUI"]
#else
let shimTargets: [Target] = []
let engineDependencies: [Target.Dependency] = []
#endif

let package = Package(
    name: "DinnerTogetherEngine",
    platforms: [.macOS(.v13), .iOS(.v17)],
    targets: shimTargets + [
        .target(
            name: "DinnerTogether",
            dependencies: engineDependencies,
            path: "DinnerTogether",
            // Explicit list: only the engine and store, never the views.
            // EngineTestSupport.swift stands in for Notifications.swift
            // (protocol copied verbatim; inert manager). It is NOT in the
            // Xcode target.
            sources: [
                "Models.swift",
                "Scheduling.swift",
                "DinnerCatalog.swift",
                "SessionStore.swift",
                "RecipeImporter.swift",
                "RecipeLibrary.swift",
                "RecipePalette.swift",
                "SocialImport.swift",
                "EngineTestSupport.swift",
            ]
        ),
        .testTarget(
            name: "DinnerTogetherTests",
            dependencies: ["DinnerTogether"],
            path: "DinnerTogetherTests"
        ),
    ]
)
