# SerenSync

SerenSync is an Android-only Flutter launcher with a built-in app blocker. It
combines a quiet home screen with rules that interrupt distracting app use.

## What works

- Minimal home screen with a clock, phone shortcut, and camera shortcut
- Alphabetical app drawer with live search and package-change refresh
- Persisted app list so the drawer can render before Android finishes a scan
- App launch, system app settings, and uninstall actions
- Schedule limits, including overnight windows
- Daily foreground-time and launch-count limits
- Enable, edit, and delete limits
- Full-screen blocking overlay with a return-home action
- Guided setup for usage access, overlays, notifications, and battery
  optimisation
- Foreground blocking service that restarts after boot and app updates

SerenSync deliberately has no accounts, analytics, backend, accessibility
service, uninstall protection, or non-Android platform support.

## Project layout

```text
lib/
  apps/        app discovery, persistence, search, and launch actions
  blocking/    pure rule evaluation, persistence, engine, overlay, and UI
  home/        launcher home screen and shortcuts
  onboarding/  permission setup and blocking-service controls
  settings/    settings navigation
```

The main product logic lives in `lib/blocking/rule.dart`. It is pure Dart:
plugins, Flutter APIs, and ambient clock access do not cross that boundary.
Usage totals come from Android on demand and are never accumulated locally.

## Run locally

Requirements:

- Flutter 3.44.6 or a compatible stable release
- An Android device or emulator

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Set SerenSync as the Home app under **Settings → Apps → Default apps → Home
app**.

The rule evaluator, persistence, widgets, and engine coordination are covered
by automated tests. Foreground detection, overlay reliability, reboot
recovery, and battery behavior still require a physical Android device.

## Android permissions

| Permission | Purpose |
|---|---|
| `QUERY_ALL_PACKAGES` | List launchable apps |
| `REQUEST_DELETE_PACKAGES` | Open Android's uninstall flow |
| `PACKAGE_USAGE_STATS` | Detect the foreground app and read today's usage |
| `SYSTEM_ALERT_WINDOW` | Display the blocking overlay |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Keep the blocking engine running |
| `POST_NOTIFICATIONS` | Show the required foreground-service notification |
| `RECEIVE_BOOT_COMPLETED` | Restart blocking after reboot |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reduce background process killing |

Usage data stays on the device.
