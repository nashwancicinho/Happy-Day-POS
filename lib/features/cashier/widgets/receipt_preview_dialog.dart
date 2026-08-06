import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../../core/services/print_service.dart';
import '../../settings/settings_provider.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  final OrderModel order;
  final List<OrderItemModel> items;
  final String? tableName;
  final double cashPaid;
  final double changeDue;

  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.items,
    this.tableName,
    this.cashPaid = 0.0,
    this.changeDue = 0.0,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getLogoIconData(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'fastfood':
        return Icons.fastfood;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'cake':
        return Icons.cake;
      case 'dinner_dining':
        return Icons.dinner_dining;
      case 'storefront':
      default:
        return Icons.storefront_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(icon: Icon(Icons.receipt_long), text: 'فاتورة الزبون (Receipt)'),
          Tab(icon: Icon(Icons.soup_kitchen), text: 'وصل المطبخ (KOT)'),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 560,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCustomerReceipt(settingsProvider),
            _buildKitchenTicket(),
          ],
        ),
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            if (_tabController.index == 0) {
              await PrintService.printCustomerReceipt(
                order: widget.order,
                items: widget.items,
                settings: settingsProvider,
                tableName: widget.tableName,
                cashPaid: widget.cashPaid,
                changeDue: widget.changeDue,
              );
            } else {
              await PrintService.printKitchenTicket(
                order: widget.order,
                items: widget.items,
                settings: settingsProvider,
                tableName: widget.tableName,
              );
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.print),
          label: const Text('طباعة وإغلاق'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildCustomerReceipt(SettingsProvider settings) {
    final logoIconName = settings.settings['store_logo_icon'] ?? 'storefront';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. TOP LOGO (Custom Image or Preset Icon)
            if (settings.storeLogoPath.isNotEmpty && File(settings.storeLogoPath).existsSync())
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(settings.storeLogoPath),
                    height: 145,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getLogoIconData(logoIconName),
                  size: 72,
                  color: AppColors.primary,
                ),
              ),
            const SizedBox(height: 8),

            // 2. STORE NAME, ADDRESS, PHONE
            Text(
              settings.storeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (settings.storeAddress.isNotEmpty)
              Text(
                settings.storeAddress,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.storePhone.isNotEmpty)
              Text(
                settings.storePhone,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.receiptHeader.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  settings.receiptHeader,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),

            const Divider(thickness: 1.5, color: Colors.black87),

            // 3. INVOICE META & ORDER TYPE & SEPARATE DATE / TIME LINES
            if (widget.order.orderType == 'DINE_IN' && widget.tableName != null) ...[
              Text(
                'طاولة: ${widget.tableName!.startsWith("طاولة") ? widget.tableName!.replaceFirst("طاولة", "").trim() : widget.tableName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                'نوع الطلب: ${_orderTypeLabel(widget.order.orderType)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'التاريخ: ${_formatDateOnly(widget.order.createdAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            Text(
              'الوقت: ${_formatTimeOnly(widget.order.createdAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),

            // Delivery Customer Phone & Address
            if (widget.order.orderType == 'DELIVERY' || (widget.order.customerPhone != null && widget.order.customerPhone!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.two_wheeler, size: 18, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          'بيانات توصيل الطلب للزبون:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📞 رقم الموبايل: ${widget.order.customerPhone ?? "غير محدد"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    if (widget.order.customerAddress != null && widget.order.customerAddress!.isNotEmpty)
                      Text(
                        '📍 عنوان التوصيل: ${widget.order.customerAddress}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],

            const Divider(thickness: 1.5, color: Colors.black87),

            // ITEMS TABLE HEADER
            Row(
              children: const [
                Expanded(flex: 6, child: Text('الصنف / المادة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('المجموع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.end)),
              ],
            ),
            const Divider(height: 8),

            // ITEMS ROWS
            ...widget.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName ?? 'صنف', style: const TextStyle(fontSize: 12)),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text('ملاحظة: ${item.notes}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(item.formattedQuantity, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${item.subtotal.toStringAsFixed(0)} ${settings.currencySymbol}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(thickness: 1.5, color: Colors.black87),

            // FINANCIAL SUMMARY
            if (widget.order.discountAmount > 0 || (widget.order.subtotal > widget.order.total && widget.order.subtotal > 0)) ...[
              _receiptSumRow(
                'المجموع:',
                '${(widget.order.subtotal > 0 ? widget.order.subtotal : (widget.order.total + widget.order.discountAmount)).toStringAsFixed(0)} ${settings.currencySymbol}',
              ),
              _receiptSumRow(
                'الخصم:',
                '-${widget.order.discountAmount.toStringAsFixed(0)} ${settings.currencySymbol}',
              ),
              if (widget.order.taxAmount > 0)
                _receiptSumRow(
                  'الضريبة:',
                  '+${widget.order.taxAmount.toStringAsFixed(0)} ${settings.currencySymbol}',
                ),
              const Divider(height: 10),
              _receiptSumRow(
                'الصافي:',
                '${widget.order.total.toStringAsFixed(0)} ${settings.currencySymbol}',
                isBold: true,
                fontSize: 15,
              ),
            ] else ...[
              _receiptSumRow(
                'الإجمالي الكلي:',
                '${widget.order.total.toStringAsFixed(0)} ${settings.currencySymbol}',
                isBold: true,
                fontSize: 15,
              ),
            ],

            if (widget.order.paymentMethod == 'CASH' && widget.cashPaid > 0) ...[
              const SizedBox(height: 4),
              _receiptSumRow('المدفوع كاش:', '${widget.cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}'),
              _receiptSumRow('المتبقي (الباقي):', '${widget.changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', isBold: true),
            ],

            const Divider(thickness: 1.5, color: Colors.black87),
            const SizedBox(height: 8),

            // FOOTER (FOOTER MSG + STORE NAME + ADDRESS + PHONE)
            Text(
              settings.receiptFooter,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${settings.storeName} - ${settings.storeAddress}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            if (settings.storePhone.isNotEmpty)
              Text(
                'هاتف المطعم: ${settings.storePhone}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              '${widget.order.id ?? 1}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenTicket() {
    final kitchenItems = widget.items.where((item) => item.printToKitchen).toList();

    return Container(
      color: Colors.yellow.shade50,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              '*** تذكرة المطبخ (KOT) ***',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              'نوع الطلب: ${_orderTypeLabel(widget.order.orderType)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.order.orderType == 'DINE_IN' && widget.tableName != null)
              Text('رقم الطاولة: ${widget.tableName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange)),
            if (widget.order.orderType == 'DELIVERY' && widget.order.customerPhone != null)
              Text('موبايل الزبون: ${widget.order.customerPhone}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('تاريخ الطلب: ${_formatFullDateTime(widget.order.createdAt)}', style: const TextStyle(fontSize: 12)),
            const Divider(thickness: 2, color: Colors.black),

            if (kitchenItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '⚠️ لا توجد أصناف مخصصة للطباعة إلى طابعة المطبخ في هذا الطلب.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...kitchenItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('[ ${item.formattedQuantity} × ] ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName ?? 'صنف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('ملاحظة المطبخ: ${item.notes}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _receiptSumRow(String label, String value, {bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
        ],
      ),
    );
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'DINE_IN':
        return 'طاولة';
      case 'TAKEAWAY':
        return 'سفري';
      case 'DELIVERY':
        return 'توصيل دليفري';
      default:
        return type;
    }
  }



  String _formatDateOnly(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final year = dt.year;
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    } catch (_) {
      return isoString.split('T').first;
    }
  }

  String _formatTimeOnly(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    } catch (_) {
      final parts = isoString.split('T');
      return parts.length > 1 ? parts.last.split('.').first : '';
    }
  }

  String _formatFullDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final year = dt.year;
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$year/$month/$day $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }
}
