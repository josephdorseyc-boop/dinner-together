#!/usr/bin/env python3
"""Bound a CI command, including a silent Xcode/test-runner hang (macOS/Linux)."""
import argparse
import os
import selectors
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, required=True)
    parser.add_argument('--idle-seconds', type=float, required=True)
    parser.add_argument('--grace-seconds', type=float, default=10)
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
    try:
        while selector.get_map() or process.poll() is None:
            now = time.monotonic()
            if now - started >= args.seconds:
                reason = 'wall-clock deadline'
                break
            if now - last_output >= args.idle_seconds:
                reason = 'no-output deadline'
                break
            for key, _ in selector.select(timeout=0.1):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if chunk:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                    last_output = time.monotonic()
                else:
                    selector.unregister(key.fileobj)
        if reason:
            print(f'::error::Native command exceeded {reason}; terminating its process group. '
                  'Partial results remain failures, never retry credit.', flush=True)
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
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
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            return 124
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        selector.close()
        process.stdout.close()


if __name__ == '__main__':
    sys.exit(main())
