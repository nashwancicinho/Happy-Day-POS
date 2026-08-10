import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../database/database_helper.dart';
import 'settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repository = SettingsRepository();

  Map<String, String> _settings = {};
  bool _isLoading = false;

  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;

  String get storeName => _settings['store_name'] ?? 'CASHBOX POS';
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
  String get autoBackupFrequency => _settings['auto_backup_frequency'] ?? 'DAILY';
  String get lastAutoBackupDate => _settings['last_auto_backup_date'] ?? '';
  String get appLanguage => _settings['app_language'] ?? 'ar';
  bool get isEnglish => appLanguage == 'en';
  TextDirection get textDirection => isEnglish ? TextDirection.ltr : TextDirection.rtl;
  Locale get locale => Locale(appLanguage);
  bool get showTopNotifications => (_settings['show_top_notifications'] ?? 'false') == 'true';
  double get screenScale => double.tryParse(_settings['app_screen_scale'] ?? '1.0') ?? 1.0;

  Future<void> setShowTopNotifications(bool value) async {
    TopNotification.enabled = value;
    await updateSetting('show_top_notifications', value.toString());
  }

  Future<void> setScreenScale(double value) async {
    await updateSetting('app_screen_scale', value.toString());
  }

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
    if (_settings['store_name'] == null || (_settings['store_name'] ?? '').contains('HAPPY DAY')) {
      _settings['store_name'] = 'CASHBOX POS';
      await _repository.saveSetting('store_name', 'CASHBOX POS');
    }
    TopNotification.enabled = showTopNotifications;
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

  static const Map<String, bool> defaultCashierPermissions = {
    'perm_cashier_access_day_closing': true,
    'perm_cashier_access_debts': true,
    'perm_cashier_access_reports': false,
    'perm_cashier_access_products': false,
    'perm_cashier_access_categories': false,
    'perm_cashier_access_inventory': false,
    'perm_cashier_access_purchases': false,
    'perm_cashier_access_settings': false,
    'perm_cashier_allow_discount': true,
    'perm_cashier_allow_price_change': false,
    'perm_cashier_allow_delete_item': true,
    'perm_cashier_allow_cancel_order': true,
    'perm_cashier_allow_debt_sale': true,
    'perm_cashier_allow_settle_debt': false,
    'perm_cashier_allow_cash_trans': false,
    'perm_cashier_view_profit_reports': false,
  };

  bool getCashierPermission(String key, {bool? defaultVal}) {
    final fallback = defaultVal ?? defaultCashierPermissions[key] ?? true;
    final valStr = _settings[key];
    if (valStr == null) return fallback;
    return valStr.toLowerCase() == 'true' || valStr == '1';
  }

  Future<void> setCashierPermission(String key, bool value) async {
    await updateSetting(key, value.toString());
  }

  Future<void> setAllCashierPermissions(bool value) async {
    final Map<String, String> newMap = {};
    for (final k in defaultCashierPermissions.keys) {
      newMap[k] = value.toString();
    }
    await updateAllSettings(newMap);
  }

  Future<void> resetCashierPermissionsToDefault() async {
    final Map<String, String> newMap = {};
    for (final entry in defaultCashierPermissions.entries) {
      newMap[entry.key] = entry.value.toString();
    }
    await updateAllSettings(newMap);
  }

  Future<bool> performAutoBackup({bool isClosingDay = false}) async {
    try {
      final freq = autoBackupFrequency;
      if (freq == 'OFF') return false;

      String targetPath = backupFolderPath.trim();

      if (targetPath.isEmpty) {
        final appDocDir = await getApplicationDocumentsDirectory();
        targetPath = join(appDocDir.path, 'HappyDayPOS_Backups');
      }

      final backupFile = await DatabaseHelper.instance.backupDatabase(targetPath);
      await updateSetting('last_auto_backup_date', DateTime.now().toIso8601String());
      debugPrint('Auto backup executed successfully to: ${backupFile.path}');
      return true;
    } catch (e) {
      debugPrint('Auto backup failed: $e');
      return false;
    }
  }
}

