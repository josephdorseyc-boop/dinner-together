#!/usr/bin/env python3
"""Read XCTest's last suite counts for diagnostics when xcresult is unreadable.

This does not establish a passing process or a complete result bundle.
"""
import re
import sys


SUMMARY = re.compile(
    r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?"
    r"(\d+) failures? \(\d+ unexpected\)(?: in .*)?"
)


def read_counts(log):
    lines = [line.strip() for line in log.splitlines()
             if line.lstrip().startswith("Executed ")]
    if not lines:
        raise ValueError("no XCTest suite summary")
    match = SUMMARY.fullmatch(lines[-1])
    if not match:
        raise ValueError("unrecognized final XCTest suite summary")
    executed, skipped, failed = (int(value or 0) for value in match.groups())
    if skipped + failed > executed:
        raise ValueError("inconsistent XCTest suite counts")
    return executed, failed, skipped


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8", errors="replace") as source:
            print(*read_counts(source.read()))
    except (IndexError, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
