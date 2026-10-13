# A2-28 — native OCR reference check

October 13, 2026. A2 prepared `Dinner_Together_OCR_Reference_Pack.zip` privately for Joe to attach to A1. Its five original source JPEGs are unmodified; zip CRC and each original SHA-256 were checked. The archive is 754,283 bytes; SHA-256 `961289118769b0fc661d6dd003d36582c435d9c80d4d113ea0dd3b5b85ff00cb`.

Original images were not published here. Automatic approval review blocked that public-image upload because the specific publication was not explicitly authorized. This text-only handoff accompanies the private archive.

## Scope

These are the five Apple News reference pages supplied with the Build 11 report, not the app-output screens or a confirmed complete copy of Joe's selected import batch. They cover five active instructions, with dimmed adjacent context. They do not supply the original cover/ingredients page, complete recipe ending, or origin of “0001 -”.

The archive contains README.md, MANIFEST.json, EXPECTED_PREFIX.json and reference-pages/news-01.jpeg … news-05.jpeg. The JSON is a human transcription contract, not recognized Vision output. Reference order is deliberately controlled and is not claimed to be Joe's original Photos selection order.

## A1's native check

1. Use the actual ScreenshotReader configuration on the selected A3 commit; record SHA, OS/SDK, request settings and recognition languages.
2. Obtain actual recognized text and boxes, then title candidates/chosen branch, navigation/body markers, candidate step heads and final numbered directions. Capture native confidence/alternatives in a private diagnostic if available; current OCRLine does not carry them.
3. Compare the full active first-five prefix from A2-22. In particular, source step 3 must retain “Set aside.” rather than the longer repeated title. Record dimmed continuation treatment separately.
4. Do not assert exactly five total output steps or infer times from oven temperature, quantities or pan counts. The provided prefix is partial.
5. Share the outcome and resulting regression assertions in PR #16; keep original images/full recognition dumps private.

A successful reference-prefix check covers those supplied pages. It does not establish a successful full-batch import on Joe's phone. A3 owns correction; A1 owns native evidence; A2 compares actual output to the product contract.
