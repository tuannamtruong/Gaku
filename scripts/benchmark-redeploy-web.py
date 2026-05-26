#!/usr/bin/env python3
"""
Benchmark the three redeploy-web implementations using --dry-run mode.
Times N iterations of each and reports min/median/mean/max.

Usage:
  python3 scripts/benchmark-redeploy-web.py          # 10 iterations (default)
  python3 scripts/benchmark-redeploy-web.py 20       # custom iteration count
"""
import statistics
import subprocess
import sys
import time
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10

SCRIPTS = [
    ("Bash  ", ["bash",       "scripts/redeploy-web.sh",          "--dry-run"]),
    ("Python", ["python3",    "scripts/redeploy-web.py",           "--dry-run"]),
    ("Go    ", ["go", "run",  "scripts/redeploy-web/main.go",      "--dry-run"]),
]

def time_run(cmd):
    start = time.perf_counter()
    r = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True)
    elapsed = time.perf_counter() - start
    if r.returncode != 0:
        print(f"  WARNING: {cmd[0]} exited {r.returncode}: {r.stderr.decode().strip()[:120]}")
    return elapsed

print(f"Benchmarking redeploy-web (--dry-run, {N} iterations each)\n")

results = {}
for label, cmd in SCRIPTS:
    print(f"  Running {label} × {N} ... ", end="", flush=True)
    samples = [time_run(cmd) for _ in range(N)]
    results[label] = samples
    print(f"done  (median {statistics.median(samples)*1000:.0f} ms)")

print()
print(f"{'Script':<10}  {'min':>8}  {'median':>8}  {'mean':>8}  {'max':>8}  {'stdev':>8}")
print("-" * 56)
for label, samples in results.items():
    mn  = min(samples) * 1000
    med = statistics.median(samples) * 1000
    avg = statistics.mean(samples) * 1000
    mx  = max(samples) * 1000
    sd  = statistics.stdev(samples) * 1000 if len(samples) > 1 else 0
    print(f"{label:<10}  {mn:>7.0f}ms  {med:>7.0f}ms  {avg:>7.0f}ms  {mx:>7.0f}ms  {sd:>7.0f}ms")

print()
fastest_label = min(results, key=lambda k: statistics.median(results[k]))
print(f"Fastest (by median): {fastest_label.strip()}")

# Relative comparison vs Bash baseline
bash_med = statistics.median(results["Bash  "])
print()
print("Overhead vs Bash (median):")
for label, samples in results.items():
    ratio = statistics.median(samples) / bash_med
    bar = "#" * int(ratio * 20)
    print(f"  {label}  {ratio:5.2f}x  {bar}")
