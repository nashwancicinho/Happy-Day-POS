import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'features/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/categories/categories_provider.dart';
import 'features/customers/customers_provider.dart';
import 'features/dashboard/dashboard_layout.dart';
import 'features/orders/orders_provider.dart';
import 'features/products/products_provider.dart';
import 'features/purchases/purchases_provider.dart';
import 'features/settings/settings_provider.dart';
import 'features/shifts/shifts_provider.dart';
import 'features/tables/tables_provider.dart';
import 'features/treasury/treasury_provider.dart';
import 'features/waiter/waiter_connect_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const HappyDayPOS());
}

class HappyDayPOS extends StatelessWidget {
  const HappyDayPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TablesProvider()..loadTables(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoriesProvider()..loadCategories(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductsProvider()..loadProducts(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider()..loadOrders(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShiftsProvider()..loadCurrentShift(),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomersProvider()..loadCustomers(),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchasesProvider()..loadAllData(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => TreasuryProvider()..loadTreasuryRecords(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final isMobile = Platform.isAndroid || Platform.isIOS;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: isMobile ? 'تطبيق النادل - Happy Day POS' : 'Happy Day POS (Aronium Edition)',
            theme: AppTheme.getTheme(settings.primaryColor),
            home: isMobile ? const WaiterConnectScreen() : const DashboardLayout(),
          );
        },
      ),
    );
  }
}