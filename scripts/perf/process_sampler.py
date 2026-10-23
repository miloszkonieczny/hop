#!/usr/bin/env python3
"""Bounded, read-only per-PID CPU/RSS sampler for HOP-PERF-01.

This does not launch, signal or kill a process. CPU time delta is authoritative
for the observation window; ps %CPU is a *proxy*, not instantaneous CPU usage.
Do not interpret this as a GUI responsiveness qualification.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time


def parse_cpu_time(text: str) -> float:
    """Parse ps TIME: [days-][hours:]minutes:seconds[.fraction]."""
    value = text.strip()
    if not value:
        raise ValueError("empty process CPU TIME")
    day = 0
    if "-" in value:
        head, value = value.split("-", 1)
        if not head.isdigit():
            raise ValueError("invalid day count")
        day = int(head)
    parts = value.split(":")
    if len(parts) not in (2, 3):
        raise ValueError("expected mm:ss or hh:mm:ss")
    try:
        fields = [float(part) for part in parts]
    except ValueError as error:
        raise ValueError("non-numeric time component") from error
    if not all(x >= 0 for x in fields) or not all(x < 60 for x in fields[-2:]):
        raise ValueError("invalid CPU time component")
    if len(fields) == 2:
        minute, second = fields
        return day * 86400 + minute * 60 + second
    hour, minute, second = fields
    return day * 86400 + hour * 3600 + minute * 60 + second


def percentile(values: list[float], percentile_value: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    idx = (len(ordered) - 1) * percentile_value / 100
    lower, upper = int(idx), min(len(ordered) - 1, int(idx) + 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (idx - lower)


def get_process(pid: int) -> dict | None:
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "pid=", "-o", "ppid=", "-o", "%cpu=", "-o", "rss=", "-o", "time=", "-o", "state=", "-o", "command="],
        capture_output=True, text=True, check=False, timeout=5,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    # The command (path/arguments) can contain arbitrary spaces; parse fixed fields.
    matched = re.match(r"^\s*(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(.+?)\s*$", result.stdout, re.S)
    if not matched:
        raise ValueError("unexpected ps output; cannot safely interpret process identity")
    actual, parent, cpu, rss, cpu_time, state, command = matched.groups()
    if "Z" in state.upper():
        return None  # zombie no longer performs any work
    if int(actual) != pid:
        raise ValueError("ps returned an unexpected PID")
    return {
        "pid": int(actual), "ppid": int(parent), "ps_cpu_percent_proxy": float(cpu),
        "rss_kib": int(rss), "cpu_time_seconds": parse_cpu_time(cpu_time),
        "command": command,
    }


def run(pid: int, seconds: float, interval: float, expected_substring: str) -> dict:
    if not (0 < pid and 5 <= seconds <= 600 and 0.25 <= interval <= 30):
        raise ValueError("invalid bounds")
    start = time.monotonic()
    first = get_process(pid)
    if first is None:
        return {"status": "INCONCLUSIVE_NOT_RUNNING", "pid": pid, "samples": []}
    if not expected_substring or expected_substring not in first["command"]:
        return {"status": "FAIL_IDENTITY_MISMATCH", "pid": pid,
                "expected_command_substring": expected_substring,
                "observed_command": first["command"], "samples": []}
    samples = [{"elapsed_seconds": 0.0, **first}]
    previous = first["cpu_time_seconds"]
    while time.monotonic() - start < seconds:
        remaining = seconds - (time.monotonic() - start)
        time.sleep(min(interval, max(0.0, remaining)))
        current = get_process(pid)
        if current is None:
            break
        # Protect against PID reuse: a reused PID can have a different command
        # and/or reset cumulative CPU time; never misattribute to the old app.
        if expected_substring not in current["command"] or current["cpu_time_seconds"] < previous:
            return {"status": "FAIL_PROCESS_IDENTITY_CHANGED", "pid": pid, "samples": samples}
        previous = current["cpu_time_seconds"]
        samples.append({"elapsed_seconds": time.monotonic() - start, **current})
    elapsed = samples[-1]["elapsed_seconds"]
    complete = elapsed >= seconds * .95 and len(samples) >= 3
    cpu_delta = samples[-1]["cpu_time_seconds"] - samples[0]["cpu_time_seconds"]
    rss = [a["rss_kib"] for a in samples]
    cpu_proxies = [a["ps_cpu_percent_proxy"] for a in samples[1:]]
    return {
        "status": "MEASURED_PROCESS_ONLY" if complete else "INCONCLUSIVE_EARLY_EXIT",
        "pid": pid, "start_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "elapsed_seconds": elapsed,
        "cpu_time_delta_seconds": cpu_delta,
        "cpu_core_equivalent_percent": 100 * cpu_delta / elapsed if elapsed > 0 else None,
        "ps_cpu_percent_proxy_median": statistics.median(cpu_proxies) if cpu_proxies else None,
        "ps_cpu_percent_proxy_p95": percentile(cpu_proxies, 95),
        "rss_kib_median": statistics.median(rss),
        "rss_kib_max": max(rss),
        "samples": samples,
        "limitations": [
            "CPU time in ps can be quantized; use windows >=30 seconds for interpretation.",
            "ps %CPU is a sampled scheduling proxy, not instantaneous process usage.",
            "No GUI tab-switching/UX/performance qualification is provided.",
            "Only the specified PID is sampled, not all child/helper processes.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--interval", type=float, default=2)
    parser.add_argument("--expected-command-substring", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = run(args.pid, args.seconds, args.interval, args.expected_command_substring)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        result = {"status": "FAIL_SAMPLER", "error": str(exc)}
    result.update({"schema_version": "1.0", "platform": platform.platform(),
                   "sampler_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "samples"}, indent=2))
    # Non-success status still records evidence. CI decides whether to block,
    # and an unavailable GUI environment must never be relabeled as a pass.
    return 0 if result["status"] == "MEASURED_PROCESS_ONLY" else 2


if __name__ == "__main__":
    sys.exit(main())
