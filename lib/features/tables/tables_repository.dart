import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/restaurant_floor.dart';
import '../../models/restaurant_table.dart';

class TablesRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<RestaurantFloor>> getAllFloors() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'restaurant_floors',
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map((e) => RestaurantFloor.fromMap(e)).toList();
  }

  Future<int> insertFloor(RestaurantFloor floor) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      'restaurant_floors',
      floor.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateFloor(RestaurantFloor floor) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'restaurant_floors',
      floor.toMap(),
      where: 'id = ?',
      whereArgs: [floor.id],
    );
  }

  Future<int> deleteFloor(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'restaurant_floors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTablesByFloor(int floorId) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'restaurant_tables',
      where: 'floor_id = ?',
      whereArgs: [floorId],
    );
  }

  Future<List<RestaurantTable>> getAllTables() async {
    final db = await _databaseHelper.database;

    final maps = await db.rawQuery('''
      SELECT t.*, 
        CASE 
          WHEN t.status = 1 THEN COALESCE((
            SELECT o.total 
            FROM orders o 
            WHERE o.table_id = t.id AND o.status IN ('OPEN', 'SUSPENDED') 
            ORDER BY o.id DESC 
            LIMIT 1
          ), 0.0)
          ELSE 0.0
        END AS current_order_amount
      FROM restaurant_tables t
      ORDER BY t.sort_order ASC, t.id ASC
    ''');

    return maps.map((e) => RestaurantTable.fromMap(e)).toList();
  }

  Future<int> insertTable(RestaurantTable table) async {
    final db = await _databaseHelper.database;

    return await db.insert(
      'restaurant_tables',
      table.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTable(RestaurantTable table) async {
    final db = await _databaseHelper.database;

    return await db.update(
      'restaurant_tables',
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<int> deleteTable(int id) async {
    final db = await _databaseHelper.database;

    return await db.delete(
      'restaurant_tables',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTableStatus(int id, int status) async {
    final db = await _databaseHelper.database;

    await db.update(
      'restaurant_tables',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTableOrder(int id, int sortOrder) async {
    final db = await _databaseHelper.database;

    await db.update(
      'restaurant_tables',
      {'sort_order': sortOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTableShape(int id, String shape) async {
    final db = await _databaseHelper.database;

    await db.update(
      'restaurant_tables',
      {'shape': shape},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTablePosition(int id, double posX, double posY, {double? width, double? height, String? shape}) async {
    final db = await _databaseHelper.database;
    final Map<String, dynamic> data = {
      'pos_x': posX,
      'pos_y': posY,
    };
    if (width != null) data['width'] = width;
    if (height != null) data['height'] = height;
    if (shape != null) data['shape'] = shape;

    await db.update(
      'restaurant_tables',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
