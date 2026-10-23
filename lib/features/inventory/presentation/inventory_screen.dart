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
  final VoidCallback? onBack;
  const InventoryScreen({super.key, this.onBack});

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
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    final isDark = context.watch<SettingsProvider>().isDarkMode;

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
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2, size: 26),
            const SizedBox(width: 10),
            Text(
              isEng ? 'Inventory & Stock Management' : 'إدارة المخزن والمواد (الكميات والتوريد)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEng ? 'Refresh Inventory Data' : 'تحديث بيانات المخزن',
            onPressed: () {
              productsProvider.loadProducts();
              TopNotification.showSuccess(
                context,
                isEng ? 'Inventory data refreshed successfully.' : 'تم تحديث بيانات المخزن بنجاح.',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickSupplyDialog(context, productsProvider.allProducts),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: Text(
          isEng ? 'Supply Stock Shipment 🏪' : 'توريد شحنة / زيادة مخزون 🏪',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Inventory Summary Cards Row
            _buildInventorySummaryCards(context, productsProvider, isDark),

            const SizedBox(height: 16),

            // 2. Search & Filter Bar
            Card(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0xFF374151) : Colors.transparent,
                ),
              ),
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
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: isEng ? 'Search product or barcode...' : 'بحث باسم المادة أو الباركود...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
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
                          color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
                          border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCatId,
                            dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                            hint: Text(
                              isEng ? 'All Categories' : 'جميع التصنيفات',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade300 : Colors.black87,
                              ),
                            ),
                            isDense: true,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  isEng ? 'All Categories' : 'جميع التصنيفات',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              ...categoriesProvider.categories.map((cat) {
                                final cName = (cat.name == 'عام' && isEng) ? 'General' : cat.name;
                                return DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Text(
                                    cName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
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
                        _buildFilterChip(
                          isEng ? 'All (${productsProvider.allProducts.length})' : 'الكل (${productsProvider.allProducts.length})',
                          StockFilterType.all,
                          Colors.blue,
                          isDark,
                        ),
                        _buildFilterChip(
                          isEng ? 'Good Stock' : 'متوفر جيدا',
                          StockFilterType.normal,
                          Colors.green,
                          isDark,
                        ),
                        _buildFilterChip(
                          isEng ? 'Low Stock (${productsProvider.lowStockProductsCount})' : 'كمية منخفضة (${productsProvider.lowStockProductsCount})',
                          StockFilterType.low,
                          Colors.orange,
                          isDark,
                        ),
                        _buildFilterChip(
                          isEng ? 'Out of Stock (${productsProvider.outOfStockProductsCount})' : 'نافد من المخزن (${productsProvider.outOfStockProductsCount})',
                          StockFilterType.outOfStock,
                          Colors.red,
                          isDark,
                        ),
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
                          Icon(Icons.inventory_sharp, size: 64, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            isEng ? 'No inventory products matching filter criteria' : 'لا توجد مواد في المخزن مطابقة لشروط البحث والتصفية',
                            style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Card(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.transparent),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1050),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF242F3E) : Colors.orange.shade50),
                              columns: [
                                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Item Name / Barcode' : 'اسم المادة / الباركود', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Category' : 'التصنيف', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Unit' : 'الوحدة', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Cost Price' : 'سعر الكلفة', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Sale Price' : 'سعر البيع', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Available Qty' : 'الكمية المتوفرة', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Alert Limit' : 'حد التنبيه', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Stock Status' : 'حالة المخزون', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                DataColumn(label: Text(isEng ? 'Actions & Stock Supply' : 'إجراءات التوريد والتعديل', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                              ],
                              rows: filteredProducts.map((product) {
                                final rawCat = categoriesProvider.categories
                                    .firstWhere(
                                      (c) => c.id == product.categoryId,
                                      orElse: () => const CategoryModel(name: 'عام'),
                                    )
                                    .name;
                                final catName = (rawCat == 'عام' && isEng) ? 'General' : rawCat;

                                return DataRow(
                                  cells: [
                                    DataCell(Text('#${product.id}', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87))),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                          if (product.barcode != null && product.barcode!.isNotEmpty)
                                            Text(
                                              isEng ? 'Barcode: ${product.barcode}' : 'باركود: ${product.barcode}',
                                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Chip(
                                      label: Text(
                                        catName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                                        ),
                                      ),
                                      backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : Colors.blue.shade50,
                                      side: BorderSide(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                                    )),
                                    DataCell(Text(formatUnit(product.unit), style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                                    DataCell(Text('${product.buyPrice.toStringAsFixed(0)} $currencySym', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87))),
                                    DataCell(Text(
                                      '${product.price.toStringAsFixed(0)} $currencySym',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF34D399) : Colors.black87,
                                      ),
                                    )),
                                    DataCell(
                                      _buildStockQuantityBadge(product, isEng, formatUnit, isDark),
                                    ),
                                    DataCell(Text(
                                      '${product.minStock.toStringAsFixed(0)} ${formatUnit(product.unit)}',
                                      style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87),
                                    )),
                                    DataCell(_buildStockStatusChip(product, isEng, isDark)),
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
                                            label: Text(
                                              isEng ? 'Adjust / Add Stock +' : 'تعديل / زيادة المخزون +',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
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

  Widget _buildFilterChip(String label, StockFilterType type, Color activeColor, bool isDark) {
    final isSelected = _selectedStockFilter == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
      side: BorderSide(
        color: isSelected ? activeColor : (isDark ? const Color(0xFF475569) : Colors.transparent),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStockFilter = type;
          });
        }
      },
    );
  }

  Widget _buildInventorySummaryCards(BuildContext context, ProductsProvider provider, bool isDark) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: isEng ? 'Total Inventory Items' : 'إجمالي مواد المخزن',
              value: isEng ? '${provider.totalProductsCount} Items' : '${provider.totalProductsCount} أصناف',
              subtitle: isEng ? 'Registered items in system' : 'المواد المسجلة في النظام',
              icon: Icons.inventory_2_outlined,
              color: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
              isDark: isDark,
            ),
            _buildStatCard(
              title: isEng ? 'Total Available Stock Qty' : 'إجمالي الكميات المتوفرة',
              value: provider.totalStockUnits.toStringAsFixed(0),
              subtitle: isEng ? 'Total units on shelves' : 'مجموع الوحدات في الرفوف',
              icon: Icons.format_list_numbered,
              color: isDark ? const Color(0xFFA78BFA) : Colors.purple.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
              isDark: isDark,
            ),
            _buildStatCard(
              title: isEng ? 'Low / Out of Stock' : 'أصناف خفيضة / نافدة',
              value: isEng
                  ? '${provider.lowStockProductsCount + provider.outOfStockProductsCount} Items'
                  : '${provider.lowStockProductsCount + provider.outOfStockProductsCount} مادة',
              subtitle: isEng ? 'Requires reorder & tracking' : 'تتطلب توريد ومتابعة',
              icon: Icons.warning_amber_rounded,
              color: (provider.lowStockProductsCount + provider.outOfStockProductsCount) > 0
                  ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                  : (isDark ? const Color(0xFF34D399) : Colors.green.shade700),
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
              isDark: isDark,
            ),
            _buildStatCard(
              title: isEng ? 'Inventory Value (Cost & Retail)' : 'قيمة المخزون (بالتكلفة والبيع)',
              value: '${provider.totalCostValue.toStringAsFixed(0)} $currencySym',
              subtitle: isEng
                  ? 'Expected Sales: ${provider.totalRetailValue.toStringAsFixed(0)} $currencySym'
                  : 'البيع المتوقع: ${provider.totalRetailValue.toStringAsFixed(0)} $currencySym',
              icon: Icons.account_balance_wallet_outlined,
              color: isDark ? const Color(0xFF2DD4BF) : Colors.teal.shade700,
              width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
              isDark: isDark,
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
    required bool isDark,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.transparent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockQuantityBadge(ProductModel product, bool isEng, String Function(String) formatUnit, bool isDark) {
    if (!product.trackStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isEng ? 'Untracked' : 'غير متتبع',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade300 : Colors.black54,
          ),
        ),
      );
    }

    Color bgColor = isDark ? Colors.green.shade900.withValues(alpha: 0.4) : Colors.green.shade50;
    Color textColor = isDark ? Colors.green.shade300 : Colors.green.shade900;
    Color borderColor = isDark ? Colors.green.shade700 : Colors.green.shade300;

    if (product.stockQuantity <= 0) {
      bgColor = isDark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade50;
      textColor = isDark ? Colors.red.shade300 : Colors.red.shade900;
      borderColor = isDark ? Colors.red.shade700 : Colors.red.shade300;
    } else if (product.stockQuantity <= product.minStock) {
      bgColor = isDark ? Colors.orange.shade900.withValues(alpha: 0.4) : Colors.orange.shade50;
      textColor = isDark ? Colors.orange.shade300 : Colors.orange.shade900;
      borderColor = isDark ? Colors.orange.shade700 : Colors.orange.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '${product.stockQuantity.toStringAsFixed(0)} ${formatUnit(product.unit)}',
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
      ),
    );
  }

  Widget _buildStockStatusChip(ProductModel product, bool isEng, bool isDark) {
    if (!product.trackStock) {
      return Chip(
        label: Text(isEng ? 'Open' : 'مفتوح', style: const TextStyle(fontSize: 11, color: Colors.white)),
        backgroundColor: isDark ? const Color(0xFF4B5563) : Colors.grey,
      );
    }

    if (product.stockQuantity <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isDark ? Colors.red.shade800 : Colors.red, borderRadius: BorderRadius.circular(6)),
        child: Text(isEng ? 'Out of Stock' : 'نافد من المخزن', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else if (product.stockQuantity <= product.minStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isDark ? Colors.orange.shade900 : Colors.orange.shade800, borderRadius: BorderRadius.circular(6)),
        child: Text(isEng ? 'Low Stock' : 'كمية خفيضة جداً', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isDark ? Colors.green.shade800 : Colors.green.shade700, borderRadius: BorderRadius.circular(6)),
        child: Text(isEng ? 'Good Stock' : 'مخزون جيد', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
  }

  void _showAddStockDialog(BuildContext context, ProductModel product) {
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    final qtyController = TextEditingController(text: '10');
    final minStockController = TextEditingController(text: product.minStock.toStringAsFixed(0));
    bool isDirectSetMode = false;

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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentQty = product.stockQuantity;
            final enteredVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
            final newCalculatedQty = isDirectSetMode ? enteredVal : (currentQty + enteredVal);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDark ? Colors.green.shade900.withValues(alpha: 0.5) : Colors.green.shade100,
                    child: Icon(Icons.add_shopping_cart, color: isDark ? Colors.green.shade300 : Colors.green.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEng ? 'Adjust & Add Product Stock' : 'تعديل و توريد مخزون المادة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
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
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEng ? 'Current Inventory Quantity:' : 'الكمية الحالية في المخزن:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade300 : Colors.black87,
                              ),
                            ),
                            Text(
                              '${currentQty.toStringAsFixed(0)} ${formatUnit(product.unit)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue.shade300 : Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mode Switcher
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(isEng ? 'Add Qty (+)' : 'إضافة كمية شحنة (+)'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(isEng ? 'Direct Set (=)' : 'تعديل الكمية المباشرة (=)'),
                          ),
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
                        Text(
                          isEng ? 'Quick Add Quantity:' : 'إضافة سريعة بالكمية:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 5, 10, 20, 50, 100].map((addAmount) {
                            return OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                foregroundColor: isDark ? Colors.white : null,
                                side: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  final currentVal = double.tryParse(qtyController.text.trim()) ?? 0.0;
                                  qtyController.text = (currentVal + addAmount).toStringAsFixed(0);
                                });
                              },
                              child: Text('+$addAmount ${formatUnit(product.unit)}'),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Quantity Input Field
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: isDirectSetMode
                              ? (isEng ? 'New Inventory Quantity *' : 'الكمية الجديدة للمخزون *')
                              : (isEng ? 'Shipment Added Quantity *' : 'الكمية المضافة للشحنة *'),
                          labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                          prefixIcon: Icon(isDirectSetMode ? Icons.edit_note : Icons.add_circle_outline, color: isDark ? Colors.grey.shade400 : null),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: formatUnit(product.unit),
                          suffixStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),

                      const SizedBox(height: 14),

                      // Min Stock Input Field
                      TextField(
                        controller: minStockController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: isEng ? 'Low Stock Warning Limit' : 'حد التنبيه الأدنى للمخزون',
                          labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                          prefixIcon: Icon(Icons.warning_amber_outlined, color: isDark ? Colors.grey.shade400 : null),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: formatUnit(product.unit),
                          suffixStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Expected Result Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: newCalculatedQty > 0
                              ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
                              : (isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: newCalculatedQty > 0
                                ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
                                : (isDark ? Colors.red.shade700 : Colors.red.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEng ? 'New Expected Quantity:' : 'الكمية الجديدة المتوقعة:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade300 : Colors.black87,
                              ),
                            ),
                            Text(
                              '${newCalculatedQty.toStringAsFixed(0)} ${formatUnit(product.unit)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: newCalculatedQty > 0
                                    ? (isDark ? Colors.green.shade300 : Colors.green.shade900)
                                    : (isDark ? Colors.red.shade300 : Colors.red.shade900),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey.shade300 : null,
                  ),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
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
                      isEng
                          ? 'Stock for "${product.name}" updated successfully to ${newCalculatedQty.toStringAsFixed(0)} ${formatUnit(product.unit)}.'
                          : 'تم تحديث مخزون المادة "${product.name}" بنجاح ليصبح ${newCalculatedQty.toStringAsFixed(0)} ${product.unit}.',
                    );
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    isEng ? 'Save & Update Stock' : 'حفظ التوريد والتحديث',
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

  void _showQuickSupplyDialog(BuildContext context, List<ProductModel> products) {
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;
    if (products.isEmpty) {
      TopNotification.showWarning(
        context,
        isEng ? 'No products registered to supply stock.' : 'لا توجد مواد مسجلة حالياً لإضافة توريد لها.',
      );
      return;
    }

    ProductModel selectedProduct = products.first;
    final qtyController = TextEditingController(text: '50');

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

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.unarchive, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? 'Supply New Stock Shipment' : 'توريد شحنة كميات جديدة للمخزن',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ProductModel>(
                      initialValue: selectedProduct,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Select Product to Supply' : 'اختر المادة / الصنف المطلوب توريده',
                        labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: products.map((p) {
                        return DropdownMenuItem<ProductModel>(
                          value: p,
                          child: Text(
                            isEng
                                ? '${p.name} (Current Stock: ${p.stockQuantity.toStringAsFixed(0)} ${formatUnit(p.unit)})'
                                : '${p.name} (المخزون الحالي: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          ),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Supplied Shipment Qty *' : 'كمية الشحنة الموردة *',
                        labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                        prefixIcon: Icon(Icons.add_circle_outline, color: isDark ? Colors.grey.shade400 : null),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixText: formatUnit(selectedProduct.unit),
                        suffixStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey.shade300 : null,
                  ),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
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
                      TopNotification.showWarning(
                        context,
                        isEng ? 'Please enter valid supply quantity greater than 0.' : 'يرجى إدخال كمية توريد صحيحة أكبر من صفر.',
                      );
                      return;
                    }

                    final productsProvider = context.read<ProductsProvider>();
                    await productsProvider.addStockQuantity(selectedProduct.id!, qtyVal);

                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    TopNotification.showSuccess(
                      context,
                      isEng
                          ? 'Added $qtyVal ${formatUnit(selectedProduct.unit)} to "${selectedProduct.name}" stock.'
                          : 'تمت إضافة $qtyVal ${selectedProduct.unit} لمخزون "${selectedProduct.name}" بنجاح.',
                    );
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    isEng ? 'Confirm Supply' : 'تأكيد التوريد',
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
}
