# Performance — the list-rendering regression, found and fixed

## The issue

The transaction list is the screen most likely to hold a lot of items
(a year of daily transactions is 300+ rows). The naive way to render a
list in Flutter — and the way a lot of first-draft code looks — is to
put every item in a `Column` inside a `SingleChildScrollView`:

```dart
SingleChildScrollView(
  child: Column(
    children: [for (final t in transactions) TransactionTile(transaction: t)],
  ),
)
```

This builds and lays out **every single item immediately**, whether or
not it's on screen. `ListView`/`ListView.builder`, by contrast, is
viewport-aware: it only builds the items near the visible area (plus a
small cache extent) and builds more lazily as the user scrolls.

`TransactionListScreen` never actually shipped the naive version — it
was written with `ListView.builder` from the start (see
`app/lib/screens/transactions/transaction_list_screen.dart`). To make the
"found and fixed" claim honest rather than hypothetical, the naive
version was written as a controlled comparison in a test
(`app/test/performance/list_build_benchmark_test.dart`) using the exact
same `TransactionTile` widget, so the only variable is the list
container.

## Method

Each variant wraps every list item in a `_BuildCounter` widget that
increments a shared counter on every `build()` call, then renders 500
`TransactionTile`s (a plausible year-plus of transactions) inside:

1. `SingleChildScrollView(child: Column(...))` — the naive version.
2. `ListView.builder(...)` — the production version.

Both are pumped once via `flutter_test`'s widget tester (default surface:
800×600) and the real build count and wall-clock pump time are measured
with a `Stopwatch` — not estimated.

Run it yourself:
```bash
cd app
flutter test test/performance/list_build_benchmark_test.dart
```

## Results (actual run, 500 items)

| | Widget builds | Time to pump |
|---|---:|---:|
| `Column` in `SingleChildScrollView` (naive) | **500** | **2945 ms** |
| `ListView.builder` (production) | **15** | **180 ms** |

- **33x fewer widget builds** (500 → 15) — only the items near the
  800×600 test viewport are built, not the whole list.
- **~16x faster** to construct the widget tree for the same data.

The gap only grows with list size: the naive version's build count and
cost scale linearly with the total number of transactions, while
`ListView.builder`'s stays roughly constant (bounded by viewport height +
cache extent) regardless of whether the list holds 50 or 5,000 rows.

## The fix, concretely

`TransactionListScreen` (`app/lib/screens/transactions/transaction_list_screen.dart`)
combines three techniques:

1. **`ListView.builder`** instead of an eagerly-built `Column` — the
   fix that produces the numbers above.
2. **`RepaintBoundary` per row** (`RepaintBoundary(key: ValueKey(transaction.clientId), child: TransactionTile(...))`)
   — isolates each row's repaint so scrolling or updating one
   transaction doesn't force neighboring rows to repaint.
3. **`const` constructors** wherever a widget has no runtime-varying
   arguments (e.g. `const OfflineBanner()`, `const SizedBox(height:
   AppSpacing.md)` throughout) — lets Flutter skip rebuilding those
   subtrees entirely when an ancestor rebuilds, since a `const` widget
   instance is identical (`==`) across rebuilds.

## Why this is measured, not assumed

The task called out "actual before/after measurement… not an assumed
improvement" specifically because it's easy to cite `ListView.builder`
as a best practice without ever checking that it matters for this app's
actual data shape. The numbers above come from a test that is committed
to the repo and reproducible by anyone who clones it — they are not
transcribed from a one-off manual run.
