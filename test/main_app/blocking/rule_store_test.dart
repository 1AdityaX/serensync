import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serensync/blocking/rule.dart';
import 'package:serensync/blocking/rule_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late RuleStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    store = RuleStore(databasePath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await store.close();
  });

  test('reads an empty database', () async {
    expect(await store.readAll(), isEmpty);
  });

  test('round-trips every trigger type and package set', () async {
    final inputs = <BlockRule>[
      const BlockRule(
        id: 90,
        name: 'Work hours',
        packages: {'com.example.mail', 'com.example.video'},
        trigger: Schedule(
          weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
          startMinute: 8 * 60,
          endMinute: 17 * 60,
        ),
        enabled: true,
      ),
      const BlockRule(
        id: 91,
        name: 'Social limit',
        packages: {},
        trigger: UsageQuota(Duration(minutes: 37, microseconds: 12)),
        enabled: false,
      ),
      const BlockRule(
        id: 92,
        name: 'Launch limit',
        packages: {'com.example.game'},
        trigger: LaunchQuota(4),
        enabled: true,
      ),
    ];

    final ids = <int>[];
    for (final rule in inputs) {
      ids.add(await store.insert(rule));
    }

    final stored = await store.readAll();
    expect(stored, hasLength(3));
    for (var index = 0; index < inputs.length; index++) {
      _expectRule(stored[index], inputs[index], expectedId: ids[index]);
    }
  });

  test('update replaces the package set and stored fields', () async {
    final id = await store.insert(
      const BlockRule(
        id: 0,
        name: 'Before',
        packages: {'com.example.one', 'com.example.two'},
        trigger: LaunchQuota(2),
        enabled: true,
      ),
    );
    final replacement = BlockRule(
      id: id,
      name: 'After',
      packages: const {'com.example.three', 'com.example.four'},
      trigger: const UsageQuota(Duration(hours: 1)),
      enabled: false,
    );

    await store.update(replacement);

    final stored = await store.readAll();
    expect(stored, hasLength(1));
    _expectRule(stored.single, replacement, expectedId: id);
  });

  test('delete cascades to package rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'serensync_rule_store_test.',
    );
    final path = '${directory.path}/rules.db';
    final fileStore = RuleStore(databasePath: path);
    try {
      final id = await fileStore.insert(
        const BlockRule(
          id: 0,
          name: 'Temporary',
          packages: {'com.example.one', 'com.example.two'},
          trigger: LaunchQuota(1),
          enabled: true,
        ),
      );
      await fileStore.delete(id);
      await fileStore.close();

      final database = await databaseFactoryFfi.openDatabase(path);
      try {
        expect(await database.query('rule_packages'), isEmpty);
      } finally {
        await database.close();
      }
    } finally {
      await fileStore.close();
      await directory.delete(recursive: true);
    }
  });

  test('enables and disables a rule', () async {
    final id = await store.insert(
      const BlockRule(
        id: 0,
        name: 'Toggle',
        packages: {},
        trigger: LaunchQuota(1),
        enabled: true,
      ),
    );

    await store.update(
      BlockRule(
        id: id,
        name: 'Toggle',
        packages: const {},
        trigger: const LaunchQuota(1),
        enabled: false,
      ),
    );
    expect((await store.readAll()).single.enabled, isFalse);

    await store.update(
      BlockRule(
        id: id,
        name: 'Toggle',
        packages: const {},
        trigger: const LaunchQuota(1),
        enabled: true,
      ),
    );
    expect((await store.readAll()).single.enabled, isTrue);
  });

  test('reads rules in id order', () async {
    for (final name in const ['Zulu', 'Alpha', 'Mike']) {
      await store.insert(
        BlockRule(
          id: 0,
          name: name,
          packages: const {},
          trigger: const LaunchQuota(1),
          enabled: true,
        ),
      );
    }

    final stored = await store.readAll();
    expect(stored.map((rule) => rule.id), orderedEquals(<int>[1, 2, 3]));
    expect(
      stored.map((rule) => rule.name),
      orderedEquals(<String>['Zulu', 'Alpha', 'Mike']),
    );
  });
}

void _expectRule(
  BlockRule actual,
  BlockRule expected, {
  required int expectedId,
}) {
  expect(actual.id, expectedId);
  expect(actual.name, expected.name);
  expect(actual.packages, unorderedEquals(expected.packages));
  expect(actual.enabled, expected.enabled);
  _expectTrigger(actual.trigger, expected.trigger);
}

void _expectTrigger(Trigger actual, Trigger expected) {
  switch ((actual, expected)) {
    case (final Schedule actual, final Schedule expected):
      expect(actual.weekdays, unorderedEquals(expected.weekdays));
      expect(actual.startMinute, expected.startMinute);
      expect(actual.endMinute, expected.endMinute);
    case (final UsageQuota actual, final UsageQuota expected):
      expect(actual.limit, expected.limit);
    case (final LaunchQuota actual, final LaunchQuota expected):
      expect(actual.limit, expected.limit);
    default:
      fail(
        'Trigger type mismatch: ${actual.runtimeType} != '
        '${expected.runtimeType}',
      );
  }
}
