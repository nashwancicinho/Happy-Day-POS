import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../categories/categories_provider.dart';
import '../../settings/settings_provider.dart';
import '../products_provider.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySym = settingsProvider.currencySymbol;
    final isEng = settingsProvider.isEnglish;

    String formatUnit(String rawUnit) {
      if (!isEng) return rawUnit;
      switch (rawUnit) {
        case 'قطعة':
          return 'Piece';
        case 'كيلوغرام':
          return 'kg';
        case 'غرام':
          return 'g';
        case 'لتر':
          return 'L';
        case 'علبة':
          return 'Box/Can';
        case 'طقم':
          return 'Set';
        case 'متر':
          return 'Meter';
        case 'كارتون':
          return 'Carton';
        default:
          return rawUnit;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Products & Items Management' : 'إدارة الأصناف والمواد الشاملة'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business),
        label: Text(isEng ? 'Add New Product ➕' : 'إضافة مادة / صنف جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search & Filter Header
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isEng ? 'Search product or barcode...' : 'بحث باسم الصنف أو الباركود...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => productsProvider.setSearchQuery(val),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: productsProvider.selectedCategoryId,
                        hint: Text(isEng ? 'All Categories' : 'كل التصنيفات', style: const TextStyle(fontSize: 13)),
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(isEng ? 'All Categories' : 'جميع التصنيفات', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ...categoriesProvider.categories.map((cat) {
                            final cName = (cat.name == 'عام' && isEng) ? 'General' : cat.name;
                            return DropdownMenuItem<int?>(
                              value: cat.id,
                              child: Text(cName, style: const TextStyle(fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) => productsProvider.selectCategory(val),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Products Table View
            Expanded(
              child: productsProvider.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 60, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            isEng ? 'No products matching search criteria' : 'لا توجد مواد مطابقة للبحث',
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 950),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.orange.shade50),
                              columns: [
                                const DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Item Name / Barcode' : 'اسم الصنف / الباركود', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Category' : 'التصنيف', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Cost (Buy)' : 'الكلُفة (الشراء)', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Sale Price' : 'سعر البيع', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Profit' : 'الربح', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Unit & Weight' : 'الوحدة والوزن', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Stock' : 'المخزون', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Status' : 'الحالة', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text(isEng ? 'Actions' : 'العمليات', style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: productsProvider.products.map((product) {
                                final rawCat = categoriesProvider.categories
                                    .firstWhere(
                                      (c) => c.id == product.categoryId,
                                      orElse: () => const CategoryModel(name: 'عام'),
                                    )
                                    .name;
                                final catName = (rawCat == 'عام' && isEng) ? 'General' : rawCat;

                                return DataRow(
                                  cells: [
                                    DataCell(Text('#${product.id}')),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (product.barcode != null && product.barcode!.isNotEmpty)
                                            Text(
                                              isEng ? 'Barcode: ${product.barcode}' : 'باركود: ${product.barcode}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Chip(
                                      label: Text(catName, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.blue.shade50,
                                    )),
                                    DataCell(Text('${product.buyPrice.toStringAsFixed(0)} $currencySym')),
                                    DataCell(Text(
                                      '${product.price.toStringAsFixed(0)} $currencySym',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    )),
                                    DataCell(Text(
                                      '${product.profitMargin.toStringAsFixed(0)} $currencySym',
                                      style: TextStyle(
                                        color: product.profitMargin >= 0 ? Colors.green.shade800 : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        children: [
                                          Text(formatUnit(product.unit)),
                                          if (product.isWeighted) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isEng ? 'Weighted' : 'موزونة',
                                                style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      product.trackStock
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: product.isLowStock ? Colors.red.shade50 : Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: product.isLowStock ? Colors.red.shade300 : Colors.green.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                '${product.stockQuantity.toStringAsFixed(0)} ${formatUnit(product.unit)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: product.isLowStock ? Colors.red.shade900 : Colors.green.shade900,
                                                ),
                                              ),
                                            )
                                          : Text(isEng ? 'Untracked' : 'غير متتبع'),
                                    ),
                                    DataCell(
                                      Switch(
                                        value: product.isAvailable,
                                        activeTrackColor: AppColors.success,
                                        onChanged: (_) {
                                          productsProvider.toggleAvailability(product);
                                        },
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.qr_code_scanner, color: Colors.purple),
                                            tooltip: isEng ? 'Print Barcode Label' : 'طباعة ملصق الباركود',
                                            onPressed: () => _showPrintBarcodeQuantityDialog(context, product),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: isEng ? 'Edit Product' : 'تعديل البيانات',
                                            onPressed: () => _showProductDialog(context, product: product),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: isEng ? 'Delete Product' : 'حذف المادة',
                                            onPressed: () => productsProvider.deleteProduct(product.id!),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, {ProductModel? product}) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final buyPriceController = TextEditingController(text: product != null ? product.buyPrice.toStringAsFixed(0) : '0');
    final sellPriceController = TextEditingController(text: product != null ? product.price.toStringAsFixed(0) : '');
    final stockController = TextEditingController(text: product != null ? product.stockQuantity.toStringAsFixed(0) : '100');
    final minStockController = TextEditingController(text: product != null ? product.minStock.toStringAsFixed(0) : '5');

    int? selectedCatId = product?.categoryId;
    String selectedUnit = product?.unit ?? 'قطعة';
    bool isWeighted = product?.isWeighted ?? false;
    bool allowPriceChange = product?.allowPriceChange ?? false;
    bool trackStock = product?.trackStock ?? false;
    bool isAvailable = product?.isAvailable ?? true;
    bool printToKitchen = product?.printToKitchen ?? true;
    String? selectedKitchenPrinter = product?.kitchenPrinter;

    List<dynamic> systemPrinters = [];
    bool isPrintersLoaded = false;

    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final categories = context.read<CategoriesProvider>().categories;
    if (selectedCatId == null && categories.isNotEmpty) {
      selectedCatId = categories.first.id;
    }

    final availableUnits = ['قطعة', 'كيلوغرام', 'غرام', 'لتر', 'علبة', 'طقم', 'متر', 'كارتون'];

    String formatUnitName(String raw) {
      if (!isEng) return raw;
      switch (raw) {
        case 'قطعة':
          return 'Piece (قطعة)';
        case 'كيلوغرام':
          return 'Kilogram (kg)';
        case 'غرام':
          return 'Gram (g)';
        case 'لتر':
          return 'Liter (L)';
        case 'علبة':
          return 'Box / Can (علبة)';
        case 'طقم':
          return 'Set (طقم)';
        case 'متر':
          return 'Meter (متر)';
        case 'كارتون':
          return 'Carton (كارتون)';
        default:
          return raw;
      }
    }

    String generateRandomBarcode() {
      final random = Random();
      final part1 = random.nextInt(899999) + 100000;
      final part2 = random.nextInt(899999) + 100000;
      return '20$part1$part2';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!isPrintersLoaded) {
              isPrintersLoaded = true;
              PrintService.getSystemPrinters().then((printers) {
                if (ctx.mounted) {
                  setState(() {
                    systemPrinters = printers;
                  });
                }
              }).catchError((_) {});
            }

            final buyPriceVal = double.tryParse(buyPriceController.text.trim()) ?? 0.0;
            final sellPriceVal = double.tryParse(sellPriceController.text.trim()) ?? 0.0;
            final calculatedProfit = sellPriceVal - buyPriceVal;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(product == null ? Icons.add_shopping_cart : Icons.edit_note, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    product == null
                        ? (isEng ? 'Add New Product / Item' : 'إضافة مادة / صنف جديد')
                        : (isEng ? 'Edit Product Details' : 'تعديل بيانات المادة'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 900,
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      final section1 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '1. Product Basic Info' : '1. البيانات الأساسية للصنف'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Product Name *' : 'اسم المادة / الصنف *',
                                prefixIcon: const Icon(Icons.fastfood),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: selectedCatId,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Main Category' : 'التصنيف الرئيسي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: categories.map((cat) {
                                final cName = (cat.name == 'عام' && isEng) ? 'General' : cat.name;
                                return DropdownMenuItem<int>(
                                  value: cat.id,
                                  child: Text(cName),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedCatId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: barcodeController,
                                    decoration: InputDecoration(
                                      labelText: isEng ? 'Barcode (Optional)' : 'الباركود (خيار الباركود)',
                                      prefixIcon: const Icon(Icons.qr_code_scanner),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade200,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    final newBarcode = generateRandomBarcode();
                                    setState(() {
                                      barcodeController.text = newBarcode;
                                      barcodeController.selection = TextSelection.collapsed(offset: newBarcode.length);
                                    });
                                  },
                                  icon: const Icon(Icons.auto_fix_high, size: 18),
                                  label: Text(isEng ? 'Generate Barcode' : 'توليد باركود'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade50,
                                    foregroundColor: Colors.purple.shade900,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.purple.shade300),
                                    ),
                                  ),
                                  onPressed: () {
                                    final bCode = barcodeController.text.trim();
                                    final pName = nameController.text.trim();
                                    if (pName.isEmpty) {
                                      TopNotification.showWarning(
                                        context,
                                        isEng ? 'Please enter product name first.' : 'يرجى كتابة اسم المادة أولاً لطباعة الباركود.',
                                      );
                                      return;
                                    }
                                    final tempProduct = ProductModel(
                                      id: product?.id ?? 999,
                                      name: pName,
                                      price: double.tryParse(sellPriceController.text.trim()) ?? 0.0,
                                      buyPrice: double.tryParse(buyPriceController.text.trim()) ?? 0.0,
                                      barcode: bCode.isNotEmpty ? bCode : generateRandomBarcode(),
                                      categoryId: selectedCatId ?? 1,
                                    );
                                    _showPrintBarcodeQuantityDialog(context, tempProduct);
                                  },
                                  icon: const Icon(Icons.print_rounded, size: 18, color: Colors.purple),
                                  label: Text(isEng ? 'Print Barcode' : 'طباعة باركود', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      final section2 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '2. Pricing & Cost Options' : '2. خيار الأسعار والتكاليف'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: buyPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: isEng ? 'Cost Price ($currencySym)' : 'سعر الكلفة / الشراء ($currencySym)',
                                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: sellPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: isEng ? 'Sale Price ($currencySym) *' : 'سعر البيع ($currencySym) *',
                                      prefixIcon: const Icon(Icons.sell_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: calculatedProfit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: calculatedProfit >= 0 ? Colors.green.shade200 : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isEng ? 'Expected Net Profit per item:' : 'صافي الربح المتوقع للقطعة:',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${calculatedProfit.toStringAsFixed(0)} $currencySym',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: calculatedProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(isEng ? 'Allow Cashier Price Override' : 'خيار تغيير السعر: السماح للتعديل المباشر بالكاشير'),
                              subtitle: Text(isEng ? 'Cashier can change the sale price directly during checkout' : 'يمكن للكاشير تغيير سعر البيع لهذه المادة مباشرة'),
                              value: allowPriceChange,
                              onChanged: (val) {
                                setState(() {
                                  allowPriceChange = val;
                                });
                              },
                            ),
                          ],
                        ),
                      );

                      final section3 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '3. Unit of Measure & Weight' : '3. خيار وحدة القياس والوزن'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: availableUnits.contains(selectedUnit) ? selectedUnit : availableUnits.first,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Unit of Measurement' : 'خيار وحدة القياس',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: availableUnits.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(formatUnitName(u)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedUnit = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(isEng ? 'Weighted Product (Sold by weight)' : 'خيار الوزن: مادة مباعة بالوزن (موزونة)'),
                              subtitle: Text(isEng ? 'Total price calculated as price multiplied by scale weight' : 'يتم حساب إجمالي السعر ضرب الكمية الموزونة'),
                              value: isWeighted,
                              onChanged: (val) {
                                setState(() {
                                  isWeighted = val;
                                });
                              },
                            ),
                          ],
                        ),
                      );

                      final section4 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '4. Inventory & Stock Tracking' : '4. خيار المخزون وتتبع الكميات'),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(isEng ? 'Enable Stock Inventory Tracking' : 'تفعيل خيار تتبع الكمية بالمخزن'),
                              subtitle: Text(isEng ? 'Automatically deduct stock on sales and trigger low stock alerts' : 'خصم الكميات تلقائياً عند إنشاء المبيعات والتنبيه'),
                              value: trackStock,
                              onChanged: (val) {
                                setState(() {
                                  trackStock = val;
                                });
                              },
                            ),
                            if (trackStock) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: stockController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: isEng ? 'Available Stock Qty' : 'الكمية المتاحة بالمخزن',
                                        prefixIcon: const Icon(Icons.inventory),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: minStockController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: isEng ? 'Low Stock Warning Limit' : 'الحد الأدنى للتنبيه',
                                        prefixIcon: const Icon(Icons.warning_amber),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(isEng ? 'Available for sale currently' : 'مادة متوفرة للبيع حالياً'),
                              value: isAvailable,
                              onChanged: (val) {
                                setState(() {
                                  isAvailable = val;
                                });
                              },
                            ),
                          ],
                        ),
                      );

                      final section5 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '5. Kitchen Printing Option (KOT Ticket)' : '5. خيار طباعة الصنف في المطبخ (وصل KOT)'),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(isEng ? '🍳 Print product to Kitchen Printer automatically' : '🍳 طباعة هذا الصنف أوتوماتيكياً على طابعة المطبخ'),
                              subtitle: Text(isEng ? 'Sends this item to kitchen ticket printer on hold/order' : 'إرسال هذا الصنف لطابعة المطبخ عند تعليق الفاتورة والطلب دون الحاجة لطباعة فاتورة الكاشير'),
                              activeThumbColor: Colors.orange,
                              value: printToKitchen,
                              onChanged: (val) {
                                setState(() {
                                  printToKitchen = val;
                                });
                              },
                            ),
                            if (printToKitchen) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.print_rounded, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEng ? 'Select target kitchen printer for this item:' : 'اختر طابعة المطبخ المراد إرسال هذا الصنف إليها:',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String?>(
                                      initialValue: selectedKitchenPrinter,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: isEng ? 'Target Kitchen Printer' : 'طابعة المطبخ المستهدفة',
                                        prefixIcon: const Icon(Icons.soup_kitchen, color: Colors.deepOrange),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            context.watch<SettingsProvider>().kitchenPrinter.isNotEmpty
                                                ? (isEng ? 'Default Main Kitchen Printer (${context.watch<SettingsProvider>().kitchenPrinter})' : 'طابعة المطبخ الرئيسية الافتراضية (${context.watch<SettingsProvider>().kitchenPrinter})')
                                                : (isEng ? 'Default Main Kitchen Printer' : 'طابعة المطبخ الرئيسية الافتراضية'),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ...systemPrinters.map((p) => DropdownMenuItem<String?>(
                                          value: p.name as String,
                                          child: Text('🖨️ ${p.name}'),
                                        )),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          selectedKitchenPrinter = val;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedKitchenPrinter == null || selectedKitchenPrinter!.isEmpty
                                          ? (isEng ? 'Item will be sent to system default kitchen printer.' : 'سيتم إرسال هذا الصنف إلى طابعة المطبخ الرئيسية المحددة بالإعدادات.')
                                          : (isEng ? 'Item routed directly to: $selectedKitchenPrinter' : 'سيتم توجيه هذا الصنف مباشرة إلى طابعة: $selectedKitchenPrinter'),
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.print_disabled, color: Colors.grey, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isEng ? 'Kitchen print disabled for this item.' : 'طباعة المطبخ غير مفعلة لهذا الصنف ولن تظهر أو تطبع في المطبخ.',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                section1,
                                const SizedBox(height: 16),
                                section2,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                section3,
                                const SizedBox(height: 16),
                                section4,
                                const SizedBox(height: 16),
                                section5,
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final barcode = barcodeController.text.trim();
                    final buyPrice = double.tryParse(buyPriceController.text.trim()) ?? 0.0;
                    final price = double.tryParse(sellPriceController.text.trim()) ?? 0.0;
                    final stockQty = double.tryParse(stockController.text.trim()) ?? 100.0;
                    final minStock = double.tryParse(minStockController.text.trim()) ?? 5.0;

                    if (name.isEmpty) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? '⚠️ Please enter product name first' : '⚠️ يرجى إدخال اسم المادة / الصنف أولاً',
                      );
                      return;
                    }

                    if (price <= 0) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? '⚠️ Please enter valid sale price greater than 0' : '⚠️ يرجى إدخال سعر بيع صحيح أكبر من الصفر',
                      );
                      return;
                    }

                    try {
                      final prodProvider = context.read<ProductsProvider>();

                      final newProduct = ProductModel(
                        id: product?.id,
                        name: name,
                        barcode: barcode.isNotEmpty ? barcode : null,
                        buyPrice: buyPrice,
                        price: price,
                        unit: selectedUnit,
                        isWeighted: isWeighted,
                        allowPriceChange: allowPriceChange,
                        stockQuantity: stockQty,
                        trackStock: trackStock,
                        minStock: minStock,
                        categoryId: selectedCatId,
                        isAvailable: isAvailable,
                        printToKitchen: printToKitchen,
                        kitchenPrinter: selectedKitchenPrinter,
                      );

                      if (product == null) {
                        await prodProvider.addProduct(newProduct);
                      } else {
                        await prodProvider.updateProduct(newProduct);
                      }

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        TopNotification.showSuccess(
                          context,
                          product == null
                              ? (isEng ? 'Product added successfully! 🎉' : 'تمت إضافة المادة بنجاح! 🎉')
                              : (isEng ? 'Product updated successfully! 🎉' : 'تم تحديث المادة بنجاح! 🎉'),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        TopNotification.showError(
                          ctx,
                          isEng ? 'Error saving product: $e' : 'حدث خطأ أثناء حفظ المادة: $e',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    isEng ? 'Save Product' : 'حفظ المادة',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }

  Future<void> _showPrintBarcodeQuantityDialog(BuildContext context, ProductModel product) async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final qtyController = TextEditingController(text: '1');
    final settings = context.read<SettingsProvider>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.purple, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEng ? 'Print Barcode: ${product.name}' : 'طباعة باركود: ${product.name}',
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
              isEng ? 'Barcode: ${product.barcode ?? "Auto-generated"}' : 'الباركود: ${product.barcode ?? "توليد تلقائي"}',
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            Text(
              isEng ? 'Price: ${product.price.toStringAsFixed(0)} ${settings.currencySymbol}' : 'السعر: ${product.price.toStringAsFixed(0)} ${settings.currencySymbol}',
              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
              decoration: InputDecoration(
                labelText: isEng ? 'Required Barcode Labels Count (Qty) *' : 'عدد ملصقات الباركود المطلوبة (الكمية) *',
                prefixIcon: const Icon(Icons.copy, color: Colors.purple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEng ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.print, color: Colors.white),
            label: Text(
              isEng ? 'Print Labels' : 'طباعة الملصقات',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final count = int.tryParse(qtyController.text.trim()) ?? 1;
              if (count <= 0) {
                TopNotification.showWarning(
                  ctx,
                  isEng ? 'Please enter valid label count greater than zero' : 'يرجى أدخال عدد ملصقات صحيح أكبر من الصفر',
                );
                return;
              }
              Navigator.pop(ctx);

              TopNotification.showInfo(
                context,
                isEng ? '🖨️ Sending $count barcode labels to printer...' : '🖨️ جاري إرسال $count ملصق باركود إلى طابعة الباركود...',
              );
              final success = await PrintService.printBarcodeLabel(
                product: product,
                labelCount: count,
                settings: settings,
              );

              if (context.mounted) {
                if (success) {
                  TopNotification.showSuccess(
                    context,
                    isEng ? '🎉 Sent $count barcode labels to printer successfully!' : '🎉 تم إرسال $count ملصق باركود للطابعة بنجاح!',
                  );
                } else {
                  TopNotification.showWarning(
                    context,
                    isEng ? '⚠️ Failed to send print command. Verify barcode printer connection.' : '⚠️ تعذر إرسال امر الطباعة. تحقق من توصيل طابعة الباركود والإعدادات.',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
