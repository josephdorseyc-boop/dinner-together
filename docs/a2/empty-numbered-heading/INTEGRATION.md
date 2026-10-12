# A2-14: empty numbered screenshot headings

Prepared for Agent 3 on October 12, 2026.

## Problem and scope

**S1, source review:** `parse(screenshots:)` filters empty text out of a flat array, then indexes that array using the positions of every numbered heading. A screenshot containing only `STEP 1`, followed by `STEP 2` and `Bake the mixture`, creates two heading keys but only one text entry. The second lookup exceeds the array bounds. Empty middle and last headings have the same problem.

The separate patch keeps assembled text keyed by step number and emits it only when present. It always emits loose directions anchored after that number, including when the heading itself is empty. This retains A3's accepted Mix → Rest → Bake anchoring policy. It does not add invented instructions or a new rejection message.

## Integration

- Patch base: main `eb04d8288a995e88e9653df4c6206694e043c7c9`.
- Apply `A2-14-empty-numbered-heading.patch` to the owning source branch.
- Supplemental compatibility check: clean application also passed against palette head `8b70d05ff64977a4bf104b54d05f792b60f1d3ae`.
- Only two existing files change: RecipeImporter.swift and ScreenshotOrderTests.swift. The existing test class gains five methods; no project membership change or new test file is needed. Preserve dynamic test-count gates.
- Five regression cases: empty first heading, empty middle heading, empty last heading, loose directions after an empty heading, and only empty headings (the existing no-text error).
- No active source branch was modified by A2. Merging these handoff documents alone does not apply the source patch.

## Validation and evidence limits

**Supplemental check:** both base files match the repository's Git blob hashes; clean patch application passed against main and the current palette branch. Applied main files are byte-for-byte identical to the isolated proposal. An assembly-only Python model reproduces the indexing error on all five empty-heading fixtures, and the repaired model retains the expected output. It matches the original model on 54 nonempty assembly cases.

**Not executed:** Swift compilation, the complete parser, XCTest, simulator or physical-device testing. The Python model checks only the changed assembly relationship. CI on a handoff-only branch evaluates the base app, not the patch inside this document directory.

After applying, A1/A3 should run the existing parser suite plus the five regressions on Linux and both native simulator targets. The runtime input reported above must return the remaining recognized direction without a crash. Nothing in this fix proves that OCR recovered every instruction from an incomplete screenshot: import review remains required.

## Work left with existing owners

Palette implementation and native integration remain with A3. Cover crop positioning, colored-pixel assertions, and retry/cancel UI flows remain with A1/A3. This patch does not duplicate those tasks or change OCR script filtering, color persistence, timers, scheduling or menu/dialog presentation.
