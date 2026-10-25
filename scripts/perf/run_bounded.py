#!/usr/bin/env python3
"""Run a build step with a hard timeout, preserving logs and killing its process group."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def stop_group(proc):
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait(timeout=5)


def run_command(command, cwd, timeout, log_path, result_path):
    if timeout < 1 or timeout > 3600 or not command:
        raise ValueError("invalid timeout or command")
    log_path = Path(log_path)
    result_path = Path(result_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    state = "START_FAILED"
    returncode = None
    proc = None
    with log_path.open("wb") as output:
        try:
            proc = subprocess.Popen(command, cwd=cwd, stdout=output,
                                    stderr=subprocess.STDOUT, start_new_session=True)
            try:
                returncode = proc.wait(timeout=timeout)
                state = "PASS" if returncode == 0 else "COMMAND_FAILED"
            except subprocess.TimeoutExpired:
                state = "TIMEOUT"
        except OSError as error:
            output.write((str(error) + "\n").encode())
        finally:
            if proc is not None:
                stop_group(proc)
    result = {
        "schema": "HOP-PERF-BOUNDED-COMMAND-1.0",
        "state": state, "returncode": returncode,
        "elapsed_seconds": round(time.monotonic() - start, 3),
        "time_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "command": command, "cwd": str(cwd),
    }
    result_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if state == "PASS" else 124 if state == "TIMEOUT" else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--log", required=True)
    parser.add_argument("--result", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command and args.command[0] == "--" else args.command
    return run_command(command, args.cwd, args.timeout, args.log, args.result)


if __name__ == "__main__":
    sys.exit(main())
