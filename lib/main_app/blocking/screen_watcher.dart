import 'dart:async';

import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';

import '../strict/strict_guard.dart';
import 'rule.dart';

typedef BrowserAddress = ({String browser, WebAddress? address});

/// A window that came to the front. [ownAdmin] marks Settings showing this
/// app's device-admin entry, the one screen where it can be deactivated.
typedef Screen = ({String package, bool ownAdmin});

/// Every package the accessibility service listens to. Keep in sync with
/// packageNames in android/app/src/main/res/xml/accessibilityservice.xml.
Set<String> get watchedPackages => {
  ...browserAddressBars.keys,
  ...settingsPackages,
  ...installerPackages,
};

/// Address-bar view ids of the browsers whose pages can be blocked.
const browserAddressBars = <String, String>{
  'com.android.chrome': 'url_bar',
  'com.chrome.beta': 'url_bar',
  'com.chrome.dev': 'url_bar',
  'com.chrome.canary': 'url_bar',
  'com.brave.browser': 'url_bar',
  'com.brave.browser_beta': 'url_bar',
  'com.microsoft.emmx': 'url_bar',
  'com.kiwibrowser.browser': 'url_bar',
  'com.vivaldi.browser': 'url_bar',
  'com.ecosia.android': 'url_bar',
  'app.vanadium.browser': 'url_bar',
  'org.mozilla.firefox': 'mozac_browser_toolbar_url_view',
  'org.mozilla.firefox_beta': 'mozac_browser_toolbar_url_view',
  'org.mozilla.fenix': 'mozac_browser_toolbar_url_view',
  'org.mozilla.focus': 'mozac_browser_toolbar_url_view',
  'org.torproject.torbrowser': 'mozac_browser_toolbar_url_view',
  'com.opera.browser': 'url_field',
  'com.opera.browser.beta': 'url_field',
  'com.opera.mini.native': 'url_field',
  'com.opera.mini.native.beta': 'url_field',
  'com.duckduckgo.mobile.android': 'omnibarTextInput',
  'com.sec.android.app.sbrowser': 'location_bar_edit_text',
  'com.sec.android.app.sbrowser.beta': 'location_bar_edit_text',
  'com.coloros.browser': 'azt',
};

/// The address a supported browser shows in [event], or null when the event
/// does not carry that browser's address bar.
BrowserAddress? browserAddressFrom(AccessibilityEvent event) {
  final browser = event.packageName;
  final viewId = browserAddressBars[browser];
  if (browser == null || viewId == null) return null;

  final addressBar = '$browser:id/$viewId';
  for (final node in <AccessibilityEvent>[event, ...?event.subNodes]) {
    if (node.nodeId == addressBar) {
      return (browser: browser, address: parseAddress(_text(node)));
    }
  }
  return null;
}

Screen? screenFrom(AccessibilityEvent event) {
  final package = event.packageName;
  if (package == null || event.eventType != EventType.typeWindowStateChanged) {
    return null;
  }
  return (
    package: package,
    ownAdmin:
        settingsPackages.contains(package) &&
        <AccessibilityEvent>[event, ...?event.subNodes].any(
          (node) =>
              (node.nodeId?.endsWith(':id/admin_name') ?? false) &&
              _text(node) == deviceAdminLabel,
        ),
  );
}

// The plugin stringifies a missing text as 'null'.
String _text(AccessibilityEvent node) {
  return switch (node.text) {
    null || 'null' => '',
    final text => text,
  };
}

/// Accessibility events from the packages in [watchedPackages].
class ScreenWatcher {
  ScreenWatcher({Stream<bool>? enabled, Stream<AccessibilityEvent>? events})
    : _enabled =
          enabled ??
          FlutterAccessibilityService.onAccessibilityServiceStatusChanged,
      _events = events ?? FlutterAccessibilityService.accessStream;

  final Stream<bool> _enabled;
  final Stream<AccessibilityEvent> _events;

  /// Address changes in supported browsers.
  Stream<BrowserAddress> addresses() => _whileEnabled(browserAddressFrom);

  /// Each window from a package in [watchedPackages] as it comes to the
  /// front; faster than the usage-stats poll, but blind to other packages.
  Stream<Screen> screens() => _whileEnabled(screenFrom);

  // The plugin only delivers events to subscriptions made while the
  // accessibility service is enabled, so the event stream is subscribed
  // afresh each time the service is enabled.
  Stream<T> _whileEnabled<T extends Object>(
    T? Function(AccessibilityEvent event) map,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<bool>? enabled;
    StreamSubscription<AccessibilityEvent>? events;
    controller = StreamController<T>(
      onListen: () {
        enabled = _enabled.listen((isEnabled) {
          if (!isEnabled) {
            unawaited(events?.cancel());
            events = null;
            return;
          }
          events ??= _events.listen((event) {
            final value = map(event);
            if (value != null) controller.add(value);
          });
        });
      },
      onCancel: () async {
        await enabled?.cancel();
        await events?.cancel();
      },
    );
    return controller.stream;
  }
}
