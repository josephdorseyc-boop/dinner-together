# A2-16: fast, original-quality UI evidence for reviewers

## Gap found during palette review

The current UI evidence exists at ci-results c595b5456a6a362cbaf1ccb7ed2ca59622046083 (native run 38290508810, app source 8b70d05ff64977a4bf104b54d05f792b60f1d3ae). Most r14-r16 PNGs exceed 1 MB. The repository file connector returned empty base64 content for larger PNGs, and its blob reader requires UTF-8. The combined native-validation-results artifact is 608,310,464 bytes; the artifact downloader rejects it above 536,870,912 bytes. These are retrieval limits, not design findings about the screenshots.

A2 could not visually inspect r14-r16 through those routes. No palette render sign-off is claimed. A2's earlier source-review concerns about material contrast still stand pending actual render review.

## Separate patch for A3

Apply A2-16-ui-review-evidence.patch against main eb04d8288a995e88e9653df4c6206694e043c7c9. It adds one independent manual workflow, ui-review-evidence. No existing source, tests, native-validation workflow or release workflow changes.

Once the workflow is on main, run it with evidence_ref:

```text
c595b5456a6a362cbaf1ccb7ed2ca59622046083
```

It checks out that existing evidence revision on Ubuntu and uploads only interactive/static screenshots, the final summary, run provenance and UI logs. It does not compile the app, run tests, sign, upload an app, modify evidence or write to repository branches. No native rerun or resized screenshots are needed.

The artifact is named ui-review-evidence-<packaging-run-id>. Give A2/A1 that run link. The existing artifact downloader can then retrieve the ZIP with all original pixels intact.

## Provenance and limits

REVIEW_EVIDENCE.json records the resolved evidence commit, tested app source commit, native-validation run ID, and each PNG's dimensions, byte count and SHA-256. It explicitly identifies SUMMARY.md as the final-status authority; RUN.txt's provisional success field cannot turn a failed native run into a pass. Failed runs can be packaged for diagnosis.

The package excludes Xcode result bundles and build products, and rejects payloads at or above 400 MiB to stay below the known downloader limit. Screenshot images are copied byte-for-byte; no resampling, recompression, quantization or generated imagery. There are no new runtime dependencies in the workflow's packaging step.

## Checks performed

Supplemental checks: YAML parsed; manual-only trigger and read-only repository permissions checked; the actual embedded Python packaging code ran in an isolated fixture repository; PNG bytes/hashes and source/run provenance matched; a failed summary was retained; no .git data was packaged; clean application of the new-file patch matched the proposal.

Not performed: an actual GitHub Actions execution of this workflow, native or physical-device testing, or visual review of the inaccessible palette PNGs. CI on the handoff-only PR evaluates base app source; merging the documents alone does not install the workflow.

## Ownership

A3 integrates and dispatches the evidence-only workflow once. A2 reviews r14-r16 (and the outstanding larger cover render) from its artifact. A1 continues test triage and assertions. This delivery helper does not duplicate their production or test fixes. Future use is manual, so it adds no automatic jobs to app commits.
