#!/usr/bin/env python3
"""Repeated A/B/B/A no-install process measurements. Never qualifies the GUI."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import time
from process_sampler import run


def hash_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def cleanup(proc):
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
        proc.wait(timeout=3)


def observe(label, binary, index, output, warmup, seconds):
    binpath = Path(binary).resolve(strict=True)
    if not binpath.is_file() or "/Hop Dev.app/Contents/MacOS/Hop" not in str(binpath):
        raise ValueError("refusing unexpected executable path")
    stdout = output / f"{index:02d}-{label}-stdout.log"
    stderr = output / f"{index:02d}-{label}-stderr.log"
    with stdout.open("wb") as out, stderr.open("wb") as err:
        proc = subprocess.Popen([str(binpath)], cwd=binpath.parent, stdout=out,
                                stderr=err, start_new_session=True)
        try:
            time.sleep(warmup)
            if proc.poll() is not None:
                measurement = {"status": "INCONCLUSIVE_NO_GUI_PROCESS"}
            else:
                measurement = run(proc.pid, seconds, 2, str(binpath))
        finally:
            cleanup(proc)
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                pass
    result = {
        "label": label, "sequence_index": index, "binary_sha256": hash_file(binpath),
        "mode": "headless_process_observation_only",
        "recorded_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "measurement": measurement,
    }
    (output / f"{index:02d}-{label}-observation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"label": label, "sequence": index, "status": measurement["status"],
                      "cpu": measurement.get("cpu_core_equivalent_percent")}), flush=True)
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--v15", required=True)
    p.add_argument("--v16", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--seconds", type=int, default=60)
    p.add_argument("--warmup", type=int, default=8)
    p.add_argument("--cycles", type=int, default=2)
    a = p.parse_args()
    if not (30 <= a.seconds <= 120 and 3 <= a.warmup <= 30 and 1 <= a.cycles <= 4):
        p.error("invalid bounded observation duration")
    a.output.mkdir(parents=True, exist_ok=True)
    apps = {"v15": a.v15, "v16": a.v16}
    schedule = ["v15", "v16", "v16", "v15"] * a.cycles
    observations = []
    for i, label in enumerate(schedule, 1):
        observations.append(observe(label, apps[label], i, a.output, a.warmup, a.seconds))
    measured = {k: [r["measurement"].get("cpu_core_equivalent_percent") for r in observations
                    if r["label"] == k and r["measurement"]["status"] == "MEASURED_PROCESS_ONLY"]
                for k in apps}
    summary = {
        "schema": "HOP-PERF-01R-1.0",
        "verdict": "HEADLESS_ONLY_NOT_INDEPENDENTLY_ACCEPTED",
        "source_kind": "debug_development_binary",
        "environment": {"platform": platform.platform(), "machine": platform.machine()},
        "schedule": schedule,
        "counts": {k: len(v) for k, v in measured.items()},
        "measurement_coverage": "COMPLETE_PROCESS_ONLY" if all(len(measured[k]) == schedule.count(k) for k in apps) else "INCONCLUSIVE_PARTIAL",
        "cpu_samples": measured,
        "limitations": [
            "Headless sampling does not exercise actual tab navigation or other GUI workflows.",
            "No wakeup or SwiftUI view invalidation measurements are provided.",
            "Background contention and shared filesystem settings may influence measurements.",
            "A separate GUI-capable macOS and M1 manual acceptance are mandatory."
        ]
    }
    (a.output / "comparison.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("cpu_samples", "limitations")}, indent=2))
    return 0  # Infrastructure execution only; never a performance or GUI PASS.


if __name__ == "__main__":
    sys.exit(main())
