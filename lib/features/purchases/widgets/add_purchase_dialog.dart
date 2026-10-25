import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/top_notification.dart';
import '../../../models/product.dart';
import '../../../models/purchase.dart';
import '../../../models/supplier.dart';
import '../../products/products_provider.dart';
import '../../settings/settings_provider.dart';
import '../purchases_provider.dart';
import 'add_supplier_dialog.dart';

class AddPurchaseDialog extends StatefulWidget {
  const AddPurchaseDialog({super.key});

  @override
  State<AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends State<AddPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  SupplierModel? _selectedSupplier;
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _quickSearchController = TextEditingController();
  final FocusNode _quickSearchFocusNode = FocusNode();

  String _paymentStatus = 'PAID'; // 'PAID', 'PARTIAL', 'UNPAID'
  String _paymentMethod = 'CASH';
  bool _updateInventory = true;

  final List<_TempPurchaseItem> _items = [];

  @override
  void initState() {
    super.initState();
    _invoiceNumberController.text = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    // Add default initial empty item row
    _items.add(_TempPurchaseItem());
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    _quickSearchController.dispose();
    _quickSearchFocusNode.dispose();
    super.dispose();
  }

  void _addProductToInvoice(ProductModel prod) {
    setState(() {
      // Check if product already exists in items
      final existingIndex = _items.indexWhere((it) => it.selectedProduct?.id == prod.id && prod.id != null);
      if (existingIndex >= 0) {
        // Increment quantity
        final currentQty = double.tryParse(_items[existingIndex].qtyController.text.trim()) ?? 1.0;
        final nextQty = currentQty + 1;
        _items[existingIndex].qtyController.text = nextQty == nextQty.roundToDouble()
            ? nextQty.toStringAsFixed(0)
            : nextQty.toStringAsFixed(2);
      } else {
        // Check if the only existing item row is empty and unused
        if (_items.length == 1 && _items[0].selectedProduct == null && _items[0].nameController.text.isEmpty) {
          _items[0].selectedProduct = prod;
          _items[0].nameController.text = prod.name;
          if (prod.buyPrice > 0) {
            _items[0].priceController.text = prod.buyPrice.toStringAsFixed(0);
          }
          _items[0].qtyController.text = '1';
        } else {
          // Add new item
          final newItem = _TempPurchaseItem();
          newItem.selectedProduct = prod;
          newItem.nameController.text = prod.name;
          if (prod.buyPrice > 0) {
            newItem.priceController.text = prod.buyPrice.toStringAsFixed(0);
          }
          newItem.qtyController.text = '1';
          _items.add(newItem);
        }
      }
    });
  }

  void _handleQuickAdd(String query, List<ProductModel> products, bool isEng) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    // 1. Try exact barcode match
    ProductModel? match = products.where((p) => p.barcode != null && p.barcode!.trim().toLowerCase() == q).firstOrNull;

    // 2. Try exact name match
    match ??= products.where((p) => p.name.trim().toLowerCase() == q).firstOrNull;

    // 3. Try partial name or barcode match
    if (match == null) {
      final matches = products.where((p) {
        final name = p.name.toLowerCase();
        final barcode = (p.barcode ?? '').toLowerCase();
        return name.contains(q) || barcode.contains(q);
      }).toList();

      if (matches.length == 1) {
        match = matches.first;
      } else if (matches.length > 1) {
        _showProductSearchDialog(context, matches, Theme.of(context).brightness == Brightness.dark, isEng).then((res) {
          if (res is ProductModel) {
            _addProductToInvoice(res);
            _quickSearchController.clear();
            _quickSearchFocusNode.requestFocus();
          }
        });
        return;
      }
    }

    if (match != null) {
      _addProductToInvoice(match);
      _quickSearchController.clear();
      _quickSearchFocusNode.requestFocus();
      TopNotification.showSuccess(context, isEng ? 'Added [${match.name}]' : 'تمت إضافة [${match.name}]');
    } else {
      TopNotification.showWarning(
        context,
        isEng ? 'No product found with barcode/name "$query"' : 'لم يتم العثور على مادة بالباركود أو الاسم "$query"',
      );
    }
  }

  Future<dynamic> _showProductSearchDialog(
    BuildContext context,
    List<ProductModel> products,
    bool isDark,
    bool isEng,
  ) async {
    return await showDialog<dynamic>(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchQuery.trim().toLowerCase();
            final filtered = products.where((p) {
              if (query.isEmpty) return true;
              final name = p.name.toLowerCase();
              final barcode = (p.barcode ?? '').toLowerCase();
              return name.contains(query) || barcode.contains(query);
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.teal, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isEng ? 'Search Product (Name / Barcode)' : 'البحث عن مادة (بالاسم أو الباركود)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: isEng
                            ? 'Search by name or scan barcode...'
                            : 'اكتب اسم المادة أو امسح الباركود مباشرة...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModalState(() => searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                      onSubmitted: (val) {
                        if (filtered.isNotEmpty) {
                          Navigator.pop(ctx, filtered.first);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    // Option: New Custom Item
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pop(ctx, 'CUSTOM');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF132A25) : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note, color: Colors.teal, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEng ? '✏️ New Custom Item (Not registered)' : '✏️ إدخال مادة مخصصة جديدة (غير مسجلة في النظام)',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${isEng ? "Results:" : "عدد المواد المطابقة:"} ${filtered.length}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 45, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    isEng ? 'No matching products found.' : 'لا توجد مواد مطابقة للبحث.',
                                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                              itemBuilder: (context, idx) {
                                final p = filtered[idx];
                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                    child: const Icon(Icons.inventory_2, size: 18, color: Colors.teal),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      if (p.barcode != null && p.barcode!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.qr_code, size: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                              const SizedBox(width: 3),
                                              Text(
                                                p.barcode!,
                                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Text(
                                        'سعر الشراء: ${p.buyPrice.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                      Text(
                                        'المخزون الحالي: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.teal.shade300 : Colors.teal.shade800),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  onTap: () {
                                    Navigator.pop(ctx, p);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _calculatedTotalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _calculatedPaidAmount {
    if (_paymentStatus == 'PAID') return _calculatedTotalAmount;
    if (_paymentStatus == 'UNPAID') return 0.0;
    return double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  }

  double get _calculatedRemainingAmount {
    final rem = _calculatedTotalAmount - _calculatedPaidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    final purchasesProvider = context.watch<PurchasesProvider>();
    final productsProvider = context.watch<ProductsProvider>();
    final currencySymbol = settings.currencySymbol;
    final suppliers = purchasesProvider.suppliers;
    final products = productsProvider.products;

    final totalAmount = _calculatedTotalAmount;
    final paidAmount = _calculatedPaidAmount;
    final remainingAmount = _calculatedRemainingAmount;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 850,
        height: 720,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Dialog Header
              Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? 'Record New Purchase Invoice 📦' : 'تسجيل فاتورة مشتريات جديدة 📦',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Supplier & Invoice Number
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Supplier Selector
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<SupplierModel>(
                                    initialValue: suppliers.where((s) => s.id == _selectedSupplier?.id).firstOrNull,
                                    dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      labelText: isEng ? 'Select Supplier *' : 'اختر المورد *',
                                      labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                      prefixIcon: Icon(Icons.business, color: isDark ? Colors.grey.shade400 : null),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      isDense: true,
                                    ),
                                    items: suppliers.map((s) {
                                      return DropdownMenuItem<SupplierModel>(
                                        value: s,
                                        child: Text(
                                          '${s.name} ${s.phone != null && s.phone!.isNotEmpty ? "(${s.phone})" : ""}',
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                        ),
                                      );
                                    }).toList(),
                                    validator: (val) => val == null ? (isEng ? 'Please select supplier' : 'يرجى اختيار المورد') : null,
                                    onChanged: (val) {
                                      setState(() => _selectedSupplier = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: isEng ? 'Add New Supplier' : 'إضافة مورد جديد',
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (_) => const AddSupplierDialog(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Invoice / Receipt Number
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _invoiceNumberController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Receipt / Invoice No *' : 'رقم الوصل / الفاتورة *',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                prefixIcon: Icon(Icons.receipt, color: isDark ? Colors.grey.shade400 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? (isEng ? 'Please enter receipt number' : 'يرجى كتابة رقم الوصل') : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Items Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEng ? 'Purchased Items & Details:' : 'تفاصيل المواد والمشتريات:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            label: Text(isEng ? 'Add Item' : 'إضافة مادة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                _items.add(_TempPurchaseItem());
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Quick Barcode & Search Bar Above Table
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.teal.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: _quickSearchController,
                                  focusNode: _quickSearchFocusNode,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: isEng
                                        ? '🔍 Scan barcode or type item name to add instantly...'
                                        : '🔍 امسح الباركود أو اكتب اسم المادة للإضافة الفورية للفاتورة...',
                                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
                                    prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                                    suffixIcon: _quickSearchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _quickSearchController.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  ),
                                  onSubmitted: (val) => _handleQuickAdd(val, products, isEng),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: Text(isEng ? 'Add' : 'إضافة', style: const TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _handleQuickAdd(_quickSearchController.text, products, isEng),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.search, size: 18),
                              label: Text(isEng ? 'Search List 🔍' : 'قائمة المواد 🔍', style: const TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final res = await _showProductSearchDialog(context, products, isDark, isEng);
                                if (res is ProductModel) {
                                  _addProductToInvoice(res);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Dynamic Purchase Items Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? const Color(0xFF111827) : Colors.grey.shade50,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            // Table Header Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    isEng ? 'Item / Product Name' : 'اسم المادة / المنتج',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    isEng ? 'Buy Price ($currencySymbol)' : 'سعر الشراء ($currencySymbol)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    isEng ? 'Purchased Qty' : 'الكمية المشتراة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    isEng ? 'Subtotal' : 'المجموع',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 40), // Delete button space
                              ],
                            ),
                            Divider(height: 12, color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),

                            // Rows list
                            for (int i = 0; i < _items.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product selection or Custom name
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () async {
                                              final res = await _showProductSearchDialog(context, products, isDark, isEng);
                                              if (res is ProductModel) {
                                                setState(() {
                                                  _items[i].selectedProduct = res;
                                                  _items[i].nameController.text = res.name;
                                                  if (res.buyPrice > 0) {
                                                    _items[i].priceController.text = res.buyPrice.toStringAsFixed(0);
                                                  }
                                                });
                                              } else if (res == 'CUSTOM') {
                                                setState(() {
                                                  _items[i].selectedProduct = null;
                                                  _items[i].nameController.clear();
                                                });
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isDark ? const Color(0xFF4B5563) : Colors.grey.shade400),
                                                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _items[i].selectedProduct != null ? Icons.inventory_2_outlined : Icons.edit_note,
                                                    size: 18,
                                                    color: Colors.teal,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _items[i].selectedProduct != null
                                                          ? '${_items[i].selectedProduct!.name}${_items[i].selectedProduct!.barcode != null && _items[i].selectedProduct!.barcode!.isNotEmpty ? " [${_items[i].selectedProduct!.barcode}]" : ""}'
                                                          : (_items[i].nameController.text.isNotEmpty
                                                              ? _items[i].nameController.text
                                                              : (isEng ? '🔍 Click to search by name/barcode...' : '🔍 اضغط للبحث بالاسم أو الباركود...')),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: _items[i].selectedProduct != null || _items[i].nameController.text.isNotEmpty
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: _items[i].selectedProduct != null || _items[i].nameController.text.isNotEmpty
                                                            ? (isDark ? Colors.white : Colors.black87)
                                                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.search, size: 13, color: Colors.teal),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          isEng ? 'Search' : 'بحث',
                                                          style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_items[i].selectedProduct == null) ...[
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _items[i].nameController,
                                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                hintText: isEng ? 'Type custom item name *' : 'اكتب اسم المادة هنا *',
                                                hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                prefixIcon: const Icon(Icons.edit_note, size: 18, color: Colors.teal),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Unit Buy Price Field
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _items[i].priceController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          hintText: isEng ? 'Price' : 'السعر',
                                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Quantity Field
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _items[i].qtyController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          hintText: isEng ? 'Qty' : 'الكمية',
                                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Subtotal
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${_items[i].subtotal.toStringAsFixed(0)} $currencySymbol',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    // Delete Row
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                      onPressed: _items.length > 1
                                          ? () {
                                              setState(() {
                                                _items.removeAt(i);
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Checkbox: Update Inventory Automatically
                      CheckboxListTile(
                        value: _updateInventory,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isEng ? 'Update stock quantity & buy price in inventory automatically 📦' : 'تحديث كميات المواد وسعر الشراء بالمخزن تلقائياً 📦',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          isEng ? 'When enabled, purchased quantities will be immediately added to system stock' : 'عند التفعيل سيتم إضافة الكمية المشتراة فوراً إلى مخزون المنتج بالسيستم',
                          style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _updateInventory = val);
                        },
                      ),
                      Divider(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),

                      // Payment Status & Calculations Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF111827) : Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.blueGrey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  isEng ? 'Invoice Payment Status:' : 'حالة دفع الفاتورة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ChoiceChip(
                                  label: Text(
                                    isEng ? 'Fully Paid 🟢' : 'مدفوعة بالكامل 🟢',
                                    style: TextStyle(
                                      color: _paymentStatus == 'PAID' ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected: _paymentStatus == 'PAID',
                                  selectedColor: isDark ? Colors.green.shade800 : Colors.green.shade100,
                                  backgroundColor: isDark ? const Color(0xFF374151) : null,
                                  onSelected: (val) {
                                    if (val) setState(() => _paymentStatus = 'PAID');
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(
                                    isEng ? 'Partially Paid 🟡' : 'مدفوعة جزئياً 🟡',
                                    style: TextStyle(
                                      color: _paymentStatus == 'PARTIAL' ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected: _paymentStatus == 'PARTIAL',
                                  selectedColor: isDark ? Colors.orange.shade800 : Colors.orange.shade100,
                                  backgroundColor: isDark ? const Color(0xFF374151) : null,
                                  onSelected: (val) {
                                    if (val) setState(() => _paymentStatus = 'PARTIAL');
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(
                                    isEng ? 'Unpaid / Credit 🔴' : 'غير مدفوعة (آجل) 🔴',
                                    style: TextStyle(
                                      color: _paymentStatus == 'UNPAID' ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected: _paymentStatus == 'UNPAID',
                                  selectedColor: isDark ? Colors.red.shade800 : Colors.red.shade100,
                                  backgroundColor: isDark ? const Color(0xFF374151) : null,
                                  onSelected: (val) {
                                    if (val) setState(() => _paymentStatus = 'UNPAID');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            if (_paymentStatus == 'PARTIAL') ...[
                              TextFormField(
                                controller: _paidAmountController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  labelText: isEng ? 'Currently Paid Amount ($currencySymbol) *' : 'المبلغ المدفوع حلياً ($currencySymbol) *',
                                  labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Center(
                                      widthFactor: 1.0,
                                      heightFactor: 1.0,
                                      child: Text(
                                        currencySymbol,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.orange.shade300 : Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Summary Amounts Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryBox(
                                  isEng ? 'Total Invoice' : 'إجمالي الفاتورة',
                                  '${totalAmount.toStringAsFixed(0)} $currencySymbol',
                                  isDark ? const Color(0xFF818CF8) : Colors.indigo,
                                  isDark,
                                ),
                                _buildSummaryBox(
                                  isEng ? 'Paid Amount' : 'المبلغ المدفوع',
                                  '${paidAmount.toStringAsFixed(0)} $currencySymbol',
                                  isDark ? const Color(0xFF34D399) : Colors.green.shade800,
                                  isDark,
                                ),
                                _buildSummaryBox(
                                  isEng ? 'Supplier Remaining Debt' : 'الدين المتبقي للمورد',
                                  '${remainingAmount.toStringAsFixed(0)} $currencySymbol',
                                  isDark ? const Color(0xFFF87171) : Colors.red.shade800,
                                  isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Payment Method & Notes
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Payment Method' : 'طريقة الدفع',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                prefixIcon: Icon(Icons.payment, color: isDark ? Colors.grey.shade400 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'CASH',
                                  child: Text(
                                    isEng ? 'Cash (Drawer Treasury)' : 'نقداً (من الخزينة)',
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'BANK',
                                  child: Text(
                                    isEng ? 'Bank Transfer' : 'تحويل بانكي',
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _paymentMethod = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _notesController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Invoice Notes' : 'ملاحظات الفاتورة',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                prefixIcon: Icon(Icons.note_alt_outlined, color: isDark ? Colors.grey.shade400 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Save Action Button Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey.shade300 : null,
                    ),
                    child: Text(isEng ? 'Cancel' : 'إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      isEng ? 'Save & Record Invoice' : 'حفظ وتسجيل الفاتورة',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;

                      if (_selectedSupplier == null) {
                        TopNotification.showWarning(context, isEng ? 'Please select supplier first.' : 'يرجى اختيار المورد أولاً.');
                        return;
                      }

                      if (totalAmount <= 0) {
                        TopNotification.showWarning(context, isEng ? 'Please enter valid items and prices greater than 0.' : 'يرجى إدخال مواد وأسعار صالحة أكبر من 0.');
                        return;
                      }

                      final purchaseItems = <PurchaseItemModel>[];
                      for (var itemRow in _items) {
                        final name = itemRow.nameController.text.trim();
                        final price = double.tryParse(itemRow.priceController.text.trim()) ?? 0.0;
                        final qty = double.tryParse(itemRow.qtyController.text.trim()) ?? 0.0;
                        if (name.isNotEmpty && qty > 0) {
                          purchaseItems.add(
                            PurchaseItemModel(
                              productId: itemRow.selectedProduct?.id,
                              itemName: name,
                              unitPrice: price,
                              quantity: qty,
                              subtotal: price * qty,
                            ),
                          );
                        }
                      }

                      if (purchaseItems.isEmpty) {
                        TopNotification.showWarning(context, isEng ? 'Please enter at least one item with quantity and price.' : 'يرجى إدخال مادة واحدة على الأقل بالكمية والسعر.');
                        return;
                      }

                      final invoice = PurchaseInvoiceModel(
                        supplierId: _selectedSupplier!.id!,
                        supplierName: _selectedSupplier!.name,
                        invoiceNumber: _invoiceNumberController.text.trim(),
                        totalAmount: totalAmount,
                        paidAmount: paidAmount,
                        remainingAmount: remainingAmount,
                        paymentStatus: _paymentStatus,
                        paymentMethod: _paymentMethod,
                        notes: _notesController.text.trim(),
                        createdAt: DateTime.now().toIso8601String(),
                        items: purchaseItems,
                      );

                      final provider = context.read<PurchasesProvider>();
                      final success = await provider.addPurchaseInvoice(
                        invoice: invoice,
                        updateInventory: _updateInventory,
                      );

                      if (!context.mounted) return;
                      if (success) {
                        TopNotification.showSuccess(context, isEng ? '🎉 Purchase invoice saved and accounts updated successfully!' : '🎉 تم حفظ فاتورة المشتريات وتحديث الحسابات بنجاح!');
                      } else {
                        TopNotification.showWarning(context, isEng ? '⚠️ Error saving invoice.' : '⚠️حدث خطأ أثناء حفظ الفاتورة.');
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.6 : 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _TempPurchaseItem {
  ProductModel? selectedProduct;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController(text: '0');
  final TextEditingController qtyController = TextEditingController(text: '1');

  double get subtotal {
    final p = double.tryParse(priceController.text.trim()) ?? 0.0;
    final q = double.tryParse(qtyController.text.trim()) ?? 0.0;
    return p * q;
  }
}
