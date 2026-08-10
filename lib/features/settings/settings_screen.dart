import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/services/print_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../core/widgets/update_dialog.dart';
import '../../database/database_helper.dart';
import '../../services/update_service.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../categories/categories_provider.dart';
import '../customers/customers_provider.dart';
import '../orders/orders_provider.dart';
import '../products/products_provider.dart';
import '../purchases/purchases_provider.dart';
import '../shifts/shifts_provider.dart';
import '../tables/tables_provider.dart';
import '../treasury/treasury_provider.dart';
import 'settings_provider.dart';
import '../../core/services/license_service.dart';
import '../license/license_activation_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late TextEditingController _cashierPrinterController;
  late TextEditingController _kitchenPrinterController;
  late TextEditingController _reportsPrinterController;
  late TextEditingController _barcodePrinterController;
  late TextEditingController _logoPathController;
  late TextEditingController _backupFolderController;
  String _selectedLogoIcon = 'storefront';
  String _selectedCurrency = 'د.ع';
  int _selectedTab = 0;

  List<Printer> _systemPrinters = [];
  bool _isLoadingPrinters = false;
  bool _isCheckingUpdate = false;
  String _currentAppVersion = '1.0.0';

  final List<Map<String, dynamic>> _logoPresets = [
    {'name': 'storefront', 'label': 'محل / متجر', 'labelEn': 'Store / Shop', 'icon': Icons.storefront_rounded},
    {'name': 'restaurant', 'label': 'مطعم شائعات', 'labelEn': 'Restaurant', 'icon': Icons.restaurant},
    {'name': 'fastfood', 'label': 'وجبات سريعة', 'labelEn': 'Fast Food', 'icon': Icons.fastfood},
    {'name': 'local_cafe', 'label': 'كافيه / قهوة', 'labelEn': 'Cafe / Coffee', 'icon': Icons.local_cafe},
    {'name': 'cake', 'label': 'حلويات / كيك', 'labelEn': 'Sweets & Bakery', 'icon': Icons.cake},
    {'name': 'dinner_dining', 'label': 'عشاء فاخر', 'labelEn': 'Fine Dining', 'icon': Icons.dinner_dining},
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _nameController = TextEditingController(text: settings.storeName);
    _addressController = TextEditingController(text: settings.storeAddress);
    _phoneController = TextEditingController(text: settings.storePhone);
    _headerController = TextEditingController(text: settings.receiptHeader);
    _footerController = TextEditingController(text: settings.receiptFooter);
    _cashierPrinterController = TextEditingController(text: settings.cashierPrinter);
    _kitchenPrinterController = TextEditingController(text: settings.kitchenPrinter);
    _reportsPrinterController = TextEditingController(text: settings.reportsPrinter);
    _barcodePrinterController = TextEditingController(text: settings.barcodePrinter);
    _logoPathController = TextEditingController(text: settings.storeLogoPath);
    _backupFolderController = TextEditingController(text: settings.backupFolderPath);
    _selectedLogoIcon = settings.settings['store_logo_icon'] ?? 'storefront';
    _selectedCurrency = settings.currencySymbol;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSystemPrinters();
      _loadCurrentVersion();
    });
  }

  Future<void> _loadCurrentVersion() async {
    final ver = await UpdateService.getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentAppVersion = ver;
      });
    }
  }

  Future<void> _checkForUpdatesManually() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    setState(() {
      _isCheckingUpdate = true;
    });
    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (!mounted) return;
      setState(() {
        _isCheckingUpdate = false;
      });

      if (updateInfo.hasUpdate) {
        UpdateDialog.show(context, updateInfo);
      } else {
        TopNotification.show(
          context,
          message: isEng
              ? 'You are running the latest version (v${updateInfo.currentVersion})'
              : 'أنت تستخدم أحدث إصدار من البرنامج (v${updateInfo.currentVersion})',
          type: TopNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        TopNotification.show(
          context,
          message: isEng ? 'Failed to check for updates' : 'فشل الفحص عن التحديثات',
          type: TopNotificationType.error,
        );
      }
    }
  }

  Future<void> _loadSystemPrinters() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPrinters = true;
    });
    try {
      final printers = await PrintService.getSystemPrinters();
      debugPrint('System printers loaded: ${printers.length}');
      if (mounted) {
        setState(() {
          _systemPrinters = printers;
          _isLoadingPrinters = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading printers: $e');
      if (mounted) {
        setState(() {
          _systemPrinters = [];
          _isLoadingPrinters = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    _cashierPrinterController.dispose();
    _kitchenPrinterController.dispose();
    _reportsPrinterController.dispose();
    _barcodePrinterController.dispose();
    _logoPathController.dispose();
    _backupFolderController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    final settingsProvider = context.read<SettingsProvider>();

    try {
      await settingsProvider.updateAllSettings({
        'store_name': _nameController.text.trim(),
        'store_address': _addressController.text.trim(),
        'store_phone': _phoneController.text.trim(),
        'currency_symbol': _selectedCurrency,
        'receipt_header': _headerController.text.trim(),
        'receipt_footer': _footerController.text.trim(),
        'store_logo_icon': _selectedLogoIcon,
        'store_logo_path': _logoPathController.text.trim(),
        'cashier_printer': _cashierPrinterController.text.trim(),
        'kitchen_printer': _kitchenPrinterController.text.trim(),
        'reports_printer': _reportsPrinterController.text.trim(),
        'barcode_printer': _barcodePrinterController.text.trim(),
        'backup_folder_path': _backupFolderController.text.trim(),
      });

      await settingsProvider.loadSettings();

      if (mounted) {
        TopNotification.showSuccess(
          context,
          'تم حفظ وتثبيت إعدادات المطعم والشعار والطابعات في قاعدة البيانات بنجاح! 🎉',
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        TopNotification.showWarning(context, 'حدث خطأ أثناء حفظ الإعدادات: $e');
      }
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'إستعراض ملفات الصور',
            extensions: <String>['jpg', 'png', 'jpeg', 'webp', 'JPG', 'PNG', 'JPEG'],
          ),
        ],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final dbPath = await DatabaseHelper.getAppDatabaseDirectory();
        final ext = p.extension(file.path).isEmpty ? '.png' : p.extension(file.path);
        final localLogoFile = File(p.join(dbPath, 'app_store_logo$ext'));
        await localLogoFile.writeAsBytes(bytes);

        setState(() {
          _logoPathController.text = localLogoFile.path;
        });
        if (mounted) {
          TopNotification.showSuccess(context, '🖼️ تم اختيار وصرف صورة اللوجو وحفظها في مجلد التطبيق الدائم بنجاح!');
        }
        _saveSettings();
      }
    } catch (e) {
      debugPrint('Error picking logo image: $e');
      if (mounted) {
        TopNotification.showWarning(context, 'يرجى لصق مسار الصورة المباشر في الحقل أدناه.');
      }
    }
  }

  void _confirmFactoryReset() {
    final managerNameController = TextEditingController();
    final managerPassController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('تأكيد إعادة تعيين المصنع (مسح البيانات)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '⚠️ تحذير: هذه العملية ستؤدي لحذف كافة المنتجات، الأصناف، الفواتير، الطاولات، والمستخدمين، وإعادة النظام لحالته الأولى عند التثبيت!',
                style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'يرجى إدخال اسم المدير وكلمة المرور للتحقق والصلاحية:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: managerNameController,
              decoration: InputDecoration(
                labelText: 'اسم المدير *',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: managerPassController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الرقم السري للمدير *',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء (عدم المسح)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final managerUser = managerNameController.text.trim();
              final managerPass = managerPassController.text.trim();

              if (managerUser.isEmpty || managerPass.isEmpty) {
                TopNotification.showWarning(ctx, 'يرجى إدخال اسم المدير والرقم السري أولاً');
                return;
              }

              final authProvider = context.read<AuthProvider>();
              final settingsProvider = context.read<SettingsProvider>();
              final productsProvider = context.read<ProductsProvider>();
              final categoriesProvider = context.read<CategoriesProvider>();
              final tablesProvider = context.read<TablesProvider>();
              final ordersProvider = context.read<OrdersProvider>();

              final treasuryProvider = context.read<TreasuryProvider>();
              final shiftsProvider = context.read<ShiftsProvider>();

              final isValid = await authProvider.verifyManagerCredentials(managerUser, managerPass);

              if (!isValid) {
                if (ctx.mounted) {
                  TopNotification.showError(ctx, 'بيانات اعتماد المدير غير صحيحة! لا تملك الصلاحية.');
                }
                return;
              }

              // Perform factory reset
              await DatabaseHelper.instance.resetAllData();

              await authProvider.loadUsers();
              await settingsProvider.loadSettings();
              await productsProvider.loadProducts();
              await categoriesProvider.loadCategories();
              await tablesProvider.loadTables();
              await ordersProvider.loadOrders();
              await treasuryProvider.loadTreasuryRecords();
              await shiftsProvider.loadCurrentShift();

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              authProvider.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                TopNotification.showSuccess(
                  context,
                  '🗑️ تم تصفية كل شيء وإعادة ضبط المصنع بنجاح! يرجى إدخال اسم ورمز المدير الجديد.',
                );
              }
            },
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('مسح وإعادة تعيين المصنع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrinterSelectionDialog(TextEditingController controller, String title) {
    final isEng = context.read<SettingsProvider>().isEnglish;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: Colors.teal),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
                tooltip: isEng ? 'Refresh printers' : 'تحديث الطابعات',
                onPressed: () async {
                  await _loadSystemPrinters();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _showPrinterSelectionDialog(controller, title);
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.star_rounded, color: Colors.amber),
                    title: Text(
                      isEng ? 'System Default Printer' : 'طابعة النظام الافتراضية (Default Printer)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      controller.text = isEng ? 'System Default Printer' : 'طابعة النظام الافتراضية (Default Printer)';
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  if (_systemPrinters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isEng ? 'No mapped printers detected. You can type the printer name directly.' : 'لم يتم الكشف عن طابعات معرفة حالياً في الكمبيوتر. يمكنك كتابة الاسم المباشر للحقل.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._systemPrinters.map((p) {
                      return ListTile(
                        leading: Icon(p.isDefault ? Icons.star_rounded : Icons.print_rounded, color: p.isDefault ? Colors.amber : Colors.teal),
                        title: Text(p.name + (p.isDefault ? (isEng ? ' (Default ⭐)' : ' (الافتراضية ⭐)') : '')),
                        subtitle: p.url != p.name ? Text(p.url, style: const TextStyle(fontSize: 11)) : null,
                        onTap: () {
                          controller.text = p.name;
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isEng ? 'Close' : 'إغلاق'),
            ),
          ],
        );
      },
    );
  }

  bool _isLoadedFromProvider = false;
  String? _lastLang;

  void _syncControllers(SettingsProvider settings) {
    final isEng = settings.isEnglish;

    String formatPrinterName(String val) {
      if (val == 'طابعة النظام الافتراضية (Default Printer)' || val == 'System Default Printer' || val.trim().isEmpty) {
        return isEng ? 'System Default Printer' : 'طابعة النظام الافتراضية (Default Printer)';
      }
      if (val == 'طابعة ملصقات الباركود (Barcode Printer)' || val == 'Barcode Label Printer') {
        return isEng ? 'Barcode Label Printer' : 'طابعة ملصقات الباركود (Barcode Printer)';
      }
      return val;
    }

    if ((!_isLoadedFromProvider || _lastLang != settings.appLanguage) && settings.settings.isNotEmpty) {
      _lastLang = settings.appLanguage;
      _nameController.text = settings.storeName;
      _addressController.text = settings.storeAddress;
      _phoneController.text = settings.storePhone;
      _headerController.text = settings.receiptHeader;
      _footerController.text = settings.receiptFooter;
      _cashierPrinterController.text = formatPrinterName(settings.cashierPrinter);
      _kitchenPrinterController.text = formatPrinterName(settings.kitchenPrinter);
      _reportsPrinterController.text = formatPrinterName(settings.reportsPrinter);
      _barcodePrinterController.text = formatPrinterName(settings.barcodePrinter);
      _logoPathController.text = settings.storeLogoPath;
      _backupFolderController.text = settings.backupFolderPath;
      _selectedLogoIcon = settings.settings['store_logo_icon'] ?? 'storefront';
      _selectedCurrency = settings.currencySymbol;
      _isLoadedFromProvider = true;
    }
  }

  final List<Map<String, dynamic>> _colorThemes = [
    {'name': 'البرتقالي الدافئ', 'nameEn': 'Warm Orange 🍊', 'hex': '#FF9800', 'color': const Color(0xFFFF9800)},
    {'name': 'الأزرق الملكي', 'nameEn': 'Royal Blue 💙', 'hex': '#1E88E5', 'color': const Color(0xFF1E88E5)},
    {'name': 'الأخضر الزمردي', 'nameEn': 'Emerald Green 💚', 'hex': '#2E7D32', 'color': const Color(0xFF2E7D32)},
    {'name': 'البنفسجي الفاخر', 'nameEn': 'Luxury Purple 💜', 'hex': '#8E24AA', 'color': const Color(0xFF8E24AA)},
    {'name': 'الأحمر الياقوتي', 'nameEn': 'Ruby Red ❤️', 'hex': '#D32F2F', 'color': const Color(0xFFD32F2F)},
    {'name': 'الرمادي الداكن الساطع', 'nameEn': 'Dark Charcoal 🖤', 'hex': '#37474F', 'color': const Color(0xFF37474F)},
    {'name': 'الوردي الفاخر (Magenta)', 'nameEn': 'Luxury Magenta 💖', 'hex': '#C2185B', 'color': const Color(0xFFC2185B)},
    {'name': 'الكحلي العميق (Navy)', 'nameEn': 'Deep Navy 💙', 'hex': '#0D47A1', 'color': const Color(0xFF0D47A1)},
  ];

  Future<void> _pickBackupFolder() async {
    try {
      final String? directoryPath = await getDirectoryPath();
      if (!mounted) return;
      if (directoryPath != null && directoryPath.isNotEmpty) {
        setState(() {
          _backupFolderController.text = directoryPath;
        });
        await context.read<SettingsProvider>().updateSetting('backup_folder_path', directoryPath);
        if (mounted) {
          TopNotification.showSuccess(context, '📁 تم اختيار وتحديد مجلد النسخ الاحتياطي بنجاح!');
        }
      }
    } catch (e) {
      debugPrint('Error picking directory: $e');
      if (mounted) {
        TopNotification.showWarning(context, 'تعذر فتح حوار اختيار المجلد تلقائياً. يمكنك كتابة أو نسخ مسار المجلد المباشر.');
      }
    }
  }

  Future<void> _performBackup() async {
    final settings = context.read<SettingsProvider>();
    String targetPath = _backupFolderController.text.trim();

    try {
      if (targetPath.isEmpty) {
        final String? selectedDir = await getDirectoryPath();
        if (selectedDir != null && selectedDir.isNotEmpty) {
          targetPath = selectedDir;
          setState(() {
            _backupFolderController.text = selectedDir;
          });
          await settings.updateSetting('backup_folder_path', selectedDir);
        } else {
          targetPath = await DatabaseHelper.getAppDatabaseDirectory();
        }
      }

      if (!mounted) return;
      TopNotification.showInfo(context, '⌛ جاري إنشاء نسخة احتياطية من قاعدة البيانات...');
      final savedFile = await DatabaseHelper.instance.backupDatabase(targetPath);

      if (mounted) {
        TopNotification.showSuccess(
          context,
          '🎉 تم حفظ النسخة الاحتياطية بنجاح في:\n${savedFile.path}',
        );
      }
    } catch (e) {
      debugPrint('Error performing backup: $e');
      if (mounted) {
        TopNotification.showWarning(context, 'حدث خطأ أثناء عمل النسخة الاحتياطية: $e');
      }
    }
  }

  Future<void> _performRestore() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'ملفات قواعد البيانات (.db, .sqlite)',
            extensions: <String>['db', 'sqlite', 'bak', 'DB', 'SQLITE'],
          ),
        ],
      );

      if (file == null) return;

      if (!mounted) return;

      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('تأكيد استعادة النسخة الاحتياطية'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تنبيه مهم: استعادة النسخة الاحتياطية ستؤدي إلى استبدال قاعدة البيانات الحالية بالبيانات الموجودة في الملف المختار.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              Text('الملف المختار: ${file.path}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
              const SizedBox(height: 12),
              const Text('هل أنت أخيرًا متأكد من استكمال عملية الاستعادة؟'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، استعادة الآن'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      if (!mounted) return;

      TopNotification.showInfo(context, '⌛ جاري استعادة قاعدة البيانات وتحديث النظام...');
      await DatabaseHelper.instance.restoreDatabase(file.path);

      if (!mounted) return;

      await context.read<SettingsProvider>().loadSettings();
      if (!mounted) return;
      await context.read<CategoriesProvider>().loadCategories();
      if (!mounted) return;
      await context.read<ProductsProvider>().loadProducts();
      if (!mounted) return;
      await context.read<OrdersProvider>().loadOrders();
      if (!mounted) return;
      await context.read<ShiftsProvider>().loadCurrentShift();
      if (!mounted) return;
      await context.read<CustomersProvider>().loadCustomers();
      if (!mounted) return;
      await context.read<PurchasesProvider>().loadAllData();
      if (!mounted) return;
      await context.read<TreasuryProvider>().loadTreasuryRecords();
      if (!mounted) return;
      await context.read<TablesProvider>().loadTables();

      if (mounted) {
        TopNotification.showSuccess(
          context,
          '🎉 تم استعادة كافة بيانات النظام والمنتجات والفواتير والإعدادات بنجاح!',
        );
      }
    } catch (e) {
      debugPrint('Error performing restore: $e');
      if (mounted) {
        TopNotification.showWarning(context, 'فشلت عملية الاستعادة: $e');
      }
    }
  }

  Widget _buildBackupRestoreSection(BuildContext context, SettingsProvider settingsProvider) {
    final isEng = settingsProvider.isEnglish;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.sd_storage_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  isEng ? 'Database Backup & Restore 💾' : 'النسخ الاحتياطي واستعادة البيانات 💾',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              isEng
                  ? 'Create database backups of all products, sales, and accounts in a safe location, or restore previous backups:'
                  : 'قم بإنشاء نسخة احتياطية لقاعدة البيانات لحفظ جميع المنتجات والمبيعات والحسابات في مكان آمن، أو استرجع نسخة سابقة عند الحاجة:',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.autorenew_rounded, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? 'Automatic Backup Schedule:' : 'جدولة النسخ الاحتياطي الأوتوماتيكي:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: ['DAILY', 'WEEKLY', 'MONTHLY', 'OFF'].contains(settingsProvider.autoBackupFrequency)
                        ? settingsProvider.autoBackupFrequency
                        : 'DAILY',
                    decoration: InputDecoration(
                      labelText: isEng ? 'Auto-Backup Frequency' : 'مدة / تكرار خزن النسخ الاحتياطية تلقائياً',
                      prefixIcon: const Icon(Icons.timer_outlined, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'DAILY',
                        child: Text(
                          isEng ? '📅 Daily Automatically (On Shift / EOD Closing)' : '📅 يومياً أوتوماتيكياً (عند إغلاق اليوم / الشفت)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'WEEKLY',
                        child: Text(
                          isEng ? '🗓️ Weekly Automatically (Every Week)' : '🗓️ أسبوعياً أوتوماتيكياً (كل أسبوع)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'MONTHLY',
                        child: Text(
                          isEng ? '📆 Monthly Automatically (Every Month)' : '📆 شهرياً أوتوماتيكياً (كل شهر)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'OFF',
                        child: Text(
                          isEng ? '🚫 Manual Only (Disable Auto-Backup)' : '🚫 يدوي فقط (تعطيل النسخ الأوتوماتيكي)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        settingsProvider.updateSetting('auto_backup_frequency', val);
                        TopNotification.showSuccess(
                          context,
                          isEng ? 'Auto backup frequency saved successfully!' : 'تم حفظ مدة النسخ الاحتياطي التلقائي نجاح!',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    settingsProvider.autoBackupFrequency == 'OFF'
                        ? (isEng ? 'Auto-backup is currently disabled. You can create manual backups anytime.' : 'النسخ الأوتوماتيكي معطل حالياً. يمكنك إنشاء نسخة احتياطية يدوياً في أي وقت.')
                        : (isEng ? 'Backup files will be saved automatically to target folder on EOD day closing.' : 'سيتم حفظ ملف النسخة الاحتياطية أوتوماتيكياً بالمجلد المختار عند إغلاق اليوم.'),
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _backupFolderController,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Default Backup Folder Path' : 'مجلد حفظ النسخ الاحتياطية (Default Backup Folder)',
                      hintText: '/Users/.../Backups or C:\\Backups',
                      prefixIcon: const Icon(Icons.folder_special, color: Colors.teal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      helperText: isEng ? 'Choose custom storage directory on your PC for automatic database backups' : 'يمكنك اختيار مجلد حفظ مخصص على جهازك ليتم حفظ النسخ فيه تلقائياً',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: ElevatedButton.icon(
                    onPressed: _pickBackupFolder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal.shade800,
                      side: BorderSide(color: Colors.teal.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(isEng ? 'Change Folder' : 'تغيير المجلد', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _performBackup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 22),
                    label: Text(
                      isEng ? '📦 Create Backup Now' : '📦 إنشاء نسخة احتياطية الآن',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _performRestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.restore_page_rounded, size: 22),
                    label: Text(
                      isEng ? '🔄 Restore Backup from File...' : '🔄 استعادة نسخة احتياطية من ملف...',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorSection(BuildContext context, SettingsProvider settingsProvider) {
    final currentHex = settingsProvider.themeColorHex.toUpperCase();
    final isEng = settingsProvider.isEnglish;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: settingsProvider.primaryColor,
                  child: const Icon(Icons.palette_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  isEng ? 'App Color Palette & Theme 🎨' : 'مظهر وألوان البرنامج (App Color Palette) 🎨',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              isEng ? 'Select your preferred primary theme color to apply instantly across all app screens:' : 'اختر اللون الرئيسي المفضل لديك ليتم تطبيقه فورياً على كافة واجهات وشاشات وأزرار البرنامج:',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorThemes.map((theme) {
                final hex = (theme['hex'] as String).toUpperCase();
                final isSelected = currentHex == hex;
                final color = theme['color'] as Color;

                return InkWell(
                  onTap: () async {
                    await settingsProvider.updateSetting('primary_color', theme['hex']);
                    if (context.mounted) {
                      TopNotification.showSuccess(
                        context,
                        isEng ? '🎨 Theme color updated successfully!' : '🎨 تم تطبيق مظهر [${theme['name']}] على الواجهة وتثبيته بنجاح!',
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: color,
                          child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEng ? (theme['nameEn'] ?? theme['name']) as String : theme['name'] as String,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? color : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context, SettingsProvider settingsProvider) {
    final currentLang = settingsProvider.appLanguage;
    final isEng = settingsProvider.isEnglish;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade700,
                  child: const Icon(Icons.language_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  isEng ? 'Application Language 🌐' : 'لغة واجهة البرنامج (App Language) 🌐',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              isEng ? 'Choose interface display language for instant application across screens:' : 'اختر لغة العرض والواجهة المناسبة لك ليتم تطبيقه فورياً على كافة الواجهات والعمليات:',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await settingsProvider.updateSetting('app_language', 'ar');
                      if (context.mounted) {
                        TopNotification.showSuccess(context, '🇸🇦 تم تغيير لغة الواجهة إلى العربية بنجاح!');
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: currentLang == 'ar' ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: currentLang == 'ar' ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: currentLang == 'ar' ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🇸🇦', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('العربية (Arabic)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 2),
                                Text('الواجهة باللغة العربية (RTL)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                          if (currentLang == 'ar') const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await settingsProvider.updateSetting('app_language', 'en');
                      if (context.mounted) {
                        TopNotification.showSuccess(context, '🇺🇸 App Language updated to English successfully!');
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: currentLang == 'en' ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: currentLang == 'en' ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: currentLang == 'en' ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('English (الإنجليزية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 2),
                                Text('English interface (LTR)', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                          if (currentLang == 'en') const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isEng = settings.isEnglish;
    _syncControllers(settings);

    final tabs = [
      {
        'title': isEng ? 'Store & Receipt' : 'بيانات المطعم والفاتورة',
        'subtitle': isEng ? 'Store details, logo & currency' : 'اسم المطعم، اللوجو، العملة، والتذييل',
        'icon': Icons.storefront_rounded,
        'color': AppColors.primary,
      },
      {
        'title': isEng ? 'Printer Settings' : 'إعدادات الطابعات',
        'subtitle': isEng ? 'Cashier, Kitchen & Reports' : 'طابعة الكاشير، المطبخ والتقارير',
        'icon': Icons.print_rounded,
        'color': Colors.teal,
      },
      {
        'title': isEng ? 'Theme & Language' : 'المظهر واللغة',
        'subtitle': isEng ? 'App language & theme color' : 'لغة الواجهة وألوان التطبيق',
        'icon': Icons.palette_rounded,
        'color': Colors.purple,
      },
      {
        'title': isEng ? 'Backup & Updates' : 'النسخ الاحتياطي والتحديثات',
        'subtitle': isEng ? 'DB Backup & Software Updates' : 'حفظ القاعدة وتحديثات البرنامج',
        'icon': Icons.cloud_sync_rounded,
        'color': Colors.blue,
      },
      {
        'title': isEng ? 'Maintenance & Reset' : 'صيانة وإعادة التعيين',
        'subtitle': isEng ? 'Factory reset & data wipe' : 'إعادة تعيين المصنع والمسح الشامل',
        'icon': Icons.engineering_rounded,
        'color': Colors.red,
      },
      {
        'title': isEng ? 'About App' : 'حول البرنامج',
        'subtitle': isEng ? 'App name, version & support contact' : 'اسم ورقم إصدار البرنامج ومعلومات الدعم',
        'icon': Icons.info_outline_rounded,
        'color': Colors.indigo,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_suggest_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              isEng ? 'System & Restaurant Settings' : 'إعدادات النظام والمطعم',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar Navigation Panel
          Container(
            width: 290,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(3, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: Colors.grey.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? 'SETTINGS SECTIONS' : 'أقسام الإعدادات',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isSelected = _selectedTab == index;
                      final tabColor = tab['color'] as Color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTab = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? tabColor.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? tabColor : Colors.transparent,
                                  width: isSelected ? 1.5 : 0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? tabColor : tabColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      tab['icon'] as IconData,
                                      color: isSelected ? Colors.white : tabColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tab['title'] as String,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 14,
                                            color: isSelected ? Colors.black87 : Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tab['subtitle'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected ? tabColor.withValues(alpha: 0.9) : Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.chevron_left_rounded, color: tabColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // Main Tab Content Area
          Expanded(
            child: Container(
              color: Colors.grey.shade50.withValues(alpha: 0.5),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedTab),
                        child: _buildSelectedTabContent(context, settings, isEng),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                isEng ? 'Click Save button to apply all changes across system' : 'تأكد من النقرفوق زر الحفظ أدناه لتطبيق كافة التعديلات فورياً',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.save_rounded, size: 22),
                label: Text(
                  isEng ? 'Save All Settings 💾' : 'حفظ إعدادات المطعم والطابعات 💾',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(BuildContext context, SettingsProvider settings, bool isEng) {
    switch (_selectedTab) {
      case 0:
        return _buildStoreAndReceiptTab(context, settings, isEng);
      case 1:
        return _buildPrintersTab(context, settings, isEng);
      case 2:
        return _buildThemeAndLanguageTab(context, settings, isEng);
      case 3:
        return _buildBackupAndUpdatesTab(context, settings, isEng);
      case 4:
        return _buildMaintenanceTab(context, settings, isEng);
      case 5:
        return _buildAboutAppSection(context, settings, isEng);
      default:
        return _buildStoreAndReceiptTab(context, settings, isEng);
    }
  }

  // TAB 0: Store & Receipt Info
  Widget _buildStoreAndReceiptTab(BuildContext context, SettingsProvider settings, bool isEng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Info & Logo Card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.store, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Restaurant Info & Printed Receipt Logo' : 'معلومات المطعم والشعار المطبوع بالفاتورة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 28),

                Text(
                  isEng ? 'Choose custom logo image from gallery (Custom Logo Image):' : 'اختيار صورة الشعار الخاص بالمطعم من المعرض (Custom Logo Image):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickLogoImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.photo_library_rounded, size: 24),
                              label: Text(
                                isEng ? '🖼️ Choose Logo Image from Gallery' : '🖼️ فتح المعرض وااختيار صورة اللوجو من الجهاز',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (_logoPathController.text.isNotEmpty && File(_logoPathController.text).existsSync()) ...[
                            const SizedBox(width: 14),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(_logoPathController.text),
                                    width: 65,
                                    height: 65,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _logoPathController.clear();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _logoPathController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: isEng ? 'Image File Path' : 'مسار ملف الصورة بالجهاز (Path)',
                          hintText: '/Users/.../logo.png',
                          isDense: true,
                          prefixIcon: const Icon(Icons.link, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  isEng ? 'Or choose a graphic logo icon preset for receipts:' : 'أو اختر شعار رمز جرافيكي جاهز للفاتورة:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _logoPresets.map((preset) {
                    final isSelected = _selectedLogoIcon == preset['name'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedLogoIcon = preset['name'];
                        });
                        _saveSettings();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              preset['icon'] as IconData,
                              color: isSelected ? AppColors.primary : Colors.grey.shade700,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEng ? (preset['labelEn'] ?? preset['label']) as String : preset['label'] as String,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Restaurant Name (Printed at header & footer) *' : 'اسم المطعم (يظهر أعلى وأسفل الفاتورة) *',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Detailed Restaurant Address (Printed on receipt) *' : 'عنوان المطعم التفصيلي (يظهر بالفاتورة) *',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Restaurant Phone Number (Printed on receipt) *' : 'رقم موبايل / هاتف المطعم (يظهر بالفاتورة) *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const Divider(height: 32),

                // Currency Selection
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Icon(Icons.monetization_on_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Store Currency' : 'عملة النظام والفواتير (Store Currency)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isEng ? 'Choose official store currency to apply across all invoices, prices, and reports:' : 'اختر العملة الرسمية للمتجر لتطبيقها فورياً على كافة الفواتير والأسعار والتقارير:',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCurrency = 'د.ع';
                          });
                          _saveSettings();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedCurrency == 'د.ع' ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedCurrency == 'د.ع' ? AppColors.primary : Colors.grey.shade300,
                              width: _selectedCurrency == 'د.ع' ? 2.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEng ? '🇮🇶 Iraqi Dinar (IQD)' : '🇮🇶 دينار عراقي (د.ع)',
                                style: TextStyle(
                                  fontWeight: _selectedCurrency == 'د.ع' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedCurrency == 'د.ع' ? AppColors.primary : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              if (_selectedCurrency == 'د.ع') ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCurrency = '\$';
                          });
                          _saveSettings();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedCurrency == '\$' ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedCurrency == '\$' ? AppColors.primary : Colors.grey.shade300,
                              width: _selectedCurrency == '\$' ? 2.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEng ? '🇺🇸 US Dollar (\$)' : '🇺🇸 دولار أمريكي (\$)',
                                style: TextStyle(
                                  fontWeight: _selectedCurrency == '\$' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedCurrency == '\$' ? AppColors.primary : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              if (_selectedCurrency == '\$') ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Receipt Messages Card
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.receipt, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Receipt Header & Footer Messages' : 'نصوص الترحيب والتذييل بالفاتورة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 28),

                TextField(
                  controller: _headerController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Receipt Top Welcome Message' : 'رسالة الترحيب أعلى الفاتورة',
                    prefixIcon: const Icon(Icons.short_text),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _footerController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Receipt Bottom Footer Message' : 'رسالة الختام أسفل الفاتورة',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // TAB 1: Printers & Multi-POS Networking Configuration
  Widget _buildPrintersTab(BuildContext context, SettingsProvider settings, bool isEng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.print_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEng ? 'Cashier & Kitchen Printer Settings (KOT)' : 'إعدادات طابعة الكاشير وطابعة المطبخ (KOT)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadSystemPrinters,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
                      tooltip: isEng ? 'Refresh system printers list' : 'تحديث قائمة طابعات الجهاز',
                    ),
                  ],
                ),
                const Divider(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.important_devices_rounded, color: Colors.teal, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoadingPrinters
                              ? (isEng ? 'Querying system printers list...' : 'جاري الاستعلام عن طابعات جهاز الكمبيوتر...')
                              : _systemPrinters.isEmpty
                                  ? (isEng ? 'No mapped printers detected. System default printer will be used.' : 'لم يتم الكشف عن طابعات مخصصة في النظام. يمكنك الطباعة عبر طابعة النظام الافتراضية.')
                                  : (isEng ? 'Detected ${_systemPrinters.length} mapped system printers on your PC!' : 'تم الكشف عن ${_systemPrinters.length} طابعة معرفة ومجهزة في جهازك!'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ),
                      if (_isLoadingPrinters)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _cashierPrinterController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Invoice & Cashier Main Printer' : 'طابعة الفواتير والكاشير الرئيسية (Invoice Printer)',
                    prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.teal),
                      tooltip: isEng ? 'Select Mapped System Printer' : 'اختيار من طابعات الكمبيوتر Mapped Printers',
                      onPressed: () => _showPrinterSelectionDialog(_cashierPrinterController, isEng ? 'Select Invoice Printer' : 'اختر طابعة الفواتير والكاشير الرئيسية'),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    helperText: isEng ? 'Click dropdown arrow to pick PC printer or type printer name directly' : 'انقر على السهم لااختيار طابعة الكمبيوتر أو اكتب اسم الطابعة المباشر',
                  ),
                ),



                TextField(
                  controller: _kitchenPrinterController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Kitchen Order Ticket Printer (KOT)' : 'طابعة المطبخ وإرسال الطلبات (Kitchen KOT Printer)',
                    prefixIcon: const Icon(Icons.soup_kitchen, color: Colors.orange),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.orange),
                      tooltip: isEng ? 'Select Mapped System Printer' : 'اختيار من طابعات الكمبيوتر Mapped Printers',
                      onPressed: () => _showPrinterSelectionDialog(_kitchenPrinterController, isEng ? 'Select Kitchen (KOT) Printer' : 'اختر طابعة المطبخ (KOT)'),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    helperText: isEng ? 'Click dropdown arrow to pick kitchen printer or type printer name directly' : 'انقر على السهم لاختيار طابعة المطبخ من الكمبيوتر أو اكتب الاسم المباشر',
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _reportsPrinterController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Administrative & Financial Reports Printer' : 'طابعة التقارير الإدارية والمالية (Reports Printer)',
                    prefixIcon: const Icon(Icons.print, color: Colors.purple),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.purple),
                      tooltip: isEng ? 'Select Mapped System Printer' : 'اختيار من طابعات الكمبيوتر Mapped Printers',
                      onPressed: () => _showPrinterSelectionDialog(_reportsPrinterController, isEng ? 'Select Reports Printer' : 'اختر طابعة التقارير الإدارية'),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    helperText: isEng ? 'Used to print daily, monthly, and financial reports directly' : 'تستخدم لطباعة التقرير اليومي، الشهري، والمالي مباشرة من قسم التقارير',
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _barcodePrinterController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Barcode Label Printer' : 'طابعة ملصقات الباركود (Barcode Label Printer)',
                    prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue),
                      tooltip: isEng ? 'Select Mapped System Printer' : 'اختيار من طابعات الكمبيوتر Mapped Printers',
                      onPressed: () => _showPrinterSelectionDialog(_barcodePrinterController, isEng ? 'Select Barcode Printer' : 'اختر طابعة ملصقات الباركود'),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    helperText: isEng ? 'Used for barcode sticker printing (e.g. Xprinter / Zebra)' : 'تستخدم لطباعة ملصقات الباركود للأصناف والمنتجات مباشرة (مثل طابعات Xprinter / Zebra)',
                  ),
                ),


              ],
            ),
          ),
        ),
      ],
    );
  }



  // TAB 2: Appearance & Language
  Widget _buildThemeAndLanguageTab(BuildContext context, SettingsProvider settings, bool isEng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLanguageSection(context, settings),
        const SizedBox(height: 20),
        _buildThemeColorSection(context, settings),
        const SizedBox(height: 20),
        _buildTopNotificationSection(context, settings),
      ],
    );
  }

  Widget _buildTopNotificationSection(BuildContext context, SettingsProvider settings) {
    final isEng = settings.isEnglish;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  isEng ? 'Top Floating Notifications' : 'إعدادات الإشعارات العلوية المنبثقة',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 28),
            SwitchListTile(
              value: settings.showTopNotifications,
              activeTrackColor: AppColors.primary,
              title: Text(
                isEng ? 'Show Top Floating Notifications' : 'إظهار الإشعارات العلوية المنبثقة',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                isEng
                    ? 'Display temporary alert banners at the top of the screen during operations.'
                    : 'عرض شريط التنبيهات المؤقت في أعلى الشاشة عند تفعيل العمليات وحفظ البيانات.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              onChanged: (val) {
                settings.setShowTopNotifications(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: Backup & Updates
  Widget _buildBackupAndUpdatesTab(BuildContext context, SettingsProvider settings, bool isEng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLicenseSubscriptionSection(context, settings),
        const SizedBox(height: 20),
        _buildBackupRestoreSection(context, settings),
        const SizedBox(height: 20),

        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFF9800),
                      child: Icon(Icons.system_update_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEng ? 'Software Updates' : 'تحديثات النظام والبرنامج',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEng
                                ? 'Current Version: v$_currentAppVersion'
                                : 'الإصدار الحالي المثبت: v$_currentAppVersion',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  isEng
                      ? 'Check for new updates online to install new features and improvements.'
                      : 'يمكنك الفحص عن التحديثات الجديدة عبر الإنترنت لتنزيل أحدث المميزات والإصلاحات تلقائياً.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isCheckingUpdate ? null : _checkForUpdatesManually,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isCheckingUpdate
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _isCheckingUpdate
                          ? (isEng ? 'Checking for updates...' : 'جاري الفحص...')
                          : (isEng ? 'Check for Updates Now 🔄' : 'فحص وجود تحديثات الآن 🔄'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseSubscriptionSection(BuildContext context, SettingsProvider settings) {
    final isEng = settings.isEnglish;
    return FutureBuilder<LicenseInfo>(
      future: LicenseService.instance.initAndGetLicenseInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final isActivated = info?.isActivated ?? false;
        final daysRemaining = info?.daysRemaining ?? 0;
        final isExpired = info?.isExpired ?? false;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isActivated
                          ? Colors.green
                          : (isExpired ? Colors.red : Colors.amber.shade800),
                      child: Icon(
                        isActivated
                            ? Icons.verified_user_rounded
                            : (isExpired ? Icons.lock_clock_rounded : Icons.hourglass_top_rounded),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEng ? 'Software Subscription & License' : 'إدارة اشتراك وترخيص النظام',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isActivated
                                ? (isEng
                                    ? 'Annual Subscription Active (${daysRemaining}d remaining)'
                                    : 'اشتراك سنوي مفعّل بنجاح (متبقي $daysRemaining يوماً)')
                                : (isExpired
                                    ? (isEng ? 'Trial Expired 🔒' : 'انتهت الفترة التجريبية (30 يوم) 🔒')
                                    : (isEng
                                        ? 'Free Trial Period ($daysRemaining days remaining)'
                                        : 'فترة تجريبية مجانية (متبقي $daysRemaining يوماً من أصل 30 يوماً)')),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isActivated
                                  ? Colors.green.shade800
                                  : (isExpired ? Colors.red.shade800 : Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  isActivated
                      ? (isEng
                          ? 'Your annual subscription key is active. Key: ${info?.activationKey ?? ''}'
                          : 'الاشتراك السنوي لـ CASHBOX POS مفعّل بنجاح. رمز التفعيل: ${info?.activationKey ?? ''}')
                      : (isEng
                          ? 'The app is running in free 30-day trial mode. Activate annual key anytime to extend.'
                          : 'البرنامج يعمل حالياً بالنسخة التجريبية المجانية لمدة 30 يوماً. يمكنك إدخال رمز الاشتراك السنوي في أي وقت للتفعيل.'),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LicenseActivationScreen(),
                        ),
                      );
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActivated ? Colors.green.shade700 : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isActivated ? Icons.key_rounded : Icons.vpn_key_rounded),
                    label: Text(
                      isActivated
                          ? (isEng ? 'Manage Subscription Key' : 'إدارة / تحديث كود الاشتراك 🔑')
                          : (isEng ? 'Activate Annual Subscription 🔑' : 'إدخال كود التفعيل السنوي 🔑'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 4: Maintenance & Factory Reset
  Widget _buildMaintenanceTab(BuildContext context, SettingsProvider settings, bool isEng) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 3,
          color: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.shade200, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Factory Reset (Erase All Data)' : 'إعادة تعيين المصنع (مسح جميع البيانات)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  isEng ? 'Warning: Deletes all products, categories, invoices, and user records. Reverts to default fresh install.' : 'تنبيه: مسح كافة بيانات النظام والمنتجات والفواتير السابقة وإعادة التثبيت الافتراضي. تتطلب موافقة المدير بالرمز السري.',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _confirmFactoryReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.warning_rounded),
                    label: Text(
                      isEng ? 'Factory Reset & Wipe Data...' : 'إعادة تعيين المصنع ومسح البيانات...',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutAppSection(BuildContext context, SettingsProvider settings, bool isEng) {
    const supportPhone = '+9647502198213';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                // App Logo Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 54, color: Colors.white),
                ),
                const SizedBox(height: 16),

                // App Name
                Text(
                  isEng ? 'CASHBOX POS SYSTEM' : 'نظام CashBox POS لنقاط البيع المباشرة',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isEng
                      ? 'Integrated Point of Sale & Restaurant Management System'
                      : 'النظام المتكامل لإدارة المطاعم والعمليات والكاشير والمبيعات',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // App Version Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEng ? 'Software Version' : 'رقم إصدار البرنامج',
                              style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v$_currentAppVersion',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEng ? 'Latest Official Stable Release' : 'الإصدار الرسمي المعتمد للنظام',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isEng ? 'Active License ✅' : 'مرخص ومفعل ✅',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Support Phone Number Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEng ? 'Technical Support Contact' : 'رقم الدعم الفني المباشر',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: SelectableText(
                                    supportPhone,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(text: supportPhone));
                                TopNotification.showSuccess(
                                  context,
                                  isEng ? 'Support phone number copied: $supportPhone 📋' : 'تم نسخ رقم الدعم الفني بنجاح: $supportPhone 📋',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: Text(
                                isEng ? 'Copy Number 📋' : 'نسخ رقم الدعم 📋',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Copyright & Rights
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copyright_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      isEng
                          ? 'CashBox POS System © 2026. All Rights Reserved.'
                          : 'حقوق الطبع والنشر © 2026 - نظام CashBox POS لنقاط البيع. جميع الحقوق محفوظة.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
