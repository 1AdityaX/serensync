import 'dart:async';
import 'dart:io';

import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:serensync/main_app/blocking/screen_watcher.dart';
import 'package:serensync/main_app/strict/strict_guard.dart';

const _chrome = 'com.android.chrome';
const _chromeBar = 'com.android.chrome:id/url_bar';

void main() {
  test('reads the address bar from the event subtree', () {
    final change = browserAddressFrom(
      _event(
        _chrome,
        nodes: [
          _node('com.android.chrome:id/toolbar', null),
          _node(_chromeBar, 'https://www.instagram.com/reels'),
        ],
      ),
    )!;

    expect(change.browser, _chrome);
    expect(change.address!.host, 'instagram.com');
    expect(change.address!.url, 'instagram.com/reels');
  });

  test('reads the address bar when it is the event source', () {
    final change = browserAddressFrom(
      _event(
        'org.mozilla.firefox',
        nodeId: 'org.mozilla.firefox:id/mozac_browser_toolbar_url_view',
        text: 'reddit.com/r/all',
      ),
    )!;

    expect(change.browser, 'org.mozilla.firefox');
    expect(change.address!.host, 'reddit.com');
  });

  test('reports a browser that shows no page', () {
    final placeholder = browserAddressFrom(
      _event(_chrome, nodes: [_node(_chromeBar, 'Search or type URL')]),
    )!;
    final missingText = browserAddressFrom(
      _event(_chrome, nodes: [_node(_chromeBar, null)]),
    )!;

    expect(placeholder.browser, _chrome);
    expect(placeholder.address, isNull);
    expect(missingText.address, isNull);
  });

  test('ignores other apps and events without the address bar', () {
    expect(
      browserAddressFrom(
        _event(
          'com.example.app',
          nodes: [_node('com.example.app:id/url_bar', 'instagram.com')],
        ),
      ),
      isNull,
    );
    expect(
      browserAddressFrom(
        _event(
          _chrome,
          nodes: [_node('com.android.chrome:id/toolbar', 'instagram.com')],
        ),
      ),
      isNull,
    );
  });

  test('the accessibility service config lists every watched package', () {
    final config = File(
      'android/app/src/main/res/xml/accessibilityservice.xml',
    ).readAsStringSync();
    final packages = RegExp(
      r'android:packageNames="([^"]*)"',
    ).firstMatch(config)!.group(1)!.split(',');

    expect(packages.toSet(), watchedPackages);
  });

  test('listens to events only while the service is enabled', () async {
    var listens = 0;
    var cancels = 0;
    final enabled = StreamController<bool>();
    final events = StreamController<AccessibilityEvent>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    final received = <BrowserAddress>[];
    final subscription = ScreenWatcher(
      enabled: enabled.stream,
      events: events.stream,
    ).addresses().listen(received.add);

    enabled.add(false);
    await pumpEventQueue();
    expect(listens, 0);

    enabled.add(true);
    await pumpEventQueue();
    expect(listens, 1);
    events.add(_event(_chrome, nodes: [_node(_chromeBar, 'instagram.com')]));
    await pumpEventQueue();
    expect(received.single.address!.host, 'instagram.com');

    enabled.add(false);
    await pumpEventQueue();
    expect(cancels, 1);

    enabled.add(true);
    await pumpEventQueue();
    expect(listens, 2);

    await subscription.cancel();
    expect(cancels, 2);
    await enabled.close();
    await events.close();
  });

  test('the device admin label matches the manifest string', () {
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final label = RegExp(
      r'<string name="device_admin_label">([^<]*)</string>',
    ).firstMatch(strings)!.group(1);

    expect(label, deviceAdminLabel);
  });

  test('the device admin screen is told apart by its admin row', () {
    final own = screenFrom(
      _event(
        'com.android.settings',
        nodes: [
          _node('com.android.settings:id/admin_name', deviceAdminLabel),
          _node('com.android.settings:id/admin_description', 'Locks blocks'),
        ],
      )..eventType = EventType.typeWindowStateChanged,
    )!;
    final other = screenFrom(
      _event(
        'com.android.settings',
        nodes: [_node('com.android.settings:id/admin_name', 'Find My Device')],
      )..eventType = EventType.typeWindowStateChanged,
    )!;
    final elsewhere = screenFrom(
      _event(
        _chrome,
        nodes: [_node('com.android.settings:id/admin_name', deviceAdminLabel)],
      )..eventType = EventType.typeWindowStateChanged,
    )!;

    expect(own.ownAdmin, isTrue);
    expect(other.ownAdmin, isFalse);
    expect(elsewhere.ownAdmin, isFalse);
  });

  test('screens report each window that appears', () async {
    final enabled = StreamController<bool>();
    final events = StreamController<AccessibilityEvent>.broadcast();
    final screens = <Screen>[];
    final subscription = ScreenWatcher(
      enabled: enabled.stream,
      events: events.stream,
    ).screens().listen(screens.add);
    enabled.add(true);
    await pumpEventQueue();

    events.add(
      _event('com.android.settings')
        ..eventType = EventType.typeWindowStateChanged,
    );
    events.add(
      _event('com.android.settings')
        ..eventType = EventType.typeWindowContentChanged,
    );
    events.add(_event(_chrome)..eventType = EventType.typeWindowStateChanged);
    await pumpEventQueue();

    expect(screens.map((screen) => screen.package), [
      'com.android.settings',
      _chrome,
    ]);
    expect(screens.every((screen) => !screen.ownAdmin), isTrue);
    await subscription.cancel();
    await enabled.close();
    await events.close();
  });
}

AccessibilityEvent _event(
  String package, {
  String? nodeId,
  String? text,
  List<Map<String, Object?>> nodes = const [],
}) {
  return AccessibilityEvent.fromMap(<String, Object?>{
    'packageName': package,
    'nodeId': nodeId,
    'capturedText': text,
    'subNodesActions': nodes,
  });
}

Map<String, Object?> _node(String id, String? text) {
  return <String, Object?>{'nodeId': id, 'capturedText': text};
}
