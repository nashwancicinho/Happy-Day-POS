import '../../database/database_helper.dart';
import '../../models/employee.dart';
import '../../models/employee_advance.dart';
import '../../models/salary_payment.dart';

class PayrollRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  // --- Employees CRUD ---
  Future<List<EmployeeModel>> getAllEmployees() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('employees', orderBy: 'id ASC');
    return maps.map((e) => EmployeeModel.fromMap(e)).toList();
  }

  Future<int> addEmployee(EmployeeModel emp) async {
    final db = await _databaseHelper.database;
    return await db.insert('employees', emp.toMap());
  }

  Future<int> updateEmployee(EmployeeModel emp) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'employees',
      emp.toMap(),
      where: 'id = ?',
      whereArgs: [emp.id],
    );
  }

  Future<int> deleteEmployee(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // --- Employee Advances / Bonuses / Deductions ---
  Future<List<EmployeeAdvanceModel>> getAdvancesForEmployee(int employeeId, {String? status}) async {
    final db = await _databaseHelper.database;
    String whereClause = 'employee_id = ?';
    List<dynamic> whereArgs = [employeeId];

    if (status != null && status.isNotEmpty) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final maps = await db.rawQuery('''
      SELECT ea.*, e.name AS employee_name
      FROM employee_advances ea
      JOIN employees e ON ea.employee_id = e.id
      WHERE $whereClause
      ORDER BY ea.id DESC
    ''', whereArgs);

    return maps.map((e) => EmployeeAdvanceModel.fromMap(e)).toList();
  }

  Future<List<EmployeeAdvanceModel>> getAllAdvances() async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT ea.*, e.name AS employee_name
      FROM employee_advances ea
      JOIN employees e ON ea.employee_id = e.id
      ORDER BY ea.id DESC
    ''');
    return maps.map((e) => EmployeeAdvanceModel.fromMap(e)).toList();
  }

  Future<int> addAdvance(EmployeeAdvanceModel advance) async {
    final db = await _databaseHelper.database;
    return await db.insert('employee_advances', advance.toMap());
  }

  Future<int> deleteAdvance(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('employee_advances', where: 'id = ?', whereArgs: [id]);
  }

  // --- Salary Payment & Settlement ---
  Future<int> processSalaryPayment({
    required SalaryPaymentModel payment,
    required List<int> pendingAdvanceIdsToSettle,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      // 1. Insert salary_payment record
      final paymentId = await txn.insert('salary_payments', payment.toMap());

      // 2. Mark selected advances as SETTLED
      for (final advId in pendingAdvanceIdsToSettle) {
        await txn.update(
          'employee_advances',
          {'status': 'SETTLED'},
          where: 'id = ?',
          whereArgs: [advId],
        );
      }

      return paymentId;
    });
  }

  Future<List<SalaryPaymentModel>> getAllSalaryPayments() async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT sp.*, e.name AS employee_name
      FROM salary_payments sp
      JOIN employees e ON sp.employee_id = e.id
      ORDER BY sp.id DESC
    ''');

    return maps.map((e) => SalaryPaymentModel.fromMap(e)).toList();
  }
}
