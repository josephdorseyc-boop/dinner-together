# A2 assistance for A1 persistence tests

Baseline: PR #2, `a1/duration-persistence-tests`
`9e56fe6385c3852dbb406bf4b2fe65c2e3631606`.
Prepared October 12, 2026. The source/test change is supplied as a separate patch
for the owning agents; this PR changes only handoff files.

## Fix 1 - Linux XCTest discovery

**Observed CI log:** native-validation run 44's Linux job fails at generated
test discovery with a call to each main-actor-isolated test in a synchronous
nonisolated context. Changing temporary-directory interpolation did not address
that error. The three persistence methods remain synchronous `throws`.

The patch marks those methods `async throws`, retaining `@MainActor` and every
existing outcome assertion. This follows the working RecipeLibraryTests pattern
already used in the same suite. No concurrency or storage implementation changes.

## Fix 2 - Xcode target membership

**Source review:** PR #2 adds a file under DinnerTogetherTests, but its project
still explicitly lists A201-A205 and B201-B205. DurationPersistenceTests.swift
has no reference or Sources entry. SwiftPM will discover it; Xcode will not.

The patch adds A206/B206, group membership and the unit-test Sources entry.
Check identifier availability on the latest head before applying. The native
runner's source-count gate requires these methods to execute on iPhone and iPad.

## Fix 3 - Make the photo rollback test meaningful

**Source review:** the old deletion test moves the entire parent folder, including
the photo, before inducing write failure. The library's original image path no
longer exists. Even an implementation that incorrectly deletes the image before
save cannot remove the moved file, so that assertion does not catch the original
bug.

The proposed setup leaves the image at its original path and replaces only the
JSON destination with a directory. The write must fail while the image remains
deletable. The same recipe/photo preservation assertions now exercise the actual
ordering requirement. This test change does not alter production persistence.

## Validation and next action

- Supplemental check: git apply --check and actual application pass in an
  isolated copy; result matches the proposed files. Three test methods remain;
  existing assertions are retained, with one photo-reachability precondition added.
- Source review: async signatures match existing tests; target reference/group/
  Sources membership is complete; deletion setup preserves the original image path.
- Not executed: Swift compilation, XCTest or simulator runs for this patch.
  A green check on this handoff-only PR would test the base source, not this fix.

Apply A2-11-persistence-test-unblock.patch, then run Linux and native suites.
Require 180 -> 181 -> reload, failed confirmation preserving the review flag,
and failed deletion preserving the reachable photo. Keep source-count and failure
gates intact. Native device behavior is separate from these tests.

A3 can continue the capture pass independently. This contribution avoids changes
to the cooking UI, parser, timers, signing and release workflow.
