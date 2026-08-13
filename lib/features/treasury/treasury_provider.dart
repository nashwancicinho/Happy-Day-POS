import 'package:flutter/foundation.dart';
import '../../models/daily_treasury.dart';
import '../../models/other_expense.dart';
import 'treasury_repository.dart';

class TreasuryProvider extends ChangeNotifier {
  final TreasuryRepository _repository = TreasuryRepository();

  List<DailyTreasuryModel> _treasuryRecords = [];
  List<OtherExpenseModel> _otherExpenses = [];
  bool _isLoading = false;

  List<DailyTreasuryModel> get treasuryRecords => _treasuryRecords;
  List<OtherExpenseModel> get otherExpenses => _otherExpenses;
  bool get isLoading => _isLoading;

  double get totalPeriodNetIncome {
    return _treasuryRecords.fold(0.0, (sum, r) => sum + r.netIncome);
  }

  double get totalPeriodIncome {
    return _treasuryRecords.fold(0.0, (sum, r) => sum + r.dailyIncome);
  }

  double get totalPeriodExpense {
    return _treasuryRecords.fold(0.0, (sum, r) => sum + r.dailyExpense);
  }

  double get totalOtherExpenses {
    return _otherExpenses.fold(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> loadTreasuryRecords({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    _treasuryRecords = await _repository.getTreasuryRecordsByPeriod(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );

    await loadOtherExpenses(datePrefix: datePrefix, fromDate: fromDate, toDate: toDate);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadOtherExpenses({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    _otherExpenses = await _repository.getOtherExpenses(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
    notifyListeners();
  }

  Future<int> addOtherExpense(OtherExpenseModel expense) async {
    final id = await _repository.addOtherExpense(expense);
    await loadOtherExpenses();
    return id;
  }

  Future<int> deleteOtherExpense(int id) async {
    final res = await _repository.deleteOtherExpense(id);
    await loadOtherExpenses();
    return res;
  }

  Future<double> getTodayOtherExpensesTotal({String? lastClosingTimestamp}) async {
    return await _repository.getTodayOtherExpensesTotal(lastClosingTimestamp: lastClosingTimestamp);
  }

  Future<int> saveTreasuryRecord(DailyTreasuryModel record) async {
    final id = await _repository.saveTreasuryRecord(record);
    await loadTreasuryRecords();
    return id;
  }

  Future<DailyTreasuryModel?> getTodayRecord() async {
    return await _repository.getTodayTreasuryRecord();
  }
}
