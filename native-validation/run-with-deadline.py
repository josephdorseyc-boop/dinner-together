#!/usr/bin/env python3
"""Bound a CI command, including a silent Xcode/test-runner hang (macOS/Linux)."""
import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time


def collect_timeout_diagnostics(process, directory, reason, done, begun, elapsed):
    """Best-effort evidence before signals; never turn a deadline into success."""
    if not directory:
        return
    try:
        destination = Path(directory)
        destination.mkdir(parents=True, exist_ok=True)
        metadata = {
            'pid': process.pid, 'reason': reason, 'suite_marker_seen': done,
            'start_marker_seen': begun, 'elapsed_seconds': elapsed,
            'process_returncode_before_signals': process.poll(),
            'platform': sys.platform, 'release_credit': False,
        }
        (destination / 'deadline.json').write_text(json.dumps(metadata, indent=2) + '\n')
        if sys.platform == 'darwin' and process.poll() is None:
            with (destination / 'sample-command.log').open('w') as output:
                try:
                    result = subprocess.run(
                        ['/usr/bin/sample', str(process.pid), '3', '-file',
                         str(destination / 'process.sample.txt')],
                        stdout=output, stderr=subprocess.STDOUT, timeout=8,
                        check=False)
                    output.write(f'\nsample exit: {result.returncode}\n')
                except (OSError, subprocess.TimeoutExpired) as error:
                    output.write(f'\nsample unavailable: {error}\n')
    except OSError as error:
        print(f'::warning::Timeout diagnostics unavailable: {error}', flush=True)


def signal_group(process, sig):
    """Signal the command's process group; if the runner forbids that
    (PermissionError in Duo run 38723119849), signal the command itself."""
    try:
        os.killpg(process.pid, sig)
    except ProcessLookupError:
        pass
    except PermissionError:
        try:
            process.send_signal(sig)
        except ProcessLookupError:
            pass


def drain(selector, timeout):
    for key, _ in selector.select(timeout=timeout):
        chunk = os.read(key.fileobj.fileno(), 65536)
        if chunk:
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
        else:
            selector.unregister(key.fileobj)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, required=True)
    parser.add_argument('--idle-seconds', type=float, required=True)
    parser.add_argument('--grace-seconds', type=float, default=10)
    parser.add_argument('--diagnostics-dir', help='Optional bounded process sample before timeout signals (macOS).')
    # Xcode 27.1 on the Duo simulator printed the suite's last line, then sat
    # silent until the idle deadline (Duo run 38723119849): once this text has
    # appeared, a shorter silence ends the command, interrupting it gently
    # (SIGINT) so xcodebuild can still close its result bundle.
    parser.add_argument('--done-pattern', action='append', default=[])
    parser.add_argument('--done-idle-seconds', type=float, default=300)
    # The Duo's part-2 hang (A1, issue #15): xcodebuild printed "Running
    # tests..." and never launched the runner. If none of these texts has
    # appeared this long after the command started, stop it with its own
    # exit code (125), so the harness can reboot the simulator and run the
    # part again from scratch — nothing has run, so nothing is credited.
    parser.add_argument('--start-pattern', action='append', default=[])
    parser.add_argument('--start-seconds', type=float, default=0)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or min(args.seconds, args.idle_seconds, args.grace_seconds) <= 0:
        parser.error('positive deadlines and a command are required')
    # A separate group lets us terminate Xcode's subprocesses without killing
    # this harness, which still needs to collect the partial result bundle.
    process = subprocess.Popen(command, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    started = last_output = time.monotonic()
    reason = None
    done = False
    tail = b''
    patterns = [p.encode() for p in args.done_pattern]
    start_patterns = [p.encode() for p in args.start_pattern]
    begun = not (start_patterns and args.start_seconds > 0)
    try:
        while selector.get_map() or process.poll() is None:
            now = time.monotonic()
            if now - started >= args.seconds:
                reason = 'wall-clock deadline'
                break
            if not begun and now - started >= args.start_seconds:
                reason = 'start deadline (no test started)'
                break
            if now - last_output >= (args.done_idle_seconds if done else args.idle_seconds):
                reason = 'no-output deadline after the tests finished' if done else 'no-output deadline'
                break
            for key, _ in selector.select(timeout=0.1):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if chunk:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                    last_output = time.monotonic()
                    if (patterns and not done) or not begun:
                        tail = (tail + chunk)[-65536:]
                    if patterns and not done:
                        done = any(p in tail for p in patterns)
                    if not begun:
                        begun = any(p in tail for p in start_patterns)
                else:
                    selector.unregister(key.fileobj)
        if reason:
            collect_timeout_diagnostics(process, args.diagnostics_dir, reason,
                                        done, begun, time.monotonic() - started)
            if not begun:
                print(f'::warning::Native command exceeded the {reason}; terminating its process group '
                      '(exit 125: nothing ran, so the harness may reboot the simulator and run it again).', flush=True)
            else:
                print(f'::error::Native command exceeded {reason}; terminating its process group. '
                      'Partial results remain failures, never retry credit.', flush=True)
            # Gently first: xcodebuild closes its result bundle on SIGINT.
            if done:
                signal_group(process, signal.SIGINT)
                until = time.monotonic() + 30
                while process.poll() is None and time.monotonic() < until:
                    drain(selector, 0.2)
            signal_group(process, signal.SIGTERM)
            # Do not wait only on the leader: a surviving child can retain
            # pipes or keep a simulator command alive after Xcode exits.
            until = time.monotonic() + args.grace_seconds
            while time.monotonic() < until:
                for key, _ in selector.select(timeout=0.1):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if chunk:
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                    else:
                        selector.unregister(key.fileobj)
            signal_group(process, signal.SIGKILL)
            process.wait()
            return 124 if begun else 125
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        selector.close()
        process.stdout.close()


if __name__ == '__main__':
    sys.exit(main())
