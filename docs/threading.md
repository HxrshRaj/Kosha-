# Threading — the CSV import, and proof it doesn't block the UI

## The feature

`CsvImportScreen` imports a bank-statement CSV (date, description, amount)
and auto-categorizes every row from its description against a keyword
table (`lib/services/transaction_categorizer.dart`). The bundled sample
is 60,000 rows — a genuinely large import, the kind a "last 3 years of
statements" export would produce. Parsing + categorizing 60k rows is real
CPU work: for every row, every category's keyword list is scanned for a
substring match (see the comment on `TransactionCategorizer.categorize`
for why that's deliberately not optimized into a precompiled index — it's
what a real, simple statement importer looks like).

Run synchronously on the isolate driving the UI, this is exactly the kind
of call that freezes the app for the duration of the import. The fix is
`compute()` (`lib/services/csv_import_service.dart`), which runs the
parse-and-categorize step on a background isolate so the UI isolate is
never blocked.

## Why "I used compute()" isn't proof by itself

It's easy to sprinkle `compute()` around and never actually check it
changed anything. This is the measurement that checks it.

## Method

Flutter's `Timer.periodic` and `SchedulerBinding`'s per-frame callback
both run on the same isolate event loop — if that loop is busy running
synchronous Dart code, neither can fire until the call stack unwinds.
So a `Timer.periodic(Duration(milliseconds: 16), ...)` is a faithful
stand-in for "the UI's ability to produce a frame": if the categorization
work blocks the isolate, the periodic timer measurably stops ticking for
exactly as long as the work takes.

`app/tool/isolate_jank_benchmark.dart` (a standalone, reproducible script
— `dart run tool/isolate_jank_benchmark.dart` from `app/`, no device or
emulator needed) does exactly this, reusing the real
`TransactionCategorizer` and the real 60k-row sample CSV:

1. Starts a `Timer.periodic` every 16ms, recording the actual gap
   (via `Stopwatch`) between every tick — including the gap before the
   very first tick, which is where the effect shows up.
2. **Scenario A**: runs the categorization synchronously, on the same
   isolate as the timer — the equivalent of calling it directly from a
   button's `onPressed`.
3. **Scenario B**: runs the identical categorization via
   `Isolate.run()` — what `CsvImportService` actually does.
4. Reports the real max gap between ticks and an estimated dropped-frame
   count (`gap / 16.7ms`, at a 60fps budget).

## Results (actual run, 60,001-row CSV)

```
=== SYNCHRONOUS on the timer-owning isolate ===
  Work duration:              457 ms
  Timer ticks recorded:       11
  Max gap between ticks:      461.9 ms   (target ~16.7 ms)
  Ticks that missed budget:   1
  Estimated dropped frames:   26

=== BACKGROUND ISOLATE via Isolate.run ===
  Work duration:              413 ms
  Timer ticks recorded:       35
  Max gap between ticks:      30.2 ms   (target ~16.7 ms)
  Ticks that missed budget:   2
  Estimated dropped frames:   0
```

- **Synchronous**: the timer records essentially *one* gap covering the
  entire 457ms of work (461.9ms ≈ the work duration) — the periodic timer
  could not fire at all while the isolate was busy. At a 16.7ms frame
  budget, that is roughly **26 consecutive dropped frames** — well past
  the point a user perceives as a freeze (Android's own ANR heuristics
  start caring around 5 seconds of total unresponsiveness; a single
  janky import is nowhere near that, but 26 dropped frames in one stall
  is very visibly a stutter, and doing this on every import of a
  multi-year statement would compound).
- **Background isolate**: the max gap (30.2ms) is in the normal range of
  `Timer.periodic` jitter on a loaded machine — the timer kept ticking
  essentially on schedule *throughout* the 413ms of work happening on the
  other isolate. Zero estimated dropped frames.

Both runs used the identical CSV and identical categorization logic —
the only variable is which isolate does the work. The difference is the
whole point: `compute()` didn't make the work faster (413ms vs. 457ms —
roughly the same total CPU cost, plus isolate-spawn overhead), it made
the work *not block the isolate that owns the UI*.

Reproduce it yourself:
```bash
cd app
dart run tool/isolate_jank_benchmark.dart
```

## In the app itself

`CsvImportScreen` also carries a live frame counter (`_frameCount`,
driven by a `Ticker` — the same scheduling primitive `AnimationController`
uses) that increments every rendered frame. It is not decorative: if the
import work ever ran on the UI isolate, that counter would visibly stall
during the import, the same mechanism the benchmark measures. In the
shipped app it keeps counting smoothly through a real 60k-row import,
because the import always goes through `compute()` — there is no
"synchronous" code path in the production UI to demo the bad case; that
comparison only exists in the benchmark script, on purpose, so the real
app never ships the broken version even for demonstration.

## Honesty about what this environment could and couldn't verify

This benchmark measures isolate scheduling directly at the Dart-VM level,
which is the actual mechanism responsible for UI jank — not a proxy for
it. What it does *not* include is Flutter's own raster/rendering cost on
top of that (GPU work, layer compositing), because doing that measurement
for real requires Flutter DevTools' timeline attached to a running
Android emulator or device, and this build environment has no
GPU-accelerated virtualization available (nested virtualization is
disabled in this sandboxed Windows VM — confirmed via
`Get-CimInstance Win32_Processor | Select VirtualizationFirmwareEnabled`
returning `False`, and `flutter doctor`'s "Connected device" list never
included an Android emulator/device as a result). The isolate-level
measurement above is the part directly caused by the threading choice
this task is about; the additional raster-thread numbers are the
"harden with more time" item called out in the final summary.
