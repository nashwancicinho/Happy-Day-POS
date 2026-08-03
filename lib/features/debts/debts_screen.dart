import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/top_notification.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../auth/auth_provider.dart';
import '../customers/customers_provider.dart';
import '../orders/orders_provider.dart';
import '../settings/settings_provider.dart';
import '../treasury/treasury_provider.dart';

class _GroupedDebtor {
  final String name;
  final String? phone;
  final List<OrderModel> orders;
  final double totalDebt;

  _GroupedDebtor({
    required this.name,
    this.phone,
    required this.orders,
    required this.totalDebt,
  });
}

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrdersProvider>().loadOrders();
        context.read<CustomersProvider>().loadCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    // 1. Filter Unpaid Credit Orders
    final creditOrders = ordersProvider.orders.where((o) => o.status == 'CREDIT').toList();

    // 2. Group Unpaid Credit Orders by Debtor Name
    final Map<String, List<OrderModel>> groupedMap = {};
    for (final order in creditOrders) {
      final rawTitle = (order.notes ?? order.customerName ?? (isEng ? 'Unnamed Customer' : 'زبون غير مسمى')).trim();
      groupedMap.putIfAbsent(rawTitle, () => []).add(order);
    }

    final List<_GroupedDebtor> groupedDebtors = groupedMap.entries.map((entry) {
      final orders = entry.value;
      final name = entry.key;
      final phone = orders.firstWhere(
        (o) => o.customerPhone != null && o.customerPhone!.isNotEmpty,
        orElse: () => orders.first,
      ).customerPhone;
      final totalDebt = orders.fold(0.0, (sum, o) => sum + o.total);
      return _GroupedDebtor(name: name, phone: phone, orders: orders, totalDebt: totalDebt);
    }).toList();

    // 3. Filter Grouped Debtors by Search Query
    final filteredDebtors = groupedDebtors.where((d) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      final nameMatch = d.name.toLowerCase().contains(query);
      final phoneMatch = d.phone != null && d.phone!.toLowerCase().contains(query);
      return nameMatch || phoneMatch;
    }).toList();

    final totalUnpaidDebt = creditOrders.fold(0.0, (sum, o) => sum + o.total);
    final totalDebtorsCount = groupedDebtors.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Customer Debts & Credit Management' : 'إدارة الديون والآجل (سداد ومتابعة الديون)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: isEng ? 'Total Outstanding Debts' : 'إجمالي الديون القائمة',
                    value: '${totalUnpaidDebt.toStringAsFixed(0)} $currencySym',
                    subtitle: isEng ? 'Uncollected revenue amounts' : 'مبالغ غير مضافة للوارد اليومي بعد',
                    icon: Icons.request_quote_rounded,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: isEng ? 'Total Debtors Count' : 'عدد الأشخاص المطلوبة',
                    value: isEng ? '$totalDebtorsCount Debtors' : '$totalDebtorsCount مدينين',
                    subtitle: isEng ? 'Unique customer debtors' : 'عملاء بدون تكرار في القائمة',
                    icon: Icons.people_outline_rounded,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: isEng ? 'Search debtor name or phone...' : 'ابحث باسم المطلوب أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Debts List (Grouped by Customer)
            Expanded(
              child: filteredDebtors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? (isEng ? 'No search results matching "$_searchQuery"' : 'لا توجد نتائج بحث لمطابقة "$_searchQuery"')
                                : (isEng ? 'Great! No outstanding customer debts currently 🎉' : 'ممتاز! لا توجد أي ديون غير مسددة حالياً 🎉'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDebtors.length,
                      itemBuilder: (context, index) {
                        final debtor = filteredDebtors[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Info & Total Debt Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.red.shade100,
                                            child: Icon(Icons.person, color: Colors.red.shade800, size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      debtor.name,
                                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                                    ),
                                                    if (context.watch<AuthProvider>().isManager) ...[
                                                      const SizedBox(width: 6),
                                                      IconButton(
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                        tooltip: isEng ? 'Delete Customer (Manager Only)' : 'حذف هذا الزبون (للمدير فقط)',
                                                        onPressed: () => _confirmDeleteCustomer(context, debtor),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  debtor.phone != null && debtor.phone!.isNotEmpty
                                                      ? (isEng
                                                          ? 'Phone: ${debtor.phone} | Invoices: ${debtor.orders.length}'
                                                          : 'رقم الهاتف: ${debtor.phone} | عدد الفواتير: ${debtor.orders.length}')
                                                      : (isEng
                                                          ? 'Credit Invoices: ${debtor.orders.length}'
                                                          : 'عدد الفواتير الآجلة: ${debtor.orders.length} فاتورة'),
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            isEng ? 'Total Due:' : 'إجمالي المطلوب:',
                                            style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '${debtor.totalDebt.toStringAsFixed(0)} $currencySym',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 18),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),

                                // Settle All Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          isEng ? 'Status: Excluded from daily revenue until settled' : 'حالة المبلغ: غير مضاف للوارد اليومي حتى التسديد',
                                          style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _showDebtPaymentModal(context, debtor),
                                      icon: const Icon(Icons.payments_rounded, size: 18),
                                      label: Text(
                                        isEng
                                            ? '💵 Settle Full Debt (${debtor.totalDebt.toStringAsFixed(0)} $currencySym)'
                                            : '💵 سداد إجمالي الدين (${debtor.totalDebt.toStringAsFixed(0)} $currencySym)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),

                                // Invoices Breakdown Accordion
                                const SizedBox(height: 8),
                                Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(
                                      isEng
                                          ? 'View detailed invoices for this debt (${debtor.orders.length} Invoices)'
                                          : 'عرض الفواتير التفصيلية لهذه الذمة (${debtor.orders.length} فواتير)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                                    ),
                                    children: debtor.orders.map((order) {
                                      return Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isEng ? 'Invoice #${order.id} | ${_formatDate(order.createdAt)}' : 'فاتورة #${order.id} | ${_formatDate(order.createdAt)}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                                Text(
                                                  isEng ? 'Type: ${order.orderType} | Staff: ${order.cashierName}' : 'نوع الطلب: ${order.orderType} | المنفذ: ${order.cashierName}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${order.total.toStringAsFixed(0)} $currencySym',
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 14),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.green.shade800,
                                                    side: BorderSide(color: Colors.green.shade600),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () => _showDebtPaymentModal(context, debtor, specificOrder: order),
                                                  child: Text(isEng ? 'Settle Invoice' : 'سداد الفاتورة', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebtPaymentModal(BuildContext parentContext, _GroupedDebtor debtor, {OrderModel? specificOrder}) {
    final isEng = parentContext.read<SettingsProvider>().isEnglish;
    final currencySym = parentContext.read<SettingsProvider>().currencySymbol;
    final double targetTotal = specificOrder != null ? specificOrder.total : debtor.totalDebt;

    final TextEditingController amountController = TextEditingController(
      text: targetTotal.toStringAsFixed(0),
    );

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final double enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
            final double remainingDebt = (targetTotal - enteredAmount) < 0 ? 0.0 : (targetTotal - enteredAmount);
            final bool isPartial = enteredAmount > 0 && enteredAmount < targetTotal;
            final bool isValid = enteredAmount > 0 && enteredAmount <= targetTotal;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            specificOrder != null
                                ? (isEng ? 'Settle Invoice #${specificOrder.id} (${debtor.name})' : 'سداد فاتورة #${specificOrder.id} (${debtor.name})')
                                : (isEng ? 'Settle Debt (${debtor.name})' : 'سداد وتسديد ديون (${debtor.name})'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Debt Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isEng ? 'Total Recorded Debt:' : 'إجمالي الدين المسجل:', style: const TextStyle(fontSize: 11, color: Colors.red)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${targetTotal.toStringAsFixed(0)} $currencySym',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: remainingDebt > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: remainingDebt > 0 ? Colors.amber.shade300 : Colors.green.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    remainingDebt > 0
                                        ? (isEng ? 'Remaining as Debt:' : 'المتبقي كدين:')
                                        : (isEng ? 'Fully Settled:' : 'تم السداد بالكامل:'),
                                    style: TextStyle(fontSize: 11, color: remainingDebt > 0 ? Colors.amber.shade900 : Colors.green.shade900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${remainingDebt.toStringAsFixed(0)} $currencySym',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: remainingDebt > 0 ? Colors.amber.shade900 : Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Amount Input Field
                      Text(
                        isEng ? 'Enter amount to collect and pay now:' : 'أدخل المبلغ المراد تحصيله وتدفعه الآن:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                        decoration: InputDecoration(
                          hintText: isEng ? 'Enter amount...' : 'أدخل المبلغ...',
                          suffixText: currencySym,
                          suffixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                          prefixIcon: (currencySym == '\$' || currencySym.contains('\$'))
                              ? const Icon(Icons.attach_money_rounded, color: Colors.green, size: 28)
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  alignment: Alignment.centerLeft,
                                  width: 52,
                                  child: Text(
                                    currencySym,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                  ),
                                ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.green, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3. Quick Payment Shortcuts
                      Text(isEng ? 'Quick Amount Options:' : 'خيارات سريعة للمبلغ:', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(isEng ? 'Full Debt (${targetTotal.toStringAsFixed(0)} $currencySym)' : 'سداد كامل الدين (${targetTotal.toStringAsFixed(0)} $currencySym)'),
                            selected: enteredAmount == targetTotal,
                            selectedColor: Colors.green.shade100,
                            onSelected: (_) {
                              setDialogState(() {
                                amountController.text = targetTotal.toStringAsFixed(0);
                              });
                            },
                          ),
                          if (targetTotal > 1000)
                            ChoiceChip(
                              label: Text(isEng ? 'Half Amount (${(targetTotal / 2).toStringAsFixed(0)} $currencySym)' : 'نصف المبلغ (${(targetTotal / 2).toStringAsFixed(0)} $currencySym)'),
                              selected: enteredAmount == (targetTotal / 2),
                              selectedColor: Colors.green.shade100,
                              onSelected: (_) {
                                setDialogState(() {
                                  amountController.text = (targetTotal / 2).toStringAsFixed(0);
                                });
                              },
                            ),
                          ChoiceChip(
                            label: Text('10,000 $currencySym'),
                            selected: enteredAmount == 10000,
                            onSelected: (_) {
                              setDialogState(() {
                                amountController.text = '10000';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('25,000 $currencySym'),
                            selected: enteredAmount == 25000,
                            onSelected: (_) {
                              setDialogState(() {
                                amountController.text = '25000';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('50,000 $currencySym'),
                            selected: enteredAmount == 50000,
                            onSelected: (_) {
                              setDialogState(() {
                                amountController.text = '50000';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Status Notice
                      if (enteredAmount > targetTotal)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEng
                                      ? 'Entered amount is greater than recorded debt!'
                                      : 'المبلغ المدخل أكبر من الدين المسجل! يرجى إدخال مبلغ يساوي أو أقل من الدين المطلوب.',
                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isPartial)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEng
                                      ? 'Partial payment: ${enteredAmount.toStringAsFixed(0)} $currencySym will be credited to daily revenue, leaving ${remainingDebt.toStringAsFixed(0)} $currencySym due.'
                                      : 'سداد جزئي: سيتم سداد ${enteredAmount.toStringAsFixed(0)} $currencySym وتمريرها للوارد، ويبقى ${remainingDebt.toStringAsFixed(0)} $currencySym كذمة قائمة على الزبون.',
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? Colors.green.shade700 : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: !isValid
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);

                          final ordersProvider = parentContext.read<OrdersProvider>();
                          final customersProvider = parentContext.read<CustomersProvider>();
                          final treasuryProvider = parentContext.read<TreasuryProvider>();

                          final ordersToSettle = specificOrder != null ? [specificOrder] : debtor.orders;

                          // Execute partial or full settlement
                          await ordersProvider.settlePartialOrFullDebt(ordersToSettle, enteredAmount);
                          await treasuryProvider.loadTreasuryRecords();

                          // Update customer DB record
                          final custTitle = debtor.name.replaceAll(RegExp(r'\(.*\)'), '').replaceAll('دين على الزبون:', '').trim();
                          final cust = customersProvider.customers.firstWhere(
                            (c) => c.name.trim() == custTitle,
                            orElse: () => CustomerModel(name: ''),
                          );
                          if (cust.id != null) {
                            await customersProvider.payDebt(cust.id!, enteredAmount);
                          }

                          if (parentContext.mounted) {
                            TopNotification.showSuccess(
                              parentContext,
                              isEng
                                  ? '🎉 Collected (${enteredAmount.toStringAsFixed(0)} $currencySym) successfully and added to daily revenue!'
                                  : '🎉 تم تحصيل وتسديد مبلغ (${enteredAmount.toStringAsFixed(0)} $currencySym) بنجاح وإضافته للوارد والخزينة!',
                            );
                          }
                        },
                  icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                  label: Text(
                    isEng
                        ? 'Confirm & Collect (${enteredAmount.toStringAsFixed(0)} $currencySym)'
                        : 'تأكيد الدفع وتحصيل (${enteredAmount.toStringAsFixed(0)} $currencySym)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCustomer(BuildContext parentContext, _GroupedDebtor debtor) {
    final isEng = parentContext.read<SettingsProvider>().isEnglish;
    final currencySym = parentContext.read<SettingsProvider>().currencySymbol;

    if (debtor.totalDebt > 0) {
      showDialog(
        context: parentContext,
        builder: (blockContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 10),
              Text(
                isEng ? 'Warning: Cannot Delete Customer' : 'تنبيه: لا يمكن حذف الزبون',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEng
                    ? 'Cannot delete customer (${debtor.name}) because they have outstanding unpaid debts (${debtor.totalDebt.toStringAsFixed(0)} $currencySym).'
                    : 'لا يمكن حذف الزبون (${debtor.name}) لأن لديه ديون سابقة غير مسددة (${debtor.totalDebt.toStringAsFixed(0)} $currencySym).',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEng
                            ? 'Please collect and settle debts first before deleting customer.'
                            : 'يرجى تحصيل وتسديد الديون وإتاحة تصفير الحساب أولاً قبل حذف الزبون من النظام.',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () => Navigator.pop(blockContext),
              child: Text(isEng ? 'Got it' : 'حسناً، فهمت', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(isEng ? 'Confirm Delete Customer & Records' : 'تأكيد حذف الزبون وسجلاته', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEng
                  ? 'Are you sure you want to delete customer (${debtor.name}) and remove their account?'
                  : 'هل أنت متأكد من حذف الزبون (${debtor.name}) وإلغاء حسابه نهائياً من القائمة بالنظام؟',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEng ? 'Manager privileges only.' : 'صلاحية المدير فقط: سيتم إزالة الزبون وتصفية ذمته من قائمة أصحاب الديون.',
                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isEng ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final customersProvider = parentContext.read<CustomersProvider>();
              final ordersProvider = parentContext.read<OrdersProvider>();

              // Settle/Clear credit orders for this customer
              for (final order in debtor.orders) {
                await ordersProvider.settlePartialOrFullDebt([order], order.total);
              }

              final custTitle = debtor.name.replaceAll(RegExp(r'\(.*\)'), '').replaceAll('دين على الزبون:', '').trim();
              final cust = customersProvider.customers.firstWhere(
                (c) => c.name.trim() == custTitle,
                orElse: () => CustomerModel(name: ''),
              );
              if (cust.id != null) {
                await customersProvider.deleteCustomer(cust.id!);
              }

              if (parentContext.mounted) {
                TopNotification.showSuccess(
                  parentContext,
                  isEng ? '🎉 Customer (${debtor.name}) deleted successfully!' : '🎉 تم حذف الزبون (${debtor.name}) وإلغاء حسابه بنجاح!',
                );
              }
            },
            child: Text(isEng ? 'Delete Customer' : 'نعم، حذف الزبون نهائياً', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
