import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'rule.dart';

class RuleStore {
  RuleStore({this.databasePath});

  static const _databaseName = 'serensync.db';
  static const _schemaVersion = 1;

  final String? databasePath;
  Future<Database>? _database;

  Future<List<BlockRule>> readAll() async {
    final database = await _getDatabase();
    final rows = await database.rawQuery('''
      SELECT
        rules.id,
        rules.name,
        rules.enabled,
        rules.trigger_type,
        rules.trigger_json,
        rule_packages.package
      FROM rules
      LEFT JOIN rule_packages ON rule_packages.rule_id = rules.id
      ORDER BY rules.id ASC
    ''');

    final rules = <BlockRule>[];
    int? currentId;
    late Set<String> packages;
    for (final row in rows) {
      final id = row['id'] as int;
      if (id != currentId) {
        packages = <String>{};
        rules.add(
          BlockRule(
            id: id,
            name: row['name'] as String,
            packages: packages,
            trigger: _decodeTrigger(
              row['trigger_type'] as String,
              row['trigger_json'] as String,
            ),
            enabled: (row['enabled'] as int) == 1,
          ),
        );
        currentId = id;
      }

      final package = row['package'] as String?;
      if (package != null) {
        packages.add(package);
      }
    }
    return rules;
  }

  Future<int> insert(BlockRule rule) async {
    final database = await _getDatabase();
    return database.transaction((transaction) async {
      final id = await transaction.insert('rules', _ruleValues(rule));
      await _insertPackages(transaction, id, rule.packages);
      return id;
    });
  }

  Future<void> update(BlockRule rule) async {
    final database = await _getDatabase();
    await database.transaction((transaction) async {
      await transaction.update(
        'rules',
        _ruleValues(rule),
        where: 'id = ?',
        whereArgs: <Object?>[rule.id],
      );
      await transaction.delete(
        'rule_packages',
        where: 'rule_id = ?',
        whereArgs: <Object?>[rule.id],
      );
      await _insertPackages(transaction, rule.id, rule.packages);
    });
  }

  Future<void> delete(int id) async {
    final database = await _getDatabase();
    await database.delete('rules', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) {
      await (await database).close();
    }
  }

  Future<Database> _getDatabase() {
    return _database ??= _openDatabase();
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
    await database.execute('''
      CREATE TABLE rule_packages (
        rule_id  INTEGER NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
        package  TEXT    NOT NULL,
        PRIMARY KEY (rule_id, package)
      )
    ''');
  }
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

Future<void> _insertPackages(
  DatabaseExecutor database,
  int ruleId,
  Set<String> packages,
) async {
  for (final package in packages) {
    await database.insert('rule_packages', <String, Object?>{
      'rule_id': ruleId,
      'package': package,
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
    'schedule' => Schedule(
      weekdays: (payload['weekdays'] as List<Object?>)
          .map((value) => value as int)
          .toSet(),
      startMinute: payload['startMinute'] as int,
      endMinute: payload['endMinute'] as int,
    ),
    'usage_quota' => UsageQuota(
      Duration(microseconds: payload['limitMicroseconds'] as int),
    ),
    'launch_quota' => LaunchQuota(payload['limit'] as int),
    _ => throw FormatException('Unknown trigger type: $type'),
  };
}
