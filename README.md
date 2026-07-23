# SerenSync

A minimalist Android launcher built with Flutter. SerenSync strips away distractions and gives you a calm, focused home screen — a clock, two quick-access shortcuts, and a clean alphabetical app drawer.

---

## Features

- **Minimal home screen** — full-screen clock with configurable Phone and Camera shortcuts
- **App drawer** — alphabetically sorted list of all installed apps with live search
- **App options** — long-press any app to open its settings, uninstall it, hide it, or lock it
- **Settings** — modular settings system with dedicated screens for:
  - Monochrome Mode
  - Hidden Apps
  - Renamed Apps
  - Locked Apps
  - Apps Timer
  - Notification Filter
  - Apps Usage
- **Default launcher support** — registers as a HOME intent handler so it can be set as your default launcher

---

## Architecture

SerenSync uses a shallow, feature-first structure. Screens and state stay close
to the feature that owns them, while reusable visual components live in a
feature-local `widgets/` folder.

```
lib/
├── main.dart
├── apps/
│   ├── app_service.dart             # Boundary around the native apps plugin
│   ├── apps_screen.dart             # Installed apps, search, and refresh state
│   └── widgets/
│       ├── app_options_dialog.dart
│       └── app_search_bar.dart
├── home/
│   ├── home_screen.dart
│   └── widgets/
│       └── clock_widget.dart
└── settings/
    └── settings_screen.dart
```

`AppsScreen` owns its loading, filtering, and app-change subscription state.
`AppService` is constructor-injected so the native boundary can be replaced in
tests without a dependency-injection framework.

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.11.0`
- Android device or emulator (API 21+)
- ADB connected or emulator running

### Setup

```bash
git clone https://github.com/1AdityaX/serensync.git
cd serensync
flutter pub get
flutter run
```

### Set as default launcher (Android)

1. Go to **Settings → Apps → Default apps → Home app**
2. Select **SerenSync**

Or, after first launch, press the Home button and choose SerenSync when prompted.

---

## Android Permissions

| Permission | Reason |
|---|---|
| `QUERY_ALL_PACKAGES` | Required to list all installed apps |
| `REQUEST_DELETE_PACKAGES` | Required to trigger app uninstallation |

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `apps_handler` | `^2.0.0` | Native plugin for listing, launching, and managing apps |
| `android_intent_plus` | `^5.3.1` | Opens the default dialer and camera |
| `intl` | `^0.20.2` | Clock time formatting |

---

## Home Screen Shortcuts

Phone uses Android's dial intent and Camera uses Android's still-image camera
intent. Android resolves the correct installed app, so the shortcuts do not
depend on manufacturer-specific package names.

---

## Development Notes

- Navigation uses Flutter's `Navigator` directly.
- The search bar receives its value and callbacks from `AppsScreen`; clearing
  search after an app launch updates both the list and text field.
- `AppsScreen` cancels its native app-change subscription when disposed.
- Settings features are currently represented by a single reusable placeholder
  screen until their behavior is implemented.
