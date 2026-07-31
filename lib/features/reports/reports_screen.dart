import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/print_service.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/order.dart';
import '../auth/auth_provider.dart';
import '../categories/categories_provider.dart';
import '../orders/orders_provider.dart';
import '../orders/orders_repository.dart';
import '../products/products_provider.dart';
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
  String _selectedReportType = 'financial'; // 'financial', 'products', 'treasury', 'invoices', 'cashier'
  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  int? _selectedCatId;
  int? _selectedProdId;
  String? _selectedCashier;
  String _selectedOrderTypeFilter = 'ALL'; // 'ALL', 'DINE_IN', 'TAKEAWAY', 'DELIVERY'

  // Loaded Report Data
  List<TopSellingProduct> _topSellingProducts = [];
  List<CashierSalesSummary> _cashierReportData = [];
  List<ProductNetProfitSummary> _netProfitReportData = [];
  bool _isLoadingReportData = false;

  String _formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        return 'تقرير اليوم (${_formatDate(DateTime.now())})';
      case ReportPeriod.monthly:
        return 'تقرير الشهر الحالي (${_formatDate(DateTime.now()).substring(0, 7)})';
      case ReportPeriod.yearly:
        return 'تقرير السنة الحالية (${DateTime.now().year})';
      case ReportPeriod.customRange:
        return 'من ${_formatDate(_fromDate)} إلى ${_formatDate(_toDate)}';
      case ReportPeriod.allTime:
        return 'كافة الفترات (تراكمي)';
    }
  }

  String _getReportTypeTitle() {
    switch (_selectedReportType) {
      case 'financial':
        return 'تقرير الملخص العام والمالي الشامل';
      case 'products':
        return 'تقرير مبيعات الأصناف والمنتجات';
      case 'net_profit':
        return 'تقرير الربح الصافي للمواد والمنتجات';
      case 'treasury':
        return 'تقرير الخزينة والمصروفات اليومية';
      case 'invoices':
        return 'تقرير قائمة الفواتير والعمليات اليومية';
      case 'cashier':
        return 'تقرير مبيعات الكاشير والمستخدمين';
      default:
        return 'تقرير مالي وإداري';
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

    final currentUsername = context.read<AuthProvider>().currentUserName;

    if (_selectedPeriod == ReportPeriod.customRange) {
      final fromStr = _formatDate(_fromDate);
      final toStr = _formatDate(_toDate);
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
        _isLoadingReportData = false;
        _isReportGenerated = true;
      });
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ بداية التقرير (من)',
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _selectedPeriod = ReportPeriod.customRange;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ نهاية التقرير (إلى)',
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
      if (order.status == 'CANCELLED') return false;

      bool matchesPeriod = true;
      if (_selectedPeriod == ReportPeriod.customRange) {
        final orderDt = DateTime.tryParse(order.createdAt);
        if (orderDt != null) {
          final startDay = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
          final endDay = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
          matchesPeriod = orderDt.isAfter(startDay.subtract(const Duration(seconds: 1))) &&
              orderDt.isBefore(endDay.add(const Duration(seconds: 1)));
        }
      } else {
        final prefix = _getDatePrefix();
        matchesPeriod = prefix.isEmpty || order.createdAt.startsWith(prefix);
      }

      final matchesOrderType = _selectedOrderTypeFilter == 'ALL' || order.orderType == _selectedOrderTypeFilter;

      return matchesPeriod && matchesOrderType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // If logged in as Cashier, show clean Access Denied screen:
    if (!authProvider.isManager) {
      return _buildAccessDeniedScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReportGenerated ? _getReportTypeTitle() : 'مركز إعداد وطباعة التقارير الإدارية'),
        centerTitle: true,
        leading: _isReportGenerated
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'تعديل خيارات التقرير',
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
              // Header Banner Card (يستخدم لون الثيم المختار)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: primaryColor,
                child: const Padding(
                  padding: EdgeInsets.all(22.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.analytics_rounded, size: 34, color: Colors.white),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحديد وتخصيص إعدادات التقرير المطلوب',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'اختر نوع التقرير والفترة الزمنية وفلاتر الأصناف ثم اضغط زر إظهار التقرير لمعاينته وطباعته.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
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
                      // 1. نوع التقرير (Report Type)
                      Row(
                        children: [
                          Icon(Icons.category_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          const Text('1. اختر نوع التقرير المطلوب:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildTypeChip(context, 'cashier', '👤 تقرير مبيعات الكاشير والمستخدمين', Icons.badge_outlined, isManagerOnly: false),
                          _buildTypeChip(context, 'net_profit', '💹 تقرير الربح الصافي للمواد والمنتجات', Icons.trending_up, isManagerOnly: true),
                          _buildTypeChip(context, 'financial', '📊 الملخص المالي والعام الشامل', Icons.monetization_on_outlined, isManagerOnly: true),
                          _buildTypeChip(context, 'products', '🍔 تقرير مبيعات الأصناف والمنتجات', Icons.fastfood_outlined, isManagerOnly: true),
                          _buildTypeChip(context, 'treasury', '💰 تقرير الخزينة والمصروفات', Icons.account_balance_wallet_outlined, isManagerOnly: true),
                          _buildTypeChip(context, 'invoices', '🧾 تقرير قائمة الفواتير التفصيلي', Icons.receipt_long_outlined, isManagerOnly: true),
                        ],
                      ),

                      const Divider(height: 32),

                      // 2. الفترة الزمنية (Time Period)
                      Row(
                        children: [
                          Icon(Icons.date_range_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          const Text('2. اختر الفترة الزمنية للتقرير:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPeriodChip(context, '📅 تقرير اليوم', ReportPeriod.daily),
                          _buildPeriodChip(context, '🗓️ تقرير الشهر', ReportPeriod.monthly),
                          _buildPeriodChip(context, '📆 تقرير السنة', ReportPeriod.yearly),
                          _buildPeriodChip(context, '⏳ فترة مخصصة (من - إلى)', ReportPeriod.customRange),
                          _buildPeriodChip(context, '📊 كافة الفترات', ReportPeriod.allTime),
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
                                label: Text('من تاريخ: ${_formatDate(_fromDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.arrow_back, color: Colors.grey),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _selectToDate(context),
                                icon: Icon(Icons.calendar_month, size: 18, color: primaryColor),
                                label: Text('إلى تاريخ: ${_formatDate(_toDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 32),

                      // 3. خيارات الفلترة الإضافية (Filter Options)
                      Row(
                        children: [
                          Icon(Icons.filter_alt_outlined, color: primaryColor),
                          const SizedBox(width: 8),
                          const Text('3. خيارات التصفية والفلترة الخاصة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cashier Selector Dropdown
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedCashier,
                        decoration: InputDecoration(
                          labelText: 'الكاشير / المستخدم المحدد',
                          prefixIcon: Icon(Icons.person_pin, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('كافة الكاشيرية والمستخدمين (الكل)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                labelText: 'التصنيف المحدد',
                                prefixIcon: Icon(Icons.category, color: primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('كافة التصنيفات (الكل)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                labelText: 'الصنف / المنتج المحدد',
                                prefixIcon: const Icon(Icons.fastfood, color: Colors.orange),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('كافة الأصناف والمنتجات', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          labelText: 'نوع الطلبات والفواتير',
                          prefixIcon: const Icon(Icons.alt_route, color: Colors.blue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('كافة أنواع الطلبات (صالة، سفري، توصيل)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'TAKEAWAY', child: Text('طلبات السفري (الكاشير السريع)')),
                          DropdownMenuItem(value: 'DINE_IN', child: Text('طلبات صالة المطعم (الطاولات)')),
                          DropdownMenuItem(value: 'DELIVERY', child: Text('طلبات التوصيل الخارجي')),
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

                      // 4. MAIN ACTION BUTTON: إظهار التقرير المختار (يتبع لون الثيم)
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
                          label: const Text(
                            'إظهار التقرير المختار',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
    final isSelected = _selectedReportType == typeKey;
    final isManager = context.watch<AuthProvider>().isManager;
    final isDisabled = isManagerOnly && !isManager;

    return ChoiceChip(
      avatar: Icon(
        isDisabled ? Icons.lock_outline : icon,
        size: 18,
        color: isDisabled ? Colors.grey : (isSelected ? Colors.white : primaryColor),
      ),
      label: Text(
        isDisabled ? '$label (للمدير)' : label,
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
          TopNotification.showWarning(context, '🔒 هذا التقرير مخصص لصلاحيات مدير النظام فقط.');
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
    final topCashier = _cashierReportData.isNotEmpty ? _cashierReportData.first.cashierName : 'لا يوجد';

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
                label: const Text('تعديل خيارات التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    final customHeaders = [
                      'اسم الصنف / المنتج',
                      'سعر الكلفة',
                      'سعر البيع',
                      'الكمية المباعة',
                      'إجمالي الإيراد',
                      'إجمالي الكلفة',
                      'صافي الربح',
                      'نسبة الربح',
                    ];
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

                    TopNotification.showInfo(context, 'جاري إرسال تقرير الربح الصافي للمواد لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                    final success = await PrintService.printReport(
                      reportTitle: _getReportTypeTitle(),
                      dateRangeText: _getPeriodTitle(),
                      generatedBy: context.read<AuthProvider>().currentUserName,
                      totalSales: totalNetRevenue,
                      totalExpenses: totalNetCost,
                      totalOrders: _netProfitReportData.length,
                      netProfit: totalNetProfit,
                      tableTitle: 'تفاصيل الربح الصافي للمواد والمنتجات المباعة:',
                      customHeaders: customHeaders,
                      customDataRows: customDataRows,
                      settings: settingsProvider,
                    );

                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(context, '🖨️ تم طباعة تقرير الربح الصافي للمواد بنجاح!');
                      } else {
                        TopNotification.showSuccess(context, '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                      }
                    }
                    return;
                  }

                  if (_selectedReportType == 'cashier') {
                    final customHeaders = [
                      'اسم الكاشير / المستخدم',
                      'عدد الفواتير',
                      'مبيعات الكاش',
                      'مبيعات الشبكة',
                      'مبيعات الآجل',
                      'معدل الفاتورة',
                      'إجمالي المبيعات',
                    ];
                    final customDataRows = _cashierReportData.map((c) => [
                      c.cashierName,
                      '${c.totalOrders} فاتورة',
                      '${c.cashSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.cardSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.creditSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.avgOrderValue.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                      '${c.totalSales.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                    ]).toList();

                    TopNotification.showInfo(context, 'جاري إرسال تقرير الكاشيرية لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                    final success = await PrintService.printReport(
                      reportTitle: _getReportTypeTitle(),
                      dateRangeText: _getPeriodTitle(),
                      generatedBy: context.read<AuthProvider>().currentUserName,
                      totalSales: totalCashierSales,
                      totalExpenses: 0.0,
                      totalOrders: totalCashierOrders,
                      netProfit: totalCashierSales,
                      tableTitle: 'تفاصيل مبيعات الكاشيرية والمستخدمين:',
                      customHeaders: customHeaders,
                      customDataRows: customDataRows,
                      settings: settingsProvider,
                    );

                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(context, '🖨️ تم طباعة تقرير الكاشيرية بنجاح!');
                      } else {
                        TopNotification.showSuccess(context, '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                      }
                    }
                    return;
                  }

                  final breakdownList = displayProducts.map((p) => {
                    'name': p.productName,
                    'qty': p.quantitySold,
                    'total': p.totalRevenue,
                  }).toList();

                  TopNotification.showInfo(context, 'جاري إرسال التقرير لـ [${settingsProvider.reportsPrinter}] وطباعته...');

                  final success = await PrintService.printReport(
                    reportTitle: _getReportTypeTitle(),
                    dateRangeText: _getPeriodTitle(),
                    generatedBy: context.read<AuthProvider>().currentUserName,
                    totalSales: totalSales,
                    totalExpenses: totalExpenses,
                    totalOrders: totalOrdersCount,
                    netProfit: calculatedNetProfit,
                    productBreakdown: breakdownList,
                    settings: settingsProvider,
                  );

                  if (context.mounted) {
                    if (success) {
                      TopNotification.showSuccess(context, '🖨️ تم طباعة التقرير بنجاح!');
                    } else {
                      TopNotification.showSuccess(context, '🖨️ تم إرسال التقرير إلى نظام الطباعة المباشرة!');
                    }
                  }
                },
                icon: const Icon(Icons.print_rounded, color: Colors.white, size: 22),
                label: const Text(
                  'طباعة التقرير (Print Report)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                                Text(_getReportTypeTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('النطاق الزمني: ${_getPeriodTitle()}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isReportGenerated = false),
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('تغيير الفلاتر'),
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
                                    ? 'إجمالي صافي أرباح المواد'
                                    : (isCashierReport ? 'إجمالي مبيعات الكاشيرية' : 'إجمالي المبيعات (الوارد)'),
                                value: '${displayTotalSales.toStringAsFixed(0)} $currencySym',
                                subtitle: isNetProfitReport
                                    ? 'صافي ربح المواد المباعة'
                                    : (isCashierReport ? 'مجموع مبيعات الكاشيرية' : 'المجموع الإجمالي للمبيعات'),
                                icon: isNetProfitReport ? Icons.trending_up : Icons.monetization_on,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? 'إجمالي إيرادات المبيعات'
                                    : (isCashierReport ? 'الكاشير الأعلى مبيعات' : 'إجمالي المصروفات'),
                                value: isNetProfitReport
                                    ? '${totalNetRevenue.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? topCashier : '${totalExpenses.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? 'إجمالي قيمة المبيعات المباشرة'
                                    : (isCashierReport ? 'الأعلى أداءً بالفترة' : 'مجموع المصاريف والنفقات'),
                                icon: isNetProfitReport ? Icons.attach_money : (isCashierReport ? Icons.star_rounded : Icons.shopping_cart_checkout),
                                color: isNetProfitReport ? Colors.blue.shade700 : (isCashierReport ? Colors.amber.shade800 : Colors.red.shade700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? 'إجمالي كلفة المواد (COGS)'
                                    : (isCashierReport ? 'عدد الكاشيرية النشطين' : 'صافي الربح المحسوب'),
                                value: isNetProfitReport
                                    ? '${totalNetCost.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? '${_cashierReportData.length} كاشير' : '${calculatedNetProfit.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? 'مجموع سعر شراء المواد'
                                    : (isCashierReport ? 'المستخدمين المتواجدين' : 'الوارد الكلي - المصروفات'),
                                icon: isNetProfitReport ? Icons.shopping_bag_outlined : (isCashierReport ? Icons.people_alt : Icons.savings),
                                color: isNetProfitReport ? Colors.deepOrange.shade700 : (isCashierReport ? Colors.teal.shade700 : (calculatedNetProfit >= 0 ? primaryColor : Colors.red.shade900)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _metricCard(
                                title: isNetProfitReport ? 'نسبة هامش الربح للصنف' : 'عدد الفواتير المكتملة',
                                value: isNetProfitReport ? '${overallProfitMarginPct.toStringAsFixed(1)}%' : '$totalOrdersCount فاتورة',
                                subtitle: isNetProfitReport ? 'معدل الربحية من المبيعات' : 'إجمالي عدد الطلبات',
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
                                    ? 'إجمالي صافي أرباح المواد'
                                    : (isCashierReport ? 'إجمالي مبيعات الكاشيرية' : 'إجمالي المبيعات (الوارد)'),
                                value: '${displayTotalSales.toStringAsFixed(0)} $currencySym',
                                subtitle: isNetProfitReport
                                    ? 'صافي ربح المواد المباعة'
                                    : (isCashierReport ? 'مجموع مبيعات الكاشيرية' : 'المجموع الإجمالي للمبيعات'),
                                icon: isNetProfitReport ? Icons.trending_up : Icons.monetization_on,
                                color: Colors.green.shade700,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? 'إجمالي إيرادات المبيعات'
                                    : (isCashierReport ? 'الكاشير الأعلى مبيعات' : 'إجمالي المصروفات'),
                                value: isNetProfitReport
                                    ? '${totalNetRevenue.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? topCashier : '${totalExpenses.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? 'إجمالي قيمة المبيعات المباشرة'
                                    : (isCashierReport ? 'الأعلى أداءً بالفترة' : 'مجموع المصاريف والنفقات'),
                                icon: isNetProfitReport ? Icons.attach_money : (isCashierReport ? Icons.star_rounded : Icons.shopping_cart_checkout),
                                color: isNetProfitReport ? Colors.blue.shade700 : (isCashierReport ? Colors.amber.shade800 : Colors.red.shade700),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport
                                    ? 'إجمالي كلفة المواد (COGS)'
                                    : (isCashierReport ? 'عدد الكاشيرية النشطين' : 'صافي الربح المحسوب'),
                                value: isNetProfitReport
                                    ? '${totalNetCost.toStringAsFixed(0)} $currencySym'
                                    : (isCashierReport ? '${_cashierReportData.length} كاشير' : '${calculatedNetProfit.toStringAsFixed(0)} $currencySym'),
                                subtitle: isNetProfitReport
                                    ? 'مجموع سعر شراء المواد'
                                    : (isCashierReport ? 'المستخدمين المتواجدين' : 'الوارد الكلي - المصروفات'),
                                icon: isNetProfitReport ? Icons.shopping_bag_outlined : (isCashierReport ? Icons.people_alt : Icons.savings),
                                color: isNetProfitReport ? Colors.deepOrange.shade700 : (isCashierReport ? Colors.teal.shade700 : (calculatedNetProfit >= 0 ? primaryColor : Colors.red.shade900)),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _metricCard(
                                title: isNetProfitReport ? 'نسبة هامش الربح للصنف' : 'عدد الفواتير المكتملة',
                                value: isNetProfitReport ? '${overallProfitMarginPct.toStringAsFixed(1)}%' : '$totalOrdersCount فاتورة',
                                subtitle: isNetProfitReport ? 'معدل الربحية من المبيعات' : 'إجمالي عدد الطلبات',
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
                  if (_selectedReportType == 'net_profit') ...[
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

  Widget _buildNetProfitReportView(BuildContext context, List<ProductNetProfitSummary> products) {
    final primaryColor = Theme.of(context).primaryColor;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (products.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('لا توجد مبيعات مواد أو أرباح مسجلة للفترة والمحددات المختارة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                const Text('تفاصيل الربح الصافي وكلفة البضاعة المباعة لكل صنف:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Chip(
                  avatar: const Icon(Icons.inventory_2, size: 18, color: Colors.white),
                  label: Text('عدد الأصناف المباعة: ${products.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    children: const [
                      Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('اسم الصنف / المنتج', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('سعر الكلفة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('سعر البيع', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('الكمية المباعة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('إجمالي الإيراد', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('إجمالي الكلفة (COGS)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('صافي الربح للمادة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('نسبة الربح (%)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
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
                      const Padding(padding: EdgeInsets.all(10), child: Text('المجموع الإجمالي', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
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
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (cashiers.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('لا توجد مبيعات كاشيرية مسجلة للفترة والمحددات المختارة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
                const Text('تفاصيل مبيعات الكاشيرية والمستخدمين:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Chip(
                  avatar: const Icon(Icons.people, size: 18, color: Colors.white),
                  label: Text('عدد الكاشيرية: ${cashiers.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    children: const [
                      Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('اسم الكاشير / المستخدم', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('عدد الفواتير', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('مبيعات الكاش', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('مبيعات الشبكة (كارت)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('مبيعات الآجل (دين)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('معدل الفاتورة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Padding(padding: EdgeInsets.all(10), child: Text('إجمالي المبيعات', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                  ...cashiers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final c = entry.value;
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(10), child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text(c.cashierName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text('${c.totalOrders} فاتورة', textAlign: TextAlign.center)),
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
                      const Padding(padding: EdgeInsets.all(10), child: Text('المجموع الإجمالي', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('$totalCashierOrders فاتورة', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
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
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (products.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('لا توجد مبيعات أصناف مسجلة للفترة والمحددات المختارة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
            const Text('تفاصيل مبيعات الأصناف والمنتجات:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('اسم الصنف / المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10), child: Text('الكمية المباعة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('إجمالي المبلغ', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
                ...products.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text('${idx + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${item.quantitySold} قطعة', textAlign: TextAlign.center)),
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
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (records.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('لا توجد سجلات خزينة مسجلة للفترة المختارة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
            const Text('سجلات حركة الخزينة والمصروفات:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.teal.shade50),
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('الوارد الكلي', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('المصروف اليومي', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('الوارد الصافي', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('المنفذ', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
                ...records.map((r) {
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text(r.date, textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.dailyIncome.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.dailyExpense.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text('${r.netIncome.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(r.closedBy ?? 'المدير', textAlign: TextAlign.center)),
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
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    if (orders.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('لا توجد فواتير مسجلة للفترة المختارة.', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
            Text('قائمة الفواتير المكتملة (${orders.length} فاتورة):', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1)),
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text('رقم الفاتورة', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('نوع الطلب', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('المبلغ الإجمالي', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(10), child: Text('التاريخ والوقت', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  ],
                ),
                ...orders.map((o) {
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text('#${o.id}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(_orderTypeLabel(o.orderType), textAlign: TextAlign.center)),
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

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'DINE_IN':
        return 'طاولة صالة';
      case 'TAKEAWAY':
        return 'سفري';
      case 'DELIVERY':
        return 'توصيل خارجي';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التقارير والمبيعات'),
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
              child: const Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.block, size: 42, color: Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'قسم غير متاح للكاشير',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'عذراً، قسم التقارير والبيانات المالية مخصص لصلاحيات مدير النظام فقط ولا يتاح لحسابات الكاشيرية.',
                      style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'يرجى تسجيل الدخول بحساب المدير للوصول واطلاع التقارير.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
