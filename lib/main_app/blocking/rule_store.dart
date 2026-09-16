import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'rule.dart';

class RuleStore {
  RuleStore({this.databasePath});

  static const _databaseName = 'serensync.db';
  static const _schemaVersion = 2;

  final String? databasePath;
  Future<Database>? _database;

  Future<List<BlockRule>> readAll() {
    return _run((database) async {
      final rows = await database.query('rules', orderBy: 'id ASC');
      final packages = await _readTargets(database, 'rule_packages', 'package');
      final websites = await _readTargets(database, 'rule_websites', 'website');
      final keywords = await _readTargets(database, 'rule_keywords', 'keyword');

      final rules = <BlockRule>[];
      for (final row in rows) {
        final id = row['id'] as int;
        rules.add(
          BlockRule(
            id: id,
            name: row['name'] as String,
            packages: packages[id] ?? <String>{},
            websites: websites[id] ?? <String>{},
            keywords: keywords[id] ?? <String>{},
            trigger: _decodeTrigger(
              row['trigger_type'] as String,
              row['trigger_json'] as String,
            ),
            enabled: (row['enabled'] as int) == 1,
          ),
        );
      }
      return rules;
    });
  }

  Future<int> insert(BlockRule rule) {
    return _run(
      (database) => database.transaction((transaction) async {
        final id = await transaction.insert('rules', _ruleValues(rule));
        await _insertTargets(transaction, id, rule);
        return id;
      }),
    );
  }

  Future<void> update(BlockRule rule) {
    return _run(
      (database) => database.transaction((transaction) async {
        await transaction.update(
          'rules',
          _ruleValues(rule),
          where: 'id = ?',
          whereArgs: <Object?>[rule.id],
        );
        for (final table in _targetTables) {
          await transaction.delete(
            table,
            where: 'rule_id = ?',
            whereArgs: <Object?>[rule.id],
          );
        }
        await _insertTargets(transaction, rule.id, rule);
      }),
    );
  }

  Future<void> delete(int id) {
    return _run(
      (database) =>
          database.delete('rules', where: 'id = ?', whereArgs: <Object?>[id]),
    );
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) {
      await (await database).close();
    }
  }

  // The native handle is shared with the blocking service's isolate and can
  // be closed from there; drop it and open once more. A failed open is not
  // cached either, so a retry gets a fresh attempt.
  Future<T> _run<T>(Future<T> Function(Database database) work) async {
    try {
      return await work(await _getDatabase());
    } on DatabaseException catch (error) {
      if (!error.isDatabaseClosedError()) rethrow;
      _database = null;
      return work(await _getDatabase());
    }
  }

  Future<Database> _getDatabase() async {
    try {
      return await (_database ??= _openDatabase());
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final path = databasePath ?? '${await getDatabasesPath()}/$_databaseName';
    return openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) => _migrate(database, 0, version),
      onUpgrade: _migrate,
    );
  }
}

const _targetTables = ['rule_packages', 'rule_websites', 'rule_keywords'];

Future<void> _migrate(Database database, int oldVersion, int newVersion) async {
  if (oldVersion < 1) {
    await database.execute('''
      CREATE TABLE rules (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        enabled       INTEGER NOT NULL,
        trigger_type  TEXT    NOT NULL,
        trigger_json  TEXT    NOT NULL
      )
    ''');
    await _createTargetTable(database, 'rule_packages', 'package');
  }
  if (oldVersion < 2) {
    await _createTargetTable(database, 'rule_websites', 'website');
    await _createTargetTable(database, 'rule_keywords', 'keyword');
  }
}

Future<void> _createTargetTable(
  Database database,
  String table,
  String column,
) {
  return database.execute('''
    CREATE TABLE $table (
      rule_id  INTEGER NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
      $column  TEXT    NOT NULL,
      PRIMARY KEY (rule_id, $column)
    )
  ''');
}

Future<Map<int, Set<String>>> _readTargets(
  Database database,
  String table,
  String column,
) async {
  final targets = <int, Set<String>>{};
  for (final row in await database.query(table)) {
    targets
        .putIfAbsent(row['rule_id'] as int, () => <String>{})
        .add(row[column] as String);
  }
  return targets;
}

Map<String, Object?> _ruleValues(BlockRule rule) {
  final trigger = _encodeTrigger(rule.trigger);
  return <String, Object?>{
    'name': rule.name,
    'enabled': rule.enabled ? 1 : 0,
    'trigger_type': trigger.type,
    'trigger_json': trigger.json,
  };
}

Future<void> _insertTargets(
  DatabaseExecutor database,
  int ruleId,
  BlockRule rule,
) async {
  await _insertValues(
    database,
    'rule_packages',
    'package',
    ruleId,
    rule.packages,
  );
  await _insertValues(
    database,
    'rule_websites',
    'website',
    ruleId,
    rule.websites,
  );
  await _insertValues(
    database,
    'rule_keywords',
    'keyword',
    ruleId,
    rule.keywords,
  );
}

Future<void> _insertValues(
  DatabaseExecutor database,
  String table,
  String column,
  int ruleId,
  Set<String> values,
) async {
  for (final value in values) {
    await database.insert(table, <String, Object?>{
      'rule_id': ruleId,
      column: value,
    });
  }
}

({String type, String json}) _encodeTrigger(Trigger trigger) {
  return switch (trigger) {
    final Schedule schedule => (
      type: 'schedule',
      json: jsonEncode(<String, Object?>{
        'weekdays': schedule.weekdays.toList(),
        'startMinute': schedule.startMinute,
        'endMinute': schedule.endMinute,
        'allDay': schedule.allDay,
        'times': [
          for (final time in schedule.times)
            <String, int>{
              'startMinute': time.startMinute,
              'endMinute': time.endMinute,
            },
        ],
      }),
    ),
    final UsageQuota quota => (
      type: 'usage_quota',
      json: jsonEncode(<String, Object?>{
        'limitMicroseconds': quota.limit.inMicroseconds,
      }),
    ),
    final LaunchQuota quota => (
      type: 'launch_quota',
      json: jsonEncode(<String, Object?>{'limit': quota.limit}),
    ),
  };
}

Trigger _decodeTrigger(String type, String value) {
  final payload = jsonDecode(value) as Map<String, Object?>;
  return switch (type) {
    'schedule' => _decodeSchedule(payload),
    'usage_quota' => UsageQuota(
      Duration(microseconds: payload['limitMicroseconds'] as int),
    ),
    'launch_quota' => LaunchQuota(payload['limit'] as int),
    _ => throw FormatException('Unknown trigger type: $type'),
  };
}

Schedule _decodeSchedule(Map<String, Object?> payload) {
  final encodedTimes = payload['times'];
  final times = encodedTimes is List<Object?>
      ? [
          for (final value in encodedTimes)
            ScheduleTime(
              startMinute:
                  (value as Map<String, Object?>)['startMinute'] as int,
              endMinute: value['endMinute'] as int,
            ),
        ]
      : <ScheduleTime>[];
  final first = times.isEmpty
      ? ScheduleTime(
          startMinute: payload['startMinute'] as int,
          endMinute: payload['endMinute'] as int,
        )
      : times.first;
  return Schedule(
    weekdays: (payload['weekdays'] as List<Object?>)
        .map((value) => value as int)
        .toSet(),
    startMinute: first.startMinute,
    endMinute: first.endMinute,
    additionalTimes: times.skip(1).toList(),
    allDay: payload['allDay'] as bool? ?? false,
  );
}
