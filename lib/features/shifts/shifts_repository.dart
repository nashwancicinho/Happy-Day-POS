import '../../database/database_helper.dart';
import '../../models/cash_transaction.dart';
import '../../models/shift.dart';

class ShiftsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<ShiftModel?> getActiveShift() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'shifts',
      where: 'status = ?',
      whereArgs: ['OPEN'],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return ShiftModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> openShift(double openingCash, String userName) async {
    final db = await _databaseHelper.database;
    final shift = ShiftModel(
      openedAt: DateTime.now().toIso8601String(),
      openingCash: openingCash,
      userName: userName,
      status: 'OPEN',
    );
    return await db.insert('shifts', shift.toMap());
  }

  Future<void> closeShift({
    required int shiftId,
    required double closingCashActual,
    required double closingCashExpected,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      'shifts',
      {
        'closed_at': DateTime.now().toIso8601String(),
        'closing_cash_actual': closingCashActual,
        'closing_cash_expected': closingCashExpected,
        'status': 'CLOSED',
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  Future<int> addCashTransaction(CashTransactionModel tx) async {
    final db = await _databaseHelper.database;
    return await db.insert('cash_transactions', tx.toMap());
  }

  Future<List<CashTransactionModel>> getShiftTransactions(int shiftId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'cash_transactions',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'id DESC',
    );
    return maps.map((e) => CashTransactionModel.fromMap(e)).toList();
  }

  Future<double> getShiftTotalCashSales(int shiftId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM(total) as total_cash
      FROM orders
      WHERE shift_id = ? AND payment_method = 'CASH' AND status != 'CANCELLED'
    ''', [shiftId]);

    final val = result.first['total_cash'];
    return (val as num? ?? 0.0).toDouble();
  }
}
