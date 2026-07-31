import 'package:flutter/foundation.dart';
import '../../models/daily_treasury.dart';
import 'treasury_repository.dart';

class TreasuryProvider extends ChangeNotifier {
  final TreasuryRepository _repository = TreasuryRepository();

  List<DailyTreasuryModel> _treasuryRecords = [];
  bool _isLoading = false;

  List<DailyTreasuryModel> get treasuryRecords => _treasuryRecords;
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

    _isLoading = false;
    notifyListeners();
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
