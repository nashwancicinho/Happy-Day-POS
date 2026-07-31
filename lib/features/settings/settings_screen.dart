import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/print_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../database/database_helper.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../categories/categories_provider.dart';
import '../orders/orders_provider.dart';
import '../products/products_provider.dart';
import '../shifts/shifts_provider.dart';
import '../tables/tables_provider.dart';
import '../treasury/treasury_provider.dart';
import 'settings_provider.dart';

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
  late TextEditingController _logoPathController;
  String _selectedLogoIcon = 'storefront';
  String _selectedCurrency = 'د.ع';

  List<Printer> _systemPrinters = [];
  bool _isLoadingPrinters = false;

  final List<Map<String, dynamic>> _logoPresets = [
    {'name': 'storefront', 'label': 'محل / متجر', 'icon': Icons.storefront_rounded},
    {'name': 'restaurant', 'label': 'مطعم شائعات', 'icon': Icons.restaurant},
    {'name': 'fastfood', 'label': 'وجبات سريعة', 'icon': Icons.fastfood},
    {'name': 'local_cafe', 'label': 'كافيه / قهوة', 'icon': Icons.local_cafe},
    {'name': 'cake', 'label': 'حلويات / كيك', 'icon': Icons.cake},
    {'name': 'dinner_dining', 'label': 'عشاء فاخر', 'icon': Icons.dinner_dining},
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
    _logoPathController = TextEditingController(text: settings.storeLogoPath);
    _selectedLogoIcon = settings.settings['store_logo_icon'] ?? 'storefront';
    _selectedCurrency = settings.currencySymbol;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSystemPrinters();
    });
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
    _logoPathController.dispose();
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
        final dbPath = await getDatabasesPath();
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
                tooltip: 'تحديث الطابعات',
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
                    title: const Text('طابعة النظام الافتراضية (Default Printer)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      controller.text = 'طابعة النظام الافتراضية (Default Printer)';
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  if (_systemPrinters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لم يتم الكشف عن طابعات معرفة حالياً في الكمبيوتر. يمكنك كتابة الاسم المباشر للحقل.', textAlign: TextAlign.center),
                    )
                  else
                    ..._systemPrinters.map((p) {
                      return ListTile(
                        leading: Icon(p.isDefault ? Icons.star_rounded : Icons.print_rounded, color: p.isDefault ? Colors.amber : Colors.teal),
                        title: Text(p.name + (p.isDefault ? ' (الافتراضية ⭐)' : '')),
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
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  bool _isLoadedFromProvider = false;

  void _syncControllers(SettingsProvider settings) {
    if (!_isLoadedFromProvider && settings.settings.isNotEmpty) {
      _nameController.text = settings.storeName;
      _addressController.text = settings.storeAddress;
      _phoneController.text = settings.storePhone;
      _headerController.text = settings.receiptHeader;
      _footerController.text = settings.receiptFooter;
      _cashierPrinterController.text = settings.cashierPrinter;
      _kitchenPrinterController.text = settings.kitchenPrinter;
      _reportsPrinterController.text = settings.reportsPrinter;
      _logoPathController.text = settings.storeLogoPath;
      _selectedLogoIcon = settings.settings['store_logo_icon'] ?? 'storefront';
      _selectedCurrency = settings.currencySymbol;
      _isLoadedFromProvider = true;
    }
  }

  final List<Map<String, dynamic>> _colorThemes = [
    {'name': 'البرتقالي الدافئ', 'hex': '#FF9800', 'color': const Color(0xFFFF9800)},
    {'name': 'الأزرق الملكي', 'hex': '#1E88E5', 'color': const Color(0xFF1E88E5)},
    {'name': 'الأخضر الزمردي', 'hex': '#2E7D32', 'color': const Color(0xFF2E7D32)},
    {'name': 'البنفسجي الفاخر', 'hex': '#8E24AA', 'color': const Color(0xFF8E24AA)},
    {'name': 'الأحمر الياقوتي', 'hex': '#D32F2F', 'color': const Color(0xFFD32F2F)},
    {'name': 'الرمادي الداكن الساطع', 'hex': '#37474F', 'color': const Color(0xFF37474F)},
    {'name': 'الوردي الفاخر (Magenta)', 'hex': '#C2185B', 'color': const Color(0xFFC2185B)},
    {'name': 'الكحلي العميق (Navy)', 'hex': '#0D47A1', 'color': const Color(0xFF0D47A1)},
  ];

  Widget _buildThemeColorSection(BuildContext context, SettingsProvider settingsProvider) {
    final currentHex = settingsProvider.themeColorHex.toUpperCase();

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
                const Text(
                  'مظهر وألوان البرنامج (App Color Palette) 🎨',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 28),
            const Text(
              'اختر اللون الرئيسي المفضل لديك ليتم تطبيقه فورياً على كافة واجهات وشاشات وأزرار البرنامج:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
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
                        '🎨 تم تطبيق مظهر [${theme['name']}] على الواجهة وتثبيته بنجاح!',
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
                          theme['name'] as String,
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    _syncControllers(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المطعم والطابعات والشعار وإعادة التعيين'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 0: Theme Color Palette Selection
                _buildThemeColorSection(context, settings),

                const SizedBox(height: 20),

                // Section 1: Store Information & Logo Upload
                Card(
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
                              backgroundColor: AppColors.primary,
                              child: const Icon(Icons.store, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'معلومات المطعم والشعار المطبوع بالفاتورة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Custom Image Logo Upload Section (معرض الصور)
                        const Text(
                          'اختيار صورة الشعار الخاص بالمطعم من المعرض (Custom Logo Image):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                      label: const Text(
                                        '🖼️ فتح المعرض واختيار صورة اللوجو من الجهاز',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                                  labelText: 'مسار ملف الصورة بالجهاز (Path)',
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

                        // Logo Presets Selection Section
                        const Text(
                          'أو اختر شعار رمز جرافيكي جاهز للفاتورة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                      preset['label'] as String,
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

                        // Store Name Field
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المطعم (يظهر أعلى وأسفل الفاتورة) *',
                            prefixIcon: const Icon(Icons.business),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Address Field
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'عنوان المطعم التفصيلي (يظهر بالفاتورة) *',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Phone Field
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم موبايل / هاتف المطعم (يظهر بالفاتورة) *',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),

                        const Divider(height: 32),

                        // Section 1.5: Currency Selection
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Icon(Icons.monetization_on_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'عملة النظام والفواتير (Store Currency)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'اختر العملة الرسمية للمتجر لتطبيقها فورياً على كافة الفواتير والأسعار والتقارير:',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
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
                                        '🇮🇶 دينار عراقي (د.ع)',
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
                                        '🇺🇸 دولار أمريكي (\$)',
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

                // Section 2: Printers Configuration (Cashier Printer & Kitchen Printer)
                Card(
                  elevation: 4,
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
                            const Expanded(
                              child: Text(
                                'إعدادات طابعة الكاشير وطابعة المطبخ (KOT)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: _loadSystemPrinters,
                              icon: const Icon(Icons.refresh_rounded, color: Colors.teal),
                              tooltip: 'تحديث قائمة طابعات الجهاز',
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // System Printers Status Banner
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
                                      ? 'جاري الاستعلام عن طابعات جهاز الكمبيوتر...'
                                      : _systemPrinters.isEmpty
                                          ? 'لم يتم الكشف عن طابعات مخصصة في النظام. يمكنك الطباعة عبر طابعة النظام الافتراضية.'
                                          : 'تم الكشف عن ${_systemPrinters.length} طابعة معرفة ومجهزة في جهازك!',
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

                        // Cashier Printer Field with Selection Dialog
                        TextField(
                          controller: _cashierPrinterController,
                          decoration: InputDecoration(
                            labelText: 'طابعة الفواتير والكاشير الرئيسية (Invoice Printer)',
                            prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.teal),
                              tooltip: 'اختيار من طابعات الكمبيوتر Mapped Printers',
                              onPressed: () => _showPrinterSelectionDialog(_cashierPrinterController, 'اختر طابعة الفواتير والكاشير الرئيسية'),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            helperText: 'انقر على السهم لاختيار طابعة الكمبيوتر أو اكتب اسم الطابعة المباشر',
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Kitchen Printer Field with Selection Dialog
                        TextField(
                          controller: _kitchenPrinterController,
                          decoration: InputDecoration(
                            labelText: 'طابعة المطبخ وإرسال الطلبات (Kitchen KOT Printer)',
                            prefixIcon: const Icon(Icons.soup_kitchen, color: Colors.orange),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.orange),
                              tooltip: 'اختيار من طابعات الكمبيوتر Mapped Printers',
                              onPressed: () => _showPrinterSelectionDialog(_kitchenPrinterController, 'اختر طابعة المطبخ (KOT)'),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            helperText: 'انقر على السهم لاختيار طابعة المطبخ من الكمبيوتر أو اكتب الاسم المباشر',
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Reports Printer Field with Selection Dialog
                        TextField(
                          controller: _reportsPrinterController,
                          decoration: InputDecoration(
                            labelText: 'طابعة التقارير الإدارية والمالية (Reports Printer)',
                            prefixIcon: const Icon(Icons.print, color: Colors.purple),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.purple),
                              tooltip: 'اختيار من طابعات الكمبيوتر Mapped Printers',
                              onPressed: () => _showPrinterSelectionDialog(_reportsPrinterController, 'اختر طابعة التقارير الإدارية'),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            helperText: 'تستخدم لطباعة التقرير اليومي، الشهري، والمالي مباشرة من قسم التقارير',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section 3: Receipt Messages
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple,
                              child: Icon(Icons.receipt, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'نصوص الترحيب والتذييل بالفاتورة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Header text
                        TextField(
                          controller: _headerController,
                          decoration: InputDecoration(
                            labelText: 'رسالة الترحيب أعلى الفاتورة',
                            prefixIcon: const Icon(Icons.short_text),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Footer text
                        TextField(
                          controller: _footerController,
                          decoration: InputDecoration(
                            labelText: 'رسالة الختام أسفل الفاتورة',
                            prefixIcon: const Icon(Icons.notes),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section 4: Factory Reset (إعادة تعيين المصنع)
                Card(
                  elevation: 4,
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
                        const Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.delete_forever, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'إعادة تعيين المصنع (مسح جميع البيانات)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        const Text(
                          'تنبيه: مسح كافة بيانات النظام والمنتجات والفواتير السابقة وإعادة التثبيت الافتراضي. تطلب موافقة المدير بالرمز السري.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
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
                            label: const Text(
                              'إعادة تعيين المصنع ومسح البيانات...',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.save_rounded, size: 26),
                    label: const Text(
                      'حفظ إعدادات المطعم والطابعات والشعار',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
