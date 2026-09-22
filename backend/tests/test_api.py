def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_categories_are_seeded_on_startup(client):
    response = client.get("/categories")
    assert response.status_code == 200
    names = {c["name"] for c in response.json()}
    assert "Food & Dining" in names
    assert "Salary" in names


def test_create_category(client):
    response = client.post(
        "/categories",
        json={"name": "Test Category A", "type": "expense", "color": "#123456", "icon": "star"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Test Category A"
    assert body["id"] is not None


def test_create_category_duplicate_name_conflicts(client):
    payload = {"name": "Duplicate Cat", "type": "expense", "color": "#111111", "icon": "star"}
    first = client.post("/categories", json=payload)
    assert first.status_code == 201
    second = client.post("/categories", json=payload)
    assert second.status_code == 409


def test_transaction_crud_roundtrip(client):
    category = client.post(
        "/categories",
        json={"name": "CRUD Test Cat", "type": "expense", "color": "#222222", "icon": "star"},
    ).json()

    created = client.post(
        "/transactions",
        json={
            "amount": 199.99,
            "type": "expense",
            "category_id": category["id"],
            "note": "Test purchase",
            "date": "2026-01-15",
        },
    )
    assert created.status_code == 201
    tx = created.json()
    assert tx["amount"] == 199.99
    assert tx["category"]["name"] == "CRUD Test Cat"

    fetched = client.get(f"/transactions/{tx['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["note"] == "Test purchase"

    updated = client.put(f"/transactions/{tx['id']}", json={"amount": 250.0})
    assert updated.status_code == 200
    assert updated.json()["amount"] == 250.0

    deleted = client.delete(f"/transactions/{tx['id']}")
    assert deleted.status_code == 204

    missing = client.get(f"/transactions/{tx['id']}")
    assert missing.status_code == 404


def test_create_transaction_rejects_unknown_category(client):
    response = client.post(
        "/transactions",
        json={"amount": 10, "type": "expense", "category_id": 999999, "date": "2026-01-01"},
    )
    assert response.status_code == 422


def test_bulk_create_is_idempotent_on_client_id(client):
    category = client.post(
        "/categories",
        json={"name": "Bulk Test Cat", "type": "expense", "color": "#333333", "icon": "star"},
    ).json()

    payload = [
        {
            "amount": 50,
            "type": "expense",
            "category_id": category["id"],
            "date": "2026-02-01",
            "client_id": "bulk-test-1",
        }
    ]
    first = client.post("/transactions/bulk", json=payload)
    assert first.status_code == 201
    first_id = first.json()[0]["id"]

    second = client.post("/transactions/bulk", json=payload)
    assert second.status_code == 201
    second_id = second.json()[0]["id"]

    # Same client_id must resolve to the same server row, not a duplicate.
    assert first_id == second_id


def test_monthly_summary_totals(client):
    category = client.post(
        "/categories",
        json={"name": "Summary Test Cat", "type": "expense", "color": "#444444", "icon": "star"},
    ).json()
    income_category = client.post(
        "/categories",
        json={"name": "Summary Income Cat", "type": "income", "color": "#555555", "icon": "star"},
    ).json()

    client.post(
        "/transactions",
        json={
            "amount": 300,
            "type": "expense",
            "category_id": category["id"],
            "date": "2026-03-10",
        },
    )
    client.post(
        "/transactions",
        json={
            "amount": 1000,
            "type": "income",
            "category_id": income_category["id"],
            "date": "2026-03-05",
        },
    )

    summary = client.get("/summary", params={"month": "2026-03"})
    assert summary.status_code == 200
    body = summary.json()
    assert body["total_expense"] >= 300
    assert body["total_income"] >= 1000
    category_names = {c["category_name"] for c in body["by_category"]}
    assert "Summary Test Cat" in category_names


def test_summary_rejects_malformed_month(client):
    response = client.get("/summary", params={"month": "not-a-month"})
    assert response.status_code == 422


def test_yearly_summary_has_twelve_months(client):
    response = client.get("/summary/yearly", params={"year": 2026})
    assert response.status_code == 200
    assert len(response.json()["months"]) == 12
