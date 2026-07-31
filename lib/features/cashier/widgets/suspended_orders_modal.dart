import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../orders/orders_provider.dart';
import '../../settings/settings_provider.dart';

class SuspendedOrdersModal extends StatelessWidget {
  final Function(OrderModel order, List<OrderItemModel> items) onResumeOrder;

  const SuspendedOrdersModal({
    super.key,
    required this.onResumeOrder,
  });

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final suspended = ordersProvider.suspendedOrders;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.pause_circle_filled, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('الطلبات المعلقة (Held Orders)', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: suspended.isEmpty
            ? const Center(
                child: Text('لا توجد طلبات معلقة حالياً', style: TextStyle(fontSize: 18, color: Colors.grey)),
              )
            : ListView.separated(
                itemCount: suspended.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final order = suspended[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.receipt, color: Colors.white),
                    ),
                    title: Text(
                      'طلب معلق #${order.id} ${order.customerName != null ? "(${order.customerName})" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('تاريخ التعليق: ${_formatDate(order.createdAt)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${order.total.toStringAsFixed(0)} $currencySymbol',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final items = await ordersProvider.getOrderItems(order.id!);
                            onResumeOrder(order, items);
                            await ordersProvider.deleteOrder(order.id!);
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('استرجاع'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await ordersProvider.deleteOrder(order.id!);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
