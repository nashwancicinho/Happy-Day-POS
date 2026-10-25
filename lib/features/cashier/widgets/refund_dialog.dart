import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/top_notification.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../orders/orders_provider.dart';
import '../../products/products_provider.dart';
import '../../settings/settings_provider.dart';
import '../../tables/tables_provider.dart';

class RefundDialog extends StatefulWidget {
  const RefundDialog({super.key});

  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, List<OrderItemModel>> _orderItemsMap = {};
  final Set<int> _expandedOrderIds = {};
  bool _isLoadingItems = false;
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedOrders() async {
    final tablesProvider = context.read<TablesProvider>();
    final ordersProvider = context.read<OrdersProvider>();
    await tablesProvider.loadTables();
    await ordersProvider.loadOrders();

    final completedOrders = ordersProvider.orders.where((o) => o.status == 'COMPLETED').toList();

    if (!mounted) return;
    setState(() {
      _isLoadingItems = true;
    });

    _orderItemsMap.clear();

    for (final order in completedOrders) {
      if (order.id != null) {
        final items = await ordersProvider.getOrderItems(order.id!);
        _orderItemsMap[order.id!] = items;
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingItems = false;
      });
    }
  }

  String _getOrderTypeLabel(OrderModel order, TablesProvider tablesProvider) {
    if (order.orderType == 'DINE_IN') {
      if (order.tableId != null) {
        final table = tablesProvider.getTableById(order.tableId!);
        if (table != null) {
          final tName = table.name.trim();
          return tName.startsWith('طاولة') ? tName : 'طاولة $tName';
        }
        return 'طاولة #${order.tableId}';
      }
      return 'طاولة صالة';
    } else if (order.orderType == 'DELIVERY') {
      return 'توصيل';
    } else {
      return 'سفري';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final tablesProvider = context.watch<TablesProvider>();
    final settings = context.watch<SettingsProvider>();
    final completedOrders = ordersProvider.orders.where((o) => o.status == 'COMPLETED').toList();

    // Search and Date Filtering: Order ID, Table Name/Number, Date, Payment Method, Product Name or Barcode
    final filteredOrders = completedOrders.where((order) {
      // 1. Date filter (if active)
      if (_selectedDate != null) {
        try {
          final dt = DateTime.parse(order.createdAt);
          if (dt.year != _selectedDate!.year ||
              dt.month != _selectedDate!.month ||
              dt.day != _selectedDate!.day) {
            return false;
          }
        } catch (_) {
          return false;
        }
      }

      // 2. Text Search Query
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final cleanQ = q.replaceAll('#', '').trim();

      // Search by Order ID (exact or partial, e.g. 171, #171)
      final orderIdStr = order.id.toString();
      if (orderIdStr.contains(cleanQ) || '#$orderIdStr'.contains(q)) return true;

      // Search by Table Name or Table Number
      if (order.tableId != null) {
        final table = tablesProvider.getTableById(order.tableId!);
        if (table != null) {
          final tName = table.name.toLowerCase().trim();
          if (tName.contains(q)) return true;
          // Match digits if user typed just the table number (e.g. "5" for "طاولة 5")
          final digits = tName.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.isNotEmpty && (digits == cleanQ || digits.contains(cleanQ))) return true;
        }
        if (order.tableId.toString() == cleanQ) return true;
      }

      // Search by Date as text (e.g. 2026-10-23 or 10-23)
      if (order.createdAt.contains(q)) return true;
      if (order.businessDate != null && order.businessDate!.contains(q)) return true;

      // Search by Order Type & Payment Method
      final typeLabel = _getOrderTypeLabel(order, tablesProvider).toLowerCase();
      if (typeLabel.contains(q)) return true;
      if (order.orderType.toLowerCase().contains(q)) return true;
      if (order.paymentMethod.toLowerCase().contains(q)) return true;
      if (order.paymentMethod == 'CASH' && ('كاش'.contains(q) || 'نقداً'.contains(q) || 'نقد'.contains(q))) return true;
      if (order.paymentMethod == 'CREDIT' && ('دين'.contains(q) || 'آجل'.contains(q))) return true;

      // Search inside items for Product Name or Barcode
      final items = _orderItemsMap[order.id] ?? [];
      for (final item in items) {
        if (item.productName != null && item.productName!.toLowerCase().contains(q)) return true;
      }

      return false;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isTodaySelected = _selectedDate != null &&
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterdaySelected = _selectedDate != null &&
        _selectedDate!.year == yesterday.year &&
        _selectedDate!.month == yesterday.month &&
        _selectedDate!.day == yesterday.day;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDark ? const Color(0xFF3B1E1E) : Colors.red.shade100,
            child: Icon(Icons.assignment_return_rounded, color: isDark ? Colors.red.shade300 : Colors.red, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة استرجاع الفواتير والمواد (Sales Refund)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'عند الاسترجاع يتم إعادة الكميات للمخزن تلقائياً وتحديث إجمالي الوارد اليومي',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 880,
        height: 570,
        child: Column(
          children: [
            // Search & Filter Bar Row
            Row(
              children: [
                // Search Input Field (Invoice ID, Table Number, Date, Product Name)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'ابحث برقم الفاتورة، رقم الطاولة، التاريخ، أو اسم الصنف... 🔍',
                      hintText: 'اكتب رقم الفاتورة (#171) أو الطاولة (طاولة 5) أو التاريخ (2026-10-23)...',
                      prefixIcon: const Icon(Icons.search, color: Colors.red),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C394B) : Colors.red.shade50.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Calendar Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _selectedDate != null ? Colors.red.shade700 : (isDark ? const Color(0xFF2C394B) : Colors.grey.shade100),
                    foregroundColor: _selectedDate != null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    side: BorderSide(
                      color: _selectedDate != null ? Colors.red.shade700 : (isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  icon: Icon(
                    Icons.calendar_month,
                    size: 18,
                    color: _selectedDate != null ? Colors.white : (isDark ? Colors.red.shade300 : Colors.red),
                  ),
                  label: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                        : 'اختر التاريخ 📅',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _pickDate,
                ),
                if (_selectedDate != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 22),
                    tooltip: 'إلغاء تصفية التاريخ',
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Quick Filter Chips Row
            Row(
              children: [
                ChoiceChip(
                  label: const Text('كل التواريخ', style: TextStyle(fontSize: 11)),
                  selected: _selectedDate == null,
                  onSelected: (val) {
                    if (val) setState(() => _selectedDate = null);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('اليوم', style: TextStyle(fontSize: 11)),
                  selected: isTodaySelected,
                  onSelected: (val) {
                    setState(() => _selectedDate = val ? DateTime(now.year, now.month, now.day) : null);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('أمس', style: TextStyle(fontSize: 11)),
                  selected: isYesterdaySelected,
                  onSelected: (val) {
                    setState(() => _selectedDate = val ? DateTime(yesterday.year, yesterday.month, yesterday.day) : null);
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'العدد: ${filteredOrders.length} فاتورة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Orders List Body
            Expanded(
              child: _isLoadingItems
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.red),
                          SizedBox(height: 12),
                          Text('جاري تحميل سجل المبيعات والمنتجات...'),
                        ],
                      ),
                    )
                  : filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isEmpty && _selectedDate == null
                                    ? 'لا توجد فواتير مبيعات مكتملة حالياً'
                                    : 'لم يتم العثور على فواتير مطابقة للبحث',
                                style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (ctx, index) {
                            final order = filteredOrders[index];
                            final isExpanded = _expandedOrderIds.contains(order.id);
                            final items = _orderItemsMap[order.id] ?? [];

                            String dateStr = order.createdAt;
                            try {
                              final dt = DateTime.parse(order.createdAt);
                              dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            } catch (_) {}

                            final typeLabel = _getOrderTypeLabel(order, tablesProvider);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  // Order Header Tile
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedOrderIds.remove(order.id);
                                        } else {
                                          _expandedOrderIds.add(order.id!);
                                        }
                                      });
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: order.paymentMethod == 'CREDIT' ? Colors.orange.shade100 : Colors.green.shade100,
                                      child: Icon(
                                        order.paymentMethod == 'CREDIT' ? Icons.account_balance_wallet : Icons.payments,
                                        color: order.paymentMethod == 'CREDIT' ? Colors.orange.shade900 : Colors.green.shade900,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          'فاتورة #${order.id}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: order.orderType == 'DINE_IN'
                                                ? Colors.purple.withValues(alpha: 0.12)
                                                : order.orderType == 'DELIVERY'
                                                    ? Colors.blue.withValues(alpha: 0.12)
                                                    : AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: order.orderType == 'DINE_IN'
                                                  ? (isDark ? Colors.purple.shade400 : Colors.purple.shade300)
                                                  : order.orderType == 'DELIVERY'
                                                      ? (isDark ? Colors.blue.shade400 : Colors.blue.shade300)
                                                      : (isDark ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.4)),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                order.orderType == 'DINE_IN'
                                                    ? Icons.table_restaurant
                                                    : order.orderType == 'DELIVERY'
                                                        ? Icons.delivery_dining
                                                        : Icons.takeout_dining,
                                                size: 14,
                                                color: order.orderType == 'DINE_IN'
                                                    ? (isDark ? Colors.purple.shade200 : Colors.purple.shade800)
                                                    : order.orderType == 'DELIVERY'
                                                        ? (isDark ? Colors.blue.shade200 : Colors.blue.shade800)
                                                        : AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                typeLabel,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: order.orderType == 'DINE_IN'
                                                      ? (isDark ? Colors.purple.shade200 : Colors.purple.shade800)
                                                      : order.orderType == 'DELIVERY'
                                                          ? (isDark ? Colors.blue.shade200 : Colors.blue.shade800)
                                                          : AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'التاريخ: $dateStr | طريقة الدفع: ${order.paymentMethod == 'CASH' ? 'نقداً (كاش)' : order.paymentMethod == 'CREDIT' ? 'بالآجل (دين)' : 'شبكة/بطاقة'}',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${order.total.toStringAsFixed(0)} ${settings.currencySymbol}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.replay_rounded, size: 16),
                                          label: const Text('استرجاع الفاتورة كلياً', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _confirmFullRefund(context, order),
                                        ),
                                        IconButton(
                                          icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                                          onPressed: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedOrderIds.remove(order.id);
                                              } else {
                                                _expandedOrderIds.add(order.id!);
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Expanded Order Items Table
                                  if (isExpanded) ...[
                                    const Divider(height: 1),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'محتويات الفاتورة (يمكنك استرجاع صنف محدد بشكل منفصل):',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                                          ),
                                          const SizedBox(height: 8),
                                          ...items.map((item) {
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF242F3E) : Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      item.productName ?? 'صنف #${item.productId}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'الكمية: ${item.formattedQuantity}',
                                                      style: const TextStyle(fontSize: 12),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'الإجمالي: ${item.subtotal.toStringAsFixed(0)} ${settings.currencySymbol}',
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red.shade800,
                                                    ),
                                                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                                                    label: const Text('استرجاع هذا الصنف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                    onPressed: () => _confirmItemRefund(context, order, item),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق الشاشة'),
        ),
      ],
    );
  }

  Future<void> _confirmFullRefund(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('تأكيد استرجاع كامل الفاتورة #${order.id}'),
          ],
        ),
        content: Text(
          'هل أنت تأكد من استرجاع كامل الفاتورة بقيمة (${order.total.toStringAsFixed(0)}) ؟\n\n'
          '• سيتم زيادة كميات المواد بالمخزن فوراً.\n'
          '• سيتم خصم هذا المبلغ من إجمالي مبيعات والوارد اليومي.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، استرجاع الكلي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ordersProvider = context.read<OrdersProvider>();
      final productsProvider = context.read<ProductsProvider>();
      final tablesProvider = context.read<TablesProvider>();

      final success = await ordersProvider.refundFullOrder(order.id!);
      if (success) {
        await productsProvider.loadProducts();
        await tablesProvider.loadTables();

        if (context.mounted) {
          TopNotification.showSuccess(
            context,
            '🎉 تم استرجاع الفاتورة #${order.id} بالكامل، وإعادة المخزن وتحديث الوارد اليومي بنجاح!',
          );
          _loadCompletedOrders();
        }
      } else {
        if (context.mounted) {
          TopNotification.showWarning(context, '⚠️ تعذر استرجاع الفاتورة. قد تكون مسترجعة سابقاً.');
        }
      }
    }
  }

  Future<void> _confirmItemRefund(BuildContext context, OrderModel order, OrderItemModel item) async {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('استرجاع صنف (${item.productName ?? "الصنف"})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية المشتراة في الفاتورة: ${item.formattedQuantity}'),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الكمية المراد استرجاعها *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الاسترجاع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final refundQty = double.tryParse(qtyController.text.trim()) ?? 1.0;
      if (refundQty <= 0) return;

      final ordersProvider = context.read<OrdersProvider>();
      final productsProvider = context.read<ProductsProvider>();
      final tablesProvider = context.read<TablesProvider>();

      final success = await ordersProvider.refundOrderItem(
        orderId: order.id!,
        orderItemId: item.id!,
        refundQuantity: refundQty,
      );

      if (success) {
        await productsProvider.loadProducts();
        await tablesProvider.loadTables();

        if (context.mounted) {
          TopNotification.showSuccess(
            context,
            '🎉 تم استرجاع $refundQty من (${item.productName}) وإعادة الكمية للمخزن وتعديل الفاتورة بنجاح!',
          );
          _loadCompletedOrders();
        }
      }
    }
  }
}
