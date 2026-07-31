import '../../database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<Map<String, String>> getAllSettings() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('settings');
    final Map<String, String> settingsMap = {};
    for (final map in maps) {
      settingsMap[map['key'] as String] = map['value'] as String;
    }
    return settingsMap;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _databaseHelper.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  Future<void> saveAllSettings(Map<String, String> settingsMap) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      for (final entry in settingsMap.entries) {
        await txn.rawInsert(
          'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
          [entry.key, entry.value],
        );
      }
    });
  }
}
