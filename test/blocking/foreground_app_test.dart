import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/blocking/foreground_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('usage_stats');
  const packageName = 'com.example.target';
  final now = DateTime(2026, 7, 27, 12);
  late List<MethodCall> calls;
  late List<Map<String, String?>> events;
  late List<Map<String, String?>> stats;

  setUp(() {
    calls = <MethodCall>[];
    events = <Map<String, String?>>[];
    stats = <Map<String, String?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'queryEvents' => events,
            'queryUsageStats' => stats,
            _ => throw StateError('Unexpected method ${call.method}'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('foreground state uses the latest resume and screen event', () async {
    events = <Map<String, String?>>[
      _event(type: 1, at: now, packageName: packageName),
      _event(
        type: 1,
        at: now.add(const Duration(seconds: 2)),
        packageName: 'com.example.latest',
      ),
      _event(
        type: 2,
        at: now.add(const Duration(seconds: 3)),
        packageName: 'com.example.background',
      ),
      _event(type: 16, at: now.add(const Duration(seconds: 4))),
    ];
    final foreground = ForegroundApp();

    final state = await foreground.foregroundState(
      now.add(const Duration(seconds: 5)),
    );

    expect(state.packageName, 'com.example.latest');
    expect(state.screenInteractive, isFalse);
  });

  test('screen state persists when the next event window is empty', () async {
    events = <Map<String, String?>>[_event(type: 17, at: now)];
    final foreground = ForegroundApp();

    expect((await foreground.foregroundState(now)).screenInteractive, isFalse);
    events = <Map<String, String?>>[];

    final nextState = await foreground.foregroundState(
      now.add(const Duration(minutes: 1)),
    );
    expect(nextState.screenInteractive, isFalse);
  });

  test(
    'long screen-off polling interval cannot miss a screen-on event',
    () async {
      events = <Map<String, String?>>[_event(type: 16, at: now)];
      final foreground = ForegroundApp();
      await foreground.foregroundState(now);
      events = <Map<String, String?>>[
        _event(type: 15, at: now.add(const Duration(seconds: 20))),
      ];

      final state = await foreground.foregroundState(
        now.add(const Duration(minutes: 1)),
      );

      expect(state.screenInteractive, isTrue);
      final interval = calls.last.arguments as Map<Object?, Object?>;
      expect(interval['start'], now.millisecondsSinceEpoch);
    },
  );

  test('today usage counts foreground time and resume events', () async {
    stats = <Map<String, String?>>[
      _usage(packageName: packageName, milliseconds: 1200),
      _usage(packageName: packageName, milliseconds: 800),
      _usage(packageName: 'com.example.other', milliseconds: 9000),
    ];
    events = <Map<String, String?>>[
      _event(type: 1, at: now, packageName: packageName),
      _event(
        type: 1,
        at: now.add(const Duration(seconds: 1)),
        packageName: packageName,
      ),
      _event(
        type: 2,
        at: now.add(const Duration(seconds: 2)),
        packageName: packageName,
      ),
      _event(
        type: 1,
        at: now.add(const Duration(seconds: 3)),
        packageName: 'com.example.other',
      ),
    ];

    final usage = await ForegroundApp().todayUsage(packageName, now);

    expect(usage.foregroundTime, const Duration(seconds: 2));
    expect(usage.launches, 2);
    expect(calls.map((call) => call.method), <String>[
      'queryUsageStats',
      'queryEvents',
    ]);
  });

  test('usage cache expires at ten seconds', () async {
    stats = <Map<String, String?>>[
      _usage(packageName: packageName, milliseconds: 1000),
    ];
    final foreground = ForegroundApp();

    final initial = await foreground.todayUsage(packageName, now);
    stats = <Map<String, String?>>[
      _usage(packageName: packageName, milliseconds: 2000),
    ];
    final cached = await foreground.todayUsage(
      packageName,
      now.add(const Duration(seconds: 9)),
    );
    expect(initial.foregroundTime, const Duration(seconds: 1));
    expect(cached.foregroundTime, const Duration(seconds: 1));
    expect(calls, hasLength(2));

    final refreshed = await foreground.todayUsage(
      packageName,
      now.add(const Duration(seconds: 10)),
    );

    expect(refreshed.foregroundTime, const Duration(seconds: 2));
    expect(calls, hasLength(4));
  });

  test('invalidating usage forces the next read through to the OS', () async {
    stats = <Map<String, String?>>[
      _usage(packageName: packageName, milliseconds: 1000),
    ];
    final foreground = ForegroundApp();

    await foreground.todayUsage(packageName, now);
    stats = <Map<String, String?>>[
      _usage(packageName: packageName, milliseconds: 2000),
    ];
    foreground.invalidateUsage();
    final refreshed = await foreground.todayUsage(packageName, now);

    expect(refreshed.foregroundTime, const Duration(seconds: 2));
    expect(calls, hasLength(4));
  });
}

Map<String, String?> _event({
  required int type,
  required DateTime at,
  String? packageName,
}) {
  return <String, String?>{
    'eventType': '$type',
    'timeStamp': '${at.millisecondsSinceEpoch}',
    'packageName': packageName,
    'className': null,
  };
}

Map<String, String?> _usage({
  required String packageName,
  required int milliseconds,
}) {
  return <String, String?>{
    'packageName': packageName,
    'firstTimeStamp': null,
    'lastTimeStamp': null,
    'lastTimeUsed': null,
    'totalTimeInForeground': '$milliseconds',
  };
}
