import 'dart:async';

import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';

import 'rule.dart';

typedef BrowserAddress = ({String browser, WebAddress? address});

/// Address-bar view ids of the browsers whose pages can be blocked. Keep in
/// sync with packageNames in android/app/src/main/res/xml/accessibilityservice.xml.
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

// The plugin stringifies a missing text as 'null'.
String _text(AccessibilityEvent node) {
  return switch (node.text) {
    null || 'null' => '',
    final text => text,
  };
}

class BrowserWatcher {
  BrowserWatcher({Stream<bool>? enabled, Stream<AccessibilityEvent>? events})
    : _enabled =
          enabled ??
          FlutterAccessibilityService.onAccessibilityServiceStatusChanged,
      _events = events ?? FlutterAccessibilityService.accessStream;

  final Stream<bool> _enabled;
  final Stream<AccessibilityEvent> _events;

  /// Address changes in supported browsers. The plugin only delivers events
  /// to subscriptions made while the accessibility service is enabled, so the
  /// event stream is subscribed afresh each time the service is enabled.
  Stream<BrowserAddress> addresses() {
    late final StreamController<BrowserAddress> controller;
    StreamSubscription<bool>? enabled;
    StreamSubscription<AccessibilityEvent>? events;
    controller = StreamController<BrowserAddress>(
      onListen: () {
        enabled = _enabled.listen((isEnabled) {
          if (!isEnabled) {
            unawaited(events?.cancel());
            events = null;
            return;
          }
          events ??= _events.listen((event) {
            final address = browserAddressFrom(event);
            if (address != null) controller.add(address);
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
