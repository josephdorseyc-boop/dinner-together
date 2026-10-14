#!/usr/bin/env python3
"""Merge the parallel parts of one native-validation run into the single
results tree the ci-results branch has always held (Joe, October 14: the
pass now runs on four machines at once).

    python3 merge-parts.py <parts-dir> <out-dir>

<parts-dir> holds one folder per part, named ci-part-<part> (as
actions/download-artifact writes them). The merged tree keeps the familiar
paths A1 and A2 read:

  * ui-screenshots/<device>/ and screenshots/ — every part's PNGs together;
  * SUMMARY.md — each part's summary in turn, under a heading;
  * status.txt — REQUIRED_FAILURES summed over the parts; a part that
    produced no status counts as one failure;
  * 25-ui-test-<device>.log — the parts' logs for that device, one after
    another;
  * every other file — the first part's copy (core first) at the top level;
  * parts/<part>/ — each part's own files, unmerged, for anything above
    that needs the original.

It never decides the verdict: each part's gate already did, and the
workflow fails if any part failed.
"""
import os
import shutil
import sys

ORDER = ["core", "ui-iphone-1-of-2", "ui-iphone-2-of-2", "ui-ipad"]


def part_name(folder):
    return folder[len("ci-part-"):] if folder.startswith("ci-part-") else folder


def main(parts_dir, out):
    os.makedirs(out, exist_ok=True)
    found = [d for d in os.listdir(parts_dir) if os.path.isdir(os.path.join(parts_dir, d))]
    found.sort(key=lambda d: (ORDER.index(part_name(d)) if part_name(d) in ORDER else len(ORDER), d))
    summaries, failures, logs = [], 0, {}
    missing_status = []
    for folder in found:
        name = part_name(folder)
        src = os.path.join(parts_dir, folder)
        shutil.copytree(src, os.path.join(out, "parts", name), dirs_exist_ok=True)
        for root, _dirs, files in os.walk(src):
            for f in files:
                path = os.path.join(root, f)
                rel = os.path.relpath(path, src)
                top = rel.split(os.sep)[0]
                if rel == "SUMMARY.md":
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        summaries.append(f"# Part: {name}\n\n" + fh.read().rstrip() + "\n")
                    continue
                if rel == "status.txt":
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        for line in fh:
                            if line.startswith("REQUIRED_FAILURES="):
                                try:
                                    failures += int(line.split("=", 1)[1].strip() or "1")
                                except ValueError:
                                    failures += 1
                                break
                    continue
                if f.startswith("25-ui-test-") and f.endswith(".log") and os.sep not in rel:
                    logs.setdefault(f, []).append((name, path))
                    continue
                dest = os.path.join(out, rel)
                if top in ("ui-screenshots", "screenshots"):
                    # PNG names are unique per flow; a clash (a manifest) keeps
                    # both, the later one suffixed with its part.
                    if os.path.exists(dest):
                        stem, ext = os.path.splitext(dest)
                        dest = f"{stem}-{name}{ext}"
                elif os.path.exists(dest):
                    continue  # the first part's copy stays on top
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.copy2(path, dest)
        if not os.path.exists(os.path.join(src, "status.txt")):
            missing_status.append(name)
            failures += 1
    for f, entries in logs.items():
        with open(os.path.join(out, f), "w", encoding="utf-8") as out_fh:
            for name, path in entries:
                out_fh.write(f"===== part {name} =====\n")
                with open(path, encoding="utf-8", errors="replace") as fh:
                    shutil.copyfileobj(fh, out_fh)
                out_fh.write("\n")
    header = f"Merged from {len(found)} part(s): {', '.join(part_name(d) for d in found) or 'none'}\n"
    if missing_status:
        header += f"Parts without status.txt (counted as failures): {', '.join(missing_status)}\n"
    with open(os.path.join(out, "SUMMARY.md"), "w", encoding="utf-8") as fh:
        fh.write(header + "\n" + "\n".join(summaries))
    with open(os.path.join(out, "status.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"REQUIRED_FAILURES={failures}\nPARTS={len(found)}\n")
    print(header.strip(), f"· REQUIRED_FAILURES={failures}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
