import 'package:flutter/foundation.dart';
import '../../models/employee.dart';
import '../../models/employee_advance.dart';
import '../../models/salary_payment.dart';
import 'payroll_repository.dart';

class PayrollProvider extends ChangeNotifier {
  final PayrollRepository _repository = PayrollRepository();

  List<EmployeeModel> _employees = [];
  List<EmployeeAdvanceModel> _advances = [];
  List<SalaryPaymentModel> _payments = [];
  bool _isLoading = false;

  List<EmployeeModel> get employees => _employees;
  List<EmployeeAdvanceModel> get advances => _advances;
  List<SalaryPaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

  Future<void> loadPayrollData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _employees = await _repository.getAllEmployees();
      _advances = await _repository.getAllAdvances();
      _payments = await _repository.getAllSalaryPayments();
    } catch (e) {
      debugPrint('Error loading payroll data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- Employees ---
  Future<void> addEmployee(EmployeeModel emp) async {
    await _repository.addEmployee(emp);
    await loadPayrollData();
  }

  Future<void> updateEmployee(EmployeeModel emp) async {
    await _repository.updateEmployee(emp);
    await loadPayrollData();
  }

  Future<void> deleteEmployee(int id) async {
    await _repository.deleteEmployee(id);
    await loadPayrollData();
  }

  // --- Advances ---
  Future<void> addAdvance(EmployeeAdvanceModel advance) async {
    await _repository.addAdvance(advance);
    await loadPayrollData();
  }

  Future<void> deleteAdvance(int id) async {
    await _repository.deleteAdvance(id);
    await loadPayrollData();
  }

  // Pending advances for specific employee
  List<EmployeeAdvanceModel> getPendingAdvancesForEmployee(int employeeId) {
    return _advances.where((a) => a.employeeId == employeeId && a.status == 'PENDING').toList();
  }

  // Calculate Net Salary Breakdown for Employee
  Map<String, double> calculateEmployeeCurrentMonthNetSalary(EmployeeModel employee) {
    final pendingList = getPendingAdvancesForEmployee(employee.id ?? 0);
    double totalAdvances = 0.0;
    double totalBonuses = 0.0;
    double totalDeductions = 0.0;

    for (final item in pendingList) {
      if (item.type == 'ADVANCE') {
        totalAdvances += item.amount;
      } else if (item.type == 'BONUS') {
        totalBonuses += item.amount;
      } else if (item.type == 'DEDUCTION') {
        totalDeductions += item.amount;
      }
    }

    final netSalary = employee.baseSalary + totalBonuses - totalAdvances - totalDeductions;

    return {
      'baseSalary': employee.baseSalary,
      'totalAdvances': totalAdvances,
      'totalBonuses': totalBonuses,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
    };
  }

  // --- Process Salary Payment ---
  Future<int> processSalaryPayment({
    required SalaryPaymentModel payment,
    required List<int> pendingAdvanceIdsToSettle,
  }) async {
    final paymentId = await _repository.processSalaryPayment(
      payment: payment,
      pendingAdvanceIdsToSettle: pendingAdvanceIdsToSettle,
    );
    await loadPayrollData();
    return paymentId;
  }
}
