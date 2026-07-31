import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصناف والمواد الشاملة'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business),
        label: const Text('إضافة مادة / صنف جديد'),
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
                      hintText: 'بحث باسم الصنف أو الباركود...',
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
                        hint: const Text('كل التصنيفات', style: TextStyle(fontSize: 13)),
                        isDense: true,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('جميع التصنيفات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ...categoriesProvider.categories.map((cat) {
                            return DropdownMenuItem<int?>(
                              value: cat.id,
                              child: Text(cat.name, style: const TextStyle(fontSize: 13)),
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('لا توجد مواد مطابقة للبحث', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                              columns: const [
                                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('اسم الصنف / الباركود', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('التصنيف', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الكلُفة (الشراء)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('سعر البيع', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الربح', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الوحدة والوزن', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('المخزون', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('العمليات', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: productsProvider.products.map((product) {
                                final catName = categoriesProvider.categories
                                    .firstWhere(
                                      (c) => c.id == product.categoryId,
                                      orElse: () => const CategoryModel(name: 'عام'),
                                    )
                                    .name;

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
                                            Text('باركود: ${product.barcode}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Chip(
                                      label: Text(catName, style: TextStyle(fontSize: 12)),
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
                                          Text(product.unit),
                                          if (product.isWeighted) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('موزونة', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
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
                                                '${product.stockQuantity.toStringAsFixed(0)} ${product.unit}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: product.isLowStock ? Colors.red.shade900 : Colors.green.shade900,
                                                ),
                                              ),
                                            )
                                          : const Text('غير متتبع'),
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
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'تعديل البيانات',
                                            onPressed: () => _showProductDialog(context, product: product),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'حذف المادة',
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

    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final categories = context.read<CategoriesProvider>().categories;
    if (selectedCatId == null && categories.isNotEmpty) {
      selectedCatId = categories.first.id;
    }

    final availableUnits = ['قطعة', 'كيلوغرام', 'غرام', 'لتر', 'علبة', 'طقم', 'متر', 'كارتون'];

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
                    product == null ? 'إضافة مادة / صنف جديد' : 'تعديل بيانات المادة',
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
                            _sectionTitle('1. البيانات الأساسية للصنف'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'اسم المادة / الصنف *',
                                prefixIcon: const Icon(Icons.fastfood),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: selectedCatId,
                              decoration: InputDecoration(
                                labelText: 'التصنيف الرئيسي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: categories.map((cat) {
                                return DropdownMenuItem<int>(
                                  value: cat.id,
                                  child: Text(cat.name),
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
                                      labelText: 'الباركود (خيار الباركود)',
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                                  label: const Text('توليد باركود'),
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
                            _sectionTitle('2. خيار الأسعار والتكاليف'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: buyPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'سعر الكلفة / الشراء ($currencySym)',
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
                                      labelText: 'سعر البيع ($currencySym) *',
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
                                  const Text('صافي الربح المتوقع للقطعة:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              title: const Text('خيار تغيير السعر: السماح للتعديل المباشر بالكاشير'),
                              subtitle: const Text('يمكن للكاشير تغيير سعر البيع لهذه المادة مباشرة'),
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
                            _sectionTitle('3. خيار وحدة القياس والوزن'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: availableUnits.contains(selectedUnit) ? selectedUnit : availableUnits.first,
                              decoration: InputDecoration(
                                labelText: 'خيار وحدة القياس',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: availableUnits.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u,
                                  child: Text(u),
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
                              title: const Text('خيار الوزن: مادة مباعة بالوزن (موزونة)'),
                              subtitle: const Text('يتم حساب إجمالي السعر ضرب الكمية الموزونة'),
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
                            _sectionTitle('4. خيار المخزون وتتبع الكميات'),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('تفعيل خيار تتبع الكمية بالمخزن'),
                              subtitle: const Text('خصم الكميات تلقائياً عند إنشاء المبيعات والتنبيه'),
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
                                        labelText: 'الكمية المتاحة بالمخزن',
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
                                        labelText: 'الحد الأدنى للتنبيه',
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
                              title: const Text('مادة متوفرة للبيع حالياً'),
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
                            _sectionTitle('5. خيار طباعة الصنف في المطبخ (وصل KOT)'),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('🍳 طباعة هذا الصنف أوتوماتيكياً على طابعة المطبخ'),
                              subtitle: const Text('إرسال هذا الصنف لطابعة المطبخ عند إضافة المواد والطلب دون طباعة فاتورة الكاشير'),
                              activeThumbColor: Colors.orange,
                              value: printToKitchen,
                              onChanged: (val) {
                                setState(() {
                                  printToKitchen = val;
                                });
                              },
                            ),
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
                  child: const Text('إلغاء'),
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
                      TopNotification.showWarning(ctx, '⚠️ يرجى إدخال اسم المادة / الصنف أولاً');
                      return;
                    }

                    if (price <= 0) {
                      TopNotification.showWarning(ctx, '⚠️ يرجى إدخال سعر بيع صحيح أكبر من الصفر');
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
                          product == null ? 'تمت إضافة المادة بنجاح! 🎉' : 'تم تحديث المادة بنجاح! 🎉',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        TopNotification.showError(ctx, 'حدث خطأ أثناء حفظ المادة: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('حفظ المادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
}
