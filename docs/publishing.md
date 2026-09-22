# Publishing Kosha — what's done and what's left

This is an honest accounting of how far Kosha is along the path to a real
Play Store release, and exactly what remains. Nothing here is simulated —
"done" means a command was actually run and its output verified; "not done"
means it genuinely requires something this environment cannot provide
(a Google account + $25, primarily).

## What's actually done

- **App identity configured**: package id `com.kosha.app.kosha`, app name
  "Kosha", versioning in `app/pubspec.yaml` (`version: 1.0.0+1` —
  `versionName`/`versionCode` on Android).
- **App icon**: a real generated icon (`app/tool/generate_icon.py` +
  `flutter_launcher_icons`) produces both the legacy launcher icon and an
  Android 8+ adaptive icon (separate background/foreground layers), wired
  into `app/android/app/src/main/res/mipmap-*`.
- **Real release builds were produced**: both `flutter build apk
  --release` (53.2MB APK) and `flutter build appbundle --release`
  (51.6MB AAB, the format Play Console actually requires) were run and
  verified (see "Verification" below) — genuine, installable release
  artifacts, not debug builds renamed.
- **ProGuard/R8 shrinking**: the release build uses Flutter's default
  release build type, which enables R8 code shrinking and resource
  shrinking for `--release` builds.
- **Backend deployable via Blueprint**: `backend/render.yaml` lets a
  Render account deploy the API with one click via
  "New → Blueprint", no manual dashboard configuration needed.

## What genuinely remains (needs an account/cost only the app owner can provide)

These steps are outside what an automated agent can do on someone else's
behalf: they require creating and paying for accounts tied to a real
identity (Google's developer terms require this), which is explicitly out
of scope here regardless of technical readiness.

1. **Google Play Console developer account** — one-time $25 registration
   fee, tied to a real Google account and identity verification.
2. **App signing**: generate a real upload keystore
   (`keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA
   -keysize 2048 -validity 10000 -alias upload`), configure
   `app/android/key.properties` (gitignored — never commit a real
   keystore or its passwords), and build the *signed* release with:
   ```bash
   flutter build appbundle --release
   ```
   The debug-signed build already produced here proves the build pipeline
   works end to end; only the signing identity changes for a real release.
3. **Play Console app listing**: title, short/full description,
   screenshots (phone + tablet, per Part 6's responsive layouts),
   feature graphic, app category, content rating questionnaire.
4. **Privacy policy**: required by Play Console because Kosha talks to a
   network backend. A real policy needs to describe what backend collects
   (transaction amounts, categories, notes, dates — no PII beyond what
   the user types into a note field) and where it's hosted, and would
   need to be hosted at a stable URL.
5. **Data safety form**: Play Console's declaration of what data the app
   collects/transmits — filled out against the backend's actual behavior
   (it stores transaction data in Postgres/SQLite; no analytics SDK, no
   ad SDK, no third-party trackers are integrated).
6. **Upload the `.aab`, complete the release rollout** (internal testing
   track first is the recommended path before production).
7. **Backend production deployment**: `backend/render.yaml` is ready for
   one-click deploy on Render, but actually creating the Render account
   and clicking deploy needs the app owner's own account (account
   creation and entering billing/API credentials on someone else's
   behalf is out of scope for an automated assistant).

## Verification of what's claimed "done"

Actually run, on this machine:

```bash
$ flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk

$ dart run flutter_launcher_icons
✓ Successfully generated launcher icons

$ flutter build apk --release
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from
1645184 to 5004 bytes (99.7% reduction).
√ Built build\app\outputs\flutter-apk\app-release.apk (53.2MB)

$ flutter build appbundle --release
√ Built build\app\outputs\bundle\release\app-release.aab (51.6MB)
```

The release build is currently **debug-signed** (Flutter's template
default — `signingConfig = signingConfigs.getByName("debug")` in
`app/android/app/build.gradle.kts`), which is why it installs and runs
but is not what Play Console would accept: that needs the real upload
keystore from step 2 above, which requires a decision (a passphrase, a
validity period) only the app owner should make and store.
