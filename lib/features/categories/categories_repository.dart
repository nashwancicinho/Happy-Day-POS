import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/category.dart';

class CategoriesRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('categories', orderBy: 'id ASC');
    return maps.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
