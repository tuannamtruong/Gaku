#!/usr/bin/env python3
"""Read-only traffic against the Gaku API, to fill the Prometheus and Grafana panels.

What it sends:
- Normal requests: a weighted random mix of /api/health, the trail list, trail by id (real ids taken from /api/trails at startup), nearby search (PostGIS) and text search.
- Errors on purpose: a random id (404), nearby search with no query parameters (400) and a route that doesn't exist (404). These give your status-code panels something besides 200s.
- Output: a count of responses by status code every 5 seconds, and a total when it stops.

Skips /api/map/*: those call Nominatim and Overpass, which rate-limit.

Usage:
  scripts/api-traffic.py                          # http://localhost:8080, 5 req/s until Ctrl+C
  scripts/api-traffic.py http://gaku.local --rps 20 --duration 300
"""
import argparse
import json
import random
import threading
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter

TERMS = ["alp", "lake", "peak", "ridge", "valley", "tour", "xyz"]


def get(url):
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except OSError as e:
        return type(e).__name__, b""


def pick(ids):
    lat, lon = random.uniform(43, 48), random.uniform(5, 16)  # roughly the Alps
    return random.choices([
        "/api/health",
        "/api/trails",
        f"/api/trails/{random.choice(ids)}" if ids else "/api/trails",
        f"/api/trails/{uuid.uuid4()}",  # 404
        f"/api/trails/nearby?lat={lat:.4f}&lon={lon:.4f}&radiusKm={random.choice([10, 50, 200])}",
        f"/api/trails/search?q={random.choice(TERMS)}",
        "/api/trails/nearby",  # 400, missing query params
        "/api/does-not-exist",  # 404, no route
    ], weights=[2, 3, 4, 1, 3, 3, 1, 1])[0]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("base", nargs="?", default="http://localhost:8080")
    p.add_argument("--rps", type=float, default=5)
    p.add_argument("--workers", type=int, default=8)
    p.add_argument("--duration", type=float, default=0, help="seconds, 0 = until Ctrl+C")
    a = p.parse_args()
    base = a.base.rstrip("/")

    status, body = get(f"{base}/api/trails")
    if status != 200:
        raise SystemExit(f"GET {base}/api/trails -> {status}")
    ids = [t["id"] for t in json.loads(body)]
    print(f"{len(ids)} trails, {a.rps} req/s over {a.workers} workers against {base}")

    stop = threading.Event()
    counts, lock = Counter(), threading.Lock()
    interval = a.workers / a.rps

    def worker():
        while not stop.is_set():
            start = time.monotonic()
            status, _ = get(base + pick(ids))
            with lock:
                counts[status] += 1
            stop.wait(max(0, interval - (time.monotonic() - start)))

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(a.workers)]
    for t in threads:
        t.start()

    deadline = time.monotonic() + a.duration if a.duration else float("inf")
    try:
        while time.monotonic() < deadline:
            stop.wait(min(5, max(0, deadline - time.monotonic())))
            with lock:
                print(f"{time.strftime('%H:%M:%S')} {dict(counts)}", flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        for t in threads:
            t.join(timeout=11)
    print(f"total {sum(counts.values())}: {dict(counts)}")


if __name__ == "__main__":
    main()
