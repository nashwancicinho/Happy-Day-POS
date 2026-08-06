import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/print_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/customize_item_appearance_dialog.dart';
import '../../core/widgets/manager_auth_dialog.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/category.dart';
import '../../models/customer.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../models/restaurant_table.dart';
import '../auth/auth_provider.dart';
import '../categories/categories_provider.dart';
import '../customers/customers_provider.dart';
import '../orders/orders_provider.dart';
import '../products/products_provider.dart';
import '../settings/settings_provider.dart';
import '../shifts/shifts_provider.dart';
import '../tables/tables_provider.dart';
import 'widgets/refund_dialog.dart';



class CashierScreen extends StatefulWidget {
  final RestaurantTable? selectedTable;
  final String initialOrderType;

  const CashierScreen({
    super.key,
    this.selectedTable,
    this.initialOrderType = 'TAKEAWAY',
  });

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  late String _orderType;
  final List<OrderItemModel> _cart = [];
  int? _existingOrderId;
  bool _isLoadingTableOrder = false;
  double _discountAmount = 0.0;

  String get _currencySymbol => context.watch<SettingsProvider>().currencySymbol;

  @override
  void initState() {
    super.initState();
    _orderType = widget.selectedTable != null ? 'DINE_IN' : widget.initialOrderType;
    if (widget.selectedTable != null) {
      _loadTableOrder();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductsProvider>().selectCategory(null);
        context.read<ProductsProvider>().setSearchQuery('');
        context.read<CustomersProvider>().loadCustomers();
      }
    });
  }

  Future<void> _loadTableOrder() async {
    if (widget.selectedTable == null) return;
    setState(() => _isLoadingTableOrder = true);

    try {
      final ordersProvider = context.read<OrdersProvider>();
      final openOrder = await ordersProvider.getOpenOrderByTable(widget.selectedTable!.id!);

      if (openOrder != null) {
        _existingOrderId = openOrder.id;
        final items = await ordersProvider.getOrderItems(openOrder.id!);
        if (mounted) {
          setState(() {
            _cart.clear();
            _cart.addAll(items);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading table order: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTableOrder = false);
      }
    }
  }

  void _addToCart(ProductModel product) {
    if (!product.isAvailable) {
      TopNotification.showWarning(context, 'هذا الصنف غير متوفر حالياً');
      return;
    }

    if (product.trackStock && product.stockQuantity <= 0) {
      TopNotification.showWarning(context, '⚠️ تنبيه: مادة "${product.name}" نافدة من المخزن!');
      return;
    }

    if (product.isWeighted || product.allowPriceChange) {
      _showProductInputDialog(product);
      return;
    }

    _addItemToCartWithQtyAndPrice(
      product: product,
      quantity: 1.0,
      price: product.price,
    );
  }

  void _addItemToCartWithQtyAndPrice({
    required ProductModel product,
    required double quantity,
    required double price,
    String? notes,
  }) {
    setState(() {
      final index = _cart.indexWhere((item) => item.productId == product.id && item.price == price);
      if (index >= 0) {
        final existing = _cart[index];
        final newQty = existing.quantity + quantity;
        if (product.trackStock && newQty > product.stockQuantity) {
          TopNotification.showWarning(
            context,
            '⚠️ الكمية المطلوبة تتجاوز الكمية المتاحة بالمخزن (${product.stockQuantity.toStringAsFixed(0)} ${product.unit})!',
          );
        }
        _cart[index] = existing.copyWith(
          quantity: newQty,
          notes: notes ?? existing.notes,
        );
      } else {
        if (product.trackStock && quantity > product.stockQuantity) {
          TopNotification.showWarning(
            context,
            '⚠️ الكمية المطلوبة تتجاوز الكمية المتاحة بالمخزن (${product.stockQuantity.toStringAsFixed(0)} ${product.unit})!',
          );
        }
        _cart.add(OrderItemModel(
          productId: product.id!,
          productName: product.name,
          buyPrice: product.buyPrice,
          quantity: quantity,
          price: price,
          notes: notes,
          printToKitchen: product.printToKitchen,
          kitchenPrinter: product.kitchenPrinter,
        ));
      }
    });
  }

  Widget _buildNumpad({
    required TextEditingController controller,
    required VoidCallback onChanged,
    String unit = 'كيلوغرام',
    bool isPrice = false,
  }) {
    void appendChar(String char) {
      final current = controller.text;
      if (char == '.') {
        if (current.contains('.')) return;
        if (current.isEmpty) {
          controller.text = '0.';
        } else {
          controller.text = '$current.';
        }
      } else if (char == '000') {
        if (current.isEmpty || current == '0') return;
        controller.text = '${current}000';
      } else {
        if (current == '0') {
          controller.text = char;
        } else {
          controller.text = '$current$char';
        }
      }
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      onChanged();
    }

    void backspace() {
      final current = controller.text;
      if (current.isNotEmpty) {
        controller.text = current.substring(0, current.length - 1);
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
        onChanged();
      }
    }

    void clearAll() {
      controller.text = '';
      onChanged();
    }

    void setPreset(double val) {
      controller.text = (val % 1 == 0) ? val.toInt().toString() : val.toStringAsFixed(3).replaceAll(RegExp(r'([.]*0)(?!.*\d)'), '');
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      onChanged();
    }

    void addPrice(double addVal) {
      final current = double.tryParse(controller.text) ?? 0;
      final newVal = current + addVal;
      controller.text = newVal.toInt().toString();
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      onChanged();
    }

    Widget numBtn(String label, {VoidCallback? onTap, Color? bg, Color? fg, IconData? icon, double fontSize = 22}) {
      return Material(
        color: bg ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1.2),
            ),
            child: icon != null
                ? Icon(icon, color: fg ?? Colors.black87, size: 24)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: fg ?? Colors.black87,
                    ),
                  ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Presets Row
          if (!isPrice)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => setPreset(0.250),
                    child: const Text('0.250 ربع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => setPreset(0.500),
                    child: const Text('0.500 نصف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => setPreset(0.750),
                    child: const Text('0.750 ٣ أرباع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => setPreset(1.000),
                    child: const Text('1.000 كيلو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => addPrice(250),
                    child: const Text('+250', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => addPrice(500),
                    child: const Text('+500', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => addPrice(1000),
                    child: const Text('+1,000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => addPrice(5000),
                    child: const Text('+5,000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),

          // Row 1: 1 (Left), 2 (Middle), 3 (Right)
          Row(
            children: [
              Expanded(child: numBtn('1', onTap: () => appendChar('1'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('2', onTap: () => appendChar('2'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('3', onTap: () => appendChar('3'))),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: 4, 5, 6
          Row(
            children: [
              Expanded(child: numBtn('4', onTap: () => appendChar('4'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('5', onTap: () => appendChar('5'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('6', onTap: () => appendChar('6'))),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: 7, 8, 9
          Row(
            children: [
              Expanded(child: numBtn('7', onTap: () => appendChar('7'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('8', onTap: () => appendChar('8'))),
              const SizedBox(width: 6),
              Expanded(child: numBtn('9', onTap: () => appendChar('9'))),
            ],
          ),
          const SizedBox(height: 6),

          // Row 4 (Bottom): Left = تصفير | Middle = 0 & (. or 000) | Right = مسح ⌫
          Row(
            children: [
              // Left: تصفير
              Expanded(
                flex: 3,
                child: numBtn('تصفير', bg: Colors.red.shade50, fg: Colors.red.shade900, fontSize: 14, onTap: clearAll),
              ),
              const SizedBox(width: 6),
              // Middle: 0
              Expanded(
                flex: 3,
                child: numBtn('0', onTap: () => appendChar('0')),
              ),
              const SizedBox(width: 6),
              // Middle: . for weight OR 000 for price
              Expanded(
                flex: 2,
                child: numBtn(isPrice ? '000' : '.', fontSize: isPrice ? 13 : 22, onTap: () => appendChar(isPrice ? '000' : '.')),
              ),
              const SizedBox(width: 6),
              // Right: مسح ⌫
              Expanded(
                flex: 3,
                child: numBtn('مسح ⌫', bg: Colors.orange.shade50, fg: Colors.orange.shade900, fontSize: 14, onTap: backspace),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProductInputDialog(ProductModel product) {
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final quantityController = TextEditingController(text: product.isWeighted ? '' : '1');
    final priceController = TextEditingController(text: product.allowPriceChange ? '' : product.price.toStringAsFixed(0));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final qtyVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
            final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;
            final calculatedTotal = qtyVal * priceVal;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (Product Info)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            product.isWeighted
                                ? Icons.scale
                                : product.allowPriceChange
                                    ? Icons.price_change
                                    : Icons.edit_note,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                              ),
                              Text(
                                'السعر الأساسي: ${product.price.toStringAsFixed(0)} $currencySym / ${product.unit}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (product.isWeighted) ...[
                      TextField(
                        controller: quantityController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'الوزن / الكمية (${product.unit})',
                          hintText: '0.000',
                          prefixIcon: const Icon(Icons.scale, color: Colors.purple, size: 22),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: product.unit,
                          filled: true,
                          fillColor: Colors.purple.shade50.withValues(alpha: 0.3),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 10),
                      _buildNumpad(
                        controller: quantityController,
                        unit: product.unit,
                        onChanged: () => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (product.allowPriceChange) ...[
                      TextField(
                        controller: priceController,
                        autofocus: !product.isWeighted,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'سعر البيع المباشر ($currencySym)',
                          hintText: 'أدخل السعر المطلوب',
                          prefixIcon: const Icon(Icons.attach_money, color: Colors.blue, size: 22),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: currencySym,
                          filled: true,
                          fillColor: Colors.blue.shade50.withValues(alpha: 0.3),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 10),
                      _buildNumpad(
                        controller: priceController,
                        unit: currencySym,
                        isPrice: true,
                        onChanged: () => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (!product.isWeighted && !product.allowPriceChange) ...[
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة خاصة بالصنف (اختياري)',
                          hintText: 'مثال: بدون بصل، زيادة صوص',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Total Subtotal Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            '${calculatedTotal.toStringAsFixed(0)} $currencySym',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                          label: const Text('تأكيد وإضافة للسلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            if (qtyVal <= 0) {
                              TopNotification.showWarning(context, 'يرجى إدخال وزن أو كمية صالحة أكبر من الصفر');
                              return;
                            }
                            if (priceVal < 0) {
                              TopNotification.showWarning(context, 'يرجى إدخال سعر صالح');
                              return;
                            }

                            if (product.allowPriceChange && priceVal != product.price) {
                              final authProvider = context.read<AuthProvider>();
                              if (!authProvider.hasPermission(context, 'perm_cashier_allow_price_change')) {
                                ManagerAuthDialog.show(
                                  context,
                                  title: 'إذن تعديل السعر 🔒',
                                  reason: 'تغيير وتعديل سعر المادة في السلة يتطلب إذن موافقة المدير',
                                ).then((authorized) {
                                  if (authorized && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _addItemToCartWithQtyAndPrice(
                                      product: product,
                                      quantity: qtyVal,
                                      price: priceVal,
                                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                    );
                                  }
                                });
                                return;
                              }
                            }

                            Navigator.pop(ctx);
                            _addItemToCartWithQtyAndPrice(
                              product: product,
                              quantity: qtyVal,
                              price: priceVal,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );

                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCartItemDialog(int index) {
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final item = _cart[index];
    final quantityController = TextEditingController(text: item.formattedQuantity);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final notesController = TextEditingController(text: item.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final qtyVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
            final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;
            final calculatedTotal = qtyVal * priceVal;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تعديل ${item.productName ?? "الصنف"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'الكمية / الوزن',
                        prefixIcon: const Icon(Icons.fitness_center),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'سعر البيع ($currencySym)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'ملاحظة الخاصة بالمطبخ / الطلب',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${calculatedTotal.toStringAsFixed(0)} $currencySym',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    if (qtyVal <= 0) {
                      TopNotification.showWarning(context, 'يرجى إدخال كمية أكبر من الصفر');
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() {
                      _cart[index] = item.copyWith(
                        quantity: qtyVal,
                        price: priceVal,
                        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                      );
                    });
                  },
                  child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateQuantity(int index, double delta) {
    setState(() {
      final item = _cart[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = item.copyWith(quantity: newQty);
      }
    });
  }

  Future<void> _removeFromCart(int index) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.hasPermission(context, 'perm_cashier_allow_delete_item')) {
      final item = _cart[index];
      final authorized = await ManagerAuthDialog.show(
        context,
        title: 'إذن حذف مادة من السلة 🔒',
        reason: 'حذف المادة (${item.productName}) من السلة يتطلب إذن موافقة المدير',
      );
      if (!authorized) return;
    }
    setState(() {
      _cart.removeAt(index);
    });
  }


  void _clearCart() {
    setState(() {
      _cart.clear();
      _existingOrderId = null;
      _discountAmount = 0.0;
    });
  }

  double get _subtotalAmount {
    return _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _totalAmount {
    return (_subtotalAmount - _discountAmount).clamp(0.0, double.infinity);
  }

  // 1. Hold / Suspend Invoice on Table (تعليق الفاتورة)
  Future<void> _holdOrderOnTable() async {
    if (_cart.isEmpty) {
      TopNotification.showWarning(context, 'سلة الطلب فارغة! قم بإضافة مواد أولاً لتعليق الفاتورة.');
      return;
    }

    final tableId = widget.selectedTable?.id ?? 1;
    final ordersProvider = context.read<OrdersProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // Calculate new/delta items for kitchen printing before saving
    final kitchenDeltaItems = await ordersProvider.getKitchenDeltaItems(_existingOrderId, _cart);

    final orderId = await ordersProvider.holdTableOrder(
      existingOrderId: _existingOrderId,
      tableId: tableId,
      items: _cart,
      subtotal: _subtotalAmount,
      discountAmount: _discountAmount,
      total: _totalAmount,
      status: 'OPEN',
    );

    final heldOrder = OrderModel(
      id: orderId,
      tableId: tableId,
      orderType: widget.selectedTable != null ? 'DINE_IN' : 'TAKEAWAY',
      subtotal: _subtotalAmount,
      total: _totalAmount,
      status: 'OPEN',
      createdAt: DateTime.now().toIso8601String(),
    );

    // Trigger actual Kitchen Order Ticket print ONLY for new/incremental delta items
    if (kitchenDeltaItems.isNotEmpty) {
      PrintService.printKitchenTicket(
        order: heldOrder,
        items: kitchenDeltaItems,
        settings: settingsProvider,
        tableName: widget.selectedTable?.name ?? 'طاولة $tableId',
      ).catchError((e) {
        debugPrint('Kitchen print error on hold order: $e');
        return false;
      });
    }

    if (!mounted) return;

    final kitchenPrinter = settingsProvider.kitchenPrinter;

    TopNotification.showSuccess(
      context,
      kitchenDeltaItems.isNotEmpty
          ? '🍳 تم تعليق الفاتورة وإرسال وطباعة ${kitchenDeltaItems.length} صنف جديد على طابعة المطبخ [$kitchenPrinter] بنجاح!'
          : '📌 تم تعليق الفاتورة وحفظها للطاولة بنجاح!',
    );

    _finishOrderFlowNavigation();
  }


  void _resetToInitialCashierState() {
    _clearCart();
    if (mounted) {
      context.read<ProductsProvider>().selectCategory(null);
      context.read<ProductsProvider>().setSearchQuery('');
    }
  }

  void _finishOrderFlowNavigation() {
    _resetToInitialCashierState();
    if (mounted && Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _cancelOrderAndGoHome() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.hasPermission(context, 'perm_cashier_allow_cancel_order')) {
      final authorized = await ManagerAuthDialog.show(
        context,
        title: 'إذن إلغاء الفاتورة 🔒',
        reason: 'إلغاء الفاتورة بالكامل وإخلاء الطاولة يتطلب إذن موافقة المدير',
      );
      if (!authorized) return;
      if (!mounted) return;
    }

    final ordersProvider = context.read<OrdersProvider>();
    final tablesProvider = context.read<TablesProvider>();

    final confirm = await showDialog<bool>(

      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('تأكيد إلغاء الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          widget.selectedTable != null
              ? 'هل أنت تأكد من إلغاء فاتورة ${widget.selectedTable!.name} وإخلاء الطاولة بالكامل؟'
              : 'هل أنت تأكد من إلغاء الفاتورة وتفريغ سلة المواد والعودة للشاشة الرئيسية؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع (البقاء)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('نعم، إلغاء الفاتورة وإخلاء الطاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.selectedTable?.id != null) {
        final tableId = widget.selectedTable!.id!;
        await ordersProvider.cancelTableOrder(tableId);
        await tablesProvider.loadTables();
      }

      if (mounted) {
        setState(() {
          _cart.clear();
          _existingOrderId = null;
        });

        TopNotification.showSuccess(context, 'تم إلغاء الفاتورة وإخلاء الطاولة بنجاح ❌');
        _finishOrderFlowNavigation();
      }
    }
  }

  // 2. Direct Checkout & Print (طلب الحساب وإتمام الفاتورة فوراً بدون حوار مؤكد)
  Future<void> _submitOrderAndPrint({String paymentMethod = 'CASH'}) async {
    if (_cart.isEmpty) {
      TopNotification.showWarning(context, 'سلة الطلب فارغة! قم بإضافة أصناف أولاً.');
      return;
    }

    String? customerName;
    String? customerPhone;
    String? customerAddress;

    if (paymentMethod == 'CREDIT') {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.hasPermission(context, 'perm_cashier_allow_debt_sale')) {
        final authorized = await ManagerAuthDialog.show(
          context,
          title: 'إذن البيع بالآجل 🔒',
          reason: 'إكمال عملية البيع بالآجل والديون يتطلب موافقة وإذن مدير النظام',
        );
        if (!authorized) return;
      }

      final creditDetails = await _promptCreditCustomerDetails();

      if (creditDetails == null) return; // User cancelled
      customerName = creditDetails['name'];
      customerPhone = creditDetails['phone'];

      if (!mounted) return;
      final ordersProvider = context.read<OrdersProvider>();
      final customersProvider = context.read<CustomersProvider>();
      final shiftsProvider = context.read<ShiftsProvider>();


      final orderId = await ordersProvider.checkoutCreditOrder(
        existingOrderId: _existingOrderId,
        tableId: _orderType == 'DINE_IN' ? widget.selectedTable?.id : null,
        debtorName: customerName ?? 'زبون غير مسمى',
        debtorPhone: customerPhone,
        cashierName: authProvider.currentUserName,
        shiftId: shiftsProvider.currentShift?.id,
        orderType: _orderType,
        items: _cart,
        subtotal: _subtotalAmount,
        discountAmount: _discountAmount,
        total: _totalAmount,
      );

      // Save / Update Customer Debt in CustomersProvider
      if (customerName != null && customerName.isNotEmpty) {
        final existingCust = customersProvider.customers.firstWhere(
          (c) => c.name.trim() == customerName!.trim(),
          orElse: () => CustomerModel(name: customerName!, phone: customerPhone, balance: 0.0),
        );
        if (existingCust.id != null) {
          await customersProvider.addDebt(existingCust.id!, _totalAmount);
        } else {
          await customersProvider.addCustomer(
            CustomerModel(name: customerName, phone: customerPhone, balance: _totalAmount),
          );
        }
      }

      if (!mounted) return;
      await context.read<ProductsProvider>().loadProducts();

      if (!mounted) return;
      final completedOrder = OrderModel(
        id: orderId,
        tableId: widget.selectedTable?.id,
        orderType: _orderType,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        paymentMethod: paymentMethod,
        total: _totalAmount,
        subtotal: _subtotalAmount,
        discountAmount: _discountAmount,
        status: 'COMPLETED',
        createdAt: DateTime.now().toIso8601String(),
      );

      final cartItemsCopy = List<OrderItemModel>.from(_cart);
      final settingsProvider = context.read<SettingsProvider>();

      PrintService.printCustomerReceipt(
        order: completedOrder,
        items: cartItemsCopy,
        settings: settingsProvider,
        tableName: widget.selectedTable?.name,
      ).catchError((e) {
        debugPrint('Direct print error: $e');
        return false;
      });

      TopNotification.showSuccess(
        context,
        '📋 تم تسجيل الفاتورة بنجاح كـ دين على ($customerName) وطباعة الفاتورة مباشرة!',
      );

      _finishOrderFlowNavigation();
      return;
    } else if (_orderType == 'DELIVERY') {
      final details = await _promptDeliveryCustomerDetails();
      if (details == null) return; // User cancelled
      customerPhone = details['phone'];
      customerAddress = details['address'];
    }

    if (!mounted) return;
    final ordersProvider = context.read<OrdersProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final authProvider = context.read<AuthProvider>();
    final shiftsProvider = context.read<ShiftsProvider>();

    final completedCartCopy = List<OrderItemModel>.from(_cart);
    final orderId = await ordersProvider.checkoutAndCompleteOrder(
      existingOrderId: _existingOrderId,
      tableId: _orderType == 'DINE_IN' ? widget.selectedTable?.id : null,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      cashierName: authProvider.currentUserName,
      shiftId: shiftsProvider.currentShift?.id,
      paymentMethod: paymentMethod,
      orderType: _orderType,
      items: _cart,
      subtotal: _subtotalAmount,
      discountAmount: _discountAmount,
      total: _totalAmount,
    );

    if (!mounted) return;
    await context.read<ProductsProvider>().loadProducts();

    final completedOrder = OrderModel(
      id: orderId,
      tableId: widget.selectedTable?.id,
      orderType: _orderType,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      paymentMethod: paymentMethod,
      total: _totalAmount,
      subtotal: _subtotalAmount,
      discountAmount: _discountAmount,
      status: 'COMPLETED',
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Direct Background Customer Receipt Print
    PrintService.printCustomerReceipt(
      order: completedOrder,
      items: completedCartCopy,
      settings: settingsProvider,
      tableName: widget.selectedTable?.name,
    ).catchError((e) {
      debugPrint('Direct print error: $e');
      return false;
    });

    // 2. Open Cash Drawer automatically on completing order / receipt print
    PrintService.openCashDrawer(settingsProvider).catchError((e) {
      debugPrint('Auto open cash drawer error: $e');
      return false;
    });


    if (!mounted) return;
    TopNotification.showSuccess(
      context,
      '⚡ تم إتمام الدفع كاش وطباعة الفاتورة #$orderId مباشرة! 🖨️',
    );

    // 3. Immediately clear cart and return to fresh cashier state
    _finishOrderFlowNavigation();
  }

  Future<Map<String, String>?> _promptCreditCustomerDetails() async {
    // Ensure latest customers are loaded
    await context.read<CustomersProvider>().loadCustomers();
    if (!mounted) return null;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String searchQuery = '';
    CustomerModel? selectedCustomer;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final customersProvider = dialogCtx.watch<CustomersProvider>();
            final allCustomers = customersProvider.customers;

            final filteredCustomers = allCustomers.where((c) {
              final query = searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;
              final nameMatch = c.name.toLowerCase().contains(query);
              final phoneMatch = c.phone != null && c.phone!.contains(query);
              return nameMatch || phoneMatch;
            }).toList();

            // Calculate previous debt if selected
            final double previousDebt = selectedCustomer?.balance ?? 0.0;
            final double newTotalDebt = previousDebt + _totalAmount;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.indigo, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'تسجيل الدفع آجل / اختيار صاحب الدين',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx, null),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // 1. Current Order Amount Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'مبلغ الفاتورة الحالية المضافة للآجل:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          Text(
                            '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Search Field
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الزبون أو رقم الهاتف...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Customers List View (Max height ~180px)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: filteredCustomers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    allCustomers.isEmpty
                                        ? 'لا يوجد عملاء مسجلون حالياً. اكتب اسم الزبون الجديد بالأسفل.'
                                        : 'لم يتم العثور على زبون بهذا الاسم.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredCustomers.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, indent: 12, endIndent: 12),
                                itemBuilder: (itemCtx, index) {
                                  final customer = filteredCustomers[index];
                                  final isSelected = selectedCustomer?.id == customer.id ||
                                      (selectedCustomer == null && nameController.text.trim() == customer.name.trim());

                                  return Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: Colors.indigo.shade50,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isSelected ? Colors.indigo : Colors.grey.shade300,
                                        child: Icon(
                                          isSelected ? Icons.check : Icons.person,
                                          size: 18,
                                          color: isSelected ? Colors.white : Colors.grey.shade700,
                                        ),
                                      ),
                                      title: Text(
                                        customer.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.indigo.shade900 : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        customer.phone != null && customer.phone!.isNotEmpty
                                            ? customer.phone!
                                            : 'بدون رقم موبايل',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'ديون سابقة: ${customer.balance.toStringAsFixed(0)} $_currencySymbol',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: customer.balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                ),
                                              ),
                                              Text(
                                                'الإجمالي الجديد: ${(customer.balance + _totalAmount).toStringAsFixed(0)} $_currencySymbol',
                                                style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (dialogCtx.watch<AuthProvider>().isManager && customer.id != null) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              tooltip: dialogCtx.watch<SettingsProvider>().isEnglish ? 'Delete Customer (Manager Only)' : 'حذف هذا الزبون (للمدير فقط)',
                                               onPressed: () async {
                                                 if (customer.balance > 0) {
                                                   showDialog(
                                                     context: ctx,
                                                     builder: (blockCtx) => AlertDialog(
                                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                       title: const Row(
                                                         children: [
                                                           Icon(Icons.block, color: Colors.red, size: 28),
                                                           SizedBox(width: 8),
                                                           Text('تنبيه: لا يمكن حذف الزبون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                                                         ],
                                                       ),
                                                       content: Text(
                                                         'لا يمكن حذف الزبون (${customer.name}) لأن لديه ديون سابقة غير مسددة (${customer.balance.toStringAsFixed(0)} $_currencySymbol).\n\nيرجى تسديد وتصفية الديون أولاً قبل حذف الزبون.',
                                                         style: const TextStyle(fontSize: 14),
                                                       ),
                                                       actions: [
                                                         ElevatedButton(
                                                           style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                                           onPressed: () => Navigator.pop(blockCtx),
                                                           child: const Text('حسناً، فهمت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                         ),
                                                       ],
                                                     ),
                                                   );
                                                   return;
                                                 }

                                                 final custProv = ctx.read<CustomersProvider>();
                                                final confirm = await showDialog<bool>(
                                                  context: ctx,
                                                  builder: (confirmCtx) => AlertDialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                    title: const Row(
                                                      children: [
                                                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                                        SizedBox(width: 8),
                                                        Text('تأكيد حذف الزبون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                      ],
                                                    ),
                                                    content: Text('هل أنت متأكد من حذف الزبون (${customer.name}) نهائياً من القائمة والنظام؟\n(ملاحظة: هذا الخيار متاح للمدير فقط)'),
                                                    actions: [
                                                      OutlinedButton(
                                                        onPressed: () => Navigator.pop(confirmCtx, false),
                                                        child: const Text('إلغاء'),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                        onPressed: () => Navigator.pop(confirmCtx, true),
                                                        child: const Text('حذف الزبون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                   await custProv.deleteCustomer(customer.id!);
                                                  setDialogState(() {
                                                    if (selectedCustomer?.id == customer.id) {
                                                      selectedCustomer = null;
                                                      nameController.clear();
                                                      phoneController.clear();
                                                    }
                                                  });
                                                  if (ctx.mounted) {
                                                    TopNotification.showSuccess(ctx, '🎉 تم حذف الزبون (${customer.name}) بنجاح!');
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                      onTap: () {
                                        setDialogState(() {
                                          selectedCustomer = customer;
                                          nameController.text = customer.name;
                                          phoneController.text = customer.phone ?? '';
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Name & Phone Input (Pre-filled if selected, or editable for new customer)
                    const Text('أو أدخل بيانات زبون جديد / معدلة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: nameController,
                            onChanged: (val) {
                              setDialogState(() {
                                if (selectedCustomer != null && selectedCustomer!.name.trim() != val.trim()) {
                                  selectedCustomer = null;
                                }
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'اسم الزبون / صاحب الدين *',
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الموبايل',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 5. Total Debt Summary Preview Box
                    if (nameController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الزبون: ${nameController.text.trim()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'ديون سابقة: ${previousDebt.toStringAsFixed(0)} $_currencySymbol + الطلب: ${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text('مجموع الدين الكلي', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text(
                                    '${newTotalDebt.toStringAsFixed(0)} $_currencySymbol',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    if (name.isEmpty) {
                      TopNotification.showWarning(ctx, 'يرجى اختيار أو كتابة اسم الزبون لتسجيل الدين عليه');
                      return;
                    }
                    Navigator.pop(ctx, {'name': name, 'phone': phone});
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  label: const Text('تأكيد وتسجيل الدين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDiscountNumpad({
    required Function(String) onAppend,
    required VoidCallback onBackspace,
    required VoidCallback onClear,
  }) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              final isBackspace = key == '⌫';
              final isClear = key == 'C';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      if (isBackspace) {
                        onBackspace();
                      } else if (isClear) {
                        onClear();
                      } else {
                        onAppend(key);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isClear
                            ? Colors.red.shade50
                            : isBackspace
                                ? Colors.orange.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isClear
                              ? Colors.red.shade200
                              : isBackspace
                                  ? Colors.orange.shade200
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          key,
                          style: TextStyle(
                            fontSize: isBackspace || isClear ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: isClear
                                ? Colors.red
                                : isBackspace
                                    ? Colors.orange.shade900
                                    : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showRefundDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => const RefundDialog(),
    );
  }

  Future<void> _showDiscountDialog() async {
    if (_cart.isEmpty) {
      TopNotification.showWarning(context, 'سلة الطلب فارغة! قم بإضافة مواد أولاً قبل تفعيل الخصم.');
      return;
    }

    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.hasPermission(context, 'perm_cashier_allow_discount')) {
      final authorized = await ManagerAuthDialog.show(
        context,
        title: 'إذن تطبيق الخصم 🔒',
        reason: 'تطبيق خصم على الفاتورة يتطلب موافقة وإذن مدير النظام',
      );
      if (!authorized) return;
      if (!mounted) return;
    }

    final discountController = TextEditingController(
      text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(0) : '',
    );
    bool isPercentage = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Row(
            children: [
              Icon(Icons.percent, color: Colors.purple, size: 28),
              SizedBox(width: 10),
              Text('تطبيق خصم على الفاتورة'),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجمالي الفاتورة الحالي: ${_subtotalAmount.toStringAsFixed(0)} $currencySym',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  // Mode Toggle Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('مبلغ مباشر ($currencySym)', style: const TextStyle(fontSize: 12))),
                          selected: !isPercentage,
                          selectedColor: Colors.purple.shade100,
                          onSelected: (val) {
                            setDialogState(() => isPercentage = false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('نسبة مئوية (%)', style: TextStyle(fontSize: 12))),
                          selected: isPercentage,
                          selectedColor: Colors.purple.shade100,
                          onSelected: (val) {
                            setDialogState(() => isPercentage = true);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Display Input Field
                  TextField(
                    controller: discountController,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                    decoration: InputDecoration(
                      labelText: isPercentage ? 'النسبة المئوية للخصم %' : 'مبلغ الخصم ($currencySym)',
                      prefixIcon: Icon(isPercentage ? Icons.percent : Icons.attach_money, color: Colors.purple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                      fillColor: Colors.purple.shade50.withValues(alpha: 0.3),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Touch Numpad
                  _buildDiscountNumpad(
                    onAppend: (digit) {
                      setDialogState(() {
                        discountController.text += digit;
                      });
                    },
                    onBackspace: () {
                      setDialogState(() {
                        if (discountController.text.isNotEmpty) {
                          discountController.text = discountController.text.substring(0, discountController.text.length - 1);
                        }
                      });
                    },
                    onClear: () {
                      setDialogState(() {
                        discountController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (_discountAmount > 0)
              TextButton(
                onPressed: () {
                  setState(() => _discountAmount = 0.0);
                  Navigator.pop(ctx);
                  TopNotification.showInfo(context, 'تم إزالة الخصم عن الفاتورة.');
                },
                child: const Text('إلغاء الخصم الحالي', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: () {
                final val = double.tryParse(discountController.text.trim()) ?? 0.0;
                if (val <= 0) {
                  TopNotification.showWarning(ctx, 'يرجى كتابة قيمة خصم أكبر من الصفر');
                  return;
                }

                double calculatedDiscount = 0.0;
                if (isPercentage) {
                  calculatedDiscount = (_subtotalAmount * val) / 100.0;
                } else {
                  calculatedDiscount = val;
                }

                if (calculatedDiscount > _subtotalAmount) {
                  TopNotification.showWarning(ctx, 'مبلغ الخصم أكبر من قيمة الفاتورة!');
                  return;
                }

                setState(() {
                  _discountAmount = calculatedDiscount;
                });

                Navigator.pop(ctx);
                TopNotification.showSuccess(
                  context,
                  '🏷️ تم تطبيق خصم بقيمة (${calculatedDiscount.toStringAsFixed(0)} $currencySym) بنجاح!',
                );
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('تطبيق الخصم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCashDrawer() async {
    final settings = context.read<SettingsProvider>();
    TopNotification.showInfo(context, '🔑 جاري فتح درج النقدية...');
    final success = await PrintService.openCashDrawer(settings);
    if (mounted) {
      if (success) {
        TopNotification.showSuccess(
          context,
          '🔑 تم فتح درج النقدية بنجاح! 💵',
        );
      } else {
        TopNotification.showWarning(
          context,
          '⚠️ تم إرسال الأمر. تأكد من توصيل سلك الدرج بالطابعة وتحديد طابعة الكاشير في الإعدادات.',
        );
      }
    }
  }

  Future<Map<String, String>?> _promptDeliveryCustomerDetails() async {
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.two_wheeler, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('بيانات توصيل الطلب (Delivery)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'يرجى إدخال رقم موبايل وعنوان الزبون المطبوعة بالفاتورة:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم موبايل الزبون *',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'عنوان التوصيل التفصيلي *',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final phone = phoneController.text.trim();
              final address = addressController.text.trim();
              if (phone.isEmpty) {
                TopNotification.showWarning(ctx, 'يرجى كتابة رقم موبايل الزبون للتوصيل');
                return;
              }
              Navigator.pop(ctx, {'phone': phone, 'address': address});
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('تأكيد وإتمام الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  Widget _buildAroniumQuickActionBar(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. كاش (Cash)
          Expanded(
            child: _aroniumActionButton(
              label: isEng ? 'Pay Cash 💵' : 'الدفع Cash',
              icon: Icons.payments_rounded,
              color: Colors.green.shade700,
              onTap: () => _submitOrderAndPrint(paymentMethod: 'CASH'),
            ),
          ),
          const SizedBox(width: 8),

          // 2. تعليق الفاتورة (Hold / Park)
          Expanded(
            child: _aroniumActionButton(
              label: isEng ? 'Hold Order ⏸️' : 'تعليق الفاتورة',
              icon: Icons.pause_circle_filled_rounded,
              color: Colors.deepOrange,
              onTap: _holdOrderOnTable,
            ),
          ),
          const SizedBox(width: 8),

          // 3. خصم (Discount)
          Expanded(
            child: _aroniumActionButton(
              label: _discountAmount > 0
                  ? (isEng ? 'Discount (${_discountAmount.toStringAsFixed(0)})' : 'خصم (${_discountAmount.toStringAsFixed(0)})')
                  : (isEng ? 'Add Discount' : 'إضافة خصم'),
              icon: Icons.percent_rounded,
              color: Colors.purple.shade700,
              badge: _discountAmount > 0 ? (isEng ? 'Active' : 'مفعل') : null,
              onTap: _showDiscountDialog,
            ),
          ),
          const SizedBox(width: 8),

          // 4. آجل / ديون (Credit / Debt)
          Expanded(
            child: _aroniumActionButton(
              label: isEng ? 'Credit / Debt 📝' : 'الدفع آجل (ديون)',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.indigo.shade700,
              onTap: () => _submitOrderAndPrint(paymentMethod: 'CREDIT'),
            ),
          ),
          const SizedBox(width: 8),

          // 5. فتح الدرج (Open Drawer)
          Expanded(
            child: _aroniumActionButton(
              label: isEng ? 'Open Drawer 🔑' : 'فتح الدرج',
              icon: Icons.meeting_room_rounded,
              color: Colors.teal.shade800,
              onTap: _openCashDrawer,
            ),
          ),
          const SizedBox(width: 8),

          // 6. استرجاع الفواتير (Refund)
          Expanded(
            child: _aroniumActionButton(
              label: isEng ? 'Refund Receipts ↩️' : 'استرجاع الفواتير',
              icon: Icons.assignment_return_rounded,
              color: Colors.red.shade700,
              onTap: _showRefundDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aroniumActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = context.watch<CategoriesProvider>();
    final productsProvider = context.watch<ProductsProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;

    final selectedCategoryId = productsProvider.selectedCategoryId;
    final searchQuery = productsProvider.searchQuery;
    final showingCategoriesView = selectedCategoryId == null && searchQuery.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedTable != null
              ? 'كاشير الطاولة - ${widget.selectedTable!.name}'
              : 'الكاشير نقطة البيع',
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _orderType,
                dropdownColor: AppColors.primary,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'TAKEAWAY', child: Text('سفري')),
                  DropdownMenuItem(value: 'DINE_IN', child: Text('طاولة')),
                  DropdownMenuItem(value: 'DELIVERY', child: Text('توصيل')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _orderType = val;
                    });
                  }
                },
              ),
            ),
          ),
          IconButton(
            tooltip: isEng ? 'Refund & Returns Management' : 'إدارة استرجاع الفواتير والمواد',
            icon: const Icon(Icons.assignment_return_rounded, color: Colors.white),
            onPressed: _showRefundDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingTableOrder
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left Pane: Categories / Items Grid View
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Aronium Quick Action Bar
                      _buildAroniumQuickActionBar(context),

                      // Search Bar (Full Width)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث عن صنف أو منتج...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) => productsProvider.setSearchQuery(val),
                        ),
                      ),

                      // View Header Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              showingCategoriesView ? Icons.category : Icons.fastfood,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              showingCategoriesView
                                  ? (isEng ? 'Select Category to view items:' : 'اختر التصنيف لعرض الأصناف بداخله:')
                                  : (isEng ? 'Category items: ${_getCategoryName(categoriesProvider, selectedCategoryId)}' : 'أصناف تصنيف: ${_getCategoryName(categoriesProvider, selectedCategoryId)}'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Content View (Categories Grid OR Items Grid)
                      Expanded(
                        child: showingCategoriesView
                            ? _buildCategoriesGrid(context, categoriesProvider, productsProvider)
                            : _buildItemsGrid(context, productsProvider),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1),

                // Right Pane: Cart Panel & Table Action Buttons
                Container(
                  width: 390,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shopping_cart_checkout, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _existingOrderId != null
                                    ? (isEng ? 'Current Table Order' : 'طلب الطاولة الحالي')
                                    : (isEng ? 'Order Cart' : 'سلة الطلب'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_cart.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.red),
                              tooltip: isEng ? 'Clear Cart' : 'تفريغ السلة',
                              onPressed: _clearCart,
                            ),
                        ],
                      ),

                      if (widget.selectedTable != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEng ? '${widget.selectedTable!.name} (Cap. ${widget.selectedTable!.capacity})' : '${widget.selectedTable!.name} (سعة ${widget.selectedTable!.capacity})',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              if (_existingOrderId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(isEng ? 'Open Order 📌' : 'طلب مفتوح 📌', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 20),

                      // Cart List
                      Expanded(
                        child: _cart.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.remove_shopping_cart_outlined, size: 60, color: Colors.grey),
                                    const SizedBox(height: 10),
                                    Text(isEng ? 'No items in current order' : 'لا توجد أصناف في الطلب حالياً', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(isEng ? 'Select an item from the list to add' : 'اختر المادة من القائمة لإضافتها', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _cart.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _cart[index];
                                  return InkWell(
                                    onLongPress: () => _showEditCartItemDialog(index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName ?? (isEng ? 'Item' : 'صنف'),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                Text(
                                                  '${item.price.toStringAsFixed(0)} $_currencySymbol',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                                if (item.notes != null && item.notes!.isNotEmpty)
                                                  Text(
                                                    '📌 ${item.notes}',
                                                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                onPressed: () => _updateQuantity(index, -1),
                                              ),
                                              InkWell(
                                                onTap: () => _showEditCartItemDialog(index),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.formattedQuantity,
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                                onPressed: () => _updateQuantity(index, 1),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_note, size: 20, color: Colors.blue),
                                            tooltip: isEng ? 'Edit price or qty' : 'تعديل السعر أو الوزن',
                                            onPressed: () => _showEditCartItemDialog(index),
                                          ),
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              '${item.subtotal.toStringAsFixed(0)} $_currencySymbol',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                            onPressed: () => _removeFromCart(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      const Divider(height: 20),

                      // Order Total Details
                      if (_discountAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Subtotal:' : 'المجموع:', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                            Text('${_subtotalAmount.toStringAsFixed(0)} $_currencySymbol', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Discount:' : 'الخصم:', style: TextStyle(fontSize: 14, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                            Text('-${_discountAmount.toStringAsFixed(0)} $_currencySymbol', style: TextStyle(fontSize: 14, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Net Total:' : 'الصافي:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Grand Total:' : 'المجموع الإجمالي:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Action Button (Cancel Invoice)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _cancelOrderAndGoHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'إلغاء الفاتورة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _getCategoryName(CategoriesProvider categoriesProvider, int? categoryId) {
    if (categoryId == null) return 'الكل';
    final match = categoriesProvider.categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => categoriesProvider.categories.isNotEmpty ? categoriesProvider.categories.first : categoriesProvider.categories.first,
    );
    return match.name;
  }

  Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _customizeCategoryAppearance(BuildContext context, CategoryModel category) async {
    final categoriesProvider = context.read<CategoriesProvider>();
    final result = await CustomizeItemAppearanceDialog.show(
      context,
      itemName: category.name,
      initialImage: category.image,
      initialColor: category.color,
    );
    if (!context.mounted) return;
    if (result != null) {
      final updated = category.copyWith(
        image: result['image'],
        clearImage: result['image'] == null,
        color: result['color'],
        clearColor: result['color'] == null,
      );
      await categoriesProvider.updateCategory(updated);
      if (!context.mounted) return;
      TopNotification.showSuccess(context, '🎨 تم تحديث مظهر تصنيف (${category.name}) بنجاح!');
    }
  }

  Future<void> _customizeProductAppearance(BuildContext context, ProductModel product) async {
    final productsProvider = context.read<ProductsProvider>();
    final result = await CustomizeItemAppearanceDialog.show(
      context,
      itemName: product.name,
      initialImage: product.image,
      initialColor: product.color,
    );
    if (!context.mounted) return;
    if (result != null) {
      final updated = product.copyWith(
        image: result['image'],
        clearImage: result['image'] == null,
        color: result['color'],
        clearColor: result['color'] == null,
      );
      await productsProvider.updateProduct(updated);
      if (!context.mounted) return;
      TopNotification.showSuccess(context, '🎨 تم تحديث مظهر مادة (${product.name}) بنجاح!');
    }
  }

  // 1. Grid View for Categories

  Widget _buildCategoriesGrid(
    BuildContext context,
    CategoriesProvider categoriesProvider,
    ProductsProvider productsProvider,
  ) {
    final categories = categoriesProvider.categories;

    if (categories.isEmpty) {
      return const Center(
        child: Text('لا توجد تصنيفات معرفة حالياً', style: TextStyle(fontSize: 18)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final itemsCount = productsProvider.allProducts.where((p) => p.categoryId == category.id).length;
        final hasImage = category.image != null && category.image!.isNotEmpty && File(category.image!).existsSync();
        final bgColor = _parseColor(category.color) ?? Colors.orange.shade50;
        final isDarkBg = hasImage || (category.color != null && bgColor.computeLuminance() < 0.5);
        final textColor = isDarkBg ? Colors.white : Colors.black87;
        final badgeBg = isDarkBg ? Colors.white24 : AppColors.primary.withValues(alpha: 0.1);
        final badgeTextColor = isDarkBg ? Colors.white : AppColors.primary;

        return Card(
          elevation: 3,
          color: hasImage ? Colors.black : bgColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(

            borderRadius: BorderRadius.circular(14),
            onTap: () {
              productsProvider.selectCategory(category.id);
            },
            onSecondaryTap: () => _customizeCategoryAppearance(context, category),
            onLongPress: () => _customizeCategoryAppearance(context, category),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        gradient: (category.color == null && !hasImage)
                            ? LinearGradient(
                                colors: [Colors.orange.shade50, Colors.white],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (hasImage)
                    Positioned.fill(
                      child: Image.file(
                        File(category.image!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(color: bgColor),
                      ),
                    ),
                  if (hasImage)
                    Positioned.fill(
                      child: Container(color: Colors.black.withValues(alpha: 0.55)),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  context.watch<SettingsProvider>().isEnglish ? '$itemsCount items' : '$itemsCount عناصر',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );


      },

    );
  }



  // 2. Grid View for Items/Products
  Widget _buildItemsGrid(BuildContext context, ProductsProvider productsProvider) {
    final products = productsProvider.products;
    final totalGridItems = products.length + 1;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: totalGridItems,
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: () {
              productsProvider.selectCategory(null);
              productsProvider.setSearchQuery('');
            },
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.grey.shade100,
                ),
                padding: const EdgeInsets.all(6),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الرجوع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1),
                      Text(
                        '← القائمة',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final product = products[index - 1];
        final hasImage = product.image != null && product.image!.isNotEmpty && File(product.image!).existsSync();
        final bgColor = _parseColor(product.color) ?? (product.isAvailable ? Colors.white : Colors.grey.shade100);
        final isDarkBg = hasImage || (product.color != null && bgColor.computeLuminance() < 0.5);
        final textColor = isDarkBg ? Colors.white : (product.isAvailable ? Colors.black87 : Colors.grey);
        final priceColor = isDarkBg ? Colors.amberAccent : AppColors.primary;

        return Card(
          elevation: 3,
          color: hasImage ? Colors.black : bgColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: product.isAvailable ? Colors.transparent : Colors.red.shade200,
            ),
          ),
          child: InkWell(

            borderRadius: BorderRadius.circular(14),
            onTap: () => _addToCart(product),
            onSecondaryTap: () => _customizeProductAppearance(context, product),
            onLongPress: () => _customizeProductAppearance(context, product),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: bgColor),
                  ),
                  if (hasImage)
                    Positioned.fill(
                      child: Image.file(
                        File(product.image!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(color: bgColor),
                      ),
                    ),
                  if (hasImage)
                    Positioned.fill(
                      child: Container(color: Colors.black.withValues(alpha: 0.55)),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.price.toStringAsFixed(0)} $_currencySymbol',
                                style: TextStyle(
                                  color: priceColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (product.isWeighted || product.allowPriceChange) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (product.isWeighted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('⚖️ موزونة', style: TextStyle(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold)),
                                      ),
                                    if (product.allowPriceChange)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('🏷️ سعر متغير', style: TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
