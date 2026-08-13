import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:window_manager/window_manager.dart';

import 'features/auth/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/categories/categories_provider.dart';
import 'features/customers/customers_provider.dart';
import 'features/dashboard/dashboard_layout.dart';
import 'features/orders/orders_provider.dart';
import 'features/payroll/payroll_provider.dart';
import 'features/products/products_provider.dart';
import 'features/purchases/purchases_provider.dart';
import 'features/raw_materials/raw_materials_provider.dart';
import 'features/settings/settings_provider.dart';
import 'features/shifts/shifts_provider.dart';
import 'features/tables/tables_provider.dart';
import 'features/treasury/treasury_provider.dart';
import 'features/waiter/waiter_connect_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global Flutter Error: ${details.exception}');
  };

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('sqfliteFfiInit error: $e');
    }

    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        fullScreen: false,
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setFullScreen(false);
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('windowManager error: $e');
    }
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
          create: (_) => TablesProvider()..loadTables().catchError((e) => debugPrint('Tables load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoriesProvider()..loadCategories().catchError((e) => debugPrint('Categories load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductsProvider()..loadProducts().catchError((e) => debugPrint('Products load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => RawMaterialsProvider()..loadRawMaterials().catchError((e) => debugPrint('RawMaterials load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider()..loadOrders().catchError((e) => debugPrint('Orders load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => ShiftsProvider()..loadCurrentShift().catchError((e) => debugPrint('Shifts load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => CustomersProvider()..loadCustomers().catchError((e) => debugPrint('Customers load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchasesProvider()..loadAllData().catchError((e) => debugPrint('Purchases load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings().catchError((e) => debugPrint('Settings load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => TreasuryProvider()..loadTreasuryRecords().catchError((e) => debugPrint('Treasury load error: $e')),
        ),
        ChangeNotifierProvider(
          create: (_) => PayrollProvider()..loadPayrollData().catchError((e) => debugPrint('Payroll load error: $e')),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final isMobile = Platform.isAndroid || Platform.isIOS;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: isMobile ? 'casghbox' : 'CashBox POS',
            theme: AppTheme.getTheme(settings.primaryColor),
            locale: settings.locale,
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Directionality(
              textDirection: settings.textDirection,
              child: isMobile ? const WaiterConnectScreen() : const DashboardLayout(),
            ),
          );
        },
      ),
    );
  }
}