from app import observability


def _category(client, name):
    return client.post("/categories", json={"name": name, "type": "expense", "color": "#fff", "icon": "x"}).json()["id"]


def _txn(client, cid, amount):
    return client.post("/transactions", json={
        "amount": amount, "type": "expense", "category_id": cid,
        "note": "t", "date": "2026-03-10",
    })


def test_metrics_endpoint_counts_requests_and_sets_request_id(client):
    observability.metrics.reset()
    r = client.get("/health", headers={"x-request-id": "abc123"})
    assert r.headers["x-request-id"] == "abc123"
    body = client.get("/metrics").text
    assert 'http_requests_total{method="GET",path="/health",status="200"} 1' in body
    assert "http_request_duration_seconds_count" in body


def test_summary_is_cached_then_invalidated_by_a_write(client):
    observability.metrics.reset()
    observability.cache.invalidate()
    cid = _category(client, "CacheCat")
    first = client.get("/summary", params={"month": "2026-03"}).json()
    again = client.get("/summary", params={"month": "2026-03"}).json()
    assert first == again
    assert observability.metrics.cache_hits == 1

    assert _txn(client, cid, 250).status_code in (200, 201)
    fresh = client.get("/summary", params={"month": "2026-03"}).json()
    assert fresh != first, "write must invalidate the cached summary"


def test_failed_write_does_not_invalidate_cache(client):
    observability.cache.invalidate()
    client.get("/summary", params={"month": "2026-04"})
    before = observability.cache.version
    client.post("/transactions", json={"amount": 5})  # 422
    assert observability.cache.version == before


def test_websocket_receives_change_event_on_write(client):
    cid = _category(client, "WsCat")
    with client.websocket_connect("/ws/events") as ws:
        assert _txn(client, cid, 10).status_code in (200, 201)
        assert ws.receive_json() == {"event": "changed", "resource": "transactions", "method": "POST"}
