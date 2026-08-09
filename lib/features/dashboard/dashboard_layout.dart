import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../cashier/cashier_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../day_closing/presentation/day_closing_screen.dart';
import '../inventory/presentation/inventory_screen.dart';
import '../payroll/payroll_screen.dart';
import '../products/presentation/products_screen.dart';
import '../products/products_provider.dart';
import '../purchases/purchases_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_provider.dart';
import '../tables/tables_screen.dart';
import '../users/users_screen.dart';
import 'home_operation_screen.dart';
import '../../services/local_server_service.dart';
import '../settings/sync_qr_widget.dart';
import '../tables/tables_provider.dart';
import '../orders/orders_provider.dart';
import '../../core/widgets/manager_auth_dialog.dart';
import '../../core/services/license_service.dart';
import '../license/license_activation_screen.dart';



class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int selectedIndex = 0;
  late final AppLifecycleListener _lifecycleListener;
  LicenseInfo? _licenseInfo;
  bool _isFullscreen = false;

  void _toggleFullscreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final current = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!current);
        if (mounted) {
          setState(() {
            _isFullscreen = !current;
          });
        }
      } catch (e) {
        debugPrint('windowManager toggle error: $e');
      }
    } else {
      setState(() {
        _isFullscreen = !_isFullscreen;
      });
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Widget _buildScaledPage(Widget page, double scale) {
    if (scale == 1.0) return page;
    if (scale == 0.0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final minW = constraints.maxWidth < 1280 ? 1280.0 : constraints.maxWidth;
          final minH = constraints.maxHeight < 720 ? 720.0 : constraints.maxHeight;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: minW,
              height: minH,
              child: page,
            ),
          );
        },
      );
    }
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: page,
    );
  }

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.isFullScreen().then((isFS) {
        if (mounted) setState(() => _isFullscreen = isFS);
      }).catchError((_) {});
    }

    // Start POS local network server for Waiter Mobile App
    LocalServerService.instance.startServer();
    LocalServerService.instance.setTableUpdateCallback(() {
      if (mounted) {
        context.read<TablesProvider>().loadTables();
        context.read<OrdersProvider>().loadOrders();
      }
    });

    _checkLicenseStatus();
  }

  Future<void> _checkLicenseStatus() async {
    final info = await LicenseService.instance.initAndGetLicenseInfo();
    if (!mounted) return;
    setState(() {
      _licenseInfo = info;
    });

    if (info.isExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => LicenseActivationScreen(
            isModalDialog: true,
            onActivated: () {
              _checkLicenseStatus();
            },
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 30),
            const SizedBox(width: 10),
            Text(isEng ? 'Confirm Exit Application' : 'تأكيد إغلاق البرنامج', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isEng
              ? 'Are you sure you want to exit the application completely?'
              : 'هل أنت تأكد من رغبتك في إغلاق وخروج البرنامج بالكامل؟',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isEng ? 'No (Cancel)' : 'لا (إلغاء الإغلاق)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isEng ? 'Yes, Exit App' : 'نعم، إغلاق البرنامج', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
      exit(0);
    }

    return (shouldExit == true) ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  final List<Widget> pages = const [
    HomeOperationScreen(),
    TablesScreen(),
    CashierScreen(),
    ProductsScreen(),
    CategoriesScreen(),
    InventoryScreen(),
    PurchasesScreen(),
    UsersScreen(),
    DebtsScreen(),
    PayrollScreen(),
    ReportsScreen(),
    SettingsScreen(),
    DayClosingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;

    // 1. Check if user is logged in. If not, show LoginScreen
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    final currentScale = context.watch<SettingsProvider>().screenScale;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _confirmExitApp(context);
          },
          child: Scaffold(
            drawer: Drawer(
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront, size: 44, color: Colors.white),
                          const SizedBox(height: 8),
                          const Text(
                            "HAPPY DAY POS",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${authProvider.currentUserName} (${isEng ? (authProvider.currentUserRole == 'مدير' ? 'Manager' : (authProvider.currentUserRole == 'كاشير' ? 'Cashier' : authProvider.currentUserRole)) : authProvider.currentUserRole})",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Consumer<SettingsProvider>(
                      builder: (context, settings, _) {
                        final isEnglish = settings.isEnglish;
                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildDrawerTile(0, Icons.home_outlined, Icons.home, isEnglish ? "Home" : "الرئيسية"),
                            _buildDrawerTile(1, Icons.table_restaurant_outlined, Icons.table_restaurant, isEnglish ? "Tables Map" : "الطاولات"),
                            _buildDrawerTile(2, Icons.point_of_sale_outlined, Icons.point_of_sale, isEnglish ? "Cashier & POS" : "الكاشير"),
                            _buildDrawerTile(3, Icons.fastfood_outlined, Icons.fastfood, isEnglish ? "Products" : "الأصناف"),
                            _buildDrawerTile(4, Icons.category_outlined, Icons.category, isEnglish ? "Categories" : "التصنيفات"),
                            _buildDrawerTile(5, Icons.inventory_2_outlined, Icons.inventory_2, isEnglish ? "Inventory" : "المخزن"),
                            _buildDrawerTile(6, Icons.shopping_bag_outlined, Icons.shopping_bag, isEnglish ? "Purchases" : "المشتريات والموردين"),
                            _buildDrawerTile(7, Icons.people_outline, Icons.people, isEnglish ? "Users & Roles" : "المستخدمون"),
                            _buildDrawerTile(8, Icons.request_quote_outlined, Icons.request_quote, isEnglish ? "Debts Log" : "سجل الديون"),
                            _buildDrawerTile(9, Icons.payments_outlined, Icons.payments, isEnglish ? "Employee Payroll" : "رواتب الموظفين والسُلف"),
                            _buildDrawerTile(10, Icons.bar_chart_outlined, Icons.bar_chart, isEnglish ? "Reports & Sales" : "التقارير"),
                            _buildDrawerTile(11, Icons.settings_outlined, Icons.settings, isEnglish ? "Settings" : "الإعدادات"),
                            _buildDrawerTile(12, Icons.lock_clock_outlined, Icons.lock_clock, isEnglish ? "Day Closing" : "إغلاق اليوم"),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            appBar: AppBar(
              centerTitle: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  tooltip: isEng ? 'Main Menu' : 'القائمة الرئيسية',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: const Text(
                "HAPPY DAY POS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                    children: [
                      // Active User Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              authProvider.isManager ? Icons.admin_panel_settings : Icons.person,
                              color: authProvider.isManager ? Colors.amber : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${authProvider.currentUserName} (${isEng ? (authProvider.currentUserRole == 'مدير' ? 'Manager' : (authProvider.currentUserRole == 'كاشير' ? 'Cashier' : authProvider.currentUserRole)) : authProvider.currentUserRole})",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // License / Subscription Badge
                      if (_licenseInfo != null) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LicenseActivationScreen(
                                  onActivated: () => _checkLicenseStatus(),
                                ),
                              ),
                            );
                            _checkLicenseStatus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _licenseInfo!.isActivated
                                  ? Colors.green.shade800
                                  : (_licenseInfo!.isExpired ? Colors.red.shade800 : Colors.amber.shade900),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _licenseInfo!.isActivated
                                      ? Icons.verified_user
                                      : (_licenseInfo!.isExpired ? Icons.lock : Icons.hourglass_top),
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _licenseInfo!.isActivated
                                      ? (isEng ? 'Annual (${_licenseInfo!.daysRemaining}d)' : 'اشتراك سنوي (${_licenseInfo!.daysRemaining} يوم)')
                                      : (_licenseInfo!.isExpired
                                          ? (isEng ? 'Expired 🔒' : 'منتهي 🔒')
                                          : (isEng ? 'Trial (${_licenseInfo!.daysRemaining}d)' : 'تجريبي (متبقي ${_licenseInfo!.daysRemaining} يوم)')),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Waiter App Mobile Sync Button
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const SyncQrDialog(),
                          );
                        },
                        icon: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 18),
                        label: Text(isEng ? 'Sync Waiter 📱' : 'ربط النادل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),



                      const SizedBox(width: 8),

                      // Clock
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 1)),
                        builder: (context, snapshot) {
                          final now = TimeOfDay.now();
                          return Row(
                            children: [
                              const Icon(Icons.access_time, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                now.format(context),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(width: 12),

                      // Full Screen Toggle Button
                      IconButton(
                        icon: Icon(
                          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                          size: 26,
                        ),
                        tooltip: isEng
                            ? (_isFullscreen ? 'Exit Full Screen' : 'Full Screen')
                            : (_isFullscreen ? 'إلغاء ملء الشاشة' : 'تكبير ملء الشاشة'),
                        onPressed: _toggleFullscreen,
                      ),

                      // Logout Button
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: isEng ? 'Logout' : 'تسجيل الخروج',
                        onPressed: () => _confirmLogout(context, authProvider),
                      ),

                      // Exit App Button
                      IconButton(
                        icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                        tooltip: isEng ? 'Exit Application' : 'إغلاق البرنامج بالكامل',
                        onPressed: () => _confirmExitApp(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
            body: _buildScaledPage(pages[selectedIndex], currentScale),
          ),
        ),
      ),
    );
  }

  String? _getPermissionKeyForIndex(int index) {
    switch (index) {
      case 3:
        return 'perm_cashier_access_products';
      case 4:
        return 'perm_cashier_access_categories';
      case 5:
        return 'perm_cashier_access_inventory';
      case 6:
        return 'perm_cashier_access_purchases';
      case 7:
        return 'perm_cashier_access_settings';
      case 8:
        return 'perm_cashier_access_debts';
      case 9:
        return 'perm_cashier_access_settings';
      case 10:
        return 'perm_cashier_access_reports';
      case 11:
        return 'perm_cashier_access_settings';
      case 12:
        return 'perm_cashier_access_day_closing';
      default:
        return null;
    }
  }

  Widget _buildDrawerTile(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    final authProvider = context.watch<AuthProvider>();
    final permKey = _getPermissionKeyForIndex(index);
    final isCashier = !authProvider.isManager;
    final isRestricted = isCashier && permKey != null && !authProvider.hasPermission(context, permKey);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: primaryColor.withValues(alpha: 0.12),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isRestricted ? Colors.grey[400] : (isSelected ? primaryColor : Colors.grey[700]),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isRestricted ? Colors.grey[500] : (isSelected ? primaryColor : Colors.black87),
          ),
        ),
        trailing: isRestricted ? const Icon(Icons.lock_outline, size: 18, color: Colors.orange) : null,
        onTap: () async {
          Navigator.pop(context);
          if (isRestricted) {
            final authorized = await ManagerAuthDialog.show(
              context,
              title: 'إذن المدير مطلوب 🔒',
              reason: 'الدخول إلى شاشة ($label) محصورة أو تتطلب موافقة وإذن المدير',
            );
            if (!authorized) return;
            if (!mounted) return;
          }

          context.read<ProductsProvider>().selectCategory(null);
          context.read<ProductsProvider>().setSearchQuery('');
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    ),
  );
  }


  void _confirmLogout(BuildContext parentContext, AuthProvider authProvider) {
    final isEng = parentContext.read<SettingsProvider>().isEnglish;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Text(isEng ? 'Confirm Logout' : 'تأكيد تسجيل الخروج', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isEng
              ? 'Are you sure you want to log out and return to login screen?'
              : 'هل أنت تأكد من رغبتك في تسجيل الخروج من النظام والعودة لشاشة الدخول؟',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isEng ? 'No (Cancel)' : 'كلا (إلغاء)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              authProvider.logout();
            },
            child: Text(isEng ? 'Yes, Log Out' : 'نعم، تسجيل الخروج', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmExitApp(BuildContext parentContext) {
    _handleExitRequested();
  }
}
