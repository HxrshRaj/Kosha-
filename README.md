# Kosha — Personal Finance Tracker

A full-stack personal finance tracker: a Flutter mobile app backed by a
real REST API, built to genuinely exercise the things a production
Flutter app needs — REST integration, offline-first local storage,
background-isolate threading for heavy work, and measured performance
tuning — rather than a tutorial-style demo.

## Architecture

```
Kosha/
├── backend/     FastAPI + SQLAlchemy REST API (SQLite by default, Postgres-ready)
└── app/         Flutter app (Riverpod, Dio, Hive)
```

The Flutter app is a genuine client of the backend over HTTP — no mocked
or hardcoded data. It also caches everything locally so it keeps working
with the network off.

## Backend

**FastAPI (Python)**, chosen over Node/Express because: Pydantic gives
request/response validation and OpenAPI docs for free (`/docs`), and
async SQLAlchemy keeps the CRUD layer simple without extra boilerplate.

- **Database**: SQLite by default (`backend/kosha.db`, a real file, not
  in-memory — data survives a restart), swappable to Postgres via the
  `DATABASE_URL` env var for deployment (see `backend/render.yaml`).
- **Endpoints**:
  | Method | Path | Purpose |
  |---|---|---|
  | GET/POST | `/transactions` | list (filterable by `month`, `category_id`, `type`) / create |
  | POST | `/transactions/bulk` | idempotent (by `client_id`) batch create — used by offline sync and CSV import |
  | GET/PUT/DELETE | `/transactions/{id}` | single transaction |
  | GET/POST | `/categories` | list / create (categories also carry an optional `monthly_budget`) |
  | PUT/DELETE | `/categories/{id}` | update / delete |
  | GET | `/summary?month=YYYY-MM` | totals + per-category spend for the dashboard |
  | GET | `/summary/yearly?year=YYYY` | 12-month income/expense trend |
  | GET | `/health` | liveness check |

### Run it locally

```bash
cd backend
python -m venv .venv
./.venv/Scripts/activate   # source .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Interactive API docs: http://127.0.0.1:8000/docs

### Backend tests

```bash
cd backend
pip install -r requirements-dev.txt
pytest tests/ -v
```

Covers CRUD round-trips, duplicate-category conflicts, unknown-category
rejection, bulk-create idempotency, and summary aggregation — against a
temp SQLite file, not the dev database.

### Deploy

Live at **https://kosha-api-j093.onrender.com** (free tier — the first
request after idling may take a few seconds to wake up). Interactive
docs: https://kosha-api-j093.onrender.com/docs

`backend/render.yaml` is a Render Blueprint: on Render, "New → Blueprint"
against this repo provisions the API with no manual configuration beyond
pointing it at `backend/render.yaml` as the Blueprint path (this is a
monorepo, so Render's root-default won't find it). It deploys with a
local SQLite file by default — set `DATABASE_URL` in the Render
dashboard to point at a Postgres instance instead if you have one.

## Flutter app

**State management: Riverpod**, chosen over Provider/Bloc because:
providers are declared once and consumed without `BuildContext` lookups,
`AsyncNotifier`/`FutureProvider` map directly onto "loading / data /
error" without hand-rolled state enums, and provider overrides make
screens testable without a mocking framework (see `app/test/screens/`).

**HTTP client: Dio**, chosen over the plain `http` package because its
`DioException` carries a `DioExceptionType` (timeout vs. connection error
vs. bad response), which `lib/core/network/api_client.dart` maps onto
typed `NetworkException` / `ServerException` — the UI shows a specific,
honest message instead of a generic failure for every kind of error.

**Local storage: Hive**, chosen over sqflite because there is no local
relational querying to do — all aggregation happens server-side via
`/summary` — so a schema-less key/value store that round-trips the same
JSON shape as the REST API is simpler than standing up SQL tables and a
migration story for two small boxes (transactions, categories).

### App structure

```
app/lib/
├── core/         theme (design tokens), network (Dio + typed errors), Result<T>
├── models/       Transaction, Category, summary DTOs
├── services/     REST clients, Hive cache, sync reconciliation, CSV import
├── providers/    Riverpod providers wiring services to screens
├── screens/      transactions, dashboard, CSV import, root nav shell
└── widgets/      shared UI (list tile, empty/error states, charts)
```

### Run it

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=https://kosha-api-j093.onrender.com
```

That points at the live deployment — no local backend needed. For local
backend development instead: `10.0.2.2` is the Android emulator's alias
for the host machine's `localhost`, so run the backend locally and use
`--dart-define=API_BASE_URL=http://10.0.2.2:8000`; on a physical device,
either `adb reverse tcp:8000 tcp:8000` or point at your machine's LAN IP.

### Offline-first behavior

The transaction list reads the local Hive cache immediately (works with
no network), then reconciles with the backend in the background:

1. Any transaction created while offline is cached instantly with
   `pendingSync: true` and a client-generated UUID (`client_id`) — it is
   never lost.
2. On refresh, pending rows are pushed first via the idempotent
   `POST /transactions/bulk` (keyed by `client_id`, so retrying a
   partially-applied push never double-creates a row).
3. Only then is the server's copy for that month fetched and used to
   replace the cache — except any row that failed to push again is kept
   rather than silently dropped by the overwrite.

See `lib/services/sync_service.dart` for the full policy and
`test/services/local_cache_service_test.dart` for the test that exercises
exactly this "offline row must survive a sync" case.

### Threading — CSV import

Importing a bank-statement CSV (parse + per-row keyword categorization)
runs on a background isolate via `compute()`, never on the UI isolate.
The measured proof that this matters — real frame-timing numbers, not
assumed — is in [`docs/threading.md`](docs/threading.md).

### Performance

A real rebuild-count/timing regression was found and fixed
(`ListView.builder` + `RepaintBoundary` vs. a naive fully-eager list) —
measured before/after numbers are in
[`docs/performance.md`](docs/performance.md).

### Tests

```bash
cd app
flutter test
```

Covers: the CSV categorization heuristic, the Hive cache's month-filtering
and pending-row-preservation logic, transaction tile rendering, add-
transaction form validation, and the list-build performance benchmark.

## Simplifications (being upfront about scope)

- Offline support covers **creating** a transaction while offline;
  offline edit/delete are not implemented (would need the same
  outbox-and-reconcile pattern, just more of it).
- The dashboard's analytics are server-computed and require a
  connection — there is no local recomputation of `/summary` from the
  cache, so the chart screen (unlike the transaction list) doesn't work
  offline. Called out explicitly rather than pretending otherwise.
- No authentication — every request hits the backend as a single
  implicit user. Adding auth would mean a `user_id` column, a login
  screen, and a token stored securely (`flutter_secure_storage`).

## What's in this repo vs. what needs your own accounts

See [`docs/publishing.md`](docs/publishing.md) for the honest split
between "a real signed release build exists" and "an actual Play Store
listing requires a Google account you'd need to provide."
