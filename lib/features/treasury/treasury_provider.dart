import 'package:flutter/foundation.dart';
import '../../models/daily_treasury.dart';
import '../../models/other_expense.dart';
import '../../models/treasury_transaction.dart';
import 'treasury_repository.dart';

class TreasuryProvider extends ChangeNotifier {
  final TreasuryRepository _repository = TreasuryRepository();

  List<DailyTreasuryModel> _treasuryRecords = [];
  List<OtherExpenseModel> _otherExpenses = [];
  List<TreasuryTransactionModel> _transactions = [];
  List<TreasuryTransactionModel> _activeTransactions = [];
  double _allTimeBalance = 0.0;
  bool _isLoading = false;

  List<DailyTreasuryModel> get treasuryRecords => _treasuryRecords;
  List<OtherExpenseModel> get otherExpenses => _otherExpenses;
  List<TreasuryTransactionModel> get transactions => _transactions;
  List<TreasuryTransactionModel> get activeTransactions => _activeTransactions;
  double get allTimeBalance => _allTimeBalance;
  bool get isLoading => _isLoading;

  // --- Calculations for Active Session (شاشة الخزينة الحالية قبل إغلاق اليوم) ---
  double get activeCashIn {
    return _activeTransactions.where((t) => t.isDeposit).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get activeCashOut {
    return _activeTransactions.where((t) => t.isWithdrawal).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get activeNetBalance => activeCashIn - activeCashOut;

  // --- Calculations for Treasury Reports (شاشة التقارير) ---
  double get totalCashIn {
    return _transactions.where((t) => t.isDeposit).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalCashOut {
    return _transactions.where((t) => t.isWithdrawal).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get netBalance => totalCashIn - totalCashOut;

  // --- Historical calculations for Daily Treasury records ---
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

  // --- Load Active Session Transactions for Treasury Screen ---
  Future<void> loadActiveTransactions() async {
    _isLoading = true;
    notifyListeners();

    _activeTransactions = await _repository.getTreasuryTransactions(
      onlyActiveSession: true,
    );
    _allTimeBalance = await _repository.getAllTimeTreasuryBalance();

    _isLoading = false;
    notifyListeners();
  }

  // --- Close Active Treasury Session (عند إغلاق اليوم) ---
  Future<void> closeActiveSession() async {
    await _repository.closeActiveTreasurySession();
    await loadActiveTransactions();
    await refreshAllTimeBalance();
  }

  // --- Load Treasury Transactions for Reports (إيداع وسحب) ---
  Future<void> loadTreasuryTransactions({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    String? type,
  }) async {
    _isLoading = true;
    notifyListeners();

    _transactions = await _repository.getTreasuryTransactions(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
      type: type,
    );
    _allTimeBalance = await _repository.getAllTimeTreasuryBalance();

    _isLoading = false;
    notifyListeners();
  }

  Future<int> addTreasuryTransaction(TreasuryTransactionModel transaction, {
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final id = await _repository.insertTreasuryTransaction(transaction);
    await loadActiveTransactions();
    await loadTreasuryTransactions(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
    return id;
  }

  Future<int> deleteTreasuryTransaction(int id, {
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final res = await _repository.deleteTreasuryTransaction(id);
    await loadActiveTransactions();
    await loadTreasuryTransactions(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
    return res;
  }

  Future<void> refreshAllTimeBalance() async {
    _allTimeBalance = await _repository.getAllTimeTreasuryBalance();
    notifyListeners();
  }

  // --- Legacy / Daily Closing Treasury Records ---
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
    await loadTreasuryTransactions(datePrefix: datePrefix, fromDate: fromDate, toDate: toDate);
    await loadActiveTransactions();

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
