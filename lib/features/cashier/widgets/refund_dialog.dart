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
    final ordersProvider = context.read<OrdersProvider>();
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

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final settings = context.watch<SettingsProvider>();
    final completedOrders = ordersProvider.orders.where((o) => o.status == 'COMPLETED').toList();

    // Search Filtering: Order ID, Customer Phone, Payment Method, Product Name or Product Barcode
    final filteredOrders = completedOrders.where((order) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();

      // Search by Order ID
      if (order.id.toString() == q || '#${order.id}' == q) return true;

      // Search by Payment Method or Type
      if (order.paymentMethod.toLowerCase().contains(q)) return true;
      if (order.orderType.toLowerCase().contains(q)) return true;

      // Search inside items for Product Name or Barcode
      final items = _orderItemsMap[order.id] ?? [];
      for (final item in items) {
        if (item.productName != null && item.productName!.toLowerCase().contains(q)) return true;
      }

      return false;
    }).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: const Icon(Icons.assignment_return_rounded, color: Colors.red, size: 26),
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
        width: 850,
        height: 550,
        child: Column(
          children: [
            // Search Input Field (Barcode or Invoice ID or Item Name)
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'ابحث برقم الفاتورة، الباركود، أو اسم الصنف... 🔍',
                hintText: 'امسح باركود الفاتورة أو اكتب #12 او اسم المنتج...',
                prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.red),
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
                fillColor: Colors.red.shade50.withValues(alpha: 0.3),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 12),

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
                                _searchQuery.isEmpty ? 'لا توجد فواتير مبيعات مكتملة حالياً' : 'لم يتم العثور على فواتير مطابقة للبحث "$_searchQuery"',
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

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade300),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            order.orderType == 'DINE_IN'
                                                ? 'طاولة (${order.tableId ?? ''})'
                                                : order.orderType == 'DELIVERY'
                                                    ? 'توصيل'
                                                    : 'سفري',
                                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'التاريخ: $dateStr | طريقة الدفع: ${order.paymentMethod == 'CASH' ? 'نقداً (كاش)' : order.paymentMethod == 'CREDIT' ? 'بالآجل (دين)' : 'شبكة/بطاقة'}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                                      color: Colors.grey.shade50,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'محتويات الفاتورة (يمكنك استرجاع صنف محدد بشكل منفصل):',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 8),
                                          ...items.map((item) {
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade200),
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
