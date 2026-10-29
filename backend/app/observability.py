"""Request metrics, structured logs, a TTL cache and a change feed.

Everything is in-process: fine for a single Render instance, and the
limits are listed in the README (not shared across workers).
"""
import asyncio
import json
import logging
import threading
import time
import uuid
from collections import defaultdict

from fastapi import APIRouter, Request, Response, WebSocket, WebSocketDisconnect

log = logging.getLogger("kosha")
router = APIRouter(tags=["meta"])

BUCKETS = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)


class Metrics:
    def __init__(self):
        self._lock = threading.Lock()
        self.reset()

    def reset(self):
        with self._lock:
            self.count = defaultdict(int)  # (method, path, status) -> n
            self.hist = defaultdict(lambda: [0] * (len(BUCKETS) + 1))
            self.sum = defaultdict(float)
            self.cache_hits = 0
            self.cache_misses = 0

    def observe(self, method, path, status, seconds):
        with self._lock:
            self.count[(method, path, status)] += 1
            key = (method, path)
            self.sum[key] += seconds
            h = self.hist[key]
            for i, b in enumerate(BUCKETS):
                if seconds <= b:
                    h[i] += 1
            h[-1] += 1

    def render(self) -> str:
        out = ["# TYPE http_requests_total counter"]
        with self._lock:
            for (m, p, s), n in sorted(self.count.items()):
                out.append(f'http_requests_total{{method="{m}",path="{p}",status="{s}"}} {n}')
            out.append("# TYPE http_request_duration_seconds histogram")
            for (m, p), h in sorted(self.hist.items()):
                for i, b in enumerate(BUCKETS):
                    out.append(f'http_request_duration_seconds_bucket{{method="{m}",path="{p}",le="{b}"}} {h[i]}')
                out.append(f'http_request_duration_seconds_bucket{{method="{m}",path="{p}",le="+Inf"}} {h[-1]}')
                out.append(f'http_request_duration_seconds_sum{{method="{m}",path="{p}"}} {self.sum[(m, p)]:.6f}')
                out.append(f'http_request_duration_seconds_count{{method="{m}",path="{p}"}} {h[-1]}')
            out.append("# TYPE cache_hits_total counter")
            out.append(f"cache_hits_total {self.cache_hits}")
            out.append("# TYPE cache_misses_total counter")
            out.append(f"cache_misses_total {self.cache_misses}")
        return "\n".join(out) + "\n"


metrics = Metrics()


class TTLCache:
    """Small TTL cache. Any write bumps `version`, which drops every entry."""

    def __init__(self, ttl: float = 30.0):
        self.ttl = ttl
        self._lock = threading.Lock()
        self._data = {}
        self.version = 0

    def get(self, key):
        with self._lock:
            hit = self._data.get(key)
            if hit and hit[0] > time.monotonic() and hit[2] == self.version:
                metrics.cache_hits += 1
                return hit[1]
            metrics.cache_misses += 1
            return None

    def set(self, key, value):
        with self._lock:
            self._data[key] = (time.monotonic() + self.ttl, value, self.version)

    def invalidate(self):
        with self._lock:
            self.version += 1
            self._data.clear()


cache = TTLCache()


class Feed:
    """Connected WebSocket clients; a mutation broadcasts one JSON event."""

    def __init__(self):
        self.clients: set[WebSocket] = set()

    async def broadcast(self, event: dict):
        dead = []
        for ws in list(self.clients):
            try:
                await ws.send_json(event)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)


feed = Feed()
WATCHED = ("/transactions", "/categories")


def _route_path(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


async def observe_requests(request: Request, call_next):
    rid = request.headers.get("x-request-id") or uuid.uuid4().hex[:12]
    start = time.perf_counter()
    status = 500
    try:
        response: Response = await call_next(request)
        status = response.status_code
        response.headers["x-request-id"] = rid
        return response
    finally:
        took = time.perf_counter() - start
        path = _route_path(request)
        metrics.observe(request.method, path, status, took)
        if request.method != "GET" and status < 400 and request.url.path.startswith(WATCHED):
            cache.invalidate()
            await feed.broadcast({"event": "changed", "resource": request.url.path.split("/")[1], "method": request.method})
        log.info(json.dumps({"rid": rid, "method": request.method, "path": path, "status": status, "ms": round(took * 1000, 2)}))


@router.get("/metrics")
def prometheus_metrics():
    return Response(metrics.render(), media_type="text/plain; version=0.0.4")


@router.websocket("/ws/events")
async def events(ws: WebSocket):
    await ws.accept()
    feed.clients.add(ws)
    try:
        while True:
            await asyncio.sleep(30)
            await ws.send_json({"event": "ping"})
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        feed.clients.discard(ws)
