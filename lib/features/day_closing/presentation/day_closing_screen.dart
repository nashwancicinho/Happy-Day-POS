import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../models/daily_treasury.dart';
import '../../auth/auth_provider.dart';
import '../../orders/orders_provider.dart';
import '../../settings/settings_provider.dart';
import '../../shifts/shifts_provider.dart';
import '../../tables/tables_provider.dart';
import '../../treasury/treasury_provider.dart';

class DayClosingScreen extends StatefulWidget {
  const DayClosingScreen({super.key});

  @override
  State<DayClosingScreen> createState() => _DayClosingScreenState();
}

class _DayClosingScreenState extends State<DayClosingScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySym = settingsProvider.currencySymbol;
    final isEng = settingsProvider.isEnglish;
    final ordersProvider = context.watch<OrdersProvider>();
    final shiftsProvider = context.watch<ShiftsProvider>();
    final authProvider = context.watch<AuthProvider>();

    final todaySales = ordersProvider.todaySalesTotal;
    final todayOrdersCount = ordersProvider.todayOrdersCount;
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
                                isEng ? 'Date: ${DateTime.now().toIso8601String().substring(0, 10)}' : 'اليوم: ${DateTime.now().toIso8601String().substring(0, 10)}',
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

                // Stats Overview Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: isEng ? 'Total Today Sales' : 'مبيعات اليوم الإجمالية',
                        value: '${todaySales.toStringAsFixed(0)} $currencySym',
                        icon: Icons.payments,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        title: isEng ? 'Completed Invoices' : 'عدد الفواتير المكتملة',
                        value: isEng ? '$todayOrdersCount Invoices' : '$todayOrdersCount فاتورة',
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
                                    todaySales,
                                    todayOrdersCount,
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
    final expenseController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final incomeVal = double.tryParse(incomeController.text.trim()) ?? 0.0;
            final expenseVal = double.tryParse(expenseController.text.trim()) ?? 0.0;
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
                              'التاريخ: ${DateTime.now().toIso8601String().substring(0, 10)}',
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
                        decoration: InputDecoration(
                          labelText: 'الوارد الكلي اليومي (إجمالي المبيعات) *',
                          prefixIcon: const Icon(Icons.add_card, color: Colors.green),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: currencySym,
                          filled: true,
                          fillColor: Colors.green.shade50.withValues(alpha: 0.3),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 14),

                      // 2. المصروف اليومي
                      TextField(
                        controller: expenseController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'المصروف اليومي (النفقات والنثريات) *',
                          prefixIcon: const Icon(Icons.shopping_cart_checkout, color: Colors.red),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: currencySym,
                          filled: true,
                          fillColor: Colors.red.shade50.withValues(alpha: 0.3),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 16),

                      // 3. صافي الربح
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: netIncomeVal >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: netIncomeVal >= 0 ? Colors.green.shade400 : Colors.red.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('صافي الربح المحسوب:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text('(الوارد الكلي - المصروف اليومي)', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                              ],
                            ),
                            Text(
                              '${netIncomeVal.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: netIncomeVal >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 4. ملاحظات اختياري
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
                    final todayStr = nowIso.substring(0, 10);

                    // 1. Save treasury record
                    final treasuryRecord = DailyTreasuryModel(
                      date: todayStr,
                      dailyIncome: incomeVal,
                      dailyExpense: expenseVal,
                      netIncome: netIncomeVal,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      closedBy: userName,
                      createdAt: nowIso,
                    );
                    await treasuryProvider.saveTreasuryRecord(treasuryRecord);

                    // 2. Close current shift & Open new clean shift

                    if (shiftsProvider.currentShift != null) {
                      await shiftsProvider.closeShift(incomeVal);
                    }
                    await shiftsProvider.openShift(0.0, userName: userName);

                    // 3. Reset today session counters to 0 for active session
                    ordersProvider.resetTodaySession(nowIso);

                    // 4. Perform Automatic Backup to selected folder on Day Closing
                    final autoBackupSuccess = await settingsProvider.performAutoBackup(isClosingDay: true);

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
