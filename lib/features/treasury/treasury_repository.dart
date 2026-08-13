import '../../database/database_helper.dart';
import '../../models/daily_treasury.dart';
import '../../models/other_expense.dart';

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

  Future<double> getTodayOtherExpensesTotal({String? lastClosingTimestamp}) async {
    final db = await _databaseHelper.database;
    final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
    
    String sql = "SELECT SUM(amount) as total FROM other_expenses WHERE created_at LIKE ?";
    List<dynamic> args = ['$todayPrefix%'];

    if (lastClosingTimestamp != null && lastClosingTimestamp.isNotEmpty) {
      sql = "SELECT SUM(amount) as total FROM other_expenses WHERE created_at > ?";
      args = [lastClosingTimestamp];
    }

    final res = await db.rawQuery(sql, args);
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toDouble();
    }
    return 0.0;
  }
}
