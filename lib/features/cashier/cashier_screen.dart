import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/print_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/customize_item_appearance_dialog.dart';
import '../../core/widgets/item_note_dialog.dart';
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
import '../../services/local_server_service.dart';



class CashierScreen extends StatefulWidget {
  final RestaurantTable? selectedTable;
  final String initialOrderType;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOrderCompleted;

  const CashierScreen({
    super.key,
    this.selectedTable,
    this.initialOrderType = 'TAKEAWAY',
    this.onBack,
    this.onOpenMenu,
    this.onOrderCompleted,
  });

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> with WindowListener {
  late String _orderType;
  final List<OrderItemModel> _cart = [];
  final Set<String> _selectedItemKeys = {};
  final ScrollController _cartScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int? _existingOrderId;
  bool _isLoadingTableOrder = false;
  double _discountAmount = 0.0;
  bool _isRearrangeMode = false;
  String? _rearrangeSelectedKey;
  void _toggleFullscreen() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final current = await windowManager.isFullScreen();
        await windowManager.setFullScreen(!current);
      } catch (e) {
        debugPrint('windowManager toggle error in Cashier: $e');
      }
    }
  }

  @override
  void onWindowMaximize() async {
    try {
      await windowManager.setFullScreen(true);
    } catch (_) {}
  }

  String get _currencySymbol => context.watch<SettingsProvider>().currencySymbol;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cartScrollController.hasClients) {
        _cartScrollController.animateTo(
          _cartScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    _orderType = widget.selectedTable != null ? 'DINE_IN' : widget.initialOrderType;
    if (widget.selectedTable != null) {
      _loadTableOrder();
    }
    LocalServerService.instance.addListener(_onServerTableOrderUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductsProvider>().selectCategory(null);
        context.read<ProductsProvider>().setSearchQuery('');
        context.read<CustomersProvider>().loadCustomers();
      }
    });
  }

  void _onServerTableOrderUpdated() {
    if (mounted && widget.selectedTable != null) {
      _loadTableOrder();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    LocalServerService.instance.removeListener(_onServerTableOrderUpdated);
    _cartScrollController.dispose();
    _searchController.dispose();
    super.dispose();
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
            _selectedItemKeys.clear();
            _cart.addAll(items.map((i) => i.copyWith(isNew: false)));
          });
          _scrollToBottom();
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
      final now = DateTime.now();
      final index = _cart.indexWhere((item) {
        if (!item.isNew) return false;
        if (item.productId != product.id || item.price != price) return false;
        if (item.createdAt == null) return true;
        // Merge only if added within the last 60 seconds (same order action)
        return now.difference(item.createdAt!).inSeconds < 60;
      });

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
          isNew: true,
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
          createdAt: now,
          isNew: true,
        ));
      }
    });
    SoundService.instance.playBeep();
    _scrollToBottom();
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    Widget numBtn(String label, {VoidCallback? onTap, Color? bg, Color? borderCol, Color? fg, IconData? icon, double fontSize = 20}) {
      final defaultBg = isDark ? const Color(0xFF2C394B) : Colors.grey.shade100;
      final defaultBorder = isDark ? const Color(0xFF374151) : Colors.grey.shade300;
      final defaultFg = isDark ? Colors.white : Colors.black87;
      return Material(
        color: bg ?? defaultBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol ?? defaultBorder, width: 1.2),
            ),
            child: icon != null
                ? Icon(icon, color: fg ?? defaultFg, size: 22)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: fg ?? defaultFg,
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
                      backgroundColor: isDark ? const Color(0xFF3B2D54) : Colors.purple.shade50,
                      foregroundColor: isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF3B2D54) : Colors.purple.shade50,
                      foregroundColor: isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF3B2D54) : Colors.purple.shade50,
                      foregroundColor: isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF3B2D54) : Colors.purple.shade50,
                      foregroundColor: isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade50,
                      foregroundColor: isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade50,
                      foregroundColor: isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade50,
                      foregroundColor: isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      backgroundColor: isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade50,
                      foregroundColor: isDark ? const Color(0xFFBFDBFE) : Colors.blue.shade800,
                      elevation: 0,
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : Colors.blue.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => addPrice(5000),
                    child: const Text('+5,000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),

          // Row 1: 1, 2, 3
          Row(
            children: [
              Expanded(child: numBtn('1', onTap: () => appendChar('1'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('2', onTap: () => appendChar('2'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('3', onTap: () => appendChar('3'))),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: 4, 5, 6
          Row(
            children: [
              Expanded(child: numBtn('4', onTap: () => appendChar('4'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('5', onTap: () => appendChar('5'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('6', onTap: () => appendChar('6'))),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: 7, 8, 9
          Row(
            children: [
              Expanded(child: numBtn('7', onTap: () => appendChar('7'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('8', onTap: () => appendChar('8'))),
              const SizedBox(width: 8),
              Expanded(child: numBtn('9', onTap: () => appendChar('9'))),
            ],
          ),
          const SizedBox(height: 8),

          // Row 4: C (Left), 0 (Middle), ⌫ (Right)
          Row(
            children: [
              Expanded(
                child: numBtn(
                  'C',
                  bg: Colors.red.shade50,
                  borderCol: Colors.red.shade200,
                  fg: Colors.red,
                  fontSize: 18,
                  onTap: clearAll,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: numBtn('0', onTap: () => appendChar('0')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: numBtn(
                  '⌫',
                  bg: Colors.orange.shade50,
                  borderCol: Colors.orange.shade200,
                  fg: Colors.orange.shade900,
                  fontSize: 18,
                  onTap: backspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProductInputDialog(ProductModel product) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final quantityController = TextEditingController(text: product.isWeighted ? '' : '1');
    final priceController = TextEditingController(text: product.allowPriceChange ? '' : product.price.toStringAsFixed(0));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final qtyVal = double.tryParse(quantityController.text.trim()) ?? 0.0;
            final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;
            final calculatedTotal = qtyVal * priceVal;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.purple.shade900,
                          letterSpacing: 1.2,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'الوزن / الكمية (${product.unit})',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : Colors.purple.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: '0.000',
                          prefixIcon: Icon(
                            Icons.scale,
                            color: isDark ? const Color(0xFFD8B4FE) : Colors.purple.shade800,
                            size: 22,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFFA855F7) : Colors.purple.shade200,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFFC084FC) : Colors.purple,
                              width: 2,
                            ),
                          ),
                          suffixText: product.unit,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.purple.shade50.withValues(alpha: 0.3),
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade800,
                          letterSpacing: 1.2,
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isEng ? 'Direct Selling Price ($currencySym)' : 'سعر البيع المباشر ($currencySym)',
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Container(
                            width: 48,
                            alignment: Alignment.center,
                            child: Text(
                              isEng ? '\$' : currencySym,
                              style: TextStyle(
                                fontSize: isEng ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF93C5FD) : Colors.blue.shade800,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF3B82F6) : Colors.blue.shade200,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF60A5FA) : Colors.blue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withValues(alpha: 0.3),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
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
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: Icon(Icons.bookmarks_rounded, color: AppColors.primary),
                            tooltip: 'اختيار من المكونات/الملاحظات المخزونة',
                            onPressed: () async {
                              final res = await ItemNoteDialog.show(
                                ctx,
                                productName: product.name,
                                initialNote: notesController.text,
                              );
                              if (res != null) {
                                notesController.text = res;
                                setStateDialog(() {});
                              }
                            },
                          ),
                        ],
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



  void _updateQuantity(int index, double delta) {
    bool isRemoved = false;
    setState(() {
      final item = _cart[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
        isRemoved = true;
      } else {
        final markAsNew = delta > 0 ? true : item.isNew;
        _cart[index] = item.copyWith(
          quantity: newQty,
          isNew: markAsNew,
        );
      }
    });
    if (isRemoved) {
      SoundService.instance.playDelete();
    } else if (delta > 0) {
      SoundService.instance.playBeep();
    }
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
    SoundService.instance.playDelete();
  }


  void _clearCart() {
    final hadItems = _cart.isNotEmpty;
    setState(() {
      _cart.clear();
      _selectedItemKeys.clear();
      _existingOrderId = null;
      _discountAmount = 0.0;
    });
    if (hadItems) {
      SoundService.instance.playDelete();
    }
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
      // عند الضغط على تعليق الفاتورة لسلة فارغة، إتمام تدفق الرجوع
      _finishOrderFlowNavigation(returnToHome: true);
      return;
    }

    int tableId;
    String tableName;

    if (widget.selectedTable != null) {
      tableId = widget.selectedTable!.id!;
      tableName = widget.selectedTable!.name;
    } else {
      final tablesProvider = context.read<TablesProvider>();
      await tablesProvider.loadTables();
      if (!mounted) return;
      final tables = tablesProvider.tables;

      if (tables.isEmpty) {
        TopNotification.showWarning(context, 'لا توجد طاولات مضافة في النظام لتعليق الفاتورة عليها.');
        return;
      }

      final chosenTable = await showDialog<RestaurantTable>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.pause_circle_filled, color: Colors.deepOrange, size: 28),
              SizedBox(width: 8),
              Text('اختر الطاولة لتعليق الفاتورة عليها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 320,
            child: ListView.separated(
              itemCount: tables.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final t = tables[idx];
                final isOccupied = t.status == 1;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOccupied ? Colors.red.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                    child: Icon(Icons.table_restaurant, color: isOccupied ? Colors.red : Colors.green),
                  ),
                  title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isOccupied ? 'مشغولة حالياً' : 'شاغرة ومتاحة', style: TextStyle(color: isOccupied ? Colors.red : Colors.green, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () => Navigator.pop(ctx, t),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );

      if (chosenTable == null || chosenTable.id == null || !mounted) return;
      tableId = chosenTable.id!;
      tableName = chosenTable.name;
    }

    if (!mounted) return;
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

    if (mounted) {
      setState(() {
        for (int i = 0; i < _cart.length; i++) {
          _cart[i] = _cart[i].copyWith(isNew: false);
        }
        _existingOrderId = orderId;
      });
    }

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
        tableName: tableName,
      ).catchError((e) {
        debugPrint('Kitchen print error on hold order: $e');
        return false;
      });
    }

    if (!mounted) return;

    final kitchenPrinter = settingsProvider.kitchenPrinter;

    SoundService.instance.playCashRegister();
    TopNotification.showSuccess(
      context,
      kitchenDeltaItems.isNotEmpty
          ? '🍳 تم تعليق الفاتورة وإرسال وطباعة ${kitchenDeltaItems.length} صنف جديد على طابعة المطبخ [$kitchenPrinter] بنجاح!'
          : '📌 تم تعليق الفاتورة وحفظها للطاولة [$tableName] بنجاح!',
    );

    _finishOrderFlowNavigation(returnToHome: true);
  }


  void _resetToInitialCashierState() {
    _clearCart();
    _searchController.clear();
    _orderType = widget.selectedTable != null ? 'DINE_IN' : widget.initialOrderType;
    if (mounted) {
      context.read<ProductsProvider>().selectCategory(null);
      context.read<ProductsProvider>().setSearchQuery('');
    }
  }

  void _finishOrderFlowNavigation({bool returnToHome = true}) {
    _resetToInitialCashierState();
    if (mounted && widget.selectedTable != null) {
      context.read<TablesProvider>().loadTables();
    }
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, returnToHome);
      } else if (returnToHome) {
        if (widget.onOrderCompleted != null) {
          widget.onOrderCompleted!();
        } else if (widget.onBack != null) {
          widget.onBack!();
        }
      }
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
      final currentUserName = authProvider.currentUserName;
      if (widget.selectedTable?.id != null) {
        final tableId = widget.selectedTable!.id!;
        await ordersProvider.cancelTableOrder(tableId, cancelledBy: currentUserName);
        await tablesProvider.loadTables();
      } else if (_cart.isNotEmpty) {
        await ordersProvider.createCancelledOrder(
          cashierName: currentUserName,
          orderType: 'TAKEAWAY',
          total: _totalAmount,
          subtotal: _subtotalAmount,
          discountAmount: _discountAmount,
          notes: 'إلغاء طلب كاشير سفري قبل الحفظ',
        );
      }

      if (mounted) {
        setState(() {
          _cart.clear();
          _existingOrderId = null;
        });

        TopNotification.showSuccess(context, 'تم إلغاء الفاتورة بنجاح ❌');
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

    final authProvider = context.read<AuthProvider>();

    if (paymentMethod == 'CREDIT') {
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
        cashierName: authProvider.currentUserName,
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
      cashierName: authProvider.currentUserName,
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




    if (!mounted) return;
    SoundService.instance.playCashRegister();
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
    CustomerModel? selectedCustomer;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final customersProvider = dialogCtx.watch<CustomersProvider>();
            final allCustomers = customersProvider.customers.where((c) {
              final nameLower = c.name.trim().toLowerCase();
              final isGeneral = c.id == 1 || nameLower == 'زبون عام (نقدي)' || nameLower.contains('زبون عام');
              return !isGeneral;
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
                      color: isDark ? const Color(0xFF1E1B4B) : Colors.indigo.shade50,
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
                        color: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.indigo.shade400 : Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'مبلغ الفاتورة الحالية المضافة للآجل:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.indigo.shade200 : Colors.indigo),
                          ),
                          Text(
                            '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.indigo.shade200 : Colors.indigo),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Dropdown Bar to select from registered debtors
                    DropdownButtonFormField<int>(
                      initialValue: selectedCustomer?.id != null && allCustomers.any((c) => c.id == selectedCustomer!.id)
                          ? selectedCustomer!.id
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'اختيار صاحب دين مسجل من القائمة 👤',
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900),
                        prefixIcon: const Icon(Icons.person_search, color: Colors.indigo),
                        suffixIcon: selectedCustomer != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                tooltip: 'إلغاء الاختيار',
                                onPressed: () {
                                  setDialogState(() {
                                    selectedCustomer = null;
                                    nameController.clear();
                                    phoneController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      hint: Text(
                        allCustomers.isEmpty
                            ? 'لا يوجد أصحاب ديون مسجلون حالياً'
                            : 'اضغط هنا لاختيار صاحب الدين من القائمة...',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      items: allCustomers.where((c) => c.id != null).map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 18, color: Colors.indigo.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${c.name} ${c.phone != null && c.phone!.isNotEmpty ? "(${c.phone})" : ""}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.balance > 0
                                      ? (isDark ? const Color(0xFF3B1E1E) : Colors.red.shade50)
                                      : (isDark ? const Color(0xFF1E3B2E) : Colors.green.shade50),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ديون سابقة: ${c.balance.toStringAsFixed(0)} $_currencySymbol',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: c.balance > 0
                                        ? (isDark ? Colors.red.shade300 : Colors.red.shade800)
                                        : (isDark ? Colors.green.shade300 : Colors.green.shade800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setDialogState(() {
                          if (id == null) {
                            selectedCustomer = null;
                            nameController.clear();
                            phoneController.clear();
                          } else {
                            final found = allCustomers.firstWhere((c) => c.id == id);
                            selectedCustomer = found;
                            nameController.text = found.name;
                            phoneController.text = found.phone ?? '';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),

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
                          color: isDark ? const Color(0xFF2E2415) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الزبون: ${nameController.text.trim()}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.amber.shade100 : Colors.black87),
                                ),
                                Text(
                                  'ديون سابقة: ${previousDebt.toStringAsFixed(0)} $_currencySymbol + الطلب: ${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
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
                              ? (isDark ? const Color(0xFF3B1E1E) : Colors.red.shade50)
                              : isBackspace
                                  ? (isDark ? const Color(0xFF3B2E1E) : Colors.orange.shade50)
                                  : (isDark ? const Color(0xFF2C394B) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isClear
                                ? (isDark ? Colors.red.shade900 : Colors.red.shade200)
                                : isBackspace
                                    ? (isDark ? Colors.orange.shade900 : Colors.orange.shade200)
                                    : (isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            key,
                            style: TextStyle(
                              fontSize: isBackspace || isClear ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: isClear
                                  ? (isDark ? Colors.red.shade300 : Colors.red)
                                  : isBackspace
                                      ? (isDark ? Colors.orange.shade300 : Colors.orange.shade900)
                                      : (isDark ? Colors.white : Colors.black87),
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
      ),
    );
  }

  Future<void> _showTransferTableDialog() async {
    final tablesProvider = context.read<TablesProvider>();
    final ordersProvider = context.read<OrdersProvider>();
    await tablesProvider.loadTables();
    if (!mounted) return;

    RestaurantTable? sourceTable = widget.selectedTable;

    // If no table was passed directly into cashier screen
    if (sourceTable == null) {
      final occupiedTables = tablesProvider.tables.where((t) => t.status == 1).toList();
      if (occupiedTables.isEmpty) {
        TopNotification.showWarning(context, 'لا توجد طاولات مشغولة حالياً لتحويلها.');
        return;
      }
      if (occupiedTables.length == 1) {
        sourceTable = occupiedTables.first;
      } else {
        sourceTable = await showDialog<RestaurantTable>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 28),
                  SizedBox(width: 8),
                  Text('اختر الطاولة المراد تحويلها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 380,
                height: 280,
                child: ListView.separated(
                  itemCount: occupiedTables.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final t = occupiedTables[idx];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.table_restaurant, color: Colors.white),
                      ),
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ],
            );
          },
        );
        if (sourceTable == null || !mounted) return;
      }
    } else {
      // If there are unsaved items in the current cart, save them first before transfer
      if (_cart.isNotEmpty && _cart.any((i) => i.isNew)) {
        final orderId = await ordersProvider.holdTableOrder(
          existingOrderId: _existingOrderId,
          tableId: sourceTable.id!,
          items: _cart,
          subtotal: _subtotalAmount,
          discountAmount: _discountAmount,
          total: _totalAmount,
          status: 'OPEN',
        );
        if (mounted) {
          setState(() {
            _existingOrderId = orderId;
            for (int i = 0; i < _cart.length; i++) {
              _cart[i] = _cart[i].copyWith(isNew: false);
            }
          });
        }
      }
    }

    if (!mounted) return;

    final availableTargetTables = tablesProvider.tables.where((t) => t.id != sourceTable!.id).toList();
    if (availableTargetTables.isEmpty) {
      TopNotification.showWarning(context, 'لا توجد طاولات أخرى متاحة للتحويل إليها.');
      return;
    }

    RestaurantTable? selectedTarget = availableTargetTables.first;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تحويل فاتورة (${sourceTable!.name})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر الطاولة التي تريد نقل تحويل الفاتورة والحساب إليها:',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RestaurantTable>(
                  initialValue: selectedTarget,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'الطاولة الهدف *',
                    prefixIcon: const Icon(Icons.table_restaurant, color: Colors.blue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  items: availableTargetTables.map((table) {
                    final isOcc = table.status == 1;
                    return DropdownMenuItem<RestaurantTable>(
                      value: table,
                      child: Text(
                        '${table.name} (${isOcc ? "مشغولة - سيتم دمج الطلبات" : "شاغرة"})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOcc ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedTarget = val;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('تأكيد التحويل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final source = sourceTable;
                  final target = selectedTarget;
                  if (source == null || target == null) return;
                  if (source.id == null || target.id == null) return;

                  Navigator.pop(ctx);

                  final targetName = target.name;
                  final sourceName = source.name;
                  final success = await ordersProvider.transferTableOrder(
                    sourceTableId: source.id!,
                    targetTableId: target.id!,
                  );

                  if (!mounted) return;
                  await tablesProvider.loadTables();
                  if (!mounted) return;
                  if (success) {
                    TopNotification.showSuccess(
                      context,
                      '🎉 تم تحويل فاتورة ($sourceName) إلى ($targetName) بنجاح!',
                    );
                    _finishOrderFlowNavigation(returnToHome: false);
                  } else {
                    TopNotification.showWarning(context, '⚠️ لا يوجد طلب مفتوح على هذه الطاولة للتحويل.');
                  }
                },
              ),
            ],
          ),
        );
      },
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

    final isEng = context.read<SettingsProvider>().isEnglish;
    final discountController = TextEditingController(
      text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(0) : '',
    );
    if (discountController.text.isNotEmpty) {
      discountController.selection = TextSelection.collapsed(offset: discountController.text.length);
    }
    final discountFocusNode = FocusNode();
    bool isPercentage = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyDiscount() {
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
            }

            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): applyDiscount,
                const SingleActivator(LogicalKeyboardKey.numpadEnter): applyDiscount,
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                title: Row(
                  children: [
                    Icon(Icons.percent, color: isDark ? const Color(0xFFD8B4FE) : Colors.purple, size: 28),
                    const SizedBox(width: 10),
                    const Text('تطبيق خصم على الفاتورة'),
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
                                selectedColor: isDark ? Colors.purple.shade800 : Colors.purple.shade100,
                                onSelected: (val) {
                                  setDialogState(() {
                                    isPercentage = false;
                                    discountFocusNode.requestFocus();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('نسبة مئوية (%)', style: TextStyle(fontSize: 12))),
                                selected: isPercentage,
                                selectedColor: isDark ? Colors.purple.shade800 : Colors.purple.shade100,
                                onSelected: (val) {
                                  setDialogState(() {
                                    isPercentage = true;
                                    discountFocusNode.requestFocus();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 14),

                      // Display Input Field
                      Theme(
                        data: Theme.of(ctx).copyWith(
                          textSelectionTheme: const TextSelectionThemeData(
                            selectionColor: Colors.transparent,
                            selectionHandleColor: Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: discountController,
                          focusNode: discountFocusNode,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          onSubmitted: (_) => applyDiscount(),
                          onChanged: (_) => setDialogState(() {}),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.purple.shade900,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            labelText: isPercentage
                                ? (isEng ? 'Discount Percentage %' : 'النسبة المئوية للخصم %')
                                : (isEng ? 'Discount Amount ($currencySym)' : 'مبلغ الخصم ($currencySym)'),
                            labelStyle: TextStyle(
                              color: isDark ? const Color(0xFFE2E8F0) : Colors.purple.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Container(
                              width: 48,
                              alignment: Alignment.center,
                              child: Text(
                                isPercentage ? '%' : (isEng ? '\$' : currencySym),
                                style: TextStyle(
                                  fontSize: isPercentage ? 20 : (isEng ? 20 : 15),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFD8B4FE) : Colors.purple.shade800,
                                ),
                              ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFFA855F7) : Colors.purple.shade200,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFFC084FC) : Colors.purple,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.purple.shade50.withValues(alpha: 0.3),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Touch Numpad
                      _buildDiscountNumpad(
                        onAppend: (digit) {
                          setDialogState(() {
                            final current = discountController.text;
                            final next = current + digit;
                            discountController.value = TextEditingValue(
                              text: next,
                              selection: TextSelection.collapsed(offset: next.length),
                            );
                          });
                        },
                        onBackspace: () {
                          setDialogState(() {
                            final current = discountController.text;
                            if (current.isNotEmpty) {
                              final next = current.substring(0, current.length - 1);
                              discountController.value = TextEditingValue(
                                text: next,
                                selection: TextSelection.collapsed(offset: next.length),
                              );
                            }
                          });
                        },
                        onClear: () {
                          setDialogState(() {
                            discountController.value = const TextEditingValue(
                              text: '',
                              selection: TextSelection.collapsed(offset: 0),
                            );
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
                  onPressed: applyDiscount,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('تطبيق الخصم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  discountFocusNode.dispose();
}

  Future<void> _openCashDrawer() async {
    final settings = context.read<SettingsProvider>();
    TopNotification.showInfo(context, '🔑 جاري إرسال إشارة فتح درج النقدية...');
    final success = await PrintService.openCashDrawer(settings);
    if (!mounted) return;

    if (success) {
      TopNotification.showSuccess(context, '🔑 تم إرسال إشارة فتح درج النقدية للطابعة بنجاح!');
    } else {
      TopNotification.showWarning(context, '⚠️ تعذر إرسال إشارة فتح الدرج! يرجى التأكد من اختيار طابعة الكاشير في الإعدادات وفحص التوصيلات.');
    }
  }

  Future<Map<String, String>?> _promptDeliveryCustomerDetails() async {
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
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
              Text(
                'يرجى إدخال رقم موبايل وعنوان الزبون المطبوعة بالفاتورة:',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
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
      );
    },
  );
}



  Widget _buildAroniumQuickActionBar(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 1. كاش (Cash)
              Expanded(
                child: _aroniumActionButton(
                  label: isEng ? 'Cash 💵' : 'الدفع Cash',
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  onTap: () => _submitOrderAndPrint(paymentMethod: 'CASH'),
                ),
              ),
              const SizedBox(width: 4),

              // 2. خصم (Discount)
              Expanded(
                child: _aroniumActionButton(
                  label: _discountAmount > 0
                      ? (isEng ? 'Disc (${_discountAmount.toStringAsFixed(0)})' : 'خصم (${_discountAmount.toStringAsFixed(0)})')
                      : (isEng ? 'Add Disc' : 'إضافة خصم'),
                  icon: Icons.percent_rounded,
                  color: Colors.purple.shade700,
                  badge: _discountAmount > 0 ? (isEng ? 'Active' : 'مفعل') : null,
                  onTap: _showDiscountDialog,
                ),
              ),
              const SizedBox(width: 4),

              // 3. تعليق الفاتورة (Hold / Park)
              Expanded(
                child: _aroniumActionButton(
                  label: isEng ? 'Hold ⏸️' : 'تعليق الفاتورة',
                  icon: Icons.pause_circle_filled_rounded,
                  color: Colors.deepOrange,
                  onTap: _holdOrderOnTable,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // 4. آجل / ديون (Credit / Debt)
              Expanded(
                child: _aroniumActionButton(
                  label: isEng ? 'Credit 📝' : 'الدفع آجل',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.indigo.shade700,
                  onTap: () => _submitOrderAndPrint(paymentMethod: 'CREDIT'),
                ),
              ),
              const SizedBox(width: 4),

              // 5. فتح الدرج (Open Drawer)
              Expanded(
                child: _aroniumActionButton(
                  label: isEng ? 'Drawer (Ctrl+D) 🔑' : 'فتح الدرج (Ctrl+D)',
                  icon: Icons.meeting_room_rounded,
                  color: Colors.teal.shade800,
                  onTap: _openCashDrawer,
                ),
              ),
              const SizedBox(width: 4),

              // 6. تحويل (Transfer)
              Expanded(
                child: _aroniumActionButton(
                  label: isEng ? 'Transfer' : 'تحويل',
                  icon: Icons.swap_horiz_rounded,
                  color: Colors.blue.shade700,
                  onTap: _showTransferTableDialog,
                ),
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveColor = isDark
        ? (color == Colors.green.shade700
            ? Colors.greenAccent.shade400
            : (color == Colors.purple.shade700
                ? Colors.purple.shade200
                : (color == Colors.indigo.shade700
                    ? Colors.indigo.shade200
                    : (color == Colors.teal.shade800
                        ? Colors.tealAccent
                        : (color == Colors.red.shade700
                            ? Colors.red.shade300
                            : (color == Colors.blue.shade700
                                ? Colors.lightBlueAccent
                                : (color == Colors.deepOrange
                                    ? Colors.deepOrange.shade300
                                    : color)))))))
        : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: isDark ? 0.22 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveColor.withValues(alpha: isDark ? 0.55 : 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: effectiveColor, size: 24),
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
                  color: effectiveColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedCategoryId = productsProvider.selectedCategoryId;
    final searchQuery = productsProvider.searchQuery;
    final showingCategoriesView = selectedCategoryId == null && searchQuery.isEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openCashDrawer,
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): _openCashDrawer,
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          body: SafeArea(
            child: _isLoadingTableOrder
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                    final cartWidth = constraints.maxWidth < 1050
                        ? 340.0
                        : (constraints.maxWidth < 1200 ? 360.0 : 380.0);

                    return Row(
                      children: [
                        // Right Pane (In RTL): Order Cart Panel + Quick Action Buttons Bar
                        Container(
                          width: cartWidth,
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (Navigator.canPop(context)) ...[
                                    IconButton(
                                      icon: const BackButtonIcon(),
                                      tooltip: isEng ? 'Back to Tables' : 'رجوع للطاولات',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _finishOrderFlowNavigation(returnToHome: false),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else ...[
                                    if (widget.onOpenMenu != null) ...[
                                      IconButton(
                                        icon: Icon(Icons.menu, size: 24, color: AppColors.primary),
                                        tooltip: isEng ? 'Main Menu' : 'القائمة الرئيسية',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: widget.onOpenMenu,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (widget.onBack != null) ...[
                                      IconButton(
                                        icon: Icon(Icons.home_outlined, size: 24, color: AppColors.primary),
                                        tooltip: isEng ? 'Home' : 'الرئيسية',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: widget.onBack,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                  if (widget.selectedTable != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3B2E1E) : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? Colors.orange.shade800 : Colors.orange.shade400, width: 1.2),
                                      ),
                                      child: Text(
                                        widget.selectedTable!.name.replaceAll(RegExp(r'[^0-9\u0660-\u0669\u06F0-\u06F9]'), '').trim().isNotEmpty
                                            ? widget.selectedTable!.name.replaceAll(RegExp(r'[^0-9\u0660-\u0669\u06F0-\u06F9]'), '').trim()
                                            : widget.selectedTable!.name,
                                        style: TextStyle(
                                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.selectedTable == null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: (_orderType == 'TAKEAWAY' || _orderType == 'DELIVERY') ? _orderType : 'TAKEAWAY',
                                      isDense: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(color: isDark ? Colors.white : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                      icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : AppColors.primary, size: 18),
                                      items: const [
                                        DropdownMenuItem(value: 'TAKEAWAY', child: Text('سفري 🛍️')),
                                        DropdownMenuItem(value: 'DELIVERY', child: Text('توصيل 🛵')),
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
                                const SizedBox(width: 6),
                              ],
                              ElevatedButton.icon(
                                onPressed: _cancelOrderAndGoHome,
                                icon: const Icon(Icons.cancel_outlined, size: 15, color: Colors.white),
                                label: Text(
                                  isEng ? 'Cancel' : 'إلغاء الفاتورة',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 1,
                                ),
                              ),
                              if (_cart.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                                  tooltip: isEng ? 'Clear Cart' : 'تفريغ السلة',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _clearCart,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 14),

                      // Cart List
                      Expanded(
                        child: _cart.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.remove_shopping_cart_outlined, size: 55, color: isDark ? Colors.grey.shade600 : Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(isEng ? 'No items in current order' : 'لا توجد أصناف في الطلب حالياً', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(isEng ? 'Select an item from the list to add' : 'اختر المادة من القائمة لإضافتها', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: _cartScrollController,
                                itemCount: _cart.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 2),
                                itemBuilder: (context, index) {
                                  final item = _cart[index];
                                  final isNew = item.isNew;
                                  final itemKey = item.id != null ? 'id_${item.id}' : 'idx_$index';
                                  final isSelected = _selectedItemKeys.contains(itemKey);

                                  final Color cardBgColor = isSelected
                                      ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                                      : (isNew ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4)) : Colors.transparent);
                                  final Border cardBorder = isSelected
                                      ? Border.all(color: const Color(0xFF3B82F6), width: 1.6)
                                      : (isNew
                                          ? Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC), width: 1.2)
                                          : Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade200, width: 0.8));
                                  final Color titleColor = isSelected
                                      ? (isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8))
                                      : (isNew ? (isDark ? Colors.green.shade300 : const Color(0xFF15803D)) : (isDark ? Colors.white : Colors.black87));
                                  final Color priceColor = isSelected
                                      ? (isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8))
                                      : (isNew ? (isDark ? Colors.green.shade300 : const Color(0xFF15803D)) : (isDark ? Colors.white70 : Colors.black87));

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: cardBorder,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          setState(() {
                                            if (_selectedItemKeys.contains(itemKey)) {
                                              _selectedItemKeys.remove(itemKey);
                                            } else {
                                              _selectedItemKeys.add(itemKey);
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      item.productName ?? (isEng ? 'Item' : 'صنف'),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: titleColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 1),
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: AlignmentDirectional.centerStart,
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${item.price.toStringAsFixed(0)} $_currencySymbol',
                                                            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
                                                          ),
                                                          if (item.formattedTime.isNotEmpty) ...[
                                                            const SizedBox(width: 5),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                              decoration: BoxDecoration(
                                                                color: isNew
                                                                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                                                                    : (isDark ? const Color(0xFF1E3A8A) : Colors.blue.shade50),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(
                                                                  color: isNew
                                                                      ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                                                                      : (isDark ? const Color(0xFF3B82F6) : Colors.blue.shade200),
                                                                  width: 0.5,
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.access_time,
                                                                    size: 9,
                                                                    color: isNew
                                                                        ? (isDark ? Colors.green.shade300 : const Color(0xFF16A34A))
                                                                        : (isDark ? Colors.blue.shade300 : Colors.blue),
                                                                  ),
                                                                  const SizedBox(width: 2),
                                                                  Text(
                                                                    item.formattedTime,
                                                                    style: TextStyle(
                                                                      color: isNew
                                                                          ? (isDark ? Colors.green.shade300 : const Color(0xFF15803D))
                                                                          : (isDark ? Colors.blue.shade300 : Colors.blue),
                                                                      fontSize: 9.5,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),

                                                    if (item.notes != null && item.notes!.isNotEmpty)
                                                      Text(
                                                        '📌 ${item.notes}',
                                                        style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              SizedBox(
                                                width: 74,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      constraints: const BoxConstraints(),
                                                      padding: const EdgeInsets.all(2),
                                                      icon: Icon(Icons.remove_circle_outline, size: 18, color: isDark ? Colors.grey.shade300 : null),
                                                      onPressed: () => _updateQuantity(index, -1),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Container(
                                                      width: 26,
                                                      height: 22,
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: isNew
                                                            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                                                            : (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.1)),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: isNew
                                                            ? Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC), width: 0.8)
                                                            : null,
                                                      ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          item.formattedQuantity,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: isNew
                                                                ? (isDark ? Colors.green.shade300 : const Color(0xFF15803D))
                                                                : (isDark ? Colors.blue.shade200 : AppColors.primary),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    IconButton(
                                                      constraints: const BoxConstraints(),
                                                      padding: const EdgeInsets.all(2),
                                                      icon: Icon(Icons.add_circle_outline, size: 18, color: isDark ? Colors.grey.shade300 : null),
                                                      onPressed: () => _updateQuantity(index, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              SizedBox(
                                                width: 65,
                                                child: Align(
                                                  alignment: AlignmentDirectional.centerEnd,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      '${item.subtotal.toStringAsFixed(0)} $_currencySymbol',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: priceColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(2),
                                                icon: Icon(Icons.close, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey),
                                                onPressed: () => _removeFromCart(index),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      const Divider(height: 14),

                      // Order Total Details
                      if (_discountAmount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Subtotal:' : 'المجموع:', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w500)),
                            Text('${_subtotalAmount.toStringAsFixed(0)} $_currencySymbol', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Discount:' : 'الخصم:', style: TextStyle(fontSize: 13, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700, fontWeight: FontWeight.bold)),
                            Text('-${_discountAmount.toStringAsFixed(0)} $_currencySymbol', style: TextStyle(fontSize: 13, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Net Total:' : 'الصافي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            Text(
                              '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.amberAccent : AppColors.primary),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isEng ? 'Grand Total:' : 'المجموع الإجمالي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            Text(
                              '${_totalAmount.toStringAsFixed(0)} $_currencySymbol',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.amberAccent : AppColors.primary),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Quick Action Buttons (Under Cart)
                      _buildAroniumQuickActionBar(context),
                    ],
                  ),
                ),

                VerticalDivider(width: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),

                // Left Pane (In RTL): Search Bar + Max-Expanded Products & Categories Grid View
                Expanded(
                  flex: 3,
                  child: Container(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Search Bar & Rearrange Mode Action Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: isEng ? 'Search item or scan barcode...' : 'ابحث عن صنف أو امسح الباركود...',
                                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                ),
                                onChanged: (val) => productsProvider.setSearchQuery(val),
                                onSubmitted: (val) {
                                  final clean = val.trim();
                                  if (clean.isEmpty) return;
                                  final match = productsProvider.products.firstWhere(
                                    (p) => (p.barcode != null && p.barcode!.trim() == clean) || p.name.trim() == clean,
                                    orElse: () => productsProvider.products.firstWhere(
                                      (p) => p.name.trim().toLowerCase().contains(clean.toLowerCase()),
                                      orElse: () => const ProductModel(name: '', price: 0),
                                    ),
                                  );
                                  if (match.name.isNotEmpty && match.id != null) {
                                    _addToCart(match);
                                    _searchController.clear();
                                    productsProvider.setSearchQuery('');
                                  } else {
                                    TopNotification.showWarning(context, isEng ? 'Item not found for barcode: $clean' : 'لم يتم العثور على صنف بالباركود: $clean');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: _isRearrangeMode ? 'إنهاء وضع ترتيب المواد' : 'ترتيب وتبديل أماكن المواد والتصنيفات',
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (!_isRearrangeMode && _searchController.text.isNotEmpty) {
                                    _searchController.clear();
                                    productsProvider.setSearchQuery('');
                                  }
                                  setState(() {
                                    _isRearrangeMode = !_isRearrangeMode;
                                    _rearrangeSelectedKey = null;
                                  });
                                },
                                icon: Icon(
                                  _isRearrangeMode ? Icons.check_circle : Icons.swap_horiz,
                                  color: _isRearrangeMode ? Colors.white : (isDark ? Colors.tealAccent : Colors.teal.shade800),
                                  size: 19,
                                ),
                                label: Text(
                                  _isRearrangeMode ? 'إنهاء الترتيب' : 'تبديل الأماكن ⇄',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: _isRearrangeMode ? Colors.white : (isDark ? Colors.tealAccent : Colors.teal.shade800),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRearrangeMode
                                      ? Colors.green.shade600
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE)),
                                  elevation: _isRearrangeMode ? 3 : 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: _isRearrangeMode
                                          ? Colors.green.shade400
                                          : (isDark ? Colors.teal.shade700 : Colors.teal.shade200),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Reorder mode instruction and reset banner
                      if (_isRearrangeMode)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF0F766E), const Color(0xFF1E293B)]
                                  : [const Color(0xFFE0F2FE), const Color(0xFFF0FDF4)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.tealAccent.shade400 : Colors.teal.shade300,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _rearrangeSelectedKey == null
                                      ? '⚡ اضغط على المادة الأولى ثم اضغط على الثانية لتبديل مكانهما، أو اسحب وأفلت ⇄'
                                      : '🎯 تم تحديد العنصر الأول! اضغط الآن على المادة أو التصنيف المراد التبديل معه.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.teal.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (_rearrangeSelectedKey != null)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() => _rearrangeSelectedKey = null);
                                  },
                                  icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                  label: const Text('إلغاء التحديد', style: TextStyle(color: Colors.redAccent, fontSize: 11.5)),
                                ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.restart_alt, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('إعادة ضبط الترتيب'),
                                        ],
                                      ),
                                      content: const Text('هل ترغب في إعادة ضبط الترتيب إلى الوضع الأبجدي الافتراضي؟'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                          child: const Text('نعم، إعادة ضبط', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    final settings = context.read<SettingsProvider>();
                                    if (showingCategoriesView) {
                                      await settings.resetCashierMainOrder();
                                    } else if (selectedCategoryId != null) {
                                      await settings.resetCategoryProductsOrder(selectedCategoryId);
                                    }
                                    setState(() {
                                      _rearrangeSelectedKey = null;
                                    });
                                    if (context.mounted) {
                                      TopNotification.showSuccess(context, 'تمت إعادة ضبط الترتيب إلى الوضع الافتراضي بنجاح');
                                    }
                                  }
                                },
                                icon: const Icon(Icons.restart_alt, size: 15),
                                label: const Text('إعادة ضبط', style: TextStyle(fontSize: 11.5)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  foregroundColor: isDark ? Colors.amberAccent : Colors.brown,
                                  side: BorderSide(
                                    color: isDark ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.brown.shade300,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Main Content View (Categories Grid OR Items Grid) - Maximized Space!
                      Expanded(
                        child: showingCategoriesView
                            ? _buildCategoriesGrid(context, categoriesProvider, productsProvider)
                            : _buildItemsGrid(context, productsProvider),
                      ),
                    ],
                  ),
                ),
              ),
              ],
            );
          },
        ),
          ),
        ),
      ),
    );
  }


  Color? _parseColor(String? hexString) {
    if (hexString == null) return null;
    final clean = hexString.trim().replaceFirst('#', '');
    if (clean.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (clean.length == 6) buffer.write('ff');
      buffer.write(clean);
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  static const List<Color> _autoItemColors = [
    Color(0xFF1D4ED8), // Royal Blue
    Color(0xFF047857), // Deep Emerald
    Color(0xFFB45309), // Amber / Gold
    Color(0xFF7E22CE), // Royal Purple
    Color(0xFFDC2626), // Crimson Red
    Color(0xFF0D9488), // Ocean Teal
    Color(0xFFEA580C), // Fiery Orange
    Color(0xFFBE185D), // Deep Rose
    Color(0xFF3730A3), // Indigo
    Color(0xFF15803D), // Forest Green
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFA16207), // Mustard Gold
    Color(0xFF6B21A8), // Imperial Purple
    Color(0xFF991B1B), // Burgundy
    Color(0xFF4D7C0F), // Olive Green
    Color(0xFF78350F), // Warm Brown
    Color(0xFF06B6D4), // Cyan
    Color(0xFF881337), // Bordeaux
    Color(0xFF334155), // Navy Slate
  ];

  static const List<Color> _autoCategoryColors = [
    Color(0xFFEA580C), // Orange
    Color(0xFF1D4ED8), // Royal Blue
    Color(0xFF7E22CE), // Purple
    Color(0xFF047857), // Emerald
    Color(0xFFBE185D), // Rose
    Color(0xFF0D9488), // Teal
    Color(0xFFB45309), // Amber
    Color(0xFFDC2626), // Red
    Color(0xFF3730A3), // Indigo
    Color(0xFF0284C7), // Sky Blue
  ];

  Color _getCategoryColor(CategoryModel category, [int index = 0]) {
    final custom = _parseColor(category.color);
    if (custom != null) return custom;
    final idVal = category.id ?? (index + 1);
    return _autoCategoryColors[idVal.abs() % _autoCategoryColors.length];
  }

  Color _getProductColor(ProductModel product, [int fallbackIndex = 0]) {
    final custom = _parseColor(product.color);
    if (custom != null) return custom;
    final key = product.id ?? (fallbackIndex + 1);
    return _autoItemColors[key.abs() % _autoItemColors.length];
  }

  Future<void> _customizeCategoryAppearance(BuildContext context, CategoryModel category) async {
    final categoriesProvider = context.read<CategoriesProvider>();
    final result = await CustomizeItemAppearanceDialog.show(
      context,
      itemName: category.name,
      initialImage: category.image,
      initialColor: category.color,
      defaultFallbackColor: _getCategoryColor(category.copyWith(clearColor: true)),
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
      defaultFallbackColor: _getProductColor(product.copyWith(clearColor: true)),
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

  List<_CashierMainGridItem> _getOrderedMainItems(
    List<CategoryModel> rawCategories,
    List<ProductModel> rawMainProducts,
    SettingsProvider settingsProvider,
  ) {
    final allItems = <_CashierMainGridItem>[
      ...rawCategories.map((c) => _CashierMainGridItem.category(c)),
      ...rawMainProducts.map((p) => _CashierMainGridItem.product(p)),
    ];

    final savedOrder = settingsProvider.getCashierMainOrder();
    if (savedOrder.isEmpty) {
      final cats = rawCategories.map((c) => _CashierMainGridItem.category(c)).toList()
        ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
      final prods = rawMainProducts.map((p) => _CashierMainGridItem.product(p)).toList()
        ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
      return [...cats, ...prods];
    }

    final orderMap = <String, int>{};
    for (int i = 0; i < savedOrder.length; i++) {
      orderMap[savedOrder[i]] = i;
    }

    allItems.sort((a, b) {
      final idxA = orderMap[a.key];
      final idxB = orderMap[b.key];
      if (idxA != null && idxB != null) return idxA.compareTo(idxB);
      if (idxA != null) return -1;
      if (idxB != null) return 1;
      return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    });

    return allItems;
  }

  List<ProductModel> _getOrderedCategoryProducts(
    List<ProductModel> rawProducts,
    int categoryId,
    SettingsProvider settingsProvider,
  ) {
    final savedOrder = settingsProvider.getCategoryProductsOrder(categoryId);
    if (savedOrder.isEmpty) {
      return List<ProductModel>.from(rawProducts)
        ..sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    }

    final orderMap = <int, int>{};
    for (int i = 0; i < savedOrder.length; i++) {
      orderMap[savedOrder[i]] = i;
    }

    final sorted = List<ProductModel>.from(rawProducts);
    sorted.sort((a, b) {
      final idA = a.id;
      final idB = b.id;
      final idxA = idA != null ? orderMap[idA] : null;
      final idxB = idB != null ? orderMap[idB] : null;
      if (idxA != null && idxB != null) return idxA.compareTo(idxB);
      if (idxA != null) return -1;
      if (idxB != null) return 1;
      return a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase());
    });
    return sorted;
  }

  Future<void> _swapMainGridItems(
    _CashierMainGridItem item1,
    _CashierMainGridItem item2,
    List<_CashierMainGridItem> currentItems,
    SettingsProvider settingsProvider,
  ) async {
    if (item1.key == item2.key) return;
    final index1 = currentItems.indexWhere((it) => it.key == item1.key);
    final index2 = currentItems.indexWhere((it) => it.key == item2.key);
    if (index1 == -1 || index2 == -1) return;

    final updated = List<_CashierMainGridItem>.from(currentItems);
    final temp = updated[index1];
    updated[index1] = updated[index2];
    updated[index2] = temp;

    final newKeys = updated.map((it) => it.key).toList();
    await settingsProvider.saveCashierMainOrder(newKeys);
    setState(() {
      _rearrangeSelectedKey = null;
    });
    if (mounted) {
      TopNotification.showSuccess(
        context,
        'تم تبديل موقع (${item1.name}) مع (${item2.name}) بنجاح ⇄',
      );
    }
  }

  Future<void> _swapCategoryProducts(
    ProductModel prod1,
    ProductModel prod2,
    int categoryId,
    List<ProductModel> currentProducts,
    SettingsProvider settingsProvider,
  ) async {
    if (prod1.id == prod2.id || prod1.id == null || prod2.id == null) return;
    final index1 = currentProducts.indexWhere((p) => p.id == prod1.id);
    final index2 = currentProducts.indexWhere((p) => p.id == prod2.id);
    if (index1 == -1 || index2 == -1) return;

    final updated = List<ProductModel>.from(currentProducts);
    final temp = updated[index1];
    updated[index1] = updated[index2];
    updated[index2] = temp;

    final newIds = updated.map((p) => p.id!).toList();
    await settingsProvider.saveCategoryProductsOrder(categoryId, newIds);
    setState(() {
      _rearrangeSelectedKey = null;
    });
    if (mounted) {
      TopNotification.showSuccess(
        context,
        'تم تبديل موقع (${prod1.name}) مع (${prod2.name}) بنجاح ⇄',
      );
    }
  }

  // 1. Grid View for Categories & Main Screen Products
  Widget _buildCategoriesGrid(
    BuildContext context,
    CategoriesProvider categoriesProvider,
    ProductsProvider productsProvider,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();
    final gridItems = _getOrderedMainItems(
      categoriesProvider.categories,
      productsProvider.mainScreenProducts,
      settingsProvider,
    );
    final totalGridItems = gridItems.length;

    if (totalGridItems == 0) {
      return const Center(
        child: Text('لا توجد تصنيفات أو مواد مخصصة للشاشة الرئيسية حالياً', style: TextStyle(fontSize: 18)),
      );
    }

    final rawItemExtent = settingsProvider.cashierItemSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemExtent = screenWidth >= 1600
        ? (rawItemExtent * 1.35).clamp(125.0, 165.0)
        : (screenWidth >= 1350
            ? (rawItemExtent * 1.2).clamp(112.0, 145.0)
            : rawItemExtent);
    final catFontSize = (itemExtent * 0.133).clamp(11.5, 17.0);
    final prodFontSize = (itemExtent * 0.127).clamp(11.0, 16.5);
    final priceFontSize = (itemExtent * 0.117).clamp(10.0, 15.5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(7),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: itemExtent,
        childAspectRatio: 1.0,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
      ),
      itemCount: totalGridItems,
      itemBuilder: (context, index) {
        final item = gridItems[index];
        final isSelectedForSwap = _isRearrangeMode && _rearrangeSelectedKey == item.key;

        Widget cardContent;

        if (item.isCategory) {
          final category = item.category!;
          final hasImage = category.image != null && category.image!.isNotEmpty && File(category.image!).existsSync();
          final bgColor = _getCategoryColor(category, index);
          final isDarkBg = hasImage || (bgColor.computeLuminance() < 0.55);
          final textColor = isDarkBg ? Colors.white : const Color(0xFF0F172A);

          cardContent = Card(
            elevation: isSelectedForSwap ? 6 : 2.5,
            shadowColor: Colors.black38,
            color: hasImage ? Colors.black : bgColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelectedForSwap
                    ? Colors.amberAccent
                    : (_isRearrangeMode
                        ? (isDark ? Colors.tealAccent.withValues(alpha: 0.6) : Colors.teal.shade300)
                        : (isDarkBg ? Colors.white.withValues(alpha: 0.22) : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)))),
                width: isSelectedForSwap ? 3.5 : (_isRearrangeMode ? 1.8 : 1.2),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_isRearrangeMode) {
                  if (_rearrangeSelectedKey == null) {
                    setState(() => _rearrangeSelectedKey = item.key);
                  } else if (_rearrangeSelectedKey == item.key) {
                    setState(() => _rearrangeSelectedKey = null);
                  } else {
                    final firstItem = gridItems.firstWhere(
                      (it) => it.key == _rearrangeSelectedKey,
                      orElse: () => item,
                    );
                    if (firstItem.key != item.key) {
                      _swapMainGridItems(firstItem, item, gridItems, settingsProvider);
                    } else {
                      setState(() => _rearrangeSelectedKey = null);
                    }
                  }
                  return;
                }
                productsProvider.selectCategory(category.id);
              },
              onSecondaryTap: () {
                if (_isRearrangeMode) return;
                _customizeCategoryAppearance(context, category);
              },
              onLongPress: () {
                if (_isRearrangeMode) return;
                _customizeCategoryAppearance(context, category);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          gradient: !hasImage
                              ? LinearGradient(
                                  colors: [
                                    bgColor.withValues(alpha: 0.88),
                                    bgColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
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
                                    fontSize: catFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    shadows: isDarkBg
                                        ? const [Shadow(color: Colors.black54, blurRadius: 2.5, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Rearrange badges
                    if (isSelectedForSwap)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'محدد للتبديل',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isRearrangeMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz, size: 12, color: Colors.cyanAccent),
                              const SizedBox(width: 2),
                              Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Main Screen Product
          final product = item.product!;
          final hasImage = product.image != null && product.image!.isNotEmpty && File(product.image!).existsSync();
          final rawBgColor = _getProductColor(product, index);
          final bgColor = product.isAvailable
              ? rawBgColor
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
          final isDarkBg = hasImage || (bgColor.computeLuminance() < 0.55);
          final textColor = isDarkBg ? Colors.white : const Color(0xFF0F172A);
          final priceColor = isDarkBg ? (isDark ? Colors.amberAccent : const Color(0xFFFEF08A)) : const Color(0xFF1E3A8A);

          cardContent = Card(
            elevation: isSelectedForSwap ? 6 : 2.5,
            shadowColor: Colors.black38,
            color: hasImage ? Colors.black : bgColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelectedForSwap
                    ? Colors.amberAccent
                    : (_isRearrangeMode
                        ? (isDark ? Colors.tealAccent.withValues(alpha: 0.6) : Colors.teal.shade300)
                        : (product.isAvailable
                            ? (isDarkBg
                                ? Colors.white.withValues(alpha: 0.22)
                                : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)))
                            : Colors.red.shade300)),
                width: isSelectedForSwap ? 3.5 : (_isRearrangeMode ? 1.8 : 1.2),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_isRearrangeMode) {
                  if (_rearrangeSelectedKey == null) {
                    setState(() => _rearrangeSelectedKey = item.key);
                  } else if (_rearrangeSelectedKey == item.key) {
                    setState(() => _rearrangeSelectedKey = null);
                  } else {
                    final firstItem = gridItems.firstWhere(
                      (it) => it.key == _rearrangeSelectedKey,
                      orElse: () => item,
                    );
                    if (firstItem.key != item.key) {
                      _swapMainGridItems(firstItem, item, gridItems, settingsProvider);
                    } else {
                      setState(() => _rearrangeSelectedKey = null);
                    }
                  }
                  return;
                }
                _addToCart(product);
              },
              onSecondaryTap: () {
                if (_isRearrangeMode) return;
                _customizeProductAppearance(context, product);
              },
              onLongPress: () {
                if (_isRearrangeMode) return;
                _customizeProductAppearance(context, product);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          gradient: (!hasImage && product.isAvailable)
                              ? (bgColor.computeLuminance() > 0.85
                                  ? (isDark
                                      ? const LinearGradient(
                                          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ))
                                  : LinearGradient(
                                      colors: [
                                        bgColor.withValues(alpha: 0.9),
                                        bgColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ))
                              : null,
                        ),
                      ),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: prodFontSize,
                                    color: textColor,
                                    shadows: isDarkBg
                                        ? const [Shadow(color: Colors.black54, blurRadius: 2.5, offset: Offset(0, 1))]
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDarkBg
                                        ? Colors.black.withValues(alpha: 0.38)
                                        : Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDarkBg
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : Colors.grey.shade400,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${product.price.toStringAsFixed(0)} $_currencySymbol',
                                    style: TextStyle(
                                      color: priceColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: priceFontSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (!product.isAvailable)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('غير متوفر', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // Rearrange badges
                    if (isSelectedForSwap)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                'محدد للتبديل',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isRearrangeMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz, size: 12, color: Colors.cyanAccent),
                              const SizedBox(width: 2),
                              Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!_isRearrangeMode) {
          return cardContent;
        }

        return DragTarget<_CashierMainGridItem>(
          onWillAcceptWithDetails: (details) => details.data.key != item.key,
          onAcceptWithDetails: (details) {
            _swapMainGridItems(details.data, item, gridItems, settingsProvider);
          },
          builder: (context, candidateData, rejectedData) {
            final isTargetOver = candidateData.isNotEmpty;
            return Draggable<_CashierMainGridItem>(
              data: item,
              feedback: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
                child: SizedBox(
                  width: itemExtent,
                  height: itemExtent,
                  child: Opacity(
                    opacity: 0.9,
                    child: cardContent,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: cardContent,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: isTargetOver
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: cardContent,
              ),
            );
          },
        );
      },
    );
  }



  // 2. Grid View for Items/Products
  Widget _buildItemsGrid(BuildContext context, ProductsProvider productsProvider) {
    final settingsProvider = context.watch<SettingsProvider>();
    final selectedCatId = productsProvider.selectedCategoryId;
    final rawProducts = productsProvider.cashierProducts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<ProductModel> products;
    if (selectedCatId != null && productsProvider.searchQuery.isEmpty) {
      products = _getOrderedCategoryProducts(rawProducts, selectedCatId, settingsProvider);
    } else {
      products = rawProducts;
    }

    final totalGridItems = products.length + 1;

    final rawItemExtent = settingsProvider.cashierItemSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemExtent = screenWidth >= 1600
        ? (rawItemExtent * 1.35).clamp(125.0, 165.0)
        : (screenWidth >= 1350
            ? (rawItemExtent * 1.2).clamp(112.0, 145.0)
            : rawItemExtent);
    final prodFontSize = (itemExtent * 0.127).clamp(11.0, 16.5);
    final priceFontSize = (itemExtent * 0.117).clamp(10.0, 15.5);

    return GridView.builder(
      padding: const EdgeInsets.all(7),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: itemExtent,
        childAspectRatio: 1.0,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
      ),
      itemCount: totalGridItems,
      itemBuilder: (context, index) {
        if (index == 0) {
          return InkWell(
            onTap: () {
              setState(() {
                _rearrangeSelectedKey = null;
              });
              productsProvider.selectCategory(null);
              productsProvider.setSearchQuery('');
            },
            child: Card(
              elevation: 2.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark ? const Color(0xFF3F3F46) : Colors.grey.shade400,
                  width: 1.2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? const Color(0xFF27272A) : Colors.white,
                ),
                padding: const EdgeInsets.all(4),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: isDark ? const Color(0xFF3F3F46) : Colors.white,
                        child: Icon(
                          Icons.arrow_back,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'الرجوع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '← القائمة',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                          fontSize: 10.5,
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
        final productKey = 'prod_${product.id}';
        final isSelectedForSwap = _isRearrangeMode && _rearrangeSelectedKey == productKey;

        final hasImage = product.image != null && product.image!.isNotEmpty && File(product.image!).existsSync();
        final rawBgColor = _getProductColor(product, index - 1);
        final bgColor = product.isAvailable
            ? rawBgColor
            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
        final isDarkBg = hasImage || (bgColor.computeLuminance() < 0.55);
        final textColor = isDarkBg ? Colors.white : const Color(0xFF0F172A);
        final priceColor = isDarkBg ? (isDark ? Colors.amberAccent : const Color(0xFFFEF08A)) : const Color(0xFF1E3A8A);

        Widget cardContent = Card(
          elevation: isSelectedForSwap ? 6 : 2.5,
          shadowColor: Colors.black38,
          color: hasImage ? Colors.black : bgColor,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelectedForSwap
                  ? Colors.amberAccent
                  : (_isRearrangeMode
                      ? (isDark ? Colors.tealAccent.withValues(alpha: 0.6) : Colors.teal.shade300)
                      : (product.isAvailable
                          ? (isDarkBg
                              ? Colors.white.withValues(alpha: 0.22)
                              : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)))
                          : Colors.red.shade300)),
              width: isSelectedForSwap ? 3.5 : (_isRearrangeMode ? 1.8 : 1.2),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (_isRearrangeMode) {
                if (_rearrangeSelectedKey == null) {
                  setState(() => _rearrangeSelectedKey = productKey);
                } else if (_rearrangeSelectedKey == productKey) {
                  setState(() => _rearrangeSelectedKey = null);
                } else {
                  final firstProd = products.firstWhere(
                    (p) => 'prod_${p.id}' == _rearrangeSelectedKey,
                    orElse: () => product,
                  );
                  if (firstProd.id != product.id && selectedCatId != null) {
                    _swapCategoryProducts(firstProd, product, selectedCatId, products, settingsProvider);
                  } else {
                    setState(() => _rearrangeSelectedKey = null);
                  }
                }
                return;
              }
              _addToCart(product);
            },
            onSecondaryTap: () {
              if (_isRearrangeMode) return;
              _customizeProductAppearance(context, product);
            },
            onLongPress: () {
              if (_isRearrangeMode) return;
              _customizeProductAppearance(context, product);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        gradient: (!hasImage && product.isAvailable)
                            ? (bgColor.computeLuminance() > 0.85
                                ? (isDark
                                    ? const LinearGradient(
                                        colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ))
                                : LinearGradient(
                                    colors: [
                                      bgColor.withValues(alpha: 0.9),
                                      bgColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ))
                            : null,
                      ),
                    ),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: prodFontSize,
                                  color: textColor,
                                  shadows: isDarkBg
                                      ? const [Shadow(color: Colors.black54, blurRadius: 2.5, offset: Offset(0, 1))]
                                      : null,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDarkBg
                                      ? Colors.black.withValues(alpha: 0.38)
                                      : Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDarkBg
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.grey.shade400,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${product.price.toStringAsFixed(0)} $_currencySymbol',
                                  style: TextStyle(
                                    color: priceColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: priceFontSize,
                                  ),
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

                  if (!product.isAvailable)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text('غير متوفر', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  // Rearrange badges
                  if (isSelectedForSwap)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'محدد للتبديل',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isRearrangeMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz, size: 12, color: Colors.cyanAccent),
                            const SizedBox(width: 2),
                            Text(
                              '$index',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        if (!_isRearrangeMode || selectedCatId == null) {
          return cardContent;
        }

        return DragTarget<ProductModel>(
          onWillAcceptWithDetails: (details) => details.data.id != product.id,
          onAcceptWithDetails: (details) {
            _swapCategoryProducts(details.data, product, selectedCatId, products, settingsProvider);
          },
          builder: (context, candidateData, rejectedData) {
            final isTargetOver = candidateData.isNotEmpty;
            return Draggable<ProductModel>(
              data: product,
              feedback: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                color: Colors.transparent,
                child: SizedBox(
                  width: itemExtent,
                  height: itemExtent,
                  child: Opacity(
                    opacity: 0.9,
                    child: cardContent,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: cardContent,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: isTargetOver
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : null,
                child: cardContent,
              ),
            );
          },
        );
      },
    );
  }
}

class _CashierMainGridItem {
  final String key;
  final CategoryModel? category;
  final ProductModel? product;

  _CashierMainGridItem.category(this.category)
      : key = 'cat_${category!.id}',
        product = null;

  _CashierMainGridItem.product(this.product)
      : key = 'prod_${product!.id}',
        category = null;

  bool get isCategory => category != null;
  String get name => isCategory ? category!.name : product!.name;
}
