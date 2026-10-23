import '../../database/database_helper.dart';
import '../../models/daily_treasury.dart';
import '../../models/other_expense.dart';
import '../../models/treasury_transaction.dart';

class TreasuryRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> saveTreasuryRecord(DailyTreasuryModel record) async {
    final db = await _databaseHelper.database;
    return await db.insert('daily_treasury', record.toMap());
  }

  Future<List<DailyTreasuryModel>> getAllTreasuryRecords() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('daily_treasury', orderBy: 'id DESC');
    return maps.map((e) => DailyTreasuryModel.fromMap(e)).toList();
  }

  Future<List<DailyTreasuryModel>> getTreasuryRecordsByPeriod({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause = "WHERE DATE(date) >= DATE(?) AND DATE(date) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause = "WHERE date LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    final maps = await db.rawQuery('''
      SELECT * FROM daily_treasury
      $whereClause
      ORDER BY id DESC
    ''', whereArgs);

    return maps.map((e) => DailyTreasuryModel.fromMap(e)).toList();
  }

  Future<DailyTreasuryModel?> getTodayTreasuryRecord() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'daily_treasury',
      where: 'date = ?',
      whereArgs: [todayStr],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return DailyTreasuryModel.fromMap(maps.first);
  }

  Future<String?> getLastClosingTimestamp() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      'daily_treasury',
      columns: ['created_at'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['created_at'] as String?;
  }

  // --- Other Expenses (مصاريف أخرى) ---
  Future<int> addOtherExpense(OtherExpenseModel expense) async {
    final db = await _databaseHelper.database;
    return await db.insert('other_expenses', expense.toMap());
  }

  Future<int> deleteOtherExpense(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('other_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<OtherExpenseModel>> getOtherExpenses({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause = "WHERE DATE(created_at) >= DATE(?) AND DATE(created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause = "WHERE created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    final maps = await db.rawQuery('''
      SELECT * FROM other_expenses
      $whereClause
      ORDER BY id DESC
    ''', whereArgs);

    return maps.map((e) => OtherExpenseModel.fromMap(e)).toList();
  }

  Future<List<OtherExpenseModel>> getActiveOtherExpenses() async {
    final db = await _databaseHelper.database;
    final lastClosing = await getLastClosingTimestamp();

    List<String> conditions = ["is_closed = 0"];
    List<dynamic> whereArgs = [];

    if (lastClosing != null && lastClosing.isNotEmpty) {
      conditions.add("created_at > ?");
      whereArgs.add(lastClosing);
    }

    final whereClause = "WHERE ${conditions.join(' AND ')}";
    final maps = await db.rawQuery('''
      SELECT * FROM other_expenses
      $whereClause
      ORDER BY id DESC
    ''', whereArgs);

    return maps.map((e) => OtherExpenseModel.fromMap(e)).toList();
  }

  Future<double> getTodayOtherExpensesTotal({String? lastClosingTimestamp}) async {
    final db = await _databaseHelper.database;
    final lastClosing = lastClosingTimestamp ?? await getLastClosingTimestamp();
    
    List<String> conditions = ["is_closed = 0"];
    List<dynamic> whereArgs = [];

    if (lastClosing != null && lastClosing.isNotEmpty) {
      conditions.add("created_at > ?");
      whereArgs.add(lastClosing);
    } else {
      final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
      conditions.add("created_at LIKE ?");
      whereArgs.add('$todayPrefix%');
    }

    final whereClause = "WHERE ${conditions.join(' AND ')}";
    final sql = "SELECT SUM(amount) as total FROM other_expenses $whereClause";
    final res = await db.rawQuery(sql, whereArgs);
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- Treasury Transactions (حركات الخزينة: إدخال وإخراج مبالغ) ---
  Future<int> insertTreasuryTransaction(TreasuryTransactionModel transaction) async {
    final db = await _databaseHelper.database;
    return await db.insert('treasury_transactions', transaction.toMap());
  }

  Future<int> deleteTreasuryTransaction(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('treasury_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TreasuryTransactionModel>> getTreasuryTransactions({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    String? type,
    bool? onlyActiveSession,
  }) async {
    final db = await _databaseHelper.database;
    List<String> conditions = [];
    List<dynamic> whereArgs = [];

    if (onlyActiveSession == true) {
      conditions.add("is_closed = 0");
    }

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      conditions.add("DATE(created_at) >= DATE(?) AND DATE(created_at) <= DATE(?)");
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      conditions.add("created_at LIKE ?");
      whereArgs.add('$datePrefix%');
    }

    if (type != null && type.isNotEmpty && type != 'ALL') {
      conditions.add("type = ?");
      whereArgs.add(type);
    }

    String whereClause = conditions.isNotEmpty ? "WHERE ${conditions.join(' AND ')}" : "";

    final maps = await db.rawQuery('''
      SELECT * FROM treasury_transactions
      $whereClause
      ORDER BY id DESC
    ''', whereArgs);

    return maps.map((e) => TreasuryTransactionModel.fromMap(e)).toList();
  }

  Future<int> closeActiveTreasurySession() async {
    final db = await _databaseHelper.database;
    await db.update(
      'other_expenses',
      {'is_closed': 1},
      where: 'is_closed = 0',
    );
    return await db.update(
      'treasury_transactions',
      {'is_closed': 1},
      where: 'is_closed = 0',
    );
  }

  Future<double> getAllTimeTreasuryBalance() async {
    final db = await _databaseHelper.database;
    final inRes = await db.rawQuery("SELECT SUM(amount) as total FROM treasury_transactions WHERE type = 'IN'");
    final outRes = await db.rawQuery("SELECT SUM(amount) as total FROM treasury_transactions WHERE type = 'OUT'");

    final totalIn = (inRes.isNotEmpty && inRes.first['total'] != null) ? (inRes.first['total'] as num).toDouble() : 0.0;
    final totalOut = (outRes.isNotEmpty && outRes.first['total'] != null) ? (outRes.first['total'] as num).toDouble() : 0.0;

    return totalIn - totalOut;
  }
}
