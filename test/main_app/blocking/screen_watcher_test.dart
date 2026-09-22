import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/main_app/blocking/screen_watcher.dart';
import 'package:tamper_guard/tamper_guard.dart';

const _chrome = 'com.android.chrome';
const _chromeBar = 'com.android.chrome:id/url_bar';

void main() {
  test('reads a browser address bar', () {
    final change = browserAddressFrom(
      const TextChange(
        packageName: _chrome,
        viewId: _chromeBar,
        text: 'https://www.instagram.com/reels',
      ),
    )!;

    expect(change.browser, _chrome);
    expect(change.address!.host, 'instagram.com');
    expect(change.address!.url, 'instagram.com/reels');
  });

  test('reports a browser that shows no page', () {
    final placeholder = browserAddressFrom(
      const TextChange(
        packageName: _chrome,
        viewId: _chromeBar,
        text: 'Search or type URL',
      ),
    )!;
    final empty = browserAddressFrom(
      const TextChange(packageName: _chrome, viewId: _chromeBar, text: ''),
    )!;

    expect(placeholder.browser, _chrome);
    expect(placeholder.address, isNull);
    expect(empty.address, isNull);
  });

  test('ignores other apps and other views', () {
    expect(
      browserAddressFrom(
        const TextChange(
          packageName: 'com.example.app',
          viewId: 'com.example.app:id/url_bar',
          text: 'instagram.com',
        ),
      ),
      isNull,
    );
    expect(
      browserAddressFrom(
        const TextChange(
          packageName: _chrome,
          viewId: 'com.android.chrome:id/title',
          text: 'instagram.com',
        ),
      ),
      isNull,
    );
  });

  test('every supported browser has a watch on its address bar', () {
    expect(
      browserWatches.map((watch) => watch.packageName).toSet(),
      browserAddressBars.keys.toSet(),
    );
    for (final watch in browserWatches) {
      expect(
        watch.viewId,
        '${watch.packageName}:id/${browserAddressBars[watch.packageName]}',
      );
    }
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

  test('the service is told to deliver events without batching', () {
    final config = File(
      'android/app/src/main/res/xml/accessibilityservice.xml',
    ).readAsStringSync();

    expect(config, contains('android:notificationTimeout="0"'));
  });

  test('streams map the service events', () async {
    final texts = StreamController<TextChange>();
    final windows = StreamController<WindowChange>();
    final watcher = ScreenWatcher(texts: texts.stream, windows: windows.stream);
    final addresses = <BrowserAddress>[];
    final screens = <String>[];
    watcher.addresses().listen(addresses.add);
    watcher.screens().listen(screens.add);

    texts.add(
      const TextChange(
        packageName: _chrome,
        viewId: _chromeBar,
        text: 'reddit.com/r/all',
      ),
    );
    texts.add(
      const TextChange(
        packageName: 'com.example.app',
        viewId: 'com.example.app:id/url_bar',
        text: 'reddit.com',
      ),
    );
    windows.add(
      const WindowChange(
        packageName: 'com.android.settings',
        className: 'com.android.settings.SubSettings',
      ),
    );
    await pumpEventQueue();

    expect(addresses.single.address!.host, 'reddit.com');
    expect(screens, ['com.android.settings']);
    await texts.close();
    await windows.close();
  });
}
