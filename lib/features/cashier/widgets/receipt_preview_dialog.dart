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

            const SizedBox(height: 10),

            // 3. INVOICE META & ORDER TYPE & SEPARATE DATE / TIME LINES IN ROUNDED BOXES
            // Box 1: Order # & Table/Customer
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        widget.tableName != null && widget.tableName!.isNotEmpty
                            ? 'طاولة: ${widget.tableName!.startsWith("طاولة") ? widget.tableName!.replaceFirst("طاولة", "").trim() : widget.tableName}'
                            : 'الطلب: ${_orderTypeLabel(widget.order.orderType)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.black87),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        'رقم: ${widget.order.id ?? 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Box 2: Date & Time
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        'الوقت: ${_formatTimeOnly(widget.order.createdAt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.black87),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Text(
                        'التاريخ: ${_formatDateOnly(widget.order.createdAt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Box 3: Cashier Name
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'الكاشير: ${widget.order.cashierName != null && widget.order.cashierName!.isNotEmpty ? widget.order.cashierName! : 'الرئيسي'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

            // Delivery Customer Phone & Address
            if (widget.order.orderType == 'DELIVERY' || (widget.order.customerPhone != null && widget.order.customerPhone!.isNotEmpty)) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
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

            const SizedBox(height: 4),

            // ITEMS TABLE GRID WITH CELL BORDER LINES
            Table(
              border: TableBorder.all(color: Colors.black87, width: 1),
              columnWidths: const {
                0: FixedColumnWidth(24), // ت
                1: FlexColumnWidth(3.5), // المادة
                2: FixedColumnWidth(36), // الكمية
                3: FixedColumnWidth(55), // السعر
                4: FixedColumnWidth(60), // القيمة
              },
              children: [
                // Header Row
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFEEEEEE)),
                  children: [
                    Padding(padding: EdgeInsets.all(4), child: Text('ت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(4), child: Text('المادة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(4), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(4), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    Padding(padding: EdgeInsets.all(4), child: Text('القيمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                  ],
                ),

                // Item Rows
                ...widget.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(4), child: Text('$idx', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(4), child: Text(item.productName ?? 'صنف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                      Padding(padding: const EdgeInsets.all(4), child: Text(item.formattedQuantity, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(4), child: Text(item.price.toStringAsFixed(0), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                      Padding(padding: const EdgeInsets.all(4), child: Text(item.subtotal.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    ],
                  );
                }),

                // Table Summary Row (Total Items Count)
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
                  children: [
                    const Padding(padding: EdgeInsets.all(4), child: Text('')),
                    const Padding(padding: EdgeInsets.all(4), child: Text('مجموع عدد المواد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        widget.items.fold<double>(0, (sum, i) => sum + i.quantity).toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Padding(padding: EdgeInsets.all(4), child: Text('')),
                    const Padding(padding: EdgeInsets.all(4), child: Text('')),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // FINANCIAL SUMMARY IN ROUNDED BOXES
            if (widget.order.discountAmount > 0 || (widget.order.subtotal > widget.order.total && widget.order.subtotal > 0)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المجموع قبل الخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${(widget.order.subtotal > 0 ? widget.order.subtotal : (widget.order.total + widget.order.discountAmount)).toStringAsFixed(0)} ${settings.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مبلغ الخصم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('-${widget.order.discountAmount.toStringAsFixed(0)} ${settings.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],

            // Main Net Total Box (الصافي)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الصافي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${widget.order.total.toStringAsFixed(0)} ${settings.currencySymbol}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),

            if (widget.order.paymentMethod == 'CASH' && widget.cashPaid > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المدفوع كاش:', style: TextStyle(fontSize: 13)),
                    Text('${widget.cashPaid.toStringAsFixed(0)} ${settings.currencySymbol}', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المتبقي (الباقي):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${widget.changeDue.toStringAsFixed(0)} ${settings.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // FOOTER
            Text(
              settings.receiptFooter,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${settings.storeName} ${settings.storeAddress.isNotEmpty ? "- ${settings.storeAddress}" : ""}',
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
                        child: Text(item.productName ?? 'صنف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
