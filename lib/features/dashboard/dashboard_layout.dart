import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../cashier/cashier_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
import '../day_closing/presentation/day_closing_screen.dart';
import '../inventory/presentation/inventory_screen.dart';
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
import '../waiter/waiter_connect_screen.dart';
import '../tables/tables_provider.dart';
import '../orders/orders_provider.dart';

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int selectedIndex = 0;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );

    // Start POS local network server for Waiter Mobile App
    LocalServerService.instance.startServer();
    LocalServerService.instance.setTableUpdateCallback(() {
      if (mounted) {
        context.read<TablesProvider>().loadTables();
        context.read<OrdersProvider>().loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('تأكيد إغلاق البرنامج', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل أنت تأكد من رغبتك في إغلاق وخروج البرنامج بالكامل؟',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لا (إلغاء الإغلاق)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، إغلاق البرنامج', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
    ReportsScreen(),
    SettingsScreen(),
    DayClosingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 1. Check if user is logged in. If not, show LoginScreen
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    return PopScope(
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
                        "${authProvider.currentUserName} (${authProvider.currentUserRole})",
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
                    final isEng = settings.isEnglish;
                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _buildDrawerTile(0, Icons.home_outlined, Icons.home, isEng ? "Home" : "الرئيسية"),
                        _buildDrawerTile(1, Icons.table_restaurant_outlined, Icons.table_restaurant, isEng ? "Tables Map" : "الطاولات"),
                        _buildDrawerTile(2, Icons.point_of_sale_outlined, Icons.point_of_sale, isEng ? "Cashier & POS" : "الكاشير"),
                        _buildDrawerTile(3, Icons.fastfood_outlined, Icons.fastfood, isEng ? "Products" : "الأصناف"),
                        _buildDrawerTile(4, Icons.category_outlined, Icons.category, isEng ? "Categories" : "التصنيفات"),
                        _buildDrawerTile(5, Icons.inventory_2_outlined, Icons.inventory_2, isEng ? "Inventory" : "المخزن"),
                        _buildDrawerTile(6, Icons.shopping_bag_outlined, Icons.shopping_bag, isEng ? "Purchases" : "المشتريات والموردين"),
                        _buildDrawerTile(7, Icons.people_outline, Icons.people, isEng ? "Users & Roles" : "المستخدمون"),
                        _buildDrawerTile(8, Icons.request_quote_outlined, Icons.request_quote, isEng ? "Debts Log" : "سجل الديون"),
                        _buildDrawerTile(9, Icons.bar_chart_outlined, Icons.bar_chart, isEng ? "Reports & Sales" : "التقارير"),
                        _buildDrawerTile(10, Icons.settings_outlined, Icons.settings, isEng ? "Settings" : "الإعدادات"),
                        _buildDrawerTile(11, Icons.lock_clock_outlined, Icons.lock_clock, isEng ? "Day Closing" : "إغلاق اليوم"),
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
              tooltip: 'القائمة الرئيسية',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 28),
              SizedBox(width: 10),
              Text(
                "HAPPY DAY POS",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          "${authProvider.currentUserName} (${context.watch<SettingsProvider>().isEnglish ? (authProvider.currentUserRole == 'مدير' ? 'Manager' : (authProvider.currentUserRole == 'كاشير' ? 'Cashier' : authProvider.currentUserRole)) : authProvider.currentUserRole})",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Waiter App Mobile Sync Button
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const SyncQrDialog(),
                      );
                    },
                    icon: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 18),
                    label: Text(context.watch<SettingsProvider>().isEnglish ? 'Sync Waiter 📱' : 'ربط النادل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),

                  const SizedBox(width: 16),

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

                  const SizedBox(width: 16),

                  // Logout Button
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'تسجيل الخروج',
                    onPressed: () => _confirmLogout(context, authProvider),
                  ),

                  // Exit App Button
                  IconButton(
                    icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                    tooltip: 'إغلاق البرنامج بالكامل',
                    onPressed: () => _confirmExitApp(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: pages[selectedIndex],
      ),
    );
  }

  Widget _buildDrawerTile(int index, IconData icon, IconData selectedIcon, String label) {
    final isSelected = selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: primaryColor.withValues(alpha: 0.12),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? primaryColor : Colors.grey[700],
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : Colors.black87,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.read<ProductsProvider>().selectCategory(null);
          context.read<ProductsProvider>().setSearchQuery('');
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }

  void _confirmLogout(BuildContext parentContext, AuthProvider authProvider) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('تأكيد تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل أنت تأكد من رغبتك في تسجيل الخروج من النظام والعودة لشاشة الدخول؟',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('كلا (إلغاء)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            child: const Text('نعم، تسجيل الخروج', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmExitApp(BuildContext parentContext) {
    _handleExitRequested();
  }
}
