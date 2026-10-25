#!/usr/bin/env python3
"""Independent known-load calibration before compiling either Hop candidate."""
import json
from pathlib import Path
import subprocess
import sys
from process_sampler import run

BUSY = "import time; e=time.monotonic()+9; n=1\nwhile time.monotonic()<e: n=(n*33+1)%10000019"
IDLE = "import time; time.sleep(9)"


def check(kind, code):
    marker = f"HOP_PERF_PREFLIGHT_{kind}"
    proc = subprocess.Popen([sys.executable, "-c", code, marker],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        result = run(proc.pid, 5, 1, marker)
        cpu = result.get("cpu_core_equivalent_percent")
        passed = (
            result["status"] == "MEASURED_PROCESS_ONLY" and
            cpu is not None and
            ((kind == "BUSY" and cpu > 20) or (kind == "IDLE" and cpu < 20))
        )
        return {"scenario": kind, "passed": passed, "result": result}
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=3)


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    cases = [check("BUSY", BUSY), check("IDLE", IDLE)]
    final = {"schema": "HOP-PERF-PREFLIGHT-1.0", "status": "PASS" if all(x["passed"] for x in cases) else "FAIL", "cases": cases}
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(final, indent=2) + "\n")
    print(json.dumps({"status": final["status"], "cpu": [(x["scenario"], x["result"].get("cpu_core_equivalent_percent")) for x in cases]}))
    return 0 if final["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
