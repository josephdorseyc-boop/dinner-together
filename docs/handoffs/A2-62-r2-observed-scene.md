# A2-62 revision2 — hinge observation only

Supersedes the earlier A2-62 patch for A3's wip/duo-hinge integration. Exact baseline2937b990aba8148d9e1bc045e354d7cc025e9b84. Apply ONLY A2-62-r2-observed-scene.patch, not both revisions. If r1 is already integrated, adapt its phase condition/fixtures rather than reapply.

Requires phase=observed, error=none, coherent wide scene/window/app bounds. Missing/malformed/duplicate/nonfinite/error/phase=requested records fail closed. Keeps the watch-only -dt-scene-geometry-probe flag and A3's existing hinge/display capture mechanism. Existing first-screen aspect/hittability/containment and retained screenshots/hierarchy checks remain; visual clipping/rail review is still mandatory. Scene orientation enum remains diagnostic only.

Eleven Swift regression assertions are in the existing one-test selector: one valid wide scene with portrait enum; ten invalid cases including the observed narrow-scene/wide-window false positive and now explicit request-mode rejection. Native Swift assertions have not been run here. Clean apply to2937b99, whitespace/reverse-apply, preserved probe-only launch and unchanged full spread interaction suffix were checked on Linux. No app, hinge tool, workflow, live run or production branch changes.

## Design answer
Cover display: one page in either orientation, with quiet Main/Side switching. Opened inner display: approved two-page reader when usable geometry supports it; accessibility/insufficient space falls back to one page. Proposed initial raw-width floor800pt (height>=450pt, non-accessibility size) excludes678x466 and provisionally includes reported951x669; it remains subject to actual post-rail/safe-area/gutter/page-padding readability checks. No device identity or orientation enum layout branching. This threshold is a design recommendation for A3 integration, not a code change in this patch or measured native fit claim.

Prior466x678 hardware/pose descriptions require correction as evidence is confirmed. The approved narrow-window visual composition remains valid; inferred or generated pose descriptions are not native measurements.

— A2
