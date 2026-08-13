import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../../core/services/print_service.dart';
import '../../../models/daily_treasury.dart';
import '../../auth/auth_provider.dart';
import '../../orders/orders_provider.dart';
import '../../settings/settings_provider.dart';
import '../../shifts/shifts_provider.dart';
import '../../tables/tables_provider.dart';
import '../../payroll/payroll_provider.dart';
import '../../purchases/purchases_provider.dart';
import '../../treasury/treasury_provider.dart';

class DayClosingScreen extends StatefulWidget {
  const DayClosingScreen({super.key});

  @override
  State<DayClosingScreen> createState() => _DayClosingScreenState();
}

class _DayClosingScreenState extends State<DayClosingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrdersProvider>().loadOrders();
        context.read<ShiftsProvider>().loadCurrentShift();
        context.read<TreasuryProvider>().loadTreasuryRecords();
        context.read<TreasuryProvider>().loadOtherExpenses();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySym = settingsProvider.currencySymbol;
    final isEng = settingsProvider.isEnglish;
    final ordersProvider = context.watch<OrdersProvider>();
    final shiftsProvider = context.watch<ShiftsProvider>();
    final authProvider = context.watch<AuthProvider>();

    final totalInflow = ordersProvider.currentShiftSalesTotal;
    final netProfitVal = ordersProvider.currentShiftNetProfit;
    final fullTodayCount = ordersProvider.fullTodayOrdersCount;
    final currentShiftCount = ordersProvider.currentShiftCompletedOrders.length;
    final isShiftOpen = shiftsProvider.currentShift != null && shiftsProvider.currentShift!.isOpen;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, size: 26),
            const SizedBox(width: 10),
            Text(isEng ? 'Day Closing & Treasury' : 'إغلاق اليوم والخزينة', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.today, size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEng ? 'Shift Start Date: ${ordersProvider.currentShiftFirstInvoiceDate}' : 'تاريخ بداية الشيفت (أول فاتورة): ${ordersProvider.currentShiftFirstInvoiceDate}',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEng ? 'Shift Status: ${isShiftOpen ? "Open & Active ✅" : "Closed 🔒"} | User: ${authProvider.currentUserName}' : 'حالة الشيفت الحالي: ${isShiftOpen ? "مفتوح ومستمر ✅" : "مغلق 🔒"} | المنفذ: ${authProvider.currentUserName}',
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

                // Stats Overview Row (Total Inflow, Net Profit, Orders Count)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: isEng ? 'Total Inflow' : 'الوارد الكلي',
                        value: '${totalInflow.toStringAsFixed(0)} $currencySym',
                        icon: Icons.payments,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: isEng ? 'Net Profit' : 'الربح الصافي',
                        value: '${netProfitVal.toStringAsFixed(0)} $currencySym',
                        icon: Icons.trending_up_rounded,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: isEng ? 'Completed Invoices' : 'فواتير اليوم',
                        value: isEng ? '$fullTodayCount Invoices' : '$fullTodayCount ($currentShiftCount بالشيفت)',
                        icon: Icons.receipt_long,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Text(
                  isEng ? 'Day Closing & Treasury Action:' : 'تصفية الخزينة وإغلاق اليوم:',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Main Integrated EOD & Treasury Action Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_reset_rounded, size: 40, color: Colors.deepOrange.shade800),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEng ? 'Close Day & Settlement' : 'إغلاق اليوم وتصفية الخزينة والشيفت',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isEng ? 'Calculates net income, saves treasury records, and performs automatic database backup to target folder.' : 'عند الضغط، تظهر شاشة الخزينة لتأكيد الوارد الكلي والمصروف واحتساب صافي الربح وإغلاق اليوم رسمياً.',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange.shade800,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 3,
                                  ),
                                  onPressed: () => _showIntegratedDayClosingDialog(
                                    context,
                                    totalInflow,
                                    currentShiftCount,
                                    authProvider.currentUserName,
                                    shiftsProvider,
                                  ),
                                  icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
                                  label: Text(
                                    isEng ? 'Close Day & Shift Now' : 'إغلاق اليوم وتصفية الشيفت',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printDailyClosingReceipt(
    BuildContext context,
    double incomeVal,
    double expenseVal,
    double netIncomeVal,
    int todayOrdersCount,
    String userName,
    String? notes,
  ) async {
    final settingsProvider = context.read<SettingsProvider>();
    final ordersProvider = context.read<OrdersProvider>();
    final treasuryProvider = context.read<TreasuryProvider>();
    final payrollProvider = context.read<PayrollProvider>();
    final purchasesProvider = context.read<PurchasesProvider>();

    await treasuryProvider.loadOtherExpenses();
    await purchasesProvider.loadAllData();
    await payrollProvider.loadPayrollData();

    final currencySym = settingsProvider.currencySymbol;

    final firstInvoiceTime = ordersProvider.currentShiftFirstInvoiceDate;
    final closingTime = DateTime.now().toIso8601String().length >= 16
        ? DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')
        : DateTime.now().toIso8601String();

    final completedOrders = ordersProvider.orders.where((o) => o.status == 'COMPLETED').toList();
    final totalDiscounts = completedOrders.fold(0.0, (sum, o) => sum + o.discountAmount);

    final cashSales = completedOrders.where((o) => o.paymentMethod == 'CASH').fold(0.0, (sum, o) => sum + o.total);
    final cardSales = completedOrders.where((o) => o.paymentMethod == 'CARD').fold(0.0, (sum, o) => sum + o.total);
    final debtSales = completedOrders.where((o) => o.paymentMethod == 'CREDIT' || o.paymentMethod == 'DEBT').fold(0.0, (sum, o) => sum + o.total);

    final refundedOrders = ordersProvider.orders.where((o) => o.status == 'REFUNDED').toList();
    final refundedCount = refundedOrders.length;
    final refundedTotal = refundedOrders.fold(0.0, (sum, o) => sum + o.total);

    final cancelledOrders = ordersProvider.orders.where((o) => o.status == 'CANCELLED').toList();
    final cancelledCount = cancelledOrders.length;

    // 1. Calculate Purchases / Materials Cost for shift date
    final reportDate = firstInvoiceTime.length >= 10 ? firstInvoiceTime.substring(0, 10) : DateTime.now().toIso8601String().substring(0, 10);
    final filteredPurchases = purchasesProvider.purchases.where((p) {
      final dateStr = p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt;
      return dateStr == reportDate;
    }).toList();
    final purchasesCost = filteredPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);

    // 2. Calculate Payroll Expenses for shift date
    final filteredPayments = payrollProvider.payments.where((p) => p.paymentDate == reportDate).toList();
    final salaryExpenses = filteredPayments.fold(0.0, (sum, p) => sum + p.netSalary);

    final totalAllExpenses = purchasesCost + salaryExpenses + expenseVal;
    final finalNetProfit = incomeVal - totalAllExpenses;

    final List<List<String>> customRows = [];

    // 1. General Sales & P&L Comprehensive Summary (الملخص العام والمالي الشامل)
    customRows.add(['الوارد الكلي (إجمالي المبيعات)', '$todayOrdersCount فاتورة', '${incomeVal.toStringAsFixed(0)} $currencySym']);
    if (cashSales > 0) {
      customRows.add(['• المبيعات نقداً (CASH)', '-', '${cashSales.toStringAsFixed(0)} $currencySym']);
    }
    if (cardSales > 0) {
      customRows.add(['• المبيعات بالبطاقة (CARD)', '-', '${cardSales.toStringAsFixed(0)} $currencySym']);
    }
    if (debtSales > 0) {
      customRows.add(['• المبيعات بالآجل (DEBT)', '-', '${debtSales.toStringAsFixed(0)} $currencySym']);
    }
    if (totalDiscounts > 0) {
      customRows.add(['إجمالي الخصومات والتخفيضات الممنوحة (-)', '-', '-${totalDiscounts.toStringAsFixed(0)} $currencySym']);
    }
    if (refundedCount > 0) {
      customRows.add(['الفواتير والعمليات المسترجعة', '$refundedCount فاتورة', '-${refundedTotal.toStringAsFixed(0)} $currencySym']);
    }
    if (cancelledCount > 0) {
      customRows.add(['الفواتير والعمليات الملغية', '$cancelledCount فاتورة', 'ملغاة']);
    }
    if (purchasesCost > 0) {
      customRows.add(['تكلفة خامات ومشتريات المواد الأولية (-)', '-', '-${purchasesCost.toStringAsFixed(0)} $currencySym']);
    }
    if (salaryExpenses > 0) {
      customRows.add(['رواتب ومستحقات الموظفين المسددة (-)', '-', '-${salaryExpenses.toStringAsFixed(0)} $currencySym']);
    }
    if (expenseVal > 0) {
      customRows.add(['مصاريف ونفقات الخزينة التشغيلية (-)', '${treasuryProvider.otherExpenses.length} عملية', '-${expenseVal.toStringAsFixed(0)} $currencySym']);
    }
    customRows.add(['صافي ربح اليوم النهائي والأخير (=)', '=', '${finalNetProfit.toStringAsFixed(0)} $currencySym']);

    // 2. Itemized Product Sales Breakdown (تفاصيل مبيعات الأصناف والمنتجات المباعة)
    final topProducts = await ordersProvider.getTopSellingProducts(datePrefix: reportDate);

    customRows.add(['--- تفاصيل مبيعات الأصناف والمنتجات المباعة ---', '---', '---']);
    if (topProducts.isEmpty) {
      customRows.add(['لا توجد منتجات مباعة اليوم', '0', '0 $currencySym']);
    } else {
      for (var p in topProducts) {
        final qty = p.quantitySold;
        final total = p.totalRevenue;
        final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
        customRows.add([
          p.productName,
          'كمية: $qtyStr',
          '${total.toStringAsFixed(0)} $currencySym',
        ]);
      }
    }

    // 3. Itemized Expenses Breakdown (جميع المصاريف المسجلة بالخزينة تفصيلياً)
    customRows.add(['--- تفاصيل المصاريف المسجلة بالخزينة ---', '---', '---']);
    final otherExpensesList = treasuryProvider.otherExpenses;
    if (otherExpensesList.isEmpty) {
      customRows.add(['لا توجد مصاريف مسجلة بالخزينة اليوم', '0', '0 $currencySym']);
    } else {
      for (var i = 0; i < otherExpensesList.length; i++) {
        final exp = otherExpensesList[i];
        final expUser = exp.createdBy ?? 'المدير';
        customRows.add([
          '#${i + 1} ${exp.title} (${exp.category})',
          'بواسطة: $expUser',
          '-${exp.amount.toStringAsFixed(0)} $currencySym',
        ]);
      }
    }

    if (notes != null && notes.isNotEmpty) {
      customRows.add(['ملاحظات الإغلاق والتصفية', '-', notes]);
    }

    final success = await PrintService.printReport(
      reportTitle: 'تقرير الملخص العام والمالي الشامل 🔒',
      dateRangeText: closingTime,
      generatedBy: userName,
      totalSales: incomeVal,
      totalExpenses: totalAllExpenses,
      totalOrders: todayOrdersCount,
      netProfit: finalNetProfit,
      firstInvoiceTime: firstInvoiceTime,
      dayClosingTime: closingTime,
      customHeaders: ['البيان / اسم المنتج والفرع', 'التفاصيل / الكمية', 'المبلغ الصافي'],
      customDataRows: customRows,
      settings: settingsProvider,
    );

    if (context.mounted) {
      if (success) {
        TopNotification.showSuccess(context, '🖨️ تم إرسال التقرير الشامل والمفصل للطابعة بنجاح!');
      } else {
        TopNotification.showError(context, '⚠️ تعذر الطباعة المباشرة، يرجى التحقق من إعدادات الطابعة');
      }
    }
  }

  // Integrated Day Closing & Treasury Dialog (الخزينة المدمجة داخل إغلاق اليوم)
  void _showIntegratedDayClosingDialog(
    BuildContext context,
    double defaultIncome,
    int todayOrdersCount,
    String userName,
    ShiftsProvider shiftsProvider,
  ) {
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final incomeController = TextEditingController(text: defaultIncome.toStringAsFixed(0));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final treasuryProvider = context.watch<TreasuryProvider>();
            final incomeVal = double.tryParse(incomeController.text.trim()) ?? 0.0;
            final expenseVal = treasuryProvider.totalOtherExpenses;
            final netIncomeVal = incomeVal - expenseVal;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepOrange.shade100,
                    child: Icon(Icons.lock_reset_rounded, color: Colors.deepOrange.shade800),
                  ),
                  const SizedBox(width: 12),
                  const Text('تصفية الخزينة وإغلاق اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تاريخ أول فاتورة: ${context.read<OrdersProvider>().currentShiftFirstInvoiceDate}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'الفواتير: $todayOrdersCount | المنفذ: $userName',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. الوارد الكلي اليومي
                      TextField(
                        controller: incomeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                        decoration: InputDecoration(
                          labelText: 'الوارد الكلي اليومي (إجمالي المبيعات) *',
                          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          prefixIcon: const Icon(Icons.add_card, color: Colors.green, size: 28),
                          suffixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: currencySym,
                          filled: true,
                          fillColor: Colors.green.shade50.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 14),

                      // ملاحظات اختياري
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات وتفاصيل الإغلاق (اختياري)',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء (إبقاء اليوم مفتوحاً)'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade900,
                    side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _printDailyClosingReceipt(
                    context,
                    incomeVal,
                    expenseVal,
                    netIncomeVal,
                    todayOrdersCount,
                    userName,
                    notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('طباعة التقرير اليومي 🖨️', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final tablesProvider = context.read<TablesProvider>();
                    final ordersProvider = context.read<OrdersProvider>();
                    final treasuryProvider = context.read<TreasuryProvider>();
                    final shiftsProvider = context.read<ShiftsProvider>();
                    final settingsProvider = context.read<SettingsProvider>();

                    await tablesProvider.loadTables();
                    await ordersProvider.loadOrders();

                    final activeTables = tablesProvider.tables.where((t) => t.status == 1).toList();
                    final openTableOrders = ordersProvider.orders.where((o) => o.status == 'OPEN' && o.tableId != null).toList();

                    if (activeTables.isNotEmpty || openTableOrders.isNotEmpty) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.table_restaurant_rounded, color: Colors.red, size: 30),
                              SizedBox(width: 10),
                              Text(
                                '🚫 لا يمكن إغلاق اليوم!',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'لا يمكن تصفية وإغلاق اليوم لأن هناك طاولات مشغولة لم يتم تسديد فواتيرها بعد!\n\nيرجى إتمام دفع وتسديد فواتير جميع الطاولات في الكاشير أولاً.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.red, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          'الطاولات المشغولة حالياً (${activeTables.length} طاولات):',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      activeTables.isNotEmpty
                                          ? activeTables.map((t) => '• ${t.name} (سعة ${t.capacity} أفراد)').join('\n')
                                          : '• توجد طلبات معلقة مفتوحة على الطاولات',
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('حسناً، استكمال الدفع أولاً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final nowIso = DateTime.now().toIso8601String();
                    final reportDate = ordersProvider.currentShiftFirstInvoiceDate;

                    // 1. Save treasury record with date of the first invoice of the shift
                    final treasuryRecord = DailyTreasuryModel(
                      date: reportDate,
                      dailyIncome: incomeVal,
                      dailyExpense: expenseVal,
                      netIncome: netIncomeVal,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      closedBy: userName,
                      createdAt: nowIso,
                    );
                    await treasuryProvider.saveTreasuryRecord(treasuryRecord);

                    // Finalize shift orders business date
                    await ordersProvider.finalizeShiftOrdersBusinessDate(reportDate, nowIso);

                    // 2. Close current shift & Open new clean shift

                    if (shiftsProvider.currentShift != null) {
                      await shiftsProvider.closeShift(incomeVal);
                    }
                    await shiftsProvider.openShift(0.0, userName: userName);

                    // 3. Reset today session counters to 0 for active session
                    ordersProvider.resetTodaySession(nowIso);

                    // 4. Perform Automatic Backup to selected folder on Day Closing
                    final autoBackupSuccess = await settingsProvider.performAutoBackup(isClosingDay: true);

                    // Automatic print removed per request. Printing is done manually via "طباعة التقرير اليومي" button.

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!context.mounted) return;

                    TopNotification.showSuccess(
                      context,
                      autoBackupSuccess
                          ? '🔒 تم إغلاق اليوم وقفل الخزينة وإنشاء نسخة احتياطية أوتوماتيكياً بالمجلد المختار! 🎉'
                          : '🔒 تم حفظ الخزينة وإغلاق اليوم وتصفية الشيفت بنجاح! (صافي الربح: ${netIncomeVal.toStringAsFixed(0)} $currencySym)',
                    );
                  },
                  icon: const Icon(Icons.lock, color: Colors.white),
                  label: const Text('تأكيد وإغلاق اليوم والخزينة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
