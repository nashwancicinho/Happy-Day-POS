import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/orders_provider.dart';
import '../../settings/settings_provider.dart';
import '../../tables/tables_provider.dart';
import '../shifts_provider.dart';

class ShiftManagementDialog extends StatelessWidget {
  const ShiftManagementDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final shiftsProvider = context.watch<ShiftsProvider>();
    final shift = shiftsProvider.currentShift;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.point_of_sale, color: AppColors.primary),
          const SizedBox(width: 10),
          const Text('إدارة الوردية والخزينة (Z-Report)', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: shift == null || shift.status == 'CLOSED'
            ? _buildOpenShiftContent(context)
            : _buildActiveShiftContent(context, shiftsProvider),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق Window'),
        ),
      ],
    );
  }

  Widget _buildOpenShiftContent(BuildContext context) {
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    final cashController = TextEditingController(text: '50000');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text('لا توجد وردية مفتوحة حالياً. يرجى إدخال مبلغ افتتاح الصندوق لفتح وردية جديدة.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: cashController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'المبلغ الافتتاحي بالدرج ($currencySym)',
            border: const OutlineInputBorder(),
            prefixIcon: (currencySym == '\$' || currencySym.contains('\$'))
                ? const Icon(Icons.attach_money)
                : const Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(cashController.text.trim()) ?? 0.0;
              await context.read<ShiftsProvider>().openShift(amount);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.lock_open),
            label: const Text('فتح وردية جديدة الان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveShiftContent(BuildContext context, ShiftsProvider shiftsProvider) {
    final shift = shiftsProvider.currentShift!;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    return FutureBuilder<double>(
      future: shiftsProvider.calculateExpectedCash(),
      builder: (context, snapshot) {
        final expectedCash = snapshot.data ?? 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الوردية رقم #${shift.id} نشطة حالياً', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('الموظف: ${shift.userName} | الافتتاحي: ${shift.openingCash.toStringAsFixed(0)} $currencySym'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cash Drawer metrics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الكاش المتوقع بالدرج:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${expectedCash.toStringAsFixed(0)} $currencySym',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons: Cash In, Cash Out, Close Shift Z-Report
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCashTxDialog(context, 'IN'),
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    label: const Text('إيداع نقدية'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCashTxDialog(context, 'OUT'),
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    label: const Text('سحب / مصروفات'),
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showCloseShiftDialog(context, expectedCash),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.lock),
                label: const Text('إغلاق الوردية وإصدار Z-Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCashTxDialog(BuildContext context, String type) {
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(type == 'IN' ? 'إيداع نقدية في الخزينة' : 'سحب نقدية / مصروفات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'المبلغ ($currencySym)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'سبب الإيداع / المصروفات'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                final reason = reasonController.text.trim();
                if (amount <= 0 || reason.isEmpty) return;

                await context.read<ShiftsProvider>().addCashTransaction(
                      type: type,
                      amount: amount,
                      reason: reason,
                    );
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseShiftDialog(BuildContext context, double expectedCash) async {
    final tablesProvider = context.read<TablesProvider>();
    final ordersProvider = context.read<OrdersProvider>();
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
                '🚫 لا يمكن إغلاق الوردية!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لا يمكن تصفية وإغلاق الوردية لأن هناك طاولات مشغولة لم يتم تسديد فواتيرها بعد!\n\nيرجى إتمام دفع وتسديد فواتير جميع الطاولات أولاً قبل توليد تقرير Z-Report.',
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

    if (!context.mounted) return;
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final actualCashController = TextEditingController(text: expectedCash.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('مطابقة الخزينة وإغلاق الوردية (Z-Report)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الكاش المتوقع بالحسابات: ${expectedCash.toStringAsFixed(0)} $currencySym'),
              const SizedBox(height: 12),
              TextField(
                controller: actualCashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكاش الفعلي المحسوب في الدرج',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final actual = double.tryParse(actualCashController.text.trim()) ?? 0.0;
                await context.read<ShiftsProvider>().closeShift(actual);
                if (context.mounted) {
                  Navigator.pop(ctx); // pop close shift dialog
                  Navigator.pop(context); // pop main shift dialog
                }
              },
              child: const Text('إغلاق وتوليد Z-Report'),
            ),
          ],
        );
      },
    );
  }
}
