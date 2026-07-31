import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';

class CustomersRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('customers', orderBy: 'id ASC');
    return maps.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await _databaseHelper.database;
    return await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCustomerBalance(int customerId, double amountDelta) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate('''
      UPDATE customers
      SET balance = balance + ?
      WHERE id = ?
    ''', [amountDelta, customerId]);
  }
}
