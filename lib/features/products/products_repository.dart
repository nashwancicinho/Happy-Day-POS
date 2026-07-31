import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/product.dart';

class ProductsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<void> _ensureProductColumns(Database db) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info(products)");
      final colNames = columns.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('unit')) {
        await db.execute("ALTER TABLE products ADD COLUMN unit TEXT DEFAULT 'قطعة';");
      }
      if (!colNames.contains('is_weighted')) {
        await db.execute("ALTER TABLE products ADD COLUMN is_weighted INTEGER DEFAULT 0;");
      }
      if (!colNames.contains('allow_price_change')) {
        await db.execute("ALTER TABLE products ADD COLUMN allow_price_change INTEGER DEFAULT 0;");
      }
    } catch (_) {}
  }

  Future<List<ProductModel>> getAllProducts() async {
    final db = await _databaseHelper.database;
    await _ensureProductColumns(db);
    final maps = await db.query('products', orderBy: 'id DESC');
    return maps.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<List<ProductModel>> getProductsByCategory(int categoryId) async {
    final db = await _databaseHelper.database;
    await _ensureProductColumns(db);
    final maps = await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return maps.map((e) => ProductModel.fromMap(e)).toList();
  }

  Future<int> insertProduct(ProductModel product) async {
    final db = await _databaseHelper.database;
    await _ensureProductColumns(db);
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await _databaseHelper.database;
    await _ensureProductColumns(db);
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> addStockQuantity(int productId, double quantity) async {
    final db = await _databaseHelper.database;
    return await db.rawUpdate('''
      UPDATE products
      SET stock_quantity = stock_quantity + ?
      WHERE id = ?
    ''', [quantity, productId]);
  }

  Future<int> updateStockQuantity(int productId, double newQuantity) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'products',
      {'stock_quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
