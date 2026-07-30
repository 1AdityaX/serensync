import 'package:sqflite/sqflite.dart';

import 'installed_app.dart';

class AppStore {
  AppStore({this.databasePath});

  static const _databaseName = 'serensync_apps.db';
  static const _schemaVersion = 1;

  final String? databasePath;
  Future<Database>? _database;

  Future<List<InstalledApp>> readAll() async {
    final database = await _getDatabase();
    final rows = await database.query('apps', orderBy: 'display_name ASC');
    return [
      for (final row in rows)
        InstalledApp(
          displayName: row['display_name'] as String,
          packageName: row['package_name'] as String,
          activityName: row['activity_name'] as String?,
        ),
    ];
  }

  Future<void> replaceAll(List<InstalledApp> apps) async {
    final database = await _getDatabase();
    await database.transaction((transaction) async {
      await transaction.delete('apps');
      for (final app in apps) {
        await transaction.insert('apps', <String, Object?>{
          'display_name': app.displayName,
          'package_name': app.packageName,
          'activity_name': app.activityName,
        });
      }
    });
  }

  Future<Database> _getDatabase() {
    return _database ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    final path = databasePath ?? '${await getDatabasesPath()}/$_databaseName';
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (database, _) => database.execute('''
        CREATE TABLE apps (
          display_name  TEXT NOT NULL,
          package_name  TEXT NOT NULL,
          activity_name TEXT
        )
      '''),
    );
  }
}
