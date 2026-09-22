import 'package:tamper_guard/tamper_guard.dart';

import '../strict/strict_guard.dart';
import 'rule.dart';

typedef BrowserAddress = ({String browser, WebAddress? address});

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

/// The address bars the service reads.
List<TextWatch> get browserWatches => [
  for (final MapEntry(key: browser, value: viewId)
      in browserAddressBars.entries)
    TextWatch(packageName: browser, viewId: '$browser:id/$viewId'),
];

/// The address a supported browser shows, or null when [change] is not a
/// browser's address bar.
BrowserAddress? browserAddressFrom(TextChange change) {
  final viewId = browserAddressBars[change.packageName];
  if (viewId == null || change.viewId != '${change.packageName}:id/$viewId') {
    return null;
  }
  return (browser: change.packageName, address: parseAddress(change.text));
}

/// What the accessibility service reports from the watched packages.
class ScreenWatcher {
  ScreenWatcher({Stream<TextChange>? texts, Stream<WindowChange>? windows})
    : _texts = texts ?? TamperGuard.textChanges,
      _windows = windows ?? TamperGuard.windowChanges;

  final Stream<TextChange> _texts;
  final Stream<WindowChange> _windows;

  /// Address changes in supported browsers.
  Stream<BrowserAddress> addresses() => _texts
      .map(browserAddressFrom)
      .where((address) => address != null)
      .cast<BrowserAddress>();

  /// The package of each window that comes to the front, the moment it
  /// does; faster than the usage-stats poll, but only for watched packages.
  Stream<String> screens() => _windows.map((window) => window.packageName);
}
