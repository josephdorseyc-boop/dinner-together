#!/usr/bin/env python3
"""Write seeded Dinner, Together session files for simulator screenshots.

Each scenario is a `dinner-together-v2.json` in the exact shape SessionStore
decodes (DinnerSession via Swift's synthesized Codable + JSONEncoder defaults:
Dates are seconds since 2001-01-01 UTC, optionals omitted when nil, every
non-optional key present). Times are relative to --now so a launch a few
seconds later lands in the intended state. Steak night menu throughout:

  Steak:       s1 10 min, s2 20 min, s3 10 min
  Mash:        p1 10 min, p2 20 min (hands-off), p3 5 min
  Green beans: b1  5 min, b2 10 min

Usage: seed-sessions.py OUT_DIR [--now UNIX_SECONDS] [--list]
Writes OUT_DIR/<scenario>.json and prints one "scenario<TAB>expectation" line
per file so the screenshot script can caption them.
"""
import json, sys, time, uuid, pathlib

REFERENCE_EPOCH = 978307200  # 2001-01-01T00:00:00Z, Swift Date reference
MIN = 60

def swift_date(unix_seconds):
    return float(unix_seconds - REFERENCE_EPOCH)

def done(start, end):
    rec = {"state": "done", "actualEnd": swift_date(end)}
    if start is not None:
        rec["actualStart"] = swift_date(start)
    return rec

def cooking(start, minutes, deadline):
    return {"runID": str(uuid.uuid4()).upper(), "state": "cooking",
            "actualStart": swift_date(start), "confirmedMinutes": minutes,
            "timerDeadline": swift_date(deadline)}

def session(now, serve_at, records, history=None, menu_id="steak"):
    return {
        "menuID": menu_id,
        "serveAt": swift_date(serve_at),
        "durationOverrides": {},
        "records": records,
        "history": history or [],
        "createdAt": swift_date(now - 60 * MIN),
        "lastOpenedAt": swift_date(now),   # today → never the stale-plan sheet
    }

def scenarios(now):
    n = lambda m: now + m * MIN
    out = {}

    # a) Routine late finish: steak prep done 7 min late; mash on schedule
    #    (p1 done on time, p2 cooking to its planned deadline); beans pending.
    #    Expect: notice "Running about 7 min behind", dinner 23 min from now,
    #    estimated +30; reason names the late prep; RIGHT NOW offers "Cook the steak".
    out["late-prep"] = (session(now, n(23), {
        "s1": done(n(-17), n(0)),
        "p1": done(n(-12), n(-2)),
        "p2": cooking(n(-2), 20, n(18)),
    }), "Running about 7 min behind; dinner +23, estimate +30; reason: prep finished 7 min late")

    # b) Nothing started, steak prep 8 min late to start.
    #    Expect: "Running about 8 min behind"; reason "late to start … about 40 min of Steak steps remain";
    #    RIGHT NOW card shows "About 8 min late to start".
    out["late-to-start"] = (session(now, n(32), {}),
        "Running about 8 min behind; reason: prep 8 min late to start")

    # c) Expired timer still cooking (lower bound). Steak cook timer ended 5 min ago,
    #    rest pending; mash and beans finished. Expect: "At least 5 min behind",
    #    "can't finish before"; reason "timer ended … check the food"; featured card Overdue 05:00.
    out["expired-timer"] = (session(now, n(5), {
        "s1": done(n(-35), n(-25)),
        "s2": cooking(n(-25), 20, n(-5)),
        "p1": done(n(-40), n(-30)), "p2": done(n(-30), n(-10)), "p3": done(n(-10), n(-5)),
        "b1": done(n(-20), n(-15)), "b2": done(n(-15), n(-5)),
    }), "At least 5 min behind (lower bound); featured expired timer; reason: check the food")

    # d) Far behind: nothing started, 15 min late → amber tone.
    out["way-behind"] = (session(now, n(25), {}),
        "Running about 15 min behind in amber; reason: prep 15 min late to start")

    # e) Everything finished, last step 9 min after dinner time. Expect NO notice,
    #    "Time to enjoy dinner."
    out["all-done-late"] = (session(now, n(-9), {
        "s1": done(n(-60), n(-50)), "s2": done(n(-50), n(-30)), "s3": done(n(-30), n(0)),
        "p1": done(n(-45), n(-35)), "p2": done(n(-35), n(-15)), "p3": done(n(-15), n(-10)),
        "b1": done(n(-25), n(-20)), "b2": done(n(-20), n(-10)),
    }), "No notice; 'Time to enjoy dinner.'")

    # f) Control: on schedule. Steak prep started 2 min ago exactly on plan.
    out["on-schedule"] = (session(now, n(38), {
        "s1": cooking(n(-2), 10, n(8)),
    }), "No notice; running timer 08:00 left; nothing late")

    # g) The planning screen ("Tonight"): launched WITHOUT -dt-open-cooking.
    #    Steak night selected, dinner 50 min out (feasible), nothing started.
    #    Expect: header, serving-time card, feasibility OK, menu cards, and the
    #    "Selected: Steak night" footer with "Build my cooking plan" (A2-S3).
    out["tonight-steak"] = (session(now, n(50), {}),
        "Tonight (plan) screen: Steak night selected, feasible time 50 min out, no progress; footer action visible")

    return out

def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__); return 2
    out_dir = pathlib.Path(argv[1]); out_dir.mkdir(parents=True, exist_ok=True)
    now = int(time.time())
    if "--now" in argv:
        now = int(argv[argv.index("--now") + 1])
    for name, (payload, expectation) in scenarios(now).items():
        path = out_dir / f"{name}.json"
        path.write_text(json.dumps(payload, indent=2))
        print(f"{name}\t{expectation}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
