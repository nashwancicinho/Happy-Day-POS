import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../categories/categories_provider.dart';
import '../../products/products_provider.dart';
import '../../settings/settings_provider.dart';

enum StockFilterType { all, normal, low, outOfStock }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  StockFilterType _selectedStockFilter = StockFilterType.all;
  String _searchQuery = '';
  int? _selectedCatId;

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final categoriesProvider = context.watch<CategoriesProvider>();
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    // Filter products based on search, category, and stock status
    final filteredProducts = productsProvider.allProducts.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode != null && p.barcode!.contains(_searchQuery));

      final matchesCategory = _selectedCatId == null || p.categoryId == _selectedCatId;

      bool matchesStock = true;
      if (_selectedStockFilter == StockFilterType.normal) {
        matchesStock = p.trackStock && p.stockQuantity > p.minStock;
      } else if (_selectedStockFilter == StockFilterType.low) {
        matchesStock = p.trackStock && p.stockQuantity <= p.minStock && p.stockQuantity > 0;
      } else if (_selectedStockFilter == StockFilterType.outOfStock) {
        matchesStock = p.trackStock && p.stockQuantity <= 0;
      }

      return matchesSearch && matchesCategory && matchesStock;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 26),
            SizedBox(width: 10),
            Text('إدارة المخزن والمواد (الكميات والتوريد)', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث بيانات المخزن',
            onPressed: () {
              productsProvider.loadProducts();
              TopNotification.showSuccess(context, 'تم تحديث بيانات المخزن بنجاح.');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickSupplyDialog(context, productsProvider.allProducts),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('توريد شحنة / زيادة مخزون', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Inventory Summary Cards Row
            _buildInventorySummaryCards(context, productsProvider),

            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Search Field
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'بحث باسم المادة أو الباركود...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),

                    // Category Filter Dropdown
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCatId,
                            hint: const Text('جميع التصنيفات', style: TextStyle(fontSize: 13)),
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
                            onChanged: (val) {
                              setState(() {
                                _selectedCatId = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // Stock Status Chips
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildFilterChip('الكل (${productsProvider.allProducts.length})', StockFilterType.all, Colors.blue),
                        _buildFilterChip('متوفر جيدا', StockFilterType.normal, Colors.green),
                        _buildFilterChip('كمية منخفضة (${productsProvider.lowStockProductsCount})', StockFilterType.low, Colors.orange),
                        _buildFilterChip('نافد من المخزن (${productsProvider.outOfStockProductsCount})', StockFilterType.outOfStock, Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Inventory Products Table
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_sharp, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد مواد في المخزن مطابقة لشروط البحث والتصفية',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
                            constraints: const BoxConstraints(minWidth: 1050),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.orange.shade50),
                              columns: const [
                                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('اسم المادة / الباركود', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('التصنيف', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الوحدة', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('سعر الكلفة', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('سعر البيع', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('الكمية المتوفرة', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('حد التنبيه', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('حالة المخزون', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('إجراءات التوريد والتعديل', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredProducts.map((product) {
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
                                      label: Text(catName, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: Colors.blue.shade50,
                                    )),
                                    DataCell(Text(product.unit)),
                                    DataCell(Text('${product.buyPrice.toStringAsFixed(0)} $currencySym')),
                                    DataCell(Text('${product.price.toStringAsFixed(0)} $currencySym', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(
                                      _buildStockQuantityBadge(product),
                                    ),
                                    DataCell(Text('${product.minStock.toStringAsFixed(0)} ${product.unit}')),
                                    DataCell(_buildStockStatusChip(product)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('تعديل / زيادة المخزون', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            onPressed: () => _showAddStockDialog(context, product),
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

  Widget _buildFilterChip(String label, StockFilterType type, Color activeColor) {
    final isSelected = _selectedStockFilter == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade200,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStockFilter = type;
          });
        }
      },
    );
  }

  Widget _buildInventorySummaryCards(BuildContext context, ProductsProvider provider) {
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: 'إجمالي مواد المخزن',
              value: '${provider.totalProductsCount} أصناف',
              subtitle: 'المواد المسجلة في النظام',
              icon: Icons.inventory_2_outlined,
              color: Colors.blue.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
            ),
            _buildStatCard(
              title: 'إجمالي الكميات المتوفرة',
              value: provider.totalStockUnits.toStringAsFixed(0),
              subtitle: 'مجموع الوحدات في الرفوف',
              icon: Icons.format_list_numbered,
              color: Colors.purple.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
            ),
            _buildStatCard(
              title: 'أصناف خفيضة / نافدة',
              value: '${provider.lowStockProductsCount + provider.outOfStockProductsCount} مادة',
              subtitle: 'تتطلب توريد ومتابعة',
              icon: Icons.warning_amber_rounded,
              color: (provider.lowStockProductsCount + provider.outOfStockProductsCount) > 0 ? Colors.red.shade700 : Colors.green.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
            ),
            _buildStatCard(
              title: 'قيمة المخزون (بالتكلفة والبيع)',
              value: '${provider.totalCostValue.toStringAsFixed(0)} $currencySym',
              subtitle: 'البيع المتوقع: ${provider.totalRetailValue.toStringAsFixed(0)} $currencySym',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.teal.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockQuantityBadge(ProductModel product) {
    if (!product.trackStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: const Text('غير متتبع', style: TextStyle(fontSize: 12, color: Colors.black54)),
      );
    }

    Color bgColor = Colors.green.shade50;
    Color textColor = Colors.green.shade900;
    Color borderColor = Colors.green.shade300;

    if (product.stockQuantity <= 0) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade900;
      borderColor = Colors.red.shade300;
    } else if (product.stockQuantity <= product.minStock) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      borderColor = Colors.orange.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '${product.stockQuantity.toStringAsFixed(0)} ${product.unit}',
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
      ),
    );
  }

  Widget _buildStockStatusChip(ProductModel product) {
    if (!product.trackStock) {
      return const Chip(label: Text('مفتوح', style: TextStyle(fontSize: 11)), backgroundColor: Colors.grey);
    }

    if (product.stockQuantity <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
        child: const Text('نافد من المخزن', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else if (product.stockQuantity <= product.minStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(6)),
        child: const Text('كمية خفيضة جداً', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(6)),
        child: const Text('مخزون جيد', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
  }

  void _showAddStockDialog(BuildContext context, ProductModel product) {
    final qtyController = TextEditingController(text: '10');
    final minStockController = TextEditingController(text: product.minStock.toStringAsFixed(0));
    bool isDirectSetMode = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentQty = product.stockQuantity;
            final enteredVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
            final newCalculatedQty = isDirectSetMode ? enteredVal : (currentQty + enteredVal);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.add_shopping_cart, color: Colors.green.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تعديل و توريد مخزون المادة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(product.name, style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Stock Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الكمية الحالية في المخزن:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${currentQty.toStringAsFixed(0)} ${product.unit}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mode Switcher
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(value: false, label: Text('إضافة كمية شحنة (+)')),
                          ButtonSegment<bool>(value: true, label: Text('تعديل الكمية المباشرة (=)')),
                        ],
                        selected: {isDirectSetMode},
                        onSelectionChanged: (Set<bool> selection) {
                          setDialogState(() {
                            isDirectSetMode = selection.first;
                            if (isDirectSetMode) {
                              qtyController.text = currentQty.toStringAsFixed(0);
                            } else {
                              qtyController.text = '10';
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Quick Add buttons (only in add mode)
                      if (!isDirectSetMode) ...[
                        const Text('إضافة سريعة بالكمية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 5, 10, 20, 50, 100].map((addAmount) {
                            return OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  final currentVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
                                  qtyController.text = (currentVal + addAmount).toStringAsFixed(0);
                                });
                              },
                              child: Text('+$addAmount ${product.unit}'),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Quantity Input Field
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isDirectSetMode ? 'الكمية الجديدة للمخزون *' : 'الكمية المضافة للشحنة *',
                          prefixIcon: Icon(isDirectSetMode ? Icons.edit_note : Icons.add_circle_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: product.unit,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 14),

                      // Min Stock Input Field
                      TextField(
                        controller: minStockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'حد التنبيه الأدنى للمخزون',
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: product.unit,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Expected Result Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: newCalculatedQty > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الكمية الجديدة المتوقعة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${newCalculatedQty.toStringAsFixed(0)} ${product.unit}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: newCalculatedQty > 0 ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final productsProvider = context.read<ProductsProvider>();
                    final minStockVal = double.tryParse(minStockController.text.trim()) ?? product.minStock;

                    if (isDirectSetMode) {
                      await productsProvider.updateStockQuantity(product.id!, newCalculatedQty);
                    } else {
                      await productsProvider.addStockQuantity(product.id!, enteredVal);
                    }

                    if (minStockVal != product.minStock) {
                      final updated = product.copyWith(
                        stockQuantity: isDirectSetMode ? newCalculatedQty : (product.stockQuantity + enteredVal),
                        minStock: minStockVal,
                      );
                      await productsProvider.updateProduct(updated);
                    }

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    TopNotification.showSuccess(
                      context,
                      'تم تحديث مخزون المادة "${product.name}" بنجاح ليصبح ${newCalculatedQty.toStringAsFixed(0)} ${product.unit}.',
                    );
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('حفظ التوريد والتحديث', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQuickSupplyDialog(BuildContext context, List<ProductModel> products) {
    if (products.isEmpty) {
      TopNotification.showWarning(context, 'لا توجد مواد مسجلة حالياً لإضافة توريد لها.');
      return;
    }

    ProductModel selectedProduct = products.first;
    final qtyController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.unarchive, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  const Text('توريد شحنة كميات جديدة للمخزن', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ProductModel>(
                      initialValue: selectedProduct,
                      decoration: InputDecoration(
                        labelText: 'اختر المادة / الصنف المطلوب توريده',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: products.map((p) {
                        return DropdownMenuItem<ProductModel>(
                          value: p,
                          child: Text('${p.name} (المخزون الحالي: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedProduct = val;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'كمية الشحنة الموردة *',
                        prefixIcon: const Icon(Icons.add_circle_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixText: selectedProduct.unit,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final qtyVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
                    if (qtyVal <= 0) {
                      TopNotification.showWarning(context, 'يرجى إدخال كمية توريد صحيحة أكبر من صفر.');
                      return;
                    }

                    final productsProvider = context.read<ProductsProvider>();
                    await productsProvider.addStockQuantity(selectedProduct.id!, qtyVal);

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    TopNotification.showSuccess(
                      context,
                      'تمت إضافة $qtyVal ${selectedProduct.unit} لمخزون "${selectedProduct.name}" بنجاح.',
                    );
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('تأكيد التوريد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
