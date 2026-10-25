# HOP-PERF-01 — Workload and experiment contract

## Source freeze

- Production `main`: `af6c53a2d48ad87422ef606b8a77b13960eb6cd3` — reference only; no modifications.
- v1.5: `593eeec1d2d9cc6ac0ee2775b403146a58b8980d` — earlier failed tab navigation UAT.
- v1.6: `7ec28b7d1e5764d86d66afa53d3244d667c6ba9e` — failed CPU/responsiveness UAT.
- Observability harness belongs on its own branch and never changes either frozen candidate.
- Test actual optimized **development** binary with `HOP_RELEASE_BUILD=1 ./scripts/build-app.sh --dev`, not default debug development build. Separate bundle identity only.

## First executable, non-interactive experiment — A01/A02/A03

The CI job builds the two frozen versions with an identical runner image and tools. For each:
1. Record `GITHUB_SHA`, pinned candidate SHA, macOS, `uname -m`, `sysctl hw.model`, Swift/Xcode, CPU logical count, `vm.swapusage`, top process snapshot, executable SHA-256 and ad-hoc signing details.
2. Attempt an isolated no-install launch of the development executable. Launch failure on CI is **INCONCLUSIVE**, not success and not a demonstrated app failure on a real desktop.
3. If it runs, warm up 10 seconds and take three **60-second** process-only observations (one PID, no key logging, no app modification). Capture process CPU seconds and RSS, and label sampled `ps %CPU` as an approximate proxy.
4. Preserve raw samples, environment logs, source identities, stdout/stderr and SHA-256 manifest. No claim of observed tab or outside-click behavior.
5. Do not compare values unless both experiments completed on equivalent runner model, macOS release, build configuration and comparable background contention.

## Full workload matrix (later, GUI-capable macOS with consent and safety stop)

| Workload | Duration | Controls and key metric | Gate |
|---|---:|---|---|
| No Hop process | 10 min | OS CPU, thermal, swap and competing processes | Context only |
| Hop idle/panel closed | 10 min | Hop PID CPU seconds, RSS, wakeups | CPU >=30% one core for 10s is emergency abort |
| Countdown running/panel closed | 5 min | Deadline accuracy, sound/banner, CPU | no timer regression |
| Finished, acknowledged | 3 min | Blink/pulse and CPU | preserve visible feedback |
| Panel open/static | 3 min | redraw rate and CPU | no UI hang |
| Tab switching | 20 switches | persistent popover and response latency | P0 manual pass required |
| Monitor visible | 3 min | 2s polling and sensor fidelity | no stale data |
| Clipboard unchanged/changed | 3 min | change count, classification, confidentiality | no clipboard regression |
| Outside clicks/reopen | 10 cycles | close reason and stable menu bar | P0 manual pass required |

## Metrics and stop conditions

- Primary process CPU: `100 * (CPU_SECONDS_END - CPU_SECONDS_START) / (MONOTONIC_END - MONOTONIC_START)` = percentage of one logical CPU, possibly above 100%.
- `ps %CPU` is a decaying/averaged proxy. Its median and p95 in JSON must not be described as true instantaneous CPU p95.
- Resident footprint is RSS, not allocated swap. Report machine-wide swap and other WebKit consumption separately.
- Compare at least three runs; never claim a 25% improvement without comparable before/after process traces and uncertainty.
- Hard fail: identity mismatch, reused PID, changed source SHA. **Inconclusive:** unable to launch GUI in unattended runner or process exits early.
- This phase measures no tab switching or interactive UI and cannot pass manual acceptance.
- No code optimization until at least one measured hotspot is established. Never modify production `main`, frozen candidates or installed apps.
