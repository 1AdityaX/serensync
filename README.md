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
- Website and keyword blocking in supported browsers, read from the address
  bar through an accessibility service
- Enable, edit, and delete limits
- Full-screen blocking overlay with a return-home action for apps and a
  go-back action for pages
- First-open intro that explains the problem, then walks through usage
  access, overlays, notifications, battery optimisation, and accessibility
  one permission at a time
- Pomodoro focus sessions that lock chosen blocks for each focus round, with
  adjustable focus, break and long-break lengths, a countdown in the
  notification shade and an alert when a phase ends
- Strict mode that locks blocks behind a PIN, a charger, a timer, your
  schedules, or any combination, with an optional cooldown and an emergency
  unlock; while on, blocks can only be tightened, and the Settings app, the
  recent-apps screen, and newly installed apps can be blocked, while a
  device-administrator registration keeps the app installed
- Foreground blocking service that starts by itself while a block is enabled,
  a focus session runs, or strict mode guards apps, and restarts after boot
  and app updates

SerenSync deliberately has no accounts, analytics, backend, or non-Android
platform support. Browsing time is not measured, so usage and launch limits
block their websites and keywords all day. Strict mode's uninstall lock uses
the legacy device-administrator API with no policies; Android still lets the
admin be removed from Settings, which is why that lock always turns on the
Settings lock, and nothing stops Safe mode or a computer with developer tools.

## Project layout

```text
lib/
  apps/        app discovery, persistence, search, and launch actions
  blocking/    pure rule evaluation, persistence, engine, overlay, and UI
  home/        launcher home screen and shortcuts
  onboarding/  first-open intro and permission walkthrough
  pomodoro/    focus sessions, their persistence and the phase alert
  strict/      strict mode model, persistence, guarded packages, and tab
```

The main product logic lives in `lib/main_app/blocking/rule.dart`. It is pure
Dart: plugins, Flutter APIs, and ambient clock access do not cross that
boundary. Usage totals come from Android on demand and are never accumulated
locally. Supported browsers and their address-bar view ids live in
`lib/main_app/blocking/browser_watcher.dart`; the accessibility service config
in `android/app/src/main/res/xml/accessibilityservice.xml` lists the same
packages, and a test keeps the two in sync.

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
| `BIND_ACCESSIBILITY_SERVICE` | Read the address bar of supported browsers for website and keyword blocks |
| `BIND_DEVICE_ADMIN` (receiver) | Keep SerenSync installed while strict mode's uninstall lock is on |
| `VIBRATE` | Buzz when a focus round or break ends |

Usage data stays on the device.
