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

SerenSync follows **feature-based clean architecture**:

```
lib/
├── core/
│   └── router/
│       └── app_router.dart          # Centralized route definitions
├── features/
│   ├── apps/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── app_repository_impl.dart
│   │   ├── domain/
│   │   │   └── repositories/
│   │   │       └── app_repository.dart   # Abstract interface
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── app_provider.dart     # Riverpod providers
│   │       ├── screens/
│   │       │   └── apps_screen.dart
│   │       └── widgets/
│   │           ├── app_options_dialog.dart
│   │           └── app_search_bar.dart
│   ├── home/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           └── clock_widget.dart
│   └── settings/
│       ├── domain/
│       │   └── models/
│       │       └── settings_item.dart
│       └── presentation/
│           ├── screens/
│           │   ├── settings_screen.dart
│           │   └── settings_features/   # One screen per setting
│           └── widgets/
│               └── settings_list_item.dart
└── main.dart
```

**State management:** [Riverpod](https://riverpod.dev) (`flutter_riverpod ^3.x`)

**Key providers** (in `features/apps/presentation/providers/app_provider.dart`):

| Provider | Type | Purpose |
|---|---|---|
| `appRepositoryProvider` | `Provider<AppRepository>` | Single source of truth for the app repository |
| `appsProvider` | `AsyncNotifierProvider` | Fetches and caches the installed apps list; auto-refreshes on installs/uninstalls |
| `searchQueryProvider` | `NotifierProvider<String>` | Current search bar text |
| `filteredAppsProvider` | `Provider<AsyncValue<List>>` | Derives filtered list from `appsProvider` + `searchQueryProvider` |

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.11.0`
- Android device or emulator (API 21+)
- ADB connected or emulator running

### Setup

```bash
git clone <repo-url>
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
| `flutter_riverpod` | `^3.2.1` | State management |
| `apps_handler` | `^1.0.1` | Native plugin for listing, launching, and managing apps |
| `intl` | `^0.20.2` | Clock time formatting |
| `cupertino_icons` | `^1.0.8` | iOS-style icons |

---

## Home Screen Shortcuts

The Phone and Camera shortcuts on the home screen use standard AOSP package names:

```dart
const _phonePackage  = 'com.android.dialer';
const _cameraPackage = 'com.android.camera2';
```

These may differ on some manufacturer ROMs (Samsung, Xiaomi, etc.). Configurable shortcut selection is planned as part of the Settings feature.

---

## Development Notes

- All navigation is centralized through `AppRouter` in `core/router/`
- The search bar manages its own `TextEditingController` and syncs with `searchQueryProvider` via `ref.listen` — clearing the provider (e.g., on app tap) automatically clears the text field
- The app stream subscription in `AppsNotifier` is cancelled via `ref.onDispose` to prevent memory leaks
- Settings screens under `settings_features/` are currently placeholder stubs
