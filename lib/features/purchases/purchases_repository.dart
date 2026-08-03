import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';

class PurchasesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- SUPPLIERS METHODS ---

  Future<List<SupplierModel>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('suppliers', orderBy: 'id DESC');
    return maps.map((e) => SupplierModel.fromMap(e)).toList();
  }

  Future<int> insertSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- PURCHASES METHODS ---

  Future<List<PurchaseInvoiceModel>> getAllPurchases() async {
    final db = await _dbHelper.database;
    final purchaseMaps = await db.query('purchases', orderBy: 'id DESC');

    List<PurchaseInvoiceModel> list = [];
    for (var pMap in purchaseMaps) {
      final pId = pMap['id'] as int;
      final itemMaps = await db.query(
        'purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [pId],
      );
      final items = itemMaps.map((e) => PurchaseItemModel.fromMap(e)).toList();
      list.add(PurchaseInvoiceModel.fromMap(pMap, items: items));
    }
    return list;
  }

  Future<bool> createPurchaseInvoice({
    required PurchaseInvoiceModel invoice,
    required bool updateInventory,
  }) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        // 1. Insert Purchase Invoice Header
        final purchaseId = await txn.insert('purchases', invoice.toMap());

        // 2. Insert Purchase Line Items & optionally update stock
        for (var item in invoice.items) {
          await txn.insert('purchase_items', item.toMap(purchaseId));

          if (updateInventory && item.productId != null) {
            // Update stock quantity and buy price in products table
            final prodRes = await txn.query(
              'products',
              columns: ['stock_quantity'],
              where: 'id = ?',
              whereArgs: [item.productId],
            );
            if (prodRes.isNotEmpty) {
              final currentStock = (prodRes.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
              final newStock = currentStock + item.quantity;
              await txn.update(
                'products',
                {
                  'stock_quantity': newStock,
                  'buy_price': item.unitPrice,
                },
                where: 'id = ?',
                whereArgs: [item.productId],
              );
            }
          }
        }

        // 3. Update Supplier Balance if there is a remaining debt
        if (invoice.remainingAmount > 0) {
          final suppRes = await txn.query(
            'suppliers',
            columns: ['balance'],
            where: 'id = ?',
            whereArgs: [invoice.supplierId],
          );
          final currentBal = suppRes.isNotEmpty ? ((suppRes.first['balance'] as num?)?.toDouble() ?? 0.0) : 0.0;
          final newBal = currentBal + invoice.remainingAmount;
          await txn.update(
            'suppliers',
            {'balance': newBal},
            where: 'id = ?',
            whereArgs: [invoice.supplierId],
          );
        }

        // 4. Record Cash Transaction Out for paid amount if paidAmount > 0 and open shift exists
        if (invoice.paidAmount > 0) {
          final openShiftRes = await txn.query(
            'shifts',
            where: 'status = ?',
            whereArgs: ['OPEN'],
            orderBy: 'id DESC',
            limit: 1,
          );

          if (openShiftRes.isNotEmpty) {
            final shiftId = openShiftRes.first['id'] as int;
            await txn.insert('cash_transactions', {
              'shift_id': shiftId,
              'type': 'OUT',
              'amount': invoice.paidAmount,
              'reason': 'دفعة فاتورة مشتريات #${invoice.invoiceNumber} - ${invoice.supplierName}',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error creating purchase invoice transaction: $e');
      return false;
    }
  }

  Future<bool> deletePurchaseInvoice(int purchaseId) async {
    final db = await _dbHelper.database;
    try {
      await db.transaction((txn) async {
        await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
        await txn.delete('purchases', where: 'id = ?', whereArgs: [purchaseId]);
      });
      return true;
    } catch (e) {
      debugPrint('Error deleting purchase invoice: $e');
      return false;
    }
  }

  // --- SUPPLIER PAYMENTS & DEBTS ---

  Future<bool> paySupplierDebt({
    required int supplierId,
    required String supplierName,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        final nowStr = DateTime.now().toIso8601String();

        // 1. Insert Payment Record
        await txn.insert('supplier_payments', {
          'supplier_id': supplierId,
          'amount': amount,
          'payment_date': nowStr,
          'payment_method': paymentMethod,
          'notes': notes,
        });

        // 2. Reduce Supplier Debt Balance
        final suppRes = await txn.query(
          'suppliers',
          columns: ['balance'],
          where: 'id = ?',
          whereArgs: [supplierId],
        );
        final currentBal = suppRes.isNotEmpty ? ((suppRes.first['balance'] as num?)?.toDouble() ?? 0.0) : 0.0;
        final newBal = (currentBal - amount).clamp(0.0, double.infinity);

        await txn.update(
          'suppliers',
          {'balance': newBal},
          where: 'id = ?',
          whereArgs: [supplierId],
        );

        // 3. Record Cash Out Transaction in current Open Shift
        final openShiftRes = await txn.query(
          'shifts',
          where: 'status = ?',
          whereArgs: ['OPEN'],
          orderBy: 'id DESC',
          limit: 1,
        );

        if (openShiftRes.isNotEmpty) {
          final shiftId = openShiftRes.first['id'] as int;
          await txn.insert('cash_transactions', {
            'shift_id': shiftId,
            'type': 'OUT',
            'amount': amount,
            'reason': 'تسديد دين للمورد: $supplierName ${notes != null && notes.isNotEmpty ? "($notes)" : ""}',
            'created_at': nowStr,
          });
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error recording supplier payment: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSupplierPayments(int supplierId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'supplier_payments',
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'id DESC',
    );
  }
}
