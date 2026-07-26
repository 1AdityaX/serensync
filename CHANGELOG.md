# Changelog

All notable changes to SerenSync are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Manual release workflow that builds a release APK and publishes a GitHub release.

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
