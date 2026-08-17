import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/print_service.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/order.dart';
import '../auth/auth_provider.dart';
import '../categories/categories_provider.dart';
import '../orders/orders_provider.dart';
import '../orders/orders_repository.dart';
import '../payroll/payroll_provider.dart';
import '../products/products_provider.dart';
import '../purchases/purchases_provider.dart';
import '../settings/settings_provider.dart';
import '../treasury/treasury_provider.dart';

enum ReportPeriod { daily, monthly, yearly, customRange, allTime }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Report Workflow State: false = Configuration Form, true = Generated Report View
  bool _isReportGenerated = false;

  // Filter Configurations
  String _selectedReportType = 'store_pnl'; // 'store_pnl', 'financial', 'products', 'treasury', 'invoices', 'cashier'
  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  int? _selectedCatId;
  int? _selectedProdId;
  String? _selectedCashier;
  String _selectedOrderTypeFilter = 'ALL'; // 'ALL', 'DINE_IN', 'TAKEAWAY', 'DELIVERY'

  final TextEditingController _invoiceSearchController = TextEditingController();

  // Loaded Report Data
  List<TopSellingProduct> _topSellingProducts = [];
  List<CashierSalesSummary> _cashierReportData = [];
  List<ProductNetProfitSummary> _netProfitReportData = [];
  SessionPeriodInfo? _sessionInfo;
  bool _isLoadingReportData = false;

  @override
  void dispose() {
    _invoiceSearchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatFullTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'غير متوفر (لا توجد فواتير بعد)';
    try {
      final dt = DateTime.parse(isoString);
      final year = dt.year.toString().padLeft(4, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final rawHour = dt.hour;
      final displayHour = rawHour > 12 ? (rawHour - 12).toString().padLeft(2, '0') : (rawHour == 0 ? '12' : rawHour.toString().padLeft(2, '0'));
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = rawHour >= 12 ? 'م' : 'ص';
      return '$year-$month-$day  $displayHour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  String _getDatePrefix() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        return _formatDate(now);
      case ReportPeriod.monthly:
        return _formatDate(now).substring(0, 7); // YYYY-MM
      case ReportPeriod.yearly:
        return _formatDate(now).substring(0, 4); // YYYY
      case ReportPeriod.customRange:
      case ReportPeriod.allTime:
        return '';
    }
  }

  String _getPeriodTitle(bool isEng) {
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        return isEng ? 'Today\'s Report (${_formatDate(DateTime.now())})' : 'تقرير اليوم (${_formatDate(DateTime.now())})';
      case ReportPeriod.monthly:
        return isEng ? 'Current Month Report (${_formatDate(DateTime.now()).substring(0, 7)})' : 'تقرير الشهر الحالي (${_formatDate(DateTime.now()).substring(0, 7)})';
      case ReportPeriod.yearly:
        return isEng ? 'Current Year Report (${DateTime.now().year})' : 'تقرير السنة الحالية (${DateTime.now().year})';
      case ReportPeriod.customRange:
        return isEng ? 'From ${_formatDate(_fromDate)} To ${_formatDate(_toDate)}' : 'من ${_formatDate(_fromDate)} إلى ${_formatDate(_toDate)}';
      case ReportPeriod.allTime:
        return isEng ? 'All Periods (Cumulative)' : 'كافة الفترات (تراكمي)';
    }
  }

  String _getReportTypeTitle(bool isEng) {
    switch (_selectedReportType) {
      case 'store_pnl':
        return isEng ? 'Store Net Profit & P&L Statement (Sales, Materials & Salaries)' : 'تقرير أرباح وخسائر المتجر الشامل (المبيعات والمخزن والرواتب والمصاريف)';
      case 'financial':
        return isEng ? 'Comprehensive Financial & General Summary Report' : 'تقرير الملخص العام والمالي الشامل';
      case 'products':
        return isEng ? 'Categories & Products Sales Report' : 'تقرير مبيعات الأصناف والمنتجات';
      case 'net_profit':
        return isEng ? 'Items & Products Net Profit Report' : 'تقرير الربح الصافي للمواد والمنتجات';
      case 'treasury':
        return isEng ? 'Treasury & Daily Expenses Report' : 'تقرير الخزينة والمصروفات اليومية';
      case 'invoices':
        return isEng ? 'Detailed Invoices List Report' : 'تقرير قائمة الفواتير والعمليات اليومية';
      case 'cashier':
        return isEng ? 'Cashier & User Sales Report' : 'تقرير مبيعات الكاشير والمستخدمين';
      default:
        return isEng ? 'Financial & Administrative Report' : 'تقرير مالي وإداري';
    }
  }

  Future<void> _generateAndLoadReport() async {
    setState(() {
      _isLoadingReportData = true;
    });

    final ordersProvider = context.read<OrdersProvider>();
    final treasuryProvider = context.read<TreasuryProvider>();

    List<TopSellingProduct> topProducts = [];
    List<CashierSalesSummary> cashierReport = [];
    List<ProductNetProfitSummary> netProfitReport = [];
    SessionPeriodInfo? sessionInfo;

    final currentUsername = context.read<AuthProvider>().currentUserName;

    if (_selectedPeriod == ReportPeriod.customRange) {
      final fromStr = _formatDate(_fromDate);
      final toStr = _formatDate(_toDate);
      sessionInfo = await ordersProvider.getSessionPeriodInfo(fromDate: fromStr, toDate: toStr);
      if (_selectedReportType == 'cashier') {
        cashierReport = await ordersProvider.getCashierSalesReport(
          fromDate: fromStr,
          toDate: toStr,
          selectedCashier: _selectedCashier,
          fallbackCashierName: currentUsername,
        );
      } else if (_selectedReportType == 'net_profit') {
        netProfitReport = await ordersProvider.getProductNetProfitReport(
          fromDate: fromStr,
          toDate: toStr,
          selectedCatId: _selectedCatId,
          selectedProdId: _selectedProdId,
        );
      } else {
        topProducts = await ordersProvider.getTopSellingProducts(fromDate: fromStr, toDate: toStr);
        await treasuryProvider.loadTreasuryRecords(fromDate: fromStr, toDate: toStr);
      }
    } else {
      final prefix = _getDatePrefix();
      sessionInfo = await ordersProvider.getSessionPeriodInfo(datePrefix: prefix);
      if (_selectedReportType == 'cashier') {
        cashierReport = await ordersProvider.getCashierSalesReport(
          datePrefix: prefix,
          selectedCashier: _selectedCashier,
          fallbackCashierName: currentUsername,
        );
      } else if (_selectedReportType == 'net_profit') {
        netProfitReport = await ordersProvider.getProductNetProfitReport(
          datePrefix: prefix,
          selectedCatId: _selectedCatId,
          selectedProdId: _selectedProdId,
        );
      } else {
        topProducts = await ordersProvider.getTopSellingProducts(datePrefix: prefix);
        await treasuryProvider.loadTreasuryRecords(datePrefix: prefix);
      }
    }

    if (mounted) {
      setState(() {
        _topSellingProducts = topProducts;
        _cashierReportData = cashierReport;
        _netProfitReportData = netProfitReport;
        _sessionInfo = sessionInfo;
        _isLoadingReportData = false;
        _isReportGenerated = true;
      });
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isEng ? 'Select report start date (From)' : 'اختر تاريخ بداية التقرير (من)',
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _selectedPeriod = ReportPeriod.customRange;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isEng ? 'Select report end date (To)' : 'اختر تاريخ نهاية التقرير (إلى)',
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _selectedPeriod = ReportPeriod.customRange;
      });
    }
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> allOrders) {
    return allOrders.where((order) {
      if (order.status != 'COMPLETED') return false;

      bool matchesPeriod = true;
      final effDateStr = order.effectiveDate;
      if (_selectedPeriod == ReportPeriod.customRange) {
        final orderDt = DateTime.tryParse(effDateStr);
        if (orderDt != null) {
          final startDay = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
          final endDay = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
          matchesPeriod = orderDt.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
              orderDt.isBefore(endDay.add(const Duration(seconds: 1)));
        }
      } else {
        final prefix = _getDatePrefix();
        matchesPeriod = prefix.isEmpty || effDateStr.startsWith(prefix);
      }

      final matchesOrderType = _selectedOrderTypeFilter == 'ALL' || order.orderType == _selectedOrderTypeFilter;

      return matchesPeriod && matchesOrderType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;

    // If logged in as Cashier, show clean Access Denied screen:
    if (!authProvider.isManager) {
      return _buildAccessDeniedScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReportGenerated ? _getReportTypeTitle(isEng) : (isEng ? 'Reports & Analytics Center' : 'مركز إعداد وطباعة التقارير الإدارية')),
        centerTitle: true,
        leading: _isReportGenerated
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: isEng ? 'Edit report options' : 'تعديل خيارات التقرير',
                onPressed: () => setState(() => _isReportGenerated = false),
              )
            : null,
      ),
      body: _isReportGenerated ? _buildGeneratedReportView(context) : _buildReportConfigForm(context),
    );
  }

  // ==========================================
  // PHASE A: STEP 1 - REPORT CONFIGURATION FORM
  // ==========================================
  Widget _buildReportConfigForm(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final authProvider = context.watch<AuthProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();
    final productsProvider = context.watch<ProductsProvider>();

    final availableProducts = productsProvider.allProducts.where((p) {
      return _selectedCatId == null || p.categoryId == _selectedCatId;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: primaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.analytics_rounded, size: 34, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEng ? 'Configure & Select Report Settings' : 'تحديد وتخصيص إعدادات التقرير المطلوب',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEng
                                  ? 'Select report type, time period, and item filters, then click Show Selected Report to preview and print.'
                                  : 'اختر نوع التقرير والفترة الزمنية وفلاتر الأصناف ثم اضغط زر إظهار التقرير لمعاينته وطباعته.',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Configuration Form Container Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Report Type Section
                      Row(
                        children: [
                          Icon(Icons.category_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(isEng ? '1. Select Desired Report Type:' : '1. اختر نوع التقرير المطلوب:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildTypeChip(
                            context,
                            'store_pnl',
                            isEng ? '📈 Store Net Profit & P&L Statement (Sales, Materials & Salaries)' : '📈 تقرير أرباح وخسائر المتجر الشامل (المبيعات والمخزن والرواتب والمصاريف)',
                            Icons.insights,
                            isManagerOnly: true,
                          ),
                          _buildTypeChip(
                            context,
                            'cashier',
                            isEng ? '👤 Cashier & Users Sales Report' : '👤 تقرير مبيعات الكاشير والمستخدمين',
                            Icons.badge_outlined,
                            isManagerOnly: false,
                          ),
                          _buildTypeChip(
                            context,
                            'net_profit',
                            isEng ? '💹 Net Profit Report for Items & Products' : '💹 تقرير الربح الصافي للمواد والمنتجات',
                            Icons.trending_up,
                            isManagerOnly: true,
                          ),
                          _buildTypeChip(
                            context,
                            'financial',
                            isEng ? '📊 Comprehensive Financial & General Summary' : '📊 الملخص المالي والعام الشامل',
                            Icons.monetization_on_outlined,
                            isManagerOnly: true,
                          ),
                          _buildTypeChip(
                            context,
                            'products',
                            isEng ? '🍔 Categories & Products Sales Report' : '🍔 تقرير مبيعات الأصناف والمنتجات',
                            Icons.fastfood_outlined,
                            isManagerOnly: true,
                          ),
                          _buildTypeChip(
                            context,
                            'treasury',
                            isEng ? '💰 Treasury & Expenses Report' : '💰 تقرير الخزينة والمصروفات',
                            Icons.account_balance_wallet_outlined,
                            isManagerOnly: true,
                          ),
                          _buildTypeChip(
                            context,
                            'invoices',
                            isEng ? '🧾 Detailed Invoices List Report' : '🧾 تقرير قائمة الفواتير التفصيلي',
                            Icons.receipt_long_outlined,
                            isManagerOnly: true,
                          ),
                        ],
                      ),

                      const Divider(height: 32),

                      // 2. Time Period Section
                      Row(
                        children: [
                          Icon(Icons.date_range_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(isEng ? '2. Select Report Time Period:' : '2. اختر الفترة الزمنية للتقرير:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPeriodChip(context, isEng ? '📅 Today\'s Report' : '📅 تقرير اليوم', ReportPeriod.daily),
                          _buildPeriodChip(context, isEng ? '🗓️ Monthly Report' : '🗓️ تقرير الشهر', ReportPeriod.monthly),
                          _buildPeriodChip(context, isEng ? '📆 Yearly Report' : '📆 تقرير السنة', ReportPeriod.yearly),
                          _buildPeriodChip(context, isEng ? '⏳ Custom Period (From - To)' : '⏳ فترة مخصصة (من - إلى)', ReportPeriod.customRange),
                          _buildPeriodChip(context, isEng ? '📊 All Periods' : '📊 كافة الفترات', ReportPeriod.allTime),
                        ],
                      ),

                      // Pickers for Custom Date Range
                      if (_selectedPeriod == ReportPeriod.customRange) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _selectFromDate(context),
                                icon: Icon(Icons.calendar_today, size: 18, color: primaryColor),
                                label: Text(isEng ? 'From Date: ${_formatDate(_fromDate)}' : 'من تاريخ: ${_formatDate(_fromDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.grey),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _selectToDate(context),
                                icon: Icon(Icons.calendar_month, size: 18, color: primaryColor),
                                label: Text(isEng ? 'To Date: ${_formatDate(_toDate)}' : 'إلى تاريخ: ${_formatDate(_toDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 32),

                      // 3. Filter Options Section
                      Row(
                        children: [
                          Icon(Icons.filter_alt_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(isEng ? '3. Custom Filtering Options:' : '3. خيارات التصفية والفلترة الخاصة:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cashier Selector Dropdown
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedCashier,
                        decoration: InputDecoration(
                          labelText: isEng ? 'Selected Cashier / User' : 'الكاشير / المستخدم المحدد',
                          prefixIcon: Icon(Icons.person_pin, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(isEng ? 'All Cashiers & Users (All)' : 'كافة الكاشيرية والمستخدمين (الكل)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...authProvider.users.map((u) {
                            return DropdownMenuItem<String?>(
                              value: u.username,
                              child: Text('${u.username} (${u.role})'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCashier = val;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          // Category Selector Dropdown
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _selectedCatId,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Selected Category' : 'التصنيف المحدد',
                                prefixIcon: Icon(Icons.category, color: primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(isEng ? 'All Categories (All)' : 'كافة التصنيفات (الكل)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                ...categoriesProvider.categories.map((cat) {
                                  return DropdownMenuItem<int?>(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedCatId = val;
                                  _selectedProdId = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Product Selector Dropdown
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _selectedProdId,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Selected Item / Product' : 'الصنف / المنتج المحدد',
                                prefixIcon: const Icon(Icons.fastfood, color: Colors.orange),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(isEng ? 'All Items & Products' : 'كافة الأصناف والمنتجات', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                ...availableProducts.map((prod) {
                                  return DropdownMenuItem<int?>(
                                    value: prod.id,
                                    child: Text(prod.name),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedProdId = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Order Type Filter
                      DropdownButtonFormField<String>(
                        initialValue: _selectedOrderTypeFilter,
                        decoration: InputDecoration(
                          labelText: isEng ? 'Order & Invoice Type' : 'نوع الطلبات والفواتير',
                          prefixIcon: const Icon(Icons.alt_route, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem(value: 'ALL', child: Text(isEng ? 'All Order Types (Dine-in, Takeaway, Delivery)' : 'كافة أنواع الطلبات (صالة، سفري، توصيل)', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'TAKEAWAY', child: Text(isEng ? 'Takeaway Orders (Quick Cashier)' : 'طلبات السفري (الكاشير السريع)')),
                          DropdownMenuItem(value: 'DINE_IN', child: Text(isEng ? 'Dine-in Orders (Tables)' : 'طلبات صالة المطعم (الطاولات)')),
                          DropdownMenuItem(value: 'DELIVERY', child: Text(isEng ? 'External Delivery Orders' : 'طلبات التوصيل الخارجي')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedOrderTypeFilter = val;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 32),

                      // 4. MAIN ACTION BUTTON: Show Selected Report
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _generateAndLoadReport,
                          icon: const Icon(Icons.bar_chart_rounded, size: 26, color: Colors.white),
                          label: Text(
                            isEng ? 'Show Selected Report' : 'إظهار التقرير المختار',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(BuildContext context, String typeKey, String label, IconData icon, {bool isManagerOnly = false}) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final isSelected = _selectedReportType == typeKey;
    final authProvider = context.watch<AuthProvider>();
    final canViewProfitReports = authProvider.hasPermission(context, 'perm_cashier_view_profit_reports');
    final isDisabled = isManagerOnly && !canViewProfitReports;


    return ChoiceChip(
      avatar: Icon(
        isDisabled ? Icons.lock_outline : icon,
        size: 18,
        color: isDisabled ? Colors.grey : (isSelected ? Colors.white : primaryColor),
      ),
      label: Text(
        isDisabled ? (isEng ? '$label (Manager Only)' : '$label (للمدير)') : label,
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDisabled ? Colors.grey.shade200 : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isDisabled ? Colors.grey.shade600 : (isSelected ? Colors.white : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        if (isDisabled) {
          TopNotification.showWarning(context, isEng ? '🔒 This report is restricted to Manager privileges.' : '🔒 هذا التقرير مخصص لصلاحيات المدير فقط.');
          return;
        }
        setState(() {
          _selectedReportType = typeKey;
        });
      },
    );
  }

  Widget _buildPeriodChip(BuildContext context, String label, ReportPeriod period) {
    final primaryColor = Theme.of(context).primaryColor;
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _selectedPeriod = period;
        });
      },
    );
  }

  // ==========================================
  // PHASE B: STEP 2 - GENERATED REPORT VIEW
  // ==========================================
  Widget _buildGeneratedReportView(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final ordersProvider = context.watch<OrdersProvider>();
    final treasuryProvider = context.watch<TreasuryProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final productsProvider = context.watch<ProductsProvider>();

    final filteredOrders = _getFilteredOrders(ordersProvider.orders);
    final totalSales = filteredOrders.fold(0.0, (sum, o) => sum + o.total);
    final totalOrdersCount = filteredOrders.length;

    // Calculate Total Expenses from Treasury Records
    final totalExpenses = treasuryProvider.treasuryRecords.fold(0.0, (sum, r) => sum + r.dailyExpense);
    final calculatedNetProfit = totalSales - totalExpenses;

    // Cashier Summary Calculations
    final totalCashierSales = _cashierReportData.fold(0.0, (sum, c) => sum + c.totalSales);
    final totalCashierOrders = _cashierReportData.fold(0, (sum, c) => sum + c.totalOrders);
    final topCashier = _cashierReportData.isNotEmpty ? _cashierReportData.first.cashierName : (isEng ? 'None' : 'لا يوجد');

    // Net Profit Summary Calculations
    final totalNetProfit = _netProfitReportData.fold(0.0, (sum, p) => sum + p.netProfit);
    final totalNetRevenue = _netProfitReportData.fold(0.0, (sum, p) => sum + p.totalRevenue);
    final totalNetCost = _netProfitReportData.fold(0.0, (sum, p) => sum + p.totalCost);
    final overallProfitMarginPct = totalNetRevenue > 0 ? (totalNetProfit / totalNetRevenue) * 100 : 0.0;

    // Filtered products list for product breakdown
    List<TopSellingProduct> displayProducts = _topSellingProducts;
    if (_selectedCatId != null || _selectedProdId != null) {
      final availableProds = productsProvider.allProducts.where((p) {
        final matchesCat = _selectedCatId == null || p.categoryId == _selectedCatId;
        final matchesProd = _selectedProdId == null || p.id == _selectedProdId;
        return matchesCat && matchesProd;
      }).map((p) => p.name.trim()).toSet();

      displayProducts = _topSellingProducts.where((p) => availableProds.contains(p.productName.trim())).toList();
    }

    return Scaffold(
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _isReportGenerated = false),
                icon: Icon(Icons.edit_note, color: primaryColor),
                label: Text(isEng ? 'Edit Report Options' : 'تعديل خيارات التقرير', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: () async {
                  if (_selectedReportType == 'net_profit') {
                    final customHeaders = isEng
                        ? ['Product / Item Name', 'Cost Price', 'Selling Price', 'Qty Sold', 'Total Revenue', 'Total Cost', 'Net Profit', 'Profit Margin %']
                        : ['اسم الصنف / المنتج', 'سعر الكلفة', 'سعر البيع', 'الكمية المباعة', 'إجمالي الإيراد', 'إجمالي الكلفة', 'صافي الربح', 'نسبة الربح'];
                    final customDataRows = _netProfitReportData.map((p) => [
                      p.productName,
                      '${p.buyPrice.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${p.sellPrice.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      p.quantitySold.toStringAsFixed(1),
                      '${p.totalRevenue.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${p.totalCost.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${p.netProfit.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${p.profitPercentage.toStringAsFixed(1)}%',
                    ]).toList();

                    TopNotification.showInfo(context, isEng ? 'Sending Net Profit Report to [${settingsProvider.reportsPrinter}]...' : 'جاري إرسال تقرير الربح الصافي للمواد لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                    final firstInvTimeStr = _formatFullTime(_sessionInfo?.firstOrderTime);
                    final dayCloseTimeStr = _sessionInfo?.isClosed == true
                        ? _formatFullTime(_sessionInfo?.closingTime)
                        : (isEng ? 'Open Session' : 'مفتوح (حتى الآن)');

                    final success = await PrintService.printReport(
                      reportTitle: _getReportTypeTitle(isEng),
                      dateRangeText: _getPeriodTitle(isEng),
                      generatedBy: context.read<AuthProvider>().currentUserName,
                      totalSales: totalNetRevenue,
                      totalExpenses: totalNetCost,
                      totalOrders: _netProfitReportData.length,
                      netProfit: totalNetProfit,
                      tableTitle: isEng ? 'Net Profit Details for Items Sold:' : 'تفاصيل الربح الصافي للمواد والمنتجات المباعة:',
                      customHeaders: customHeaders,
                      customDataRows: customDataRows,
                      firstInvoiceTime: firstInvTimeStr,
                      dayClosingTime: dayCloseTimeStr,
                      settings: settingsProvider,
                    );

                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Net Profit Report printed successfully!' : '🖨️ تم طباعة تقرير الربح الصافي للمواد بنجاح!');
                      } else {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Report sent to direct printing system!' : '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                      }
                    }
                    return;
                  }

                  if (_selectedReportType == 'store_pnl') {
                    final payrollProvider = context.read<PayrollProvider>();
                    final purchasesProvider = context.read<PurchasesProvider>();

                    // Materials Cost
                    final filteredPurchases = purchasesProvider.purchases.where((p) {
                      if (_selectedPeriod == ReportPeriod.allTime) return true;
                      final dateStr = p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt;
                      if (_selectedPeriod == ReportPeriod.customRange) {
                        final fromStr = _formatDate(_fromDate);
                        final toStr = _formatDate(_toDate);
                        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
                      }
                      return dateStr.startsWith(_getDatePrefix());
                    }).toList();

                    double materialsCost = filteredPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
                    if (materialsCost == 0.0 && _netProfitReportData.isNotEmpty) {
                      materialsCost = _netProfitReportData.fold(0.0, (sum, item) => sum + item.totalCost);
                    }

                    // Payroll Expenses
                    final filteredPayments = payrollProvider.payments.where((p) {
                      if (_selectedPeriod == ReportPeriod.allTime) return true;
                      final dateStr = p.paymentDate;
                      if (_selectedPeriod == ReportPeriod.customRange) {
                        final fromStr = _formatDate(_fromDate);
                        final toStr = _formatDate(_toDate);
                        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
                      }
                      return dateStr.startsWith(_getDatePrefix());
                    }).toList();

                    final salaryExpenses = filteredPayments.fold(0.0, (sum, p) => sum + p.netSalary);

                    // General Expenses
                    final filteredExpenses = treasuryProvider.treasuryRecords.where((r) {
                      if (_selectedPeriod == ReportPeriod.allTime) return true;
                      final dateStr = r.date;
                      if (_selectedPeriod == ReportPeriod.customRange) {
                        final fromStr = _formatDate(_fromDate);
                        final toStr = _formatDate(_toDate);
                        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
                      }
                      return dateStr.startsWith(_getDatePrefix());
                    }).toList();

                    final generalExpenses = filteredExpenses.fold(0.0, (sum, r) => sum + r.dailyExpense);
                    final totalExpensesSum = materialsCost + salaryExpenses + generalExpenses;
                    final netStoreProfit = totalSales - totalExpensesSum;
                    final netMarginPct = totalSales > 0 ? (netStoreProfit / totalSales) * 100 : 0.0;

                    final materialsPct = totalSales > 0 ? (materialsCost / totalSales) * 100 : 0.0;
                    final salaryPct = totalSales > 0 ? (salaryExpenses / totalSales) * 100 : 0.0;
                    final generalPct = totalSales > 0 ? (generalExpenses / totalSales) * 100 : 0.0;

                    final customHeaders = isEng
                        ? ['P&L Statement Line Item', 'Total Amount', '% of Gross Sales']
                        : ['بند قائمة الأرباح والخسائر', 'المبلغ الإجمالي', 'النسبة المئوية من المبيعات'];
                    final customDataRows = [
                      ['إجمالي مبيعات وإيرادات المتجر (100%)', '${totalSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', '100.0%'],
                      ['تكلفة المواد الأولية وخامات الأصناف (-)', '-${materialsCost.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', '${materialsPct.toStringAsFixed(1)}%'],
                      ['مصاريف رواتب ومستحقات الموظفين (-)', '-${salaryExpenses.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', '${salaryPct.toStringAsFixed(1)}%'],
                      ['النفقات والمصاريف التشغيلية الخزينة (-)', '-${generalExpenses.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', '${generalPct.toStringAsFixed(1)}%'],
                      ['صافي ربح المتجر النهائي والأخير (=)', '${netStoreProfit.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', '${netMarginPct.toStringAsFixed(1)}%'],
                    ];

                    TopNotification.showInfo(context, isEng ? 'Sending Store P&L Report to [${settingsProvider.reportsPrinter}]...' : 'جاري إرسال تقرير أرباح وخسائر المتجر لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                    final firstInvTimeStr = _formatFullTime(_sessionInfo?.firstOrderTime);
                    final dayCloseTimeStr = _sessionInfo?.isClosed == true
                        ? _formatFullTime(_sessionInfo?.closingTime)
                        : (isEng ? 'Open Session' : 'مفتوح (حتى الآن)');

                    final success = await PrintService.printReport(
                      reportTitle: _getReportTypeTitle(isEng),
                      dateRangeText: _getPeriodTitle(isEng),
                      generatedBy: context.read<AuthProvider>().currentUserName,
                      totalSales: totalSales,
                      totalExpenses: totalExpensesSum,
                      totalOrders: totalOrdersCount,
                      netProfit: netStoreProfit,
                      tableTitle: isEng ? 'Store Net Profit & P&L Statement Details:' : 'تفاصيل قائمة أرباح وخسائر المتجر الشاملة:',
                      customHeaders: customHeaders,
                      customDataRows: customDataRows,
                      firstInvoiceTime: firstInvTimeStr,
                      dayClosingTime: dayCloseTimeStr,
                      settings: settingsProvider,
                    );

                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Store P&L Report printed successfully!' : '🖨️ تم طباعة تقرير أرباح وخسائر المتجر بنجاح!');
                      } else {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Report sent to direct printing system!' : '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                      }
                    }
                    return;
                  }

                  if (_selectedReportType == 'cashier') {
                    final customHeaders = isEng
                        ? ['Cashier Name', 'Invoices Count', 'Cash Sales', 'Card Sales', 'Credit Sales', 'Average Order Value', 'Total Sales']
                        : ['اسم الكاشير / المستخدم', 'عدد الفواتير', 'مبيعات الكاش', 'مبيعات الشبكة', 'مبيعات الآجل', 'معدل الفاتورة', 'إجمالي المبيعات'];
                    final customDataRows = _cashierReportData.map((c) => [
                      c.cashierName,
                      isEng ? '${c.totalOrders} Invoices' : '${c.totalOrders} فاتورة',
                      '${c.cashSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.cardSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.creditSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.avgOrderValue.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.totalSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                    ]).toList();

                    TopNotification.showInfo(context, isEng ? 'Sending Cashier Report to [${settingsProvider.reportsPrinter}]...' : 'جاري إرسال تقرير الكاشيرية لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                    final firstInvTimeStr = _formatFullTime(_sessionInfo?.firstOrderTime);
                    final dayCloseTimeStr = _sessionInfo?.isClosed == true
                        ? _formatFullTime(_sessionInfo?.closingTime)
                        : (isEng ? 'Open Session' : 'مفتوح (حتى الآن)');

                    final success = await PrintService.printReport(
                      reportTitle: _getReportTypeTitle(isEng),
                      dateRangeText: _getPeriodTitle(isEng),
                      generatedBy: context.read<AuthProvider>().currentUserName,
                      totalSales: totalCashierSales,
                      totalExpenses: 0.0,
                      totalOrders: totalCashierOrders,
                      netProfit: totalCashierSales,
                      tableTitle: isEng ? 'Cashier & User Sales Breakdown:' : 'تفاصيل مبيعات الكاشيرية والمستخدمين:',
                      customHeaders: customHeaders,
                      customDataRows: customDataRows,
                      firstInvoiceTime: firstInvTimeStr,
                      dayClosingTime: dayCloseTimeStr,
                      settings: settingsProvider,
                    );

                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Cashier Report printed successfully!' : '🖨️ تم طباعة تقرير الكاشيرية بنجاح!');
                      } else {
                        TopNotification.showSuccess(context, isEng ? '🖨️ Report sent to direct printing system!' : '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                      }
                    }
                    return;
                  }

                  final breakdownList = displayProducts.map((p) => {
                    'name': p.productName,
                    'qty': p.quantitySold,
                    'total': p.totalRevenue,
                  }).toList();

                  TopNotification.showInfo(context, isEng ? 'Sending Report to [${settingsProvider.reportsPrinter}]...' : 'جاري إرسال التقرير لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                  final firstInvTimeStr = _formatFullTime(_sessionInfo?.firstOrderTime);
                  final dayCloseTimeStr = _sessionInfo?.isClosed == true
                      ? _formatFullTime(_sessionInfo?.closingTime)
                      : (isEng ? 'Open Session' : 'مفتوح (حتى الآن)');

                  final success = await PrintService.printReport(
                    reportTitle: _getReportTypeTitle(isEng),
                    dateRangeText: _getPeriodTitle(isEng),
                    generatedBy: context.read<AuthProvider>().currentUserName,
                    totalSales: totalSales,
                    totalExpenses: totalExpenses,
                    totalOrders: totalOrdersCount,
                    netProfit: calculatedNetProfit,
                    productBreakdown: breakdownList,
                    firstInvoiceTime: firstInvTimeStr,
                    dayClosingTime: dayCloseTimeStr,
                    settings: settingsProvider,
                  );

                  if (context.mounted) {
                    if (success) {
                      TopNotification.showSuccess(context, isEng ? '🖨️ Report printed successfully!' : '🖨️ تم طباعة التقرير بنجاح!');
                    } else {
                      TopNotification.showSuccess(context, isEng ? '🖨️ Report sent to direct printing system!' : '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                    }
                  }
                },
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 22),
                label: Text(
                  isEng ? 'Print Report' : 'طباعة التقرير (Print Report)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingReportData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back & Status Header Bar
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: primaryColor),
                            onPressed: () => setState(() => _isReportGenerated = false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getReportTypeTitle(isEng), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('${isEng ? "Time Range:" : "النطاق الزمني:"} ${_getPeriodTitle(isEng)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isReportGenerated = false),
                            icon: const Icon(Icons.tune, size: 16),
                            label: Text(isEng ? 'Change Filters' : 'تغيير الفلاتر'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Shift & Session Start / End Info Card
                  Card(
                    elevation: 2,
                    color: Colors.blue.shade900.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.blue.shade300.withValues(alpha: 0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Icon(Icons.history_toggle_off_rounded, color: primaryColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEng ? '🕒 Shift Work Period & Session Limits:' : '🕒 حيز النطاق وتوقيت أول فاتورة وإغلاق اليوم:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_circle_fill, color: Colors.green, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${isEng ? "First Invoice:" : "تاريخ ووقت أول فاتورة:"} ${_formatFullTime(_sessionInfo?.firstOrderTime)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _sessionInfo?.isClosed == true ? Icons.lock_clock : Icons.access_time_filled,
                                          color: _sessionInfo?.isClosed == true ? Colors.deepOrange : Colors.blue,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _sessionInfo?.isClosed == true
                                              ? '${isEng ? "Day Closed At:" : "تاريخ ووقت إغلاق اليوم:"} ${_formatFullTime(_sessionInfo?.closingTime)} (${_sessionInfo?.closedBy ?? ''})'
                                              : '${isEng ? "Day Closed At:" : "تاريخ ووقت إغلاق اليوم:"} مفتوح (حتى الوقت الحالي)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: _sessionInfo?.isClosed == true ? Colors.deepOrange.shade800 : Colors.blue.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Overview Summary Cards Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCashierReport = _selectedReportType == 'cashier';
                      final isNetProfitReport = _selectedReportType == 'net_profit';

                      final displayTotalSales = isNetProfitReport
                          ? totalNetProfit
                          : (isCashierReport ? totalCashierSales : totalSales);

                      final currencySym = settingsProvider.currencySymbol;

                      if (constraints.maxWidth > 900) {
                        return Row(
                          children: [
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Item Net Profit' : 'إجمالي صافي أرباح المواد')
                                    : (isCashierReport
                                        ? (isEng ? 'Total Cashier Sales' : 'إجمالي مبيعات الكاشيرية')
                                        : (isEng ? 'Total Sales (Revenue)' : 'إجمالي المبيعات (الوارد)')),
                                value: '${displayTotalSales.toStringAsFixed(0)} $currencySym',
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Net profit of sold items' : 'صافي ربح المواد المباعة')
                                    : (isCashierReport
                                        ? (isEng ? 'Total cashier sales sum' : 'مجموع مبيعات الكاشيرية')
                                        : (isEng ? 'Total gross sales' : 'المجموع الإجمالي للمبيعات')),
                                icon: isNetProfitReport ? Icons.trending_up : Icons.monetization_on,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Sales Revenue' : 'إجمالي إيرادات المبيعات')
                                    : (isCashierReport
                                        ? (isEng ? 'Top Selling Cashier' : 'الكاشير الأعلى مبيعات')
                                        : (isEng ? 'Total Expenses' : 'إجمالي المصروفات')),
                                value: isNetProfitReport
                                    ? '${totalNetRevenue.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? topCashier : '${totalExpenses.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Direct sales value' : 'إجمالي قيمة المبيعات المباشرة')
                                    : (isCashierReport
                                        ? (isEng ? 'Highest performing cashier' : 'الأعلى أداءً بالفترة')
                                        : (isEng ? 'Total expenses sum' : 'مجموع المصاريف والنفقات')),
                                icon: isNetProfitReport ? Icons.attach_money : (isCashierReport ? Icons.star_rounded : Icons.shopping_cart_checkout),
                                color: isNetProfitReport ? Colors.blue.shade700 : (isCashierReport ? Colors.amber.shade800 : Colors.red.shade700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Cost of Goods (COGS)' : 'إجمالي كلفة المواد (COGS)')
                                    : (isCashierReport
                                        ? (isEng ? 'Active Cashiers Count' : 'عدد الكاشيرية النشطين')
                                        : (isEng ? 'Calculated Net Profit' : 'صافي الربح المحسوب')),
                                value: isNetProfitReport
                                    ? '${totalNetCost.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport
                                        ? (isEng ? '${_cashierReportData.length} Cashiers' : '${_cashierReportData.length} كاشير')
                                        : '${calculatedNetProfit.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Total item purchase cost' : 'مجموع سعر شراء المواد')
                                    : (isCashierReport
                                        ? (isEng ? 'Present users' : 'المستخدمين المتواجدين')
                                        : (isEng ? 'Total Revenue - Expenses' : 'الوارد الكلي - المصروفات')),
                                icon: isNetProfitReport ? Icons.shopping_bag_outlined : (isCashierReport ? Icons.people_alt : Icons.savings),
                                color: isNetProfitReport ? Colors.deepOrange.shade700 : (isCashierReport ? Colors.teal.shade700 : (calculatedNetProfit >= 0 ? primaryColor : Colors.red.shade900)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport ? (isEng ? 'Item Profit Margin %' : 'نسبة هامش الربح للصنف') : (isEng ? 'Completed Invoices Count' : 'عدد الفواتير المكتملة'),
                                value: isNetProfitReport ? '${overallProfitMarginPct.toStringAsFixed(1)}%' : (isEng ? '$totalOrdersCount Invoices' : '$totalOrdersCount فاتورة'),
                                subtitle: isNetProfitReport ? (isEng ? 'Average profitability margin' : 'معدل الربحية من المبيعات') : (isEng ? 'Total orders count' : 'إجمالي عدد الطلبات'),
                                icon: isNetProfitReport ? Icons.pie_chart : Icons.receipt_long,
                                color: isNetProfitReport ? Colors.purple.shade700 : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        );
                      } else {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Item Net Profit' : 'إجمالي صافي أرباح المواد')
                                    : (isCashierReport
                                        ? (isEng ? 'Total Cashier Sales' : 'إجمالي مبيعات الكاشيرية')
                                        : (isEng ? 'Total Sales (Revenue)' : 'إجمالي المبيعات (الوارد)')),
                                value: '${displayTotalSales.toStringAsFixed(0)} $currencySym',
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Net profit of sold items' : 'صافي ربح المواد المباعة')
                                    : (isCashierReport
                                        ? (isEng ? 'Total cashier sales sum' : 'مجموع مبيعات الكاشيرية')
                                        : (isEng ? 'Total gross sales' : 'المجموع الإجمالي للمبيعات')),
                                icon: isNetProfitReport ? Icons.trending_up : Icons.monetization_on,
                                color: Colors.green.shade700,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Sales Revenue' : 'إجمالي إيرادات المبيعات')
                                    : (isCashierReport
                                        ? (isEng ? 'Top Selling Cashier' : 'الكاشير الأعلى مبيعات')
                                        : (isEng ? 'Total Expenses' : 'إجمالي المصروفات')),
                                value: isNetProfitReport
                                    ? '${totalNetRevenue.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? topCashier : '${totalExpenses.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Direct sales value' : 'إجمالي قيمة المبيعات المباشرة')
                                    : (isCashierReport
                                        ? (isEng ? 'Highest performing cashier' : 'الأعلى أداءً بالفترة')
                                        : (isEng ? 'Total expenses sum' : 'مجموع المصاريف والنفقات')),
                                icon: isNetProfitReport ? Icons.attach_money : (isCashierReport ? Icons.star_rounded : Icons.shopping_cart_checkout),
                                color: isNetProfitReport ? Colors.blue.shade700 : (isCashierReport ? Colors.amber.shade800 : Colors.red.shade700),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? (isEng ? 'Total Cost of Goods (COGS)' : 'إجمالي كلفة المواد (COGS)')
                                    : (isCashierReport
                                        ? (isEng ? 'Active Cashiers Count' : 'عدد الكاشيرية النشطين')
                                        : (isEng ? 'Calculated Net Profit' : 'صافي الربح المحسوب')),
                                value: isNetProfitReport
                                    ? '${totalNetCost.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport
                                        ? (isEng ? '${_cashierReportData.length} Cashiers' : '${_cashierReportData.length} كاشير')
                                        : '${calculatedNetProfit.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? (isEng ? 'Total item purchase cost' : 'مجموع سعر شراء المواد')
                                    : (isCashierReport
                                        ? (isEng ? 'Present users' : 'المستخدمين المتواجدين')
                                        : (isEng ? 'Total Revenue - Expenses' : 'الوارد الكلي - المصروفات')),
                                icon: isNetProfitReport ? Icons.shopping_bag_outlined : (isCashierReport ? Icons.people_alt : Icons.savings),
                                color: isNetProfitReport ? Colors.deepOrange.shade700 : (isCashierReport ? Colors.teal.shade700 : (calculatedNetProfit >= 0 ? primaryColor : Colors.red.shade900)),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport ? (isEng ? 'Item Profit Margin %' : 'نسبة هامش الربح للصنف') : (isEng ? 'Completed Invoices Count' : 'عدد الفواتير المكتملة'),
                                value: isNetProfitReport ? '${overallProfitMarginPct.toStringAsFixed(1)}%' : (isEng ? '$totalOrdersCount Invoices' : '$totalOrdersCount فاتورة'),
                                subtitle: isNetProfitReport ? (isEng ? 'Average profitability margin' : 'معدل الربحية من المبيعات') : (isEng ? 'Total orders count' : 'إجمالي عدد الطلبات'),
                                icon: isNetProfitReport ? Icons.pie_chart : Icons.receipt_long,
                                color: isNetProfitReport ? Colors.purple.shade700 : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Specific Report Data View
                  if (_selectedReportType == 'store_pnl') ...[
                    _buildStorePnLReportView(context),
                  ] else if (_selectedReportType == 'net_profit') ...[
                    _buildNetProfitReportView(context, _netProfitReportData),
                  ] else if (_selectedReportType == 'cashier') ...[
                    _buildCashierReportView(context, _cashierReportData),
                  ] else if (_selectedReportType == 'financial' || _selectedReportType == 'products') ...[
                    _buildProductsReportView(context, displayProducts),
                  ] else if (_selectedReportType == 'treasury') ...[
                    _buildTreasuryReportView(context, treasuryProvider),
                  ] else if (_selectedReportType == 'invoices') ...[
                    _buildInvoicesReportView(context, filteredOrders),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStorePnLReportView(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    final ordersProvider = context.watch<OrdersProvider>();
    final treasuryProvider = context.watch<TreasuryProvider>();
    final payrollProvider = context.watch<PayrollProvider>();
    final purchasesProvider = context.watch<PurchasesProvider>();

    final filteredOrders = _getFilteredOrders(ordersProvider.orders);
    final totalSales = filteredOrders.fold(0.0, (sum, o) => sum + o.total);

    // 1. Materials & Purchases Cost
    final filteredPurchases = purchasesProvider.purchases.where((p) {
      if (_selectedPeriod == ReportPeriod.allTime) return true;
      final dateStr = p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt;
      if (_selectedPeriod == ReportPeriod.customRange) {
        final fromStr = _formatDate(_fromDate);
        final toStr = _formatDate(_toDate);
        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
      }
      return dateStr.startsWith(_getDatePrefix());
    }).toList();

    double materialsCost = filteredPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    if (materialsCost == 0.0 && _netProfitReportData.isNotEmpty) {
      materialsCost = _netProfitReportData.fold(0.0, (sum, item) => sum + item.totalCost);
    }

    // 2. Employee Payroll Expenses
    final filteredPayments = payrollProvider.payments.where((p) {
      if (_selectedPeriod == ReportPeriod.allTime) return true;
      final dateStr = p.paymentDate;
      if (_selectedPeriod == ReportPeriod.customRange) {
        final fromStr = _formatDate(_fromDate);
        final toStr = _formatDate(_toDate);
        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
      }
      return dateStr.startsWith(_getDatePrefix());
    }).toList();

    final salaryExpenses = filteredPayments.fold(0.0, (sum, p) => sum + p.netSalary);

    // 3. General Treasury Expenses
    final filteredExpenses = treasuryProvider.treasuryRecords.where((r) {
      if (_selectedPeriod == ReportPeriod.allTime) return true;
      final dateStr = r.date;
      if (_selectedPeriod == ReportPeriod.customRange) {
        final fromStr = _formatDate(_fromDate);
        final toStr = _formatDate(_toDate);
        return dateStr.compareTo(fromStr) >= 0 && dateStr.compareTo(toStr) <= 0;
      }
      return dateStr.startsWith(_getDatePrefix());
    }).toList();

    final generalExpenses = filteredExpenses.fold(0.0, (sum, r) => sum + r.dailyExpense);

    // 4. Net Store Profit Calculation
    final totalExpensesSum = materialsCost + salaryExpenses + generalExpenses;
    final netStoreProfit = totalSales - totalExpensesSum;
    final netProfitMargin = totalSales > 0 ? (netStoreProfit / totalSales) * 100 : 0.0;

    final materialsPct = totalSales > 0 ? (materialsCost / totalSales) * 100 : 0.0;
    final salaryPct = totalSales > 0 ? (salaryExpenses / totalSales) * 100 : 0.0;
    final generalPct = totalSales > 0 ? (generalExpenses / totalSales) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. FINANCIAL SUMMARY CARDS GRID
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 850;
            final cardWidth = isDesktop ? (constraints.maxWidth - 40) / 5 : (constraints.maxWidth - 10) / 2;

            final cards = [
              _pnlSummaryMetricCard(
                title: isEng ? 'Total Sales Revenue' : 'إجمالي مبيعات المتجر',
                value: '${totalSales.toStringAsFixed(0)} $currencySym',
                subtitle: isEng ? '100% Gross Baseline' : 'الوارد الإجمالي (100%)',
                icon: Icons.storefront,
                color: Colors.green.shade700,
              ),
              _pnlSummaryMetricCard(
                title: isEng ? 'Materials & Purchases Cost' : 'كلفة المواد والمشتريات',
                value: '${materialsCost.toStringAsFixed(0)} $currencySym',
                subtitle: '${materialsPct.toStringAsFixed(1)}% ${isEng ? "of sales" : "من المبيعات"}',
                icon: Icons.inventory_2_outlined,
                color: Colors.orange.shade800,
              ),
              _pnlSummaryMetricCard(
                title: isEng ? 'Employee Salary Expenses' : 'مصاريف رواتب الموظفين',
                value: '${salaryExpenses.toStringAsFixed(0)} $currencySym',
                subtitle: '${salaryPct.toStringAsFixed(1)}% ${isEng ? "of sales" : "من المبيعات"}',
                icon: Icons.badge_outlined,
                color: Colors.blue.shade800,
              ),
              _pnlSummaryMetricCard(
                title: isEng ? 'General Operating Expenses' : 'المصاريف العامة والنفقات',
                value: '${generalExpenses.toStringAsFixed(0)} $currencySym',
                subtitle: '${generalPct.toStringAsFixed(1)}% ${isEng ? "of sales" : "من المبيعات"}',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.red.shade700,
              ),
              _pnlSummaryMetricCard(
                title: isEng ? 'Final Net Store Profit' : 'صافي ربح المتجر الأخير',
                value: '${netStoreProfit.toStringAsFixed(0)} $currencySym',
                subtitle: '${netProfitMargin.toStringAsFixed(1)}% ${isEng ? "Net Margin" : "هامش الربح الصافي"}',
                icon: Icons.insights,
                color: netStoreProfit >= 0 ? Colors.purple.shade700 : Colors.red.shade900,
              ),
            ];

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
            );
          },
        ),

        const SizedBox(height: 20),

        // B. VISUAL INTERACTIVE CHARTS CARD
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, color: primaryColor, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          isEng ? '📊 Store Revenue vs Expenses Visual Distribution' : '📊 المخطط البياني لتوزيع إيرادات ومصاريف المتجر',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (netProfitMargin >= 20 ? Colors.green : (netProfitMargin >= 0 ? Colors.orange : Colors.red)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (netProfitMargin >= 20 ? Colors.green : (netProfitMargin >= 0 ? Colors.orange : Colors.red)).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${isEng ? "Profit Margin:" : "معدل هامش الربح الصافي:"} ${netProfitMargin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: netProfitMargin >= 20 ? Colors.green.shade800 : (netProfitMargin >= 0 ? Colors.orange.shade900 : Colors.red.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Visual Bars Section
                _buildVisualPnlBar(
                  context: context,
                  label: isEng ? 'Gross Store Sales Revenue (Total Income)' : '🟩 إجمالي مبيعات وإيرادات المتجر (الوارد الأساسي)',
                  amount: totalSales,
                  percentage: 100.0,
                  maxAmount: totalSales,
                  color: Colors.green.shade700,
                  currencySym: currencySym,
                ),
                const SizedBox(height: 16),
                _buildVisualPnlBar(
                  context: context,
                  label: isEng ? 'Materials & Stock Cost (-)' : '🟧 تكلفة المواد الأولية وخامات الأصناف والمشتريات (-)',
                  amount: materialsCost,
                  percentage: materialsPct,
                  maxAmount: totalSales,
                  color: Colors.orange.shade800,
                  currencySym: currencySym,
                ),
                const SizedBox(height: 16),
                _buildVisualPnlBar(
                  context: context,
                  label: isEng ? 'Employee Salary & Payroll Expenses (-)' : '🟦 مصاريف رواتب ومستحقات الموظفين (-)',
                  amount: salaryExpenses,
                  percentage: salaryPct,
                  maxAmount: totalSales,
                  color: Colors.blue.shade800,
                  currencySym: currencySym,
                ),
                const SizedBox(height: 16),
                _buildVisualPnlBar(
                  context: context,
                  label: isEng ? 'General Operating Expenses (-)' : '🟥 النفقات والمصاريف التشغيلية العامة والخزينة (-)',
                  amount: generalExpenses,
                  percentage: generalPct,
                  maxAmount: totalSales,
                  color: Colors.red.shade700,
                  currencySym: currencySym,
                ),
                const SizedBox(height: 16),
                _buildVisualPnlBar(
                  context: context,
                  label: isEng ? 'Final Store Net Profit (=)' : '🟪 صافي ربح المتجر النهائي والأخير (=)',
                  amount: netStoreProfit,
                  percentage: netProfitMargin,
                  maxAmount: totalSales,
                  color: netStoreProfit >= 0 ? Colors.purple.shade700 : Colors.red.shade900,
                  currencySym: currencySym,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // C. COMPREHENSIVE P&L FINANCIAL TABLE CARD
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart, color: Colors.indigo, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      isEng ? 'Comprehensive P&L Statement Details' : 'جدول القائمة المالية المفصلة للأرباح والخسائر',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                      columns: [
                        DataColumn(label: Text(isEng ? 'Financial Item' : 'بند القائمة المالية', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEng ? 'Type / Direction' : 'النوع / الاتجاه', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEng ? 'Total Amount' : 'المبلغ الإجمالي', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(isEng ? '% of Sales' : 'النسبة من المبيعات', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        DataRow(cells: [
                          const DataCell(Text('إجمالي مبيعات المتجر (Gross Revenue)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('إيراد +', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataCell(Text('${totalSales.toStringAsFixed(0)} $currencySym', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          const DataCell(Text('100.0%')),
                        ]),
                        DataRow(cells: [
                          const DataCell(Text('تكلفة المواد الأولية وخامات الأصناف والمشتريات')),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('مصروف -', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataCell(Text('-${materialsCost.toStringAsFixed(0)} $currencySym', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                          DataCell(Text('${materialsPct.toStringAsFixed(1)}%')),
                        ]),
                        DataRow(cells: [
                          const DataCell(Text('مصاريف رواتب ومستحقات الموظفين والسُلف')),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('مصروف -', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataCell(Text('-${salaryExpenses.toStringAsFixed(0)} $currencySym', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold))),
                          DataCell(Text('${salaryPct.toStringAsFixed(1)}%')),
                        ]),
                        DataRow(cells: [
                          const DataCell(Text('النفقات والمصاريف التشغيلية العامة')),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('مصروف -', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataCell(Text('-${generalExpenses.toStringAsFixed(0)} $currencySym', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
                          DataCell(Text('${generalPct.toStringAsFixed(1)}%')),
                        ]),
                        DataRow(
                          color: WidgetStateProperty.all(Colors.purple.shade50),
                          cells: [
                            const DataCell(Text('صافي ربح المتجر الأخير (Net Profit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('صافي ربح =', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataCell(Text('${netStoreProfit.toStringAsFixed(0)} $currencySym', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: netStoreProfit >= 0 ? Colors.purple.shade900 : Colors.red.shade900))),
                            DataCell(Text('${netProfitMargin.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
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

  Widget _pnlSummaryMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualPnlBar({
    required BuildContext context,
    required String label,
    required double amount,
    required double percentage,
    required double maxAmount,
    required Color color,
    required String currencySym,
    bool isBold = false,
  }) {
    final double fillRatio = maxAmount > 0 ? (amount.abs() / maxAmount).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: isBold ? 15 : 13.5,
                color: isBold ? color : Colors.black87,
              ),
            ),
            Row(
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} $currencySym',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isBold ? 16 : 14,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: isBold ? 14 : 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fillRatio,
              child: Container(
                height: isBold ? 14 : 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetProfitReportView(BuildContext context, List<ProductNetProfitSummary> products) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (products.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              isEng ? 'No item sales or profits recorded for selected period and filters.' : 'لا توجد مبيعات مواد أو أرباح مسجلة للفترة والمحددات المختارة.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final totalRevenue = products.fold(0.0, (sum, p) => sum + p.totalRevenue);
    final totalCost = products.fold(0.0, (sum, p) => sum + p.totalCost);
    final totalNetProfit = products.fold(0.0, (sum, p) => sum + p.netProfit);
    final totalQty = products.fold(0.0, (sum, p) => sum + p.quantitySold);
    final overallMargin = totalRevenue > 0 ? (totalNetProfit / totalRevenue) * 100 : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEng ? 'Net Profit & Cost Breakdown per Item:' : 'تفاصيل الربح الصافي وكلفة البضاعة المباعة لكل صنف:',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Chip(
                  avatar: const Icon(Icons.inventory_2, size: 18, color: Colors.white),
                  label: Text(isEng ? 'Items Sold: ${products.length}' : 'عدد الأصناف المباعة: ${products.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1)),
                    children: [
                      const Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Item Name' : 'اسم الصنف / المنتج', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Cost Price' : 'سعر الكلفة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Sell Price' : 'سعر البيع', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Qty Sold' : 'الكمية المباعة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Revenue' : 'إجمالي الإيراد', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Cost (COGS)' : 'إجمالي الكلفة (COGS)', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Item Net Profit' : 'صافي الربح للمادة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Profit %' : 'نسبة الربح (%)', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                  ...products.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(10), child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(p.productName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.buyPrice.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.deepOrange))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.sellPrice.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(p.quantitySold.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.totalRevenue.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.totalCost.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.netProfit.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: p.netProfit >= 0 ? Colors.green.shade700 : Colors.red))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${p.profitPercentage.toStringAsFixed(1)}%', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                      ],
                    );
                  }),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      const Padding(padding: EdgeInsets.all(10), child: Text('Σ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Grand Total' : 'المجموع الإجمالي', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      const Padding(padding: EdgeInsets.all(10), child: Text('-', textAlign: TextAlign.center)),
                      const Padding(padding: EdgeInsets.all(10), child: Text('-', textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(totalQty.toStringAsFixed(1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalRevenue.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalCost.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalNetProfit.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: totalNetProfit >= 0 ? Colors.green.shade700 : Colors.red))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${overallMargin.toStringAsFixed(1)}%', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashierReportView(BuildContext context, List<CashierSalesSummary> cashiers) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (cashiers.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              isEng ? 'No cashier sales recorded for selected period and filters.' : 'لا توجد مبيعات كاشيرية مسجلة للفترة والمحددات المختارة.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final totalCashierSales = cashiers.fold(0.0, (sum, c) => sum + c.totalSales);
    final totalCashierOrders = cashiers.fold(0, (sum, c) => sum + c.totalOrders);
    final totalCashSales = cashiers.fold(0.0, (sum, c) => sum + c.cashSales);
    final totalCardSales = cashiers.fold(0.0, (sum, c) => sum + c.cardSales);
    final totalCreditSales = cashiers.fold(0.0, (sum, c) => sum + c.creditSales);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEng ? 'Cashier & User Sales Breakdown:' : 'تفاصيل مبيعات الكاشيرية والمستخدمين:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Chip(
                  avatar: const Icon(Icons.people, size: 18, color: Colors.white),
                  label: Text(isEng ? 'Cashiers Count: ${cashiers.length}' : 'عدد الكاشيرية: ${cashiers.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1)),
                    children: [
                      const Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Cashier / User Name' : 'اسم الكاشير / المستخدم', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Invoices Count' : 'عدد الفواتير', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Cash Sales' : 'مبيعات الكاش', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Card / Bank Sales' : 'مبيعات الشبكة (كارت)', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Credit / Debt Sales' : 'مبيعات الآجل (دين)', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Avg Order Value' : 'معدل الفاتورة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Sales' : 'إجمالي المبيعات', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                  ...cashiers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final c = entry.value;
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(10), child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(c.cashierName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? '${c.totalOrders} Invoices' : '${c.totalOrders} فاتورة', textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.cashSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.cardSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.creditSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.avgOrderValue.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.totalSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                      ],
                    );
                  }),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade200),
                    children: [
                      const Padding(padding: EdgeInsets.all(10), child: Text('Σ', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Grand Total' : 'المجموع الإجمالي', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? '$totalCashierOrders Invoices' : '$totalCashierOrders فاتورة', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalCashSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalCardSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalCreditSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${(totalCashierOrders > 0 ? totalCashierSales / totalCashierOrders : 0.0).toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${totalCashierSales.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsReportView(BuildContext context, List<TopSellingProduct> products) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (products.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              isEng ? 'No item sales recorded for selected period and filters.' : 'لا توجد مبيعات أصناف مسجلة للفترة والمحددات المختارة.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEng ? 'Categories & Products Sales Details:' : 'تفاصيل مبيعات الأصناف والمنتجات:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1)),
                  children: [
                    const Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Item Name' : 'اسم الصنف / المنتج', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Quantity Sold' : 'الكمية المباعة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Amount' : 'إجمالي المبلغ', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
                ...products.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? '${item.quantitySold} Pcs' : '${item.quantitySold} قطعة', textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${item.totalRevenue.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreasuryReportView(BuildContext context, TreasuryProvider treasuryProvider) {
    final records = treasuryProvider.treasuryRecords;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (records.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              isEng ? 'No treasury records found for selected period.' : 'لا توجد سجلات خزينة مسجلة للفترة المختارة.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEng ? 'Treasury & Expenses Log:' : 'سجلات حركة الخزينة والمصروفات:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.teal.shade50),
                  children: [
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Date' : 'التاريخ', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Income' : 'الوارد الكلي', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Daily Expense' : 'المصروف اليومي', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Net Income' : 'الوارد الصافي', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Closed By' : 'المنفذ', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
                ...records.map((r) {
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text(r.date, textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.dailyIncome.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.dailyExpense.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.netIncome.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(r.closedBy ?? (isEng ? 'Manager' : 'المدير'), textAlign: TextAlign.center)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesReportView(BuildContext context, List<OrderModel> orders) {
    final primaryColor = Theme.of(context).primaryColor;
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (orders.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              isEng ? 'No invoices found for selected period.' : 'لا توجد فواتير مسجلة للفترة المختارة.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final query = _invoiceSearchController.text.trim().toLowerCase();
    final filteredOrders = orders.where((o) {
      if (query.isEmpty) return true;
      final idStr = o.id.toString();
      final formattedId = '#${o.id}';
      final cashier = (o.cashierName ?? '').toLowerCase();
      final payment = o.paymentMethod.toLowerCase();
      final orderType = _orderTypeLabel(o.orderType, isEng).toLowerCase();
      final totalStr = o.total.toStringAsFixed(0);

      return idStr.contains(query) ||
          formattedId.contains(query) ||
          cashier.contains(query) ||
          payment.contains(query) ||
          orderType.contains(query) ||
          totalStr.contains(query);
    }).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    query.isEmpty
                        ? (isEng ? 'Completed Invoices List (${orders.length} Invoices):' : 'قائمة الفواتير المكتملة (${orders.length} فاتورة):')
                        : (isEng ? 'Search Result (${filteredOrders.length} of ${orders.length} Invoices):' : 'نتيجة البحث (${filteredOrders.length} من أصل ${orders.length} فاتورة):'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _invoiceSearchController,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: isEng ? 'Search invoice number...' : 'البحث برقم الفاتورة...',
                      hintText: isEng ? 'Type invoice number (e.g. 55)' : 'اكتب رقم الفاتورة (مثال: 55)',
                      prefixIcon: const Icon(Icons.search, color: Colors.purple),
                      suffixIcon: _invoiceSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _invoiceSearchController.clear();
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        isEng ? 'No invoice matching search query "$query"' : 'لم يتم العثور على أي فاتورة تطابق رقم الفاتورة أو البحث "$query"',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Table(
                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1)),
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Invoice No' : 'رقم الفاتورة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Order Type' : 'نوع الطلب', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Payment Method' : 'طريقة الدفع', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Total Amount' : 'المبلغ الإجمالي', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Date & Time' : 'التاريخ والوقت', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                  ...filteredOrders.map((o) {
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(10), child: Text('#${o.id}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(_orderTypeLabel(o.orderType, isEng), textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(10), child: Text(o.paymentMethod, textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${o.total.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(o.createdAt.substring(0, 16), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _orderTypeLabel(String type, bool isEng) {
    switch (type) {
      case 'DINE_IN':
        return isEng ? 'Dine-In Table' : 'طاولة صالة';
      case 'TAKEAWAY':
        return isEng ? 'Takeaway' : 'سفري';
      case 'DELIVERY':
        return isEng ? 'Delivery' : 'توصيل خارجي';
      default:
        return type;
    }
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Reports & Analytics Center' : 'مركز التقارير والمبيعات'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.block, size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEng ? 'Section Restricted for Cashiers' : 'قسم غير متاح للكاشير',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEng
                          ? 'Sorry, reports and financial analytics section is restricted to System Manager privileges only.'
                          : 'عذراً، قسم التقارير والبيانات المالية مخصص لصلاحيات المدير فقط ولا يتاح لحسابات الكاشيرية.',
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEng ? 'Please log in with Manager account to access reports.' : 'يرجى تسجيل الدخول بحساب المدير للوصول واطلاع التقارير.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
