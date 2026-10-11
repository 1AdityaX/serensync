# Changelog

All notable changes to SerenSync are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A Today tab, opened first, with a greeting, what is blocked right now, a
  setup checklist for missing permissions, screen time against yesterday and
  quick actions.
- An on/off switch and a plain-language status on every block, undo after
  deleting one, and starter ideas when there are none.
- Icon tiles and a one-line summary in the block editor.
- One-tap focus length presets.
- A custom icon set and small illustrations, drawn in code.
- A Settings screen that explains each permission and opens Android's home
  app picker.
- Strict mode with PIN, charger, timer, and schedule unlock conditions, an
  optional cooldown, an emergency unlock, and locks for blocks, the Settings
  app, the recent-apps screen, newly installed apps, and uninstalling through
  a device-administrator registration.
- Pomodoro focus sessions that lock chosen blocks during focus, with a
  notification countdown and an alert when a phase ends.
- First-open intro with a short story and one screen per permission, shown
  once before the dashboard.
- Manual release workflow that builds a release APK and publishes a GitHub release.
- Schedule, foreground-time, and launch-count app limits.
- Website and keyword blocking in supported browsers, read from the address
  bar through an accessibility service.
- Accessibility permission in the setup flow and the block editor.
- Rule persistence, editing, and enable/disable controls.
- Permission setup and foreground blocking-service controls.
- A blocking overlay with a return-home action.

### Changed

- A clean, minimal light look: black ink on near-white, one blue accent,
  flat surfaces, the bundled Inter typeface and much less text.
- The tabs are now Today, Focus, Blocks, Strict and Insights; Settings moved
  behind the gear in the top bar.
- The block screen shows a breathing circle and "Pause" instead of
  "Blocked".
- The home screen clock drops the ticking seconds and shows the date.

- The blocking service now starts and stops by itself; the manual switch and
  the App blocking settings screen are gone.
- The launcher's settings entry opens the main app.
- Removed generated non-Android platform projects.
- Removed settings and app actions that only opened placeholders.

## [0.2.1] - 2026-07-23

### Fixed

- Launcher shortcuts now resolve correctly.
- Launcher state is preserved across restarts; the app list refreshes only when
  packages change.

### Changed

- Reorganised the codebase into a feature-first structure.

## [0.2] - 2023-12-14

### Added

- App listing and launching through `AppsHandler`.
- Settings screens for launcher configuration.

## [0.1] - 2023-11-20

### Added

- Initial launcher with clock widget and app drawer.
