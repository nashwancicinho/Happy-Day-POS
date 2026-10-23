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
    super.dispose();
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
                      const SizedBox(height: 8),

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
                                          DropdownButtonFormField<ProductModel?>(
                                            initialValue: _items[i].selectedProduct,
                                            dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              hintText: isEng ? 'Select or custom item' : 'اختر مادة أو اكتب اسمها',
                                              hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            ),
                                            items: [
                                              DropdownMenuItem<ProductModel?>(
                                                value: null,
                                                child: Text(
                                                  isEng ? '✏️ New Custom Item' : '✏️ مادة مخصصة جديدة',
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFF2DD4BF) : Colors.teal.shade800,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              ...products.map((p) {
                                                return DropdownMenuItem<ProductModel?>(
                                                  value: p,
                                                  child: Text(
                                                    p.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ],
                                            onChanged: (prod) {
                                              setState(() {
                                                _items[i].selectedProduct = prod;
                                                if (prod != null) {
                                                  _items[i].nameController.text = prod.name;
                                                  if (prod.buyPrice > 0) {
                                                    _items[i].priceController.text = prod.buyPrice.toStringAsFixed(0);
                                                  }
                                                } else {
                                                  _items[i].nameController.clear();
                                                }
                                              });
                                            },
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
