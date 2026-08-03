import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository = SettingsRepository();

  Map<String, String> _settings = {};
  bool _isLoading = false;

  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;

  String get storeName => _settings['store_name'] ?? 'HAPPY DAY POS';
  String get storePhone => _settings['store_phone'] ?? '';
  String get storeAddress => _settings['store_address'] ?? '';
  double get taxRate => double.tryParse(_settings['tax_rate'] ?? '0.0') ?? 0.0;
  String get currencySymbol => _settings['currency_symbol'] ?? 'د.ع';
  String get receiptHeader => _settings['receipt_header'] ?? 'أهلاً وسهلاً بكم';
  String get receiptFooter => _settings['receipt_footer'] ?? 'شكراً لزيارتكم';
  String get cashierPrinter => _settings['cashier_printer'] ?? 'طابعة الكاشير الرئيسية (POS-80)';
  String get kitchenPrinter => _settings['kitchen_printer'] ?? 'طابعة المطبخ الحرارية (KOT-Kitchen)';
  String get reportsPrinter => _settings['reports_printer'] ?? 'طابعة النظام الافتراضية (Default Printer)';
  String get barcodePrinter => _settings['barcode_printer'] ?? 'طابعة ملصقات الباركود (Barcode Printer)';
  String get storeLogoPath => _settings['store_logo_path'] ?? '';
  String get themeColorHex => _settings['primary_color'] ?? '#FF9800';
  String get backupFolderPath => _settings['backup_folder_path'] ?? '';


  Color get primaryColor {
    final hex = themeColorHex.replaceAll('#', '');
    final val = int.tryParse(hex, radix: 16);
    if (val != null) {
      final col = Color(0xFF000000 | val);
      AppColors.primary = col;
      return col;
    }
    AppColors.primary = const Color(0xFFFF9800);
    return const Color(0xFFFF9800);
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    _settings = await _repository.getAllSettings();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSetting(String key, String value) async {
    _settings[key] = value;
    await _repository.saveSetting(key, value);
    notifyListeners();
  }

  Future<void> updateAllSettings(Map<String, String> newSettings) async {
    _settings.addAll(newSettings);
    await _repository.saveAllSettings(newSettings);
    notifyListeners();
  }
}
