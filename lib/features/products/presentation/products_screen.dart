import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/print_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/customize_item_appearance_dialog.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../models/product_recipe.dart';
import '../../../models/raw_material.dart';
import '../../categories/categories_provider.dart';
import '../../raw_materials/raw_materials_provider.dart';
import '../../settings/settings_provider.dart';
import '../products_provider.dart';

class ProductsScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const ProductsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySym = settingsProvider.currencySymbol;
    final isEng = settingsProvider.isEnglish;
    final isDark = settingsProvider.isDarkMode;

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
        leadingWidth: 150,
        leading: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: Text(
            isEng ? 'Management' : 'لوحة الإدارة',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business),
        label: Text(isEng ? 'Add New Product ➕' : 'إضافة مادة / صنف جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            // Search & Filter Header
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: isEng ? 'Search product or barcode...' : 'بحث باسم الصنف أو الباركود...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey.shade400),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: productsProvider.selectedCategoryId,
                        dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                        iconEnabledColor: isDark ? Colors.white70 : Colors.black87,
                        hint: Text(
                          isEng ? 'All Categories' : 'كل التصنيفات',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        isDense: true,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              isEng ? 'All Categories' : 'جميع التصنيفات',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          ...categoriesProvider.categories.map((cat) {
                            final cName = (cat.name == 'عام' && isEng) ? 'General' : cat.name;
                            return DropdownMenuItem<int?>(
                              value: cat.id,
                              child: Text(cName, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
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
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.transparent),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  columnSpacing: 10,
                                  horizontalMargin: 8,
                                  headingRowHeight: 40,
                                  dataRowMinHeight: 42,
                                  dataRowMaxHeight: 52,
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? const Color(0xFF242F3E) : Colors.orange.shade50,
                                  ),
                                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.hovered)) {
                                      return isDark ? const Color(0xFF2D3B4E) : Colors.grey.shade100;
                                    }
                                    return isDark ? const Color(0xFF1F2937) : Colors.white;
                                  }),
                                  dividerThickness: 1,
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  columns: [
                                    DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Item / Barcode' : 'اسم الصنف / الباركود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Category' : 'التصنيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Cost' : 'الكلُفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Sale Price' : 'سعر البيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Profit' : 'الربح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Unit' : 'الوحدة والوزن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Stock' : 'المخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Status' : 'الحالة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                    DataColumn(label: Text(isEng ? 'Actions' : 'العمليات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                                  ],
                                  rows: productsProvider.products.map((product) {
                                    final rawCat = product.categoryId == null
                                        ? (isEng ? '📌 Main' : '📌 الشاشة الرئيسية')
                                        : categoriesProvider.categories
                                            .firstWhere(
                                              (c) => c.id == product.categoryId,
                                              orElse: () => const CategoryModel(name: 'عام'),
                                            )
                                            .name;
                                    final catName = (rawCat == 'عام' && isEng) ? 'General' : rawCat;

                                    return DataRow(
                                      cells: [
                                        DataCell(Text('#${product.id}', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.black87))),
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
                                              if (product.barcode != null && product.barcode!.isNotEmpty)
                                                Text(
                                                  isEng ? 'Barcode: ${product.barcode}' : 'باركود: ${product.barcode}',
                                                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                                                ),
                                                child: Text(
                                                  catName,
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade200 : Colors.blue.shade900),
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                product.displayLocation == 'BOTH'
                                                    ? '🌟 رئيسية وتصنيف'
                                                    : (product.displayLocation == 'MAIN_ONLY' ? '📌 رئيسية فقط' : '📂 داخل التصنيف'),
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: isDark ? const Color(0xFFD8B4FE) : Colors.purple.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(
                                          '${product.buyPrice.toStringAsFixed(0)} $currencySym',
                                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.black87),
                                        )),
                                        DataCell(Text(
                                          '${product.price.toStringAsFixed(0)} $currencySym',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFBBF24) : AppColors.primary),
                                        )),
                                        DataCell(Text(
                                          '${product.profitMargin.toStringAsFixed(0)} $currencySym',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: product.profitMargin >= 0
                                                ? (isDark ? const Color(0xFF34D399) : Colors.green.shade800)
                                                : (isDark ? const Color(0xFFF87171) : Colors.red),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(formatUnit(product.unit), style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                                              if (product.isWeighted) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : Colors.purple.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade200),
                                                  ),
                                                  child: Text(
                                                    isEng ? 'Weighted' : 'موزونة',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      color: isDark ? const Color(0xFFD8B4FE) : Colors.purple,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          product.trackStock
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: product.isLowStock
                                                        ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50)
                                                        : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.green.shade50),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: product.isLowStock
                                                          ? (isDark ? const Color(0xFF991B1B) : Colors.red.shade300)
                                                          : (isDark ? const Color(0xFF059669) : Colors.green.shade300),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${product.stockQuantity.toStringAsFixed(0)} ${formatUnit(product.unit)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: product.isLowStock
                                                          ? (isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900)
                                                          : (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900),
                                                    ),
                                                  ),
                                                )
                                              : Text(isEng ? 'Untracked' : 'غير متتبع', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                        ),
                                        DataCell(
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: product.isAvailable,
                                              activeTrackColor: AppColors.success,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              onChanged: (_) {
                                                productsProvider.toggleAvailability(product);
                                              },
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                iconSize: 18,
                                                icon: const Icon(Icons.palette_outlined, color: Colors.orangeAccent),
                                                tooltip: isEng ? 'Customize Color & Appearance' : 'تخصيص اللون والمظهر 🎨',
                                                onPressed: () => _customizeProductAppearance(context, product),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                iconSize: 18,
                                                icon: Icon(Icons.qr_code_scanner, color: isDark ? const Color(0xFFC084FC) : Colors.purple),
                                                tooltip: isEng ? 'Print Barcode Label' : 'طباعة ملصق الباركود',
                                                onPressed: () => _showPrintBarcodeQuantityDialog(context, product),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                iconSize: 18,
                                                icon: Icon(Icons.edit, color: isDark ? const Color(0xFF60A5FA) : Colors.blue),
                                                tooltip: isEng ? 'Edit Product' : 'تعديل البيانات',
                                                onPressed: () => _showProductDialog(context, product: product),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                iconSize: 18,
                                                icon: Icon(Icons.delete, color: isDark ? const Color(0xFFF87171) : Colors.red),
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
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, {ProductModel? product}) {
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final buyPriceController = TextEditingController(text: product != null ? product.buyPrice.toStringAsFixed(0) : '0');
    final sellPriceController = TextEditingController(text: product != null ? product.price.toStringAsFixed(0) : '');
    final stockController = TextEditingController(text: product != null ? product.stockQuantity.toStringAsFixed(0) : '100');
    final minStockController = TextEditingController(text: product != null ? product.minStock.toStringAsFixed(0) : '5');

    int? selectedCatId = product?.categoryId;
    String selectedDisplayLocation = product?.displayLocation ?? 'CATEGORY_ONLY';
    String selectedUnit = product?.unit ?? 'قطعة';
    bool isWeighted = product?.isWeighted ?? false;
    bool allowPriceChange = product?.allowPriceChange ?? false;
    bool trackStock = product?.trackStock ?? false;
    bool isAvailable = product?.isAvailable ?? true;
    bool printToKitchen = product?.printToKitchen ?? false;
    String? selectedKitchenPrinter = product?.kitchenPrinter;

    List<dynamic> systemPrinters = [];
    bool isPrintersLoaded = false;

    final currencySym = settings.currencySymbol;
    final categories = context.read<CategoriesProvider>().categories;

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

    List<ProductRecipeItemModel> recipeItems = [];
    bool isRecipesLoaded = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!isRecipesLoaded) {
              isRecipesLoaded = true;
              if (product?.id != null) {
                context.read<RawMaterialsProvider>().getProductRecipes(product!.id!).then((items) {
                  if (ctx.mounted) {
                    setState(() {
                      recipeItems = items;
                    });
                  }
                }).catchError((_) {});
              }
            }

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
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
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
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '1. Product Basic Info' : '1. البيانات الأساسية للصنف'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Product Name *' : 'اسم المادة / الصنف *',
                                prefixIcon: const Icon(Icons.fastfood),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 1. Category / Section Selection
                            DropdownButtonFormField<int?>(
                              initialValue: selectedCatId,
                              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isEng ? 'Category / Section' : 'القسم / التصنيف الرئيسي',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.category_outlined),
                              ),
                              items: categories.map((cat) {
                                final cName = (cat.name == 'عام' && isEng) ? 'General' : cat.name;
                                return DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Text('📂 $cName', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedCatId = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // 2. POS Display Location Option
                            DropdownButtonFormField<String>(
                              initialValue: selectedDisplayLocation,
                              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: isEng ? 'POS Display Location *' : 'خيار مكان عرض المادة بالكاشير *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.visibility_outlined),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'CATEGORY_ONLY',
                                  child: Text(
                                    isEng ? '📂 Display Inside Selected Category Only' : '📂 عرض داخل التصنيف المحدد فقط',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : Colors.blue),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'BOTH',
                                  child: Text(
                                    isEng ? '🌟 Display in Both (Main Screen + Inside Category)' : '🌟 عرض في الاثنين (الشاشة الرئيسية + داخل التصنيف)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'MAIN_ONLY',
                                  child: Text(
                                    isEng ? '📌 Display on Main Screen Only' : '📌 عرض في الشاشة الرئيسية المباشرة فقط',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFC084FC) : Colors.purple),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedDisplayLocation = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: barcodeController,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                                    backgroundColor: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
                                    foregroundColor: isDark ? Colors.white : Colors.black87,
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
                                    backgroundColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : Colors.purple.shade50,
                                    foregroundColor: isDark ? const Color(0xFFD8B4FE) : Colors.purple.shade900,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: isDark ? const Color(0xFF7E22CE) : Colors.purple.shade300),
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
                                  icon: Icon(Icons.print_rounded, size: 18, color: isDark ? const Color(0xFFD8B4FE) : Colors.purple),
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
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
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
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                                color: calculatedProfit >= 0
                                    ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : Colors.green.shade50)
                                    : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: calculatedProfit >= 0
                                      ? (isDark ? const Color(0xFF059669) : Colors.green.shade200)
                                      : (isDark ? const Color(0xFF991B1B) : Colors.red.shade200),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isEng ? 'Expected Net Profit per item:' : 'صافي الربح المتوقع للقطعة:',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                  Text(
                                    '${calculatedProfit.toStringAsFixed(0)} $currencySym',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: calculatedProfit >= 0
                                          ? (isDark ? const Color(0xFF34D399) : Colors.green.shade900)
                                          : (isDark ? const Color(0xFFF87171) : Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEng ? 'Allow Cashier Price Override' : 'خيار تغيير السعر: السماح للتعديل المباشر بالكاشير',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEng ? 'Cashier can change the sale price directly during checkout' : 'يمكن للكاشير تغيير سعر البيع لهذه المادة مباشرة',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: allowPriceChange,
                                  onChanged: (val) {
                                    setState(() {
                                      allowPriceChange = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      final sectionRecipe = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.2) : Colors.orange.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF9A3412) : Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _sectionTitle(isEng ? 'Recipe & Raw Materials' : 'مكونات المادة والمقادير الأولية (الخلطة / Recipe)'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    _showAddRecipeItemDialog(context, setState, recipeItems);
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(isEng ? 'Add Ingredient' : 'إضافة مكون', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (recipeItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  isEng ? 'No raw material ingredients added yet for this product.' : 'لم يتم إضافة مواد أولية لهذه المادة بعد.',
                                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Divider(color: isDark ? const Color(0xFF475569) : null),
                                  ...recipeItems.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.orange.shade100),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        leading: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                          child: Text('${idx + 1}', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                        title: Text(item.rawMaterialName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                                        subtitle: Text(
                                          'الكمية: ${item.quantityRequired} ${item.rawMaterialUnit} (كلفة: ${item.costPerUnit} $currencySym)',
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.black54),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${item.totalCost.toStringAsFixed(0)} $currencySym',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFBBF24) : Colors.brown, fontSize: 12),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                              onPressed: () {
                                                setState(() {
                                                  recipeItems.removeAt(idx);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  Divider(color: isDark ? const Color(0xFF475569) : null),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        isEng ? 'Total Recipe Cost:' : 'كلفة المواد الأولية:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${recipeItems.fold(0.0, (sum, i) => sum + i.totalCost).toStringAsFixed(0)} $currencySym',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? const Color(0xFFFBBF24) : Colors.orange),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? const Color(0xFF78350F) : Colors.orange.shade100,
                                              foregroundColor: isDark ? const Color(0xFFFED7AA) : Colors.orange.shade900,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onPressed: () {
                                              final totalCost = recipeItems.fold(0.0, (sum, i) => sum + i.totalCost);
                                              setState(() {
                                                buyPriceController.text = totalCost.toStringAsFixed(0);
                                              });
                                            },
                                            icon: const Icon(Icons.copy, size: 14),
                                            label: Text(isEng ? 'Use as Cost' : 'اعتماد كـ سعر الكلفة', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );

                      final section3 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '3. Unit of Measure & Weight' : '3. خيار وحدة القياس والوزن'),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: availableUnits.contains(selectedUnit) ? selectedUnit : availableUnits.first,
                              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                              title: Text(
                                isEng ? 'Weighted Product (Sold by weight)' : 'خيار الوزن: مادة مباعة بالوزن (موزونة)',
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              ),
                              subtitle: Text(
                                isEng ? 'Total price calculated as price multiplied by scale weight' : 'يتم حساب إجمالي السعر ضرب الكمية الموزونة',
                                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
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
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '4. Inventory & Stock Tracking' : '4. خيار المخزون وتتبع الكميات'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEng ? 'Enable Stock Inventory Tracking' : 'تفعيل خيار تتبع الكمية بالمخزن',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEng ? 'Automatically deduct stock on sales and trigger low stock alerts' : 'خصم الكميات تلقائياً عند إنشاء المبيعات والتنبيه',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: trackStock,
                                  onChanged: (val) {
                                    setState(() {
                                      trackStock = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (trackStock) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: stockController,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isEng ? 'Available for sale currently' : 'مادة متوفرة للبيع حالياً',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                Switch(
                                  value: isAvailable,
                                  onChanged: (val) {
                                    setState(() {
                                      isAvailable = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      final section5 = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(isEng ? '5. Kitchen Printing Option (KOT Ticket)' : '5. خيار طباعة الصنف في المطبخ (وصل KOT)'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEng ? '🍳 Print product to Kitchen Printer automatically' : '🍳 طباعة هذا الصنف أوتوماتيكياً على طابعة المطبخ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEng ? 'Sends this item to kitchen ticket printer on hold/order' : 'إرسال هذا الصنف لطابعة المطبخ عند تعليق الفاتورة والطلب دون الحاجة لطباعة فاتورة الكاشير',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  activeTrackColor: Colors.orange,
                                  value: printToKitchen,
                                  onChanged: (val) {
                                    setState(() {
                                      printToKitchen = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (printToKitchen) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.25) : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF9A3412) : Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.print_rounded, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isEng ? 'Select target kitchen printer for this item:' : 'اختر طابعة المطبخ المراد إرسال هذا الصنف إليها:',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String?>(
                                      initialValue: selectedKitchenPrinter,
                                      dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: isEng ? 'Target Kitchen Printer' : 'طابعة المطبخ المستهدفة',
                                        prefixIcon: const Icon(Icons.soup_kitchen, color: Colors.deepOrange),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFFED7AA) : Colors.orange.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.print_disabled, color: Colors.grey, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isEng ? 'Kitchen print disabled for this item.' : 'طباعة المطبخ غير مفعلة لهذا الصنف ولن تظهر أو تطبع في المطبخ.',
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.black54),
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
                                const SizedBox(height: 16),
                                sectionRecipe,
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
                        displayLocation: selectedDisplayLocation,
                        image: product?.image,
                        color: product?.color,
                      );

                      int saveId = product?.id ?? 0;
                      if (product == null) {
                        saveId = await prodProvider.addProduct(newProduct);
                      } else {
                        await prodProvider.updateProduct(newProduct);
                      }

                      if (saveId > 0 && context.mounted) {
                        await context.read<RawMaterialsProvider>().saveProductRecipes(saveId, recipeItems);
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

  Future<void> _showAddRecipeItemDialog(
    BuildContext context,
    StateSetter parentSetState,
    List<ProductRecipeItemModel> recipeItems,
  ) async {
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    final currencySym = settings.currencySymbol;
    final rawMaterialsProvider = context.read<RawMaterialsProvider>();
    final rawMaterials = rawMaterialsProvider.rawMaterials;

    if (rawMaterials.isEmpty) {
      TopNotification.showWarning(
        context,
        isEng
            ? 'No raw materials added yet! Please add raw materials first in Purchases screen.'
            : 'لم يتم إضافة مواد أولية بعد! يرجى إضافة المواد الأولية أولاً من شاشة المشتريات -> قسم المواد الأولية.',
      );
      return;
    }

    RawMaterialModel? selectedMaterial = rawMaterials.first;
    final qtyController = TextEditingController(text: '100');

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final qtyVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
            final costPerUnit = selectedMaterial?.costPerUnit ?? 0.0;
            final calculatedCost = qtyVal * costPerUnit;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.rice_bowl, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? 'Add Raw Material Ingredient' : 'إضافة مادة أولية / مكون للوجبة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<RawMaterialModel>(
                      initialValue: selectedMaterial,
                      dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Select Raw Material' : 'اختر المادة الأولية',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: rawMaterials.map((rm) {
                        return DropdownMenuItem<RawMaterialModel>(
                          value: rm,
                          child: Text('${rm.name} (${rm.unit}) - كلفة الوحدة: ${rm.costPerUnit} $currencySym', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMaterial = val;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: isEng
                            ? 'Required Quantity (${selectedMaterial?.unit ?? "Unit"}) *'
                            : 'الكمية المطلوبة للوجبة الواحدة (${selectedMaterial?.unit ?? "الوحدة"}) *',
                        prefixIcon: const Icon(Icons.scale_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF9A3412) : Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEng ? 'Calculated Ingredient Cost:' : 'الكلفة المحسوبة للمكون:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          Text(
                            '${calculatedCost.toStringAsFixed(0)} $currencySym',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? const Color(0xFFFBBF24) : Colors.orange),
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
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    isEng ? 'Add Ingredient' : 'إضافة المكون',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (selectedMaterial == null || qtyVal <= 0) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? 'Please enter valid quantity' : 'يرجى إدخال كمية صحيحة أكبر من الصفر',
                      );
                      return;
                    }

                    parentSetState(() {
                      recipeItems.add(
                        ProductRecipeItemModel(
                          productId: 0,
                          rawMaterialId: selectedMaterial!.id!,
                          rawMaterialName: selectedMaterial!.name,
                          rawMaterialUnit: selectedMaterial!.unit,
                          costPerUnit: selectedMaterial!.costPerUnit,
                          quantityRequired: qtyVal,
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
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
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    final qtyController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: isDark ? const Color(0xFFC084FC) : Colors.purple, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEng ? 'Print Barcode: ${product.name}' : 'طباعة باركود: ${product.name}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
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
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold),
            ),
            Text(
              isEng ? 'Price: ${product.price.toStringAsFixed(0)} ${settings.currencySymbol}' : 'السعر: ${product.price.toStringAsFixed(0)} ${settings.currencySymbol}',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF34D399) : Colors.green.shade800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFC084FC) : Colors.purple),
              decoration: InputDecoration(
                labelText: isEng ? 'Required Barcode Labels Count (Qty) *' : 'عدد ملصقات الباركود المطلوبة (الكمية) *',
                prefixIcon: Icon(Icons.copy, color: isDark ? const Color(0xFFC084FC) : Colors.purple),
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

  Future<void> _customizeProductAppearance(BuildContext context, ProductModel product) async {
    final productsProvider = context.read<ProductsProvider>();
    final result = await CustomizeItemAppearanceDialog.show(
      context,
      itemName: product.name,
      initialImage: product.image,
      initialColor: product.color,
      defaultFallbackColor: const Color(0xFF1D4ED8),
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
}
