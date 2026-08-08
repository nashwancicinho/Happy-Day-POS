import 'package:flutter/foundation.dart';
import '../../database/database_helper.dart';
import '../../models/product_recipe.dart';
import '../../models/raw_material.dart';

class RawMaterialsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<RawMaterialModel>> getAllRawMaterials() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('raw_materials', orderBy: 'name ASC');
      return maps.map((map) => RawMaterialModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting raw materials: $e');
      return [];
    }
  }

  Future<int> insertRawMaterial(RawMaterialModel item) async {
    try {
      final db = await _dbHelper.database;
      return await db.insert('raw_materials', item.toMap());
    } catch (e) {
      debugPrint('Error inserting raw material: $e');
      return 0;
    }
  }

  Future<int> updateRawMaterial(RawMaterialModel item) async {
    try {
      final db = await _dbHelper.database;
      return await db.update(
        'raw_materials',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } catch (e) {
      debugPrint('Error updating raw material: $e');
      return 0;
    }
  }

  Future<int> deleteRawMaterial(int id) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        'raw_materials',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Error deleting raw material: $e');
      return 0;
    }
  }

  Future<void> addStockQuantity(int rawMaterialId, double qtyToAdd, {double? newCostPerUnit}) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('raw_materials', where: 'id = ?', whereArgs: [rawMaterialId]);
      if (maps.isNotEmpty) {
        final current = RawMaterialModel.fromMap(maps.first);
        final newStock = current.stockQuantity + qtyToAdd;
        final updatedCost = newCostPerUnit ?? current.costPerUnit;
        await db.update(
          'raw_materials',
          {
            'stock_quantity': newStock,
            'cost_per_unit': updatedCost,
          },
          where: 'id = ?',
          whereArgs: [rawMaterialId],
        );
      }
    } catch (e) {
      debugPrint('Error adding raw material stock: $e');
    }
  }

  Future<List<ProductRecipeItemModel>> getProductRecipes(int productId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT pr.id, pr.product_id, pr.raw_material_id, pr.quantity_required,
               rm.name AS raw_material_name, rm.unit AS raw_material_unit, rm.cost_per_unit
        FROM product_recipes pr
        INNER JOIN raw_materials rm ON pr.raw_material_id = rm.id
        WHERE pr.product_id = ?
      ''', [productId]);

      return results.map((map) => ProductRecipeItemModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting product recipes: $e');
      return [];
    }
  }

  Future<void> saveProductRecipes(int productId, List<ProductRecipeItemModel> recipes) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('product_recipes', where: 'product_id = ?', whereArgs: [productId]);
        for (final r in recipes) {
          await txn.insert('product_recipes', {
            'product_id': productId,
            'raw_material_id': r.rawMaterialId,
            'quantity_required': r.quantityRequired,
          });
        }
      });
    } catch (e) {
      debugPrint('Error saving product recipes: $e');
    }
  }

  Future<void> deductRecipeStockForSoldProduct(int productId, double soldQuantity) async {
    try {
      final db = await _dbHelper.database;
      final recipes = await getProductRecipes(productId);
      for (final r in recipes) {
        final totalDeduct = r.quantityRequired * soldQuantity;
        await db.rawUpdate('''
          UPDATE raw_materials
          SET stock_quantity = stock_quantity - ?
          WHERE id = ?
        ''', [totalDeduct, r.rawMaterialId]);
      }
    } catch (e) {
      debugPrint('Error deducting raw material recipe stock: $e');
    }
  }
}
