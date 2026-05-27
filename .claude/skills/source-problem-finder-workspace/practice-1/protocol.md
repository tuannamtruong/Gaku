# Diagnostic Protocol — Map Not Shown on gaku.local

## Problem

Opening `https://gaku.local/` in the browser shows only the navbar. The Leaflet map
never renders — the page body stays blank. The gaku-web pod is Running (no crash).

---

## Signals Collected

| Source                                            | Finding                                                                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `kubectl get pods -n gaku`                        | All pods Running; gaku-web restarted 0 times                                              |
| `kubectl logs gaku-web`                           | Overpass HTTP calls succeeding (200 OK) but taking **51–59 seconds** each                 |
| Host curl to overpass-api.de (same query)         | **0.14 s**                                                                                |
| minikube node curl to overpass-api.de             | **0.13 s**                                                                                |
| Host curl directly to `65.109.112.52` (pod's IP)  | **0.10 s** — server itself is fast                                                        |
| DNS resolution from inside pod (`getent ahosts`)  | **20 ms** — fast                                                                          |
| Pod MTU                                           | 1500 — matches all CNI veth/bridge interfaces, no mismatch                                |
| Pod env vars                                      | No HTTP proxy configured                                                                  |
| `/proc/net/tcp6` (caught during active page load) | Active ESTABLISHED connection to `65.109.112.52:443` (overpass-api.de), **0 retransmits** |

---

## First Suspicion — Code: Overpass call blocks the Blazor render

### Hypothesis

`Home.razor` calls `LoadMapInfoAsync()` inside `OnInitializedAsync()`, which
synchronously awaits `MapService.GetMapInfoAsync()` → `OpenStreetMapService.GetTrailsInBoundsAsync()`
→ `client.PostAsync("https://overpass-api.de/api/interpreter", ...)`.

In Blazor Web App with `@rendermode InteractiveServer`, pre-rendering is enabled by
default. During the SSR pre-render phase the server awaits `OnInitializedAsync` in full
before sending any HTML to the browser. While the Overpass call is in flight the browser
receives **nothing** and shows a blank page.

After the pre-render eventually delivers HTML, the interactive SignalR circuit runs
`OnInitializedAsync` a **second time**, causing another full round-trip before
`OnAfterRenderAsync` fires and Leaflet can initialise the map.

### Supporting evidence

- `Home.razor:23-24` — `OnInitializedAsync` directly awaits `LoadMapInfoAsync()`
- `OpenStreetMapService.cs:64` — blocking `PostAsync` to Overpass with a 60 s timeout
- Pod logs show Overpass calls of 51–59 s, just within the 60 s `client.Timeout`
- Screenshot: blank white body, only navbar visible — consistent with no HTML delivered yet

### Status

**Confirmed as a real structural problem.** However the question remained: why does the
Overpass call take 51 s from the pod when it takes 0.13 s from the node?

---

## Second Suspicion — Network: IPv6 SYN packets silently dropped by CNI

### Hypothesis

`overpass-api.de` advertises both IPv4 (`162.55.144.139`, `65.109.112.52`) and IPv6
(`2a01:4f9:3051:3e48::2`, `2a01:4f8:261:3c4f::2`) addresses. The pod has IPv6 enabled
(`disable_ipv6=0`) but carries no global IPv6 route — only a `::/0` REJECT entry on
`lo`. If the CNI bridge silently drops IPv6 TCP SYN packets instead of returning
`ENETUNREACH` immediately, .NET's `SocketsHttpHandler` Happy Eyeballs would sit in
SYN_SENT for the full TCP retransmit sequence before falling back to IPv4:

```
tcp_syn_retries = 6, initial RTO ≈ 0.8 s
0.8 + 1.6 + 3.2 + 6.4 + 12.8 + 25.6 ≈ 50 s
```

### Refuted by evidence

`/proc/net/tcp6` captured during an active page load showed:

```
remote 65.109.112.52:443   state 01 (ESTABLISHED)   retrnsmt 00000000
```

- The connection is **IPv4** (IPv4-mapped address, `FFFF0000` prefix — normal on
  dual-stack Linux)
- State is ESTABLISHED — TCP handshake completed without timeout
- Zero retransmits — no packet loss at TCP level

IPv6 SYN drop is therefore **not the cause**. The 51-second delay occurs entirely
within the established TCP connection, at the TLS or HTTP layer.

### Resolved

Host curl directly to `65.109.112.52` returned **0.10 s**. The server is fast from the
host. The open question is therefore answered: the bottleneck is not the Overpass server.
The 51-second delay is specific to **.NET's `SocketsHttpHandler` inside the pod**.

---

## Third Suspicion — HTTP/2 negotiation stall inside the pod

### Hypothesis

`curl` defaults to HTTP/1.1. .NET's `SocketsHttpHandler` defaults to HTTP/2, negotiated
via TLS ALPN. The pod's CNI or the minikube bridge may interfere with the larger
TLS records involved in an HTTP/2 connection preface exchange in a way that does not
affect the smaller HTTP/1.1 records that curl sends. This would cause the ALPN
negotiation or the HTTP/2 SETTINGS frame exchange to stall until .NET falls back to
HTTP/1.1 — a process that can take the observed ~51 seconds.

Everything slower than curl but faster than the 60 s timeout fits: DNS (20 ms) + TCP
handshake (fast) + stalled HTTP/2 preface (~50 s) + HTTP/1.1 fallback + request/response
(fast) ≈ 51 s total.

### Refuted by evidence

`curl --http2 https://65.109.112.52/api/interpreter -H "Host: overpass-api.de" ...`
from the host returned **0.12 s**. HTTP/2 is not the slow path.

---

## Signals Collected (continued)

| Source                                                                            | Finding                                                                                                                                                                    |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `curl --http2` from host to `65.109.112.52`                                       | **0.12 s** — HTTP/2 is fast, not the cause                                                                                                                                 |
| Both IPs (`65.109.112.52`, `162.55.144.139`) from pod via `--resolve`             | **< 0.2 s each** — both Overpass servers fast from pod                                                                                                                     |
| `curl https://overpass-api.de/...` from inside pod (debug container, correct SNI) | **0.13 s** — pod network is fast end-to-end                                                                                                                                |
| `curl https://65.109.112.52/...` from debug container (no SNI)                    | **0.000000 s** — TLS cert mismatch: server returned `CN=lambert.openstreetmap.de`, not `overpass-api.de`. curl with IP URL sends no SNI; .NET sends SNI from `BaseAddress` |

**Key conclusion**: The pod's network is fully capable of reaching Overpass in ~0.13 s.
The 51-second delay is **specific to .NET's `SocketsHttpHandler`** and does not occur
with curl using the same network path.

---

## Fourth Suspicion — .NET `SocketsHttpHandler` connection pool behaviour

### Hypothesis

curl and .NET both reach the same server at the same speed at the network level. The
delay must be inside the .NET HTTP stack — most likely one of:

- **Connection pool queue duration**: requests queue waiting for a pooled connection to
  become available. If the pool is exhausted (e.g. one connection is held for 51 s by a
  prior request), all subsequent requests wait.
- **Connection pool `PooledConnectionLifetime` rotation**: `IHttpClientFactory` rotates
  the underlying `SocketsHttpHandler` every 2 minutes. During rotation, a new connection
  must be established. If something in the new connection establishment stalls in .NET
  (not at the network level, since curl is fast), this adds latency.
- **Some .NET-specific TLS or protocol behaviour** that curl does not exercise (e.g.
  session ticket fetch, certificate transparency check, or HTTP/2 connection preface
  even when ALPN negotiates HTTP/1.1).

### Current state

`dotnet-counters` has been installed in the pod (version `9.0.661903`) and the image
redeployed. The pod is Running. Image load issue encountered and resolved: minikube
cached the old image; required `kubectl scale --replicas=0`, `minikube ssh docker rmi -f`,
`minikube image load`, then scale back up.

### Next step — run dotnet-counters while triggering a page load

```bash
# Terminal 1 — start monitoring
kubectl exec -n gaku deployment/gaku-web -- \
  dotnet-counters monitor --process-id 1 \
    --counters System.Net.Http \
    --refresh-interval 1

# Terminal 2 — trigger Overpass call
# Open https://gaku.local/ in browser, or curl the web endpoint
```

Watch for:
| Counter | Indicates |
|---|---|
| `http11-requests-queue-duration` spike ~51 000 ms | Pool exhaustion — requests waiting for a free connection |
| `active-requests` stays at 1, queue near 0 | Delay is inside the single active connection, not queuing |
| `requests-failed` > 0 | Silent failures followed by retries |
| `http11-connections-current-total` = 0 then 1 | New connection being established each time (no reuse) |

---

## Final Suspicion — Blazor interactive circuit not starting

### Hypothesis

The Overpass delay (whether 51 s or the later 504 in 9.8 s) is a separate problem from the
map never appearing. Even with the Overpass call handled, the Leaflet map requires the Blazor
interactive circuit to run `OnAfterRenderAsync` and call `Leaflet.InitMapAsync`. If
`/_framework/blazor.web.js` is not served, the browser never bootstraps the circuit — the
page stays frozen at the SSR output (navbar visible, map div blank).

**Key diagnostic signal**: with SSR pre-rendering enabled, `OnInitializedAsync` runs once per
page load for SSR and once for the interactive circuit → two Overpass calls per browser page
load. Pod logs showed only **one** Overpass call per page load, proving the interactive
circuit was never starting.

### Evidence

Ingress logs for any browser page load:

```
"GET /_framework/blazor.web.js HTTP/2.0" 404 0  [gaku-gaku-web-8080]
"GET /Gaku.Web.styles.css HTTP/2.0" 404 0        [gaku-gaku-web-8080]
```

Port-forward confirmation from the pod directly:

```
blazor.web.js:      404
Gaku.Web.styles.css: 404
app.css:             200   ← plain wwwroot file, served fine
```

Pod filesystem:

```
/app/wwwroot/
  app.css   app.css.br   app.css.gz   js/
  ← no _framework/ directory
```

### Root Cause

**File:** `docker/Dockerfile.Gaku.Web` line 15

```dockerfile
# Before (broken):
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /app/publish --no-restore

# After (fixed):
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /app/publish
```

`--no-restore` skips the MSBuild static web assets resolution pass. The preceding
`dotnet restore` layer populates the NuGet package cache but does not assemble the Blazor
framework files. `dotnet publish` without `--no-restore` runs a full integrated
restore-build-publish pipeline that correctly generates `wwwroot/_framework/blazor.web.js`
and `blazor.server.js`.

### How to reproduce

The Dockerfile has already been fixed (no `--no-restore`), so reproduction requires
temporarily reverting the publish command before building.


```bash
# Temporarily add --no-restore back into docker/Dockerfile.Gaku.Web
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /app/publish --no-restore

# Build only the build stage (stops before the runtime COPY)
docker build -f docker/Dockerfile.Gaku.Web . --target build -t actually-broken-build

# Inspect the publish output
docker run --rm --entrypoint sh actually-broken-build -c "ls /app/publish/wwwroot/"
# Output: app.css  app.css.br  app.css.gz  js/   ← no _framework

# Remove the --no-restore in docker/Dockerfile.Gaku.Web
RUN dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /app/publish

# Build the fixed version
docker build -f docker/Dockerfile.Gaku.Web . --target build -t fixed-build
docker run --rm --entrypoint sh fixed-build -c "ls /app/publish/wwwroot/"
# Output: _framework  app.css  app.css.br  app.css.gz  js/   ← correct
```

### How to verify the fix

```bash
kubectl port-forward svc/gaku-web -n gaku 18081:8080 &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18081/_framework/blazor.web.js
# Expected: 200
```

### Fix applied

`--no-restore` removed from `docker/Dockerfile.Gaku.Web`. Old image evicted from minikube
(`docker rmi -f`), new image loaded, deployment restarted. `blazor.web.js` now returns 200.

### Note on `Gaku.Web.styles.css` 404

This file also 404s but is a pre-existing stale reference in `App.razor` — no `.razor.css`
component-scoped CSS files exist in the project so the bundle is never generated. Browsers
silently ignore failed CSS loads; this does not affect functionality.
