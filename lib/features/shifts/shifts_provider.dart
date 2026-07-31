import 'package:flutter/foundation.dart';
import '../../models/cash_transaction.dart';
import '../../models/shift.dart';
import 'shifts_repository.dart';

class ShiftsProvider extends ChangeNotifier {
  final ShiftsRepository _repository = ShiftsRepository();

  ShiftModel? _currentShift;
  List<CashTransactionModel> _transactions = [];
  bool _isLoading = false;

  ShiftModel? get currentShift => _currentShift;
  List<CashTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isShiftOpen => _currentShift != null && _currentShift!.status == 'OPEN';

  Future<void> loadCurrentShift() async {
    _isLoading = true;
    notifyListeners();

    _currentShift = await _repository.getActiveShift();
    if (_currentShift != null) {
      _transactions = await _repository.getShiftTransactions(_currentShift!.id!);
    } else {
      _transactions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> openShift(double openingCash, {String userName = 'Nashwan'}) async {
    await _repository.openShift(openingCash, userName);
    await loadCurrentShift();
  }

  Future<double> calculateExpectedCash() async {
    if (_currentShift == null) return 0.0;

    final cashSales = await _repository.getShiftTotalCashSales(_currentShift!.id!);
    final cashInSum = _transactions
        .where((t) => t.type == 'IN')
        .fold(0.0, (sum, t) => sum + t.amount);
    final cashOutSum = _transactions
        .where((t) => t.type == 'OUT')
        .fold(0.0, (sum, t) => sum + t.amount);

    return _currentShift!.openingCash + cashSales + cashInSum - cashOutSum;
  }

  Future<void> closeShift(double closingCashActual) async {
    if (_currentShift == null) return;

    final expected = await calculateExpectedCash();
    await _repository.closeShift(
      shiftId: _currentShift!.id!,
      closingCashActual: closingCashActual,
      closingCashExpected: expected,
    );
    await loadCurrentShift();
  }

  Future<void> addCashTransaction({
    required String type,
    required double amount,
    required String reason,
  }) async {
    if (_currentShift == null) return;

    final tx = CashTransactionModel(
      shiftId: _currentShift!.id!,
      type: type,
      amount: amount,
      reason: reason,
      createdAt: DateTime.now().toIso8601String(),
    );

    await _repository.addCashTransaction(tx);
    await loadCurrentShift();
  }
}
