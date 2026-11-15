import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/item_note_dialog.dart';
import '../../services/waiter_api_client.dart';
import '../settings/settings_provider.dart';
import 'waiter_display_settings.dart';

class WaiterOrderScreen extends StatefulWidget {
  final WaiterApiClient apiClient;
  final int tableId;
  final String tableName;
  final String waiterName;

  const WaiterOrderScreen({
    super.key,
    required this.apiClient,
    required this.tableId,
    required this.tableName,
    required this.waiterName,
  });

  @override
  State<WaiterOrderScreen> createState() => _WaiterOrderScreenState();
}

class _WaiterOrderScreenState extends State<WaiterOrderScreen> {
  // Vibrant palette identical to Cashier screen
  static const List<Color> _autoItemColors = [
    Color(0xFF1E3A8A), // Royal Dark Blue
    Color(0xFF065F46), // Deep Emerald
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

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  int? _selectedCategoryId;
  bool _showAllProducts = false;
  String _searchQuery = '';

  // Rearrange / Swapping mode states
  bool _isRearrangeMode = false;
  int? _rearrangeSelectedId;
  final Map<String, List<int>> _savedOrders = {};

  // Order items map for the CURRENT unsent round: productId -> Map with product info, quantity, notes
  final Map<int, Map<String, dynamic>> _selectedItems = {};

  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _orderNotesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String get _currencySymbol {
    try {
      return context.watch<SettingsProvider>().currencySymbol;
    } catch (_) {
      return 'د.ع';
    }
  }

  @override
  void initState() {
    super.initState();
    WaiterDisplaySettings.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _orderNotesController.dispose();
    _searchController.dispose();
    super.dispose();
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

  Color _getCategoryColor(Map<String, dynamic> category, [int index = 0]) {
    final custom = _parseColor(category['color'] as String?);
    if (custom != null) return custom;
    final idVal = (category['id'] as int?) ?? (index + 1);
    return _autoCategoryColors[idVal.abs() % _autoCategoryColors.length];
  }

  Color _getProductColor(Map<String, dynamic> product, [int fallbackIndex = 0]) {
    final custom = _parseColor(product['color'] as String?);
    if (custom != null) return custom;
    final key = (product['id'] as int?) ?? (fallbackIndex + 1);
    return _autoItemColors[key.abs() % _autoItemColors.length];
  }

  Future<void> _loadSavedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('waiter_order_') || k.startsWith('waiter_cat_order_') || k == 'waiter_categories_order');
      for (final k in keys) {
        final raw = prefs.getString(k) ?? '';
        if (raw.isNotEmpty) {
          _savedOrders[k] = raw.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved orders: $e');
    }
  }

  List<Map<String, dynamic>> _applySavedOrder(List<Map<String, dynamic>> items, String key) {
    final savedOrder = _savedOrders[key];
    if (savedOrder == null || savedOrder.isEmpty) return items;

    final Map<int, Map<String, dynamic>> itemMap = {
      for (var it in items) (it['id'] as int): it
    };
    final List<Map<String, dynamic>> result = [];
    for (final id in savedOrder) {
      if (itemMap.containsKey(id)) {
        result.add(itemMap.remove(id)!);
      }
    }
    result.addAll(itemMap.values);
    return result;
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await _loadSavedOrders();
      final categories = await widget.apiClient.getCategories();
      final products = await widget.apiClient.getProducts();

      if (mounted) {
        setState(() {
          _categories = categories;
          _allProducts = products;
          _isLoading = false;
        });
        _filterProducts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المنيو: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterProducts() {
    final rawFiltered = _allProducts.where((p) {
      final matchesCategory = _showAllProducts ||
          _selectedCategoryId == null ||
          p['category_id'] == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty ||
          (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final key = _selectedCategoryId != null
        ? 'waiter_cat_order_$_selectedCategoryId'
        : 'waiter_order_all';

    setState(() {
      _filteredProducts = _applySavedOrder(rawFiltered, key);
    });
  }

  Future<void> _swapItems(int id1, int id2, bool isCategory) async {
    if (id1 == id2) return;

    if (isCategory) {
      final list = _applySavedOrder(_categories, 'waiter_categories_order');
      final idx1 = list.indexWhere((c) => c['id'] == id1);
      final idx2 = list.indexWhere((c) => c['id'] == id2);
      if (idx1 == -1 || idx2 == -1) return;

      final name1 = list[idx1]['name'] ?? '';
      final name2 = list[idx2]['name'] ?? '';

      final updated = List<Map<String, dynamic>>.from(list);
      final temp = updated[idx1];
      updated[idx1] = updated[idx2];
      updated[idx2] = temp;

      final newIds = updated.map((c) => c['id'] as int).toList();
      _savedOrders['waiter_categories_order'] = newIds;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('waiter_categories_order', newIds.join(','));

      setState(() {
        _rearrangeSelectedId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تبديل موقع قسم ($name1) مع ($name2) بنجاح ⇄'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      final list = _filteredProducts;
      final idx1 = list.indexWhere((p) => p['id'] == id1);
      final idx2 = list.indexWhere((p) => p['id'] == id2);
      if (idx1 == -1 || idx2 == -1) return;

      final name1 = list[idx1]['name'] ?? '';
      final name2 = list[idx2]['name'] ?? '';

      final updated = List<Map<String, dynamic>>.from(list);
      final temp = updated[idx1];
      updated[idx1] = updated[idx2];
      updated[idx2] = temp;

      final newIds = updated.map((p) => p['id'] as int).toList();
      final key = _selectedCategoryId != null
          ? 'waiter_cat_order_$_selectedCategoryId'
          : 'waiter_order_all';

      _savedOrders[key] = newIds;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, newIds.join(','));

      setState(() {
        _rearrangeSelectedId = null;
        _filterProducts();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تبديل موقع ($name1) مع ($name2) بنجاح ⇄'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _resetOrder(String key) async {
    _savedOrders.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    setState(() {
      _rearrangeSelectedId = null;
      _filterProducts();
    });
  }

  void _addItem(Map<String, dynamic> product) {
    final pid = product['id'] as int;
    final name = product['name'] as String;
    final price = (product['price'] as num).toDouble();

    setState(() {
      if (_selectedItems.containsKey(pid)) {
        _selectedItems[pid]!['quantity'] = (_selectedItems[pid]!['quantity'] as double) + 1.0;
      } else {
        _selectedItems[pid] = {
          'id': pid,
          'product_id': pid,
          'name': name,
          'product_name': name,
          'price': price,
          'quantity': 1.0,
          'notes': '',
        };
      }
    });
  }

  void _removeItem(int productId) {
    setState(() {
      if (_selectedItems.containsKey(productId)) {
        final currentQty = _selectedItems[productId]!['quantity'] as double;
        if (currentQty > 1) {
          _selectedItems[productId]!['quantity'] = currentQty - 1.0;
        } else {
          _selectedItems.remove(productId);
        }
      }
    });
  }

  Future<void> _showItemNoteDialog(int productId, String productName) async {
    final existingNote = (_selectedItems[productId]?['notes'] as String?) ?? '';

    final result = await ItemNoteDialog.show(
      context,
      productName: productName,
      initialNote: existingNote,
    );

    if (result != null) {
      setState(() {
        if (_selectedItems.containsKey(productId)) {
          _selectedItems[productId]!['notes'] = result;
        } else {
          final product = _allProducts.firstWhere((p) => p['id'] == productId, orElse: () => {});
          if (product.isNotEmpty) {
            _addItem(product);
            _selectedItems[productId]!['notes'] = result;
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isEmpty ? 'تم مسح ملاحظة الصنف 🗑️' : 'تم حفظ ملاحظة الصنف للمطبخ ✅'),
            backgroundColor: result.isEmpty ? Colors.redAccent : const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  double _calculateTotal() {
    double total = 0;
    _selectedItems.forEach((_, item) {
      total += (item['price'] as double) * (item['quantity'] as double);
    });
    return total;
  }

  Future<void> _sendOrderToCashier() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار أصناف أولاً!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSending = true);

    final itemsList = _selectedItems.values.toList();
    final total = _calculateTotal();
    final notes = _orderNotesController.text.trim();

    final success = await widget.apiClient.sendTableOrder(
      tableId: widget.tableId,
      waiterName: widget.waiterName,
      items: itemsList,
      total: total,
      notes: notes.isNotEmpty ? notes : null,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('تم إرسال طلب ${widget.tableName} بنجاح للكاشير 🚀'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال الطلب، تأكد من الاتصال.'), backgroundColor: Colors.red),
      );
    }
  }

  void _showOrderReviewSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final total = _calculateTotal();
            final itemsList = _selectedItems.values.toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Text(
                                'مراجعة الطلب (${itemsList.length} أصناف)',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (_selectedItems.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _selectedItems.clear());
                                setSheetState(() {});
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              label: const Text('إفراغ الكل', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF374151)),
                    Expanded(
                      child: itemsList.isEmpty
                          ? const Center(
                              child: Text(
                                'لم يتم اختيار أي أصناف بعد',
                                style: TextStyle(color: Colors.grey, fontSize: 15),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: itemsList.length,
                              separatorBuilder: (context, index) => const Divider(color: Color(0xFF374151), height: 1),
                              itemBuilder: (context, idx) {
                                final it = itemsList[idx];
                                final pid = it['product_id'] as int;
                                final name = it['name'] as String;
                                final price = (it['price'] as num).toDouble();
                                final qty = (it['quantity'] as num).toDouble();
                                final note = (it['notes'] as String?) ?? '';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(price * qty).toStringAsFixed(0)} $_currencySymbol  (${price.toStringAsFixed(0)} × ${qty.toInt()})',
                                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      if (note.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '📝 $note',
                                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_note,
                                          color: note.isNotEmpty ? Colors.amber : Colors.grey.shade400,
                                          size: 24,
                                        ),
                                        tooltip: 'ملاحظة المطبخ',
                                        onPressed: () async {
                                          await _showItemNoteDialog(pid, name);
                                          setState(() {});
                                          setSheetState(() {});
                                        },
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF374151),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
                                              onPressed: () {
                                                _removeItem(pid);
                                                setState(() {});
                                                setSheetState(() {});
                                              },
                                            ),
                                            Text(
                                              '${qty.toInt()}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                                              onPressed: () {
                                                _addItem({'id': pid, 'name': name, 'price': price});
                                                setState(() {});
                                                setSheetState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _orderNotesController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'ملاحظة عامة للطلب (اختياري)...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.grey, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF111827),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF111827),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي النهائي:', style: TextStyle(color: Colors.grey, fontSize: 15)),
                                Text(
                                  '${total.toStringAsFixed(0)} $_currencySymbol',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSending || _selectedItems.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(ctx);
                                        _sendOrderToCashier();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _isSending
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('إرسال الطلب للكاشير 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
    final itemCount = _selectedItems.values.fold<int>(0, (sum, i) => sum + (i['quantity'] as double).toInt());

    final showingCategoriesView = _selectedCategoryId == null && !_showAllProducts && _searchQuery.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: Text(
          'طلب طاولة - ${widget.tableName}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          // Rearrange / Swapping mode button
          Tooltip(
            message: _isRearrangeMode ? 'إنهاء وضع ترتيب المواد' : 'ترتيب وتبديل أماكن المواد والتصنيفات',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _isRearrangeMode = !_isRearrangeMode;
                  _rearrangeSelectedId = null;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isRearrangeMode ? const Color(0xFF10B981) : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isRearrangeMode ? Colors.greenAccent : Colors.grey.shade600,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRearrangeMode ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                      size: 18,
                      color: _isRearrangeMode ? Colors.white : Colors.tealAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isRearrangeMode ? 'إنهاء الترتيب' : 'تبديل الأماكن ⇄',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedItems.isNotEmpty && !_isRearrangeMode)
            GestureDetector(
              onTap: _showOrderReviewSheet,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_cart, size: 15, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount أصناف',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Column(
              children: [
                // Top Search Bar (hidden or disabled in rearrange mode to prevent confusion)
                if (!_isRearrangeMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'بحث في الأصناف...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _filterProducts();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF1F2937),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        _searchQuery = val.trim();
                        _filterProducts();
                      },
                    ),
                  ),

                // Breadcrumb & Navigation Bar
                _buildHeaderBar(showingCategoriesView),

                // Rearrange Instruction Banner
                if (_isRearrangeMode)
                  _buildRearrangeBanner(showingCategoriesView),

                // Main Content (Categories Grid or Items Grid)
                Expanded(
                  child: showingCategoriesView
                      ? _buildCategoriesGrid()
                      : _buildItemsGrid(),
                ),

                // Bottom Action Bar (hidden in rearrange mode for cleaner space)
                if (!_isRearrangeMode)
                  _buildBottomActionBar(total, itemCount),
              ],
            ),
    );
  }

  Widget _buildRearrangeBanner(bool showingCategoriesView) {
    final targetName = showingCategoriesView ? 'التصنيفات' : 'المواد';
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.tealAccent, width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _rearrangeSelectedId == null
                  ? 'اضغط على الصنف الأول ثم الثاني لتبديل مكانهما فوراً ⇄ أو اسحب وأفلت'
                  : 'تم تحديد الصنف الأول! الآن اضغط على صنف آخر للتبديل معه',
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_rearrangeSelectedId != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _rearrangeSelectedId = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent, width: 0.8),
                ),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              final key = showingCategoriesView
                  ? 'waiter_categories_order'
                  : (_selectedCategoryId != null
                      ? 'waiter_cat_order_$_selectedCategoryId'
                      : 'waiter_order_all');
              await _resetOrder(key);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تمت إعادة ضبط ترتيب $targetName للافتراضي بنجاح'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade600, width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restart_alt, size: 12, color: Colors.amber),
                  SizedBox(width: 2),
                  Text('إعادة ضبط', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(bool showingCategoriesView) {
    if (showingCategoriesView) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: const Color(0xFF1F2937).withValues(alpha: 0.6),
        child: Row(
          children: [
            const Icon(Icons.category_rounded, size: 17, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            const Text(
              'الأقسام الرئيسية',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const Spacer(),
            Text(
              '${_categories.length} قسم',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    String title;
    if (_searchQuery.isNotEmpty) {
      title = 'نتائج البحث عن "$_searchQuery"';
    } else if (_showAllProducts) {
      title = 'جميع الأصناف';
    } else {
      final selectedCat = _categories.firstWhere(
        (c) => c['id'] == _selectedCategoryId,
        orElse: () => {'name': 'القسم'},
      );
      title = selectedCat['name'] as String? ?? 'القسم';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFF1F2937).withValues(alpha: 0.6),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              if (_isRearrangeMode) {
                setState(() => _rearrangeSelectedId = null);
              }
              setState(() {
                _selectedCategoryId = null;
                _showAllProducts = false;
                _searchController.clear();
                _searchQuery = '';
                _filterProducts();
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, size: 16, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text('الأقسام', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('←', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_filteredProducts.length} صنف',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // 1. Categories Grid
  Widget _buildCategoriesGrid() {
    if (_categories.isEmpty) {
      return const Center(
        child: Text('لا توجد أقسام مسجلة في النظام', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    final orderedCategories = _applySavedOrder(_categories, 'waiter_categories_order');
    final totalCount = orderedCategories.length + 1; // +1 for "عرض الكل" card

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: WaiterDisplaySettings.buildItemsGridDelegate(),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAllProductsCard();
        }
        final category = orderedCategories[index - 1];
        return _buildCategoryCard(category, index - 1);
      },
    );
  }

  Widget _buildAllProductsCard() {
    return Card(
      elevation: 2.5,
      shadowColor: Colors.black38,
      color: const Color(0xFF0D9488),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_isRearrangeMode) return;
          setState(() {
            _selectedCategoryId = null;
            _showAllProducts = true;
            _filterProducts();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0D9488).withValues(alpha: 0.9),
                const Color(0xFF0F766E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.grid_view_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: (13.5 * WaiterDisplaySettings.itemScale).clamp(10.5, 19.0),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 2.5, offset: Offset(0, 1))],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_allProducts.length} صنف',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final imagePath = category['image'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
    final bgColor = _getCategoryColor(category, index);
    final isDarkBg = hasImage || (bgColor.computeLuminance() < 0.55);
    final textColor = isDarkBg ? Colors.white : const Color(0xFF0F172A);
    final catName = (category['name'] as String?) ?? '';
    final catId = category['id'] as int;

    final count = _allProducts.where((p) => p['category_id'] == catId).length;
    final isSelectedForSwap = _isRearrangeMode && _rearrangeSelectedId == catId;

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
                  ? Colors.tealAccent.withValues(alpha: 0.7)
                  : (isDarkBg ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF475569))),
          width: isSelectedForSwap ? 3.5 : (_isRearrangeMode ? 1.8 : 1.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_isRearrangeMode) {
            if (_rearrangeSelectedId == null) {
              setState(() => _rearrangeSelectedId = catId);
            } else if (_rearrangeSelectedId == catId) {
              setState(() => _rearrangeSelectedId = null);
            } else {
              _swapItems(_rearrangeSelectedId!, catId, true);
            }
            return;
          }
          setState(() {
            _selectedCategoryId = catId;
            _showAllProducts = false;
            _filterProducts();
          });
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
                    File(imagePath),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          catName,
                          style: TextStyle(
                            fontSize: (13.5 * WaiterDisplaySettings.itemScale).clamp(10.5, 19.0),
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
                        if (count > 0) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$count صنف',
                              style: TextStyle(
                                color: isDarkBg ? Colors.white70 : Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Rearrange indicator badge
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
                    child: const Text('محدد للتبديل ⇄', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!_isRearrangeMode) return cardContent;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != catId,
      onAcceptWithDetails: (details) {
        _swapItems(details.data, catId, true);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: catId,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 105,
              height: 105,
              child: Opacity(opacity: 0.85, child: cardContent),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
          child: cardContent,
        );
      },
    );
  }

  // 2. Items Grid (identical to Cashier screen items grid)
  Widget _buildItemsGrid() {
    final isSearching = _searchQuery.isNotEmpty;
    // When not searching, index 0 is the "الرجوع ← القائمة" Back card!
    final totalCount = isSearching ? _filteredProducts.length : _filteredProducts.length + 1;

    if (_filteredProducts.isEmpty && isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('لا توجد أصناف تطابق "$_searchQuery"', style: const TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: WaiterDisplaySettings.buildItemsGridDelegate(),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (!isSearching && index == 0) {
          return _buildBackCard();
        }

        final productIndex = isSearching ? index : index - 1;
        final product = _filteredProducts[productIndex];
        return _buildProductCard(product, productIndex);
      },
    );
  }

  Widget _buildBackCard() {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: Color(0xFF3F3F46),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_isRearrangeMode) {
            setState(() => _rearrangeSelectedId = null);
          }
          setState(() {
            _selectedCategoryId = null;
            _showAllProducts = false;
            _searchController.clear();
            _searchQuery = '';
            _filterProducts();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF27272A),
          ),
          padding: const EdgeInsets.all(4),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3F3F46),
                  child: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'الرجوع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '← القائمة',
                  style: TextStyle(
                    color: Colors.grey,
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

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final pid = product['id'] as int;
    final name = (product['name'] as String?) ?? '';
    final price = (product['price'] as num).toDouble();
    final isWeighted = product['is_weighted'] == 1;
    final allowPriceChange = product['allow_price_change'] == 1;

    final currentQty = (_selectedItems[pid]?['quantity'] as double?) ?? 0;
    final isSelected = currentQty > 0;
    final itemNote = (_selectedItems[pid]?['notes'] as String?) ?? '';

    final imagePath = product['image'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();
    final rawBgColor = _getProductColor(product, index);
    final bgColor = rawBgColor;
    final isDarkBg = hasImage || (bgColor.computeLuminance() < 0.55);
    final textColor = isDarkBg ? Colors.white : const Color(0xFF0F172A);
    final priceColor = isDarkBg ? Colors.amberAccent : const Color(0xFF1E3A8A);

    final scale = WaiterDisplaySettings.itemScale;
    final prodFontSize = (12.5 * scale).clamp(9.5, 18.0);
    final priceFontSize = (11.0 * scale).clamp(8.5, 16.0);
    final badgeFontSize = (10.5 * scale).clamp(8.5, 15.0);

    final isSelectedForSwap = _isRearrangeMode && _rearrangeSelectedId == pid;

    Widget cardContent = Card(
      elevation: isSelectedForSwap ? 6 : (isSelected ? 4 : 2),
      shadowColor: Colors.black45,
      color: hasImage ? Colors.black : bgColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelectedForSwap
              ? Colors.amberAccent
              : (_isRearrangeMode
                  ? Colors.tealAccent.withValues(alpha: 0.7)
                  : (isSelected
                      ? Colors.amberAccent
                      : (isDarkBg ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF475569)))),
          width: isSelectedForSwap ? 3.5 : (_isRearrangeMode ? 1.8 : (isSelected ? 2.5 : 1.2)),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_isRearrangeMode) {
            if (_rearrangeSelectedId == null) {
              setState(() => _rearrangeSelectedId = pid);
            } else if (_rearrangeSelectedId == pid) {
              setState(() => _rearrangeSelectedId = null);
            } else {
              _swapItems(_rearrangeSelectedId!, pid, false);
            }
            return;
          }
          _addItem(product);
        },
        onLongPress: () {
          if (_isRearrangeMode) return;
          _showItemNoteDialog(pid, name);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Background Gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    gradient: (!hasImage)
                        ? LinearGradient(
                            colors: [
                              bgColor.withValues(alpha: 0.9),
                              bgColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                ),
              ),

              // Image Background
              if (hasImage)
                Positioned.fill(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(color: bgColor),
                  ),
                ),
              if (hasImage)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),

              // Central Content (Product Name & Price Badge)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
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
                                  ? Colors.black.withValues(alpha: 0.4)
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
                              '${price.toStringAsFixed(0)} $_currencySymbol',
                              style: TextStyle(
                                color: priceColor,
                                fontWeight: FontWeight.w900,
                                fontSize: priceFontSize,
                              ),
                            ),
                          ),
                          if (isWeighted || allowPriceChange) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isWeighted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade900.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('⚖️', style: TextStyle(fontSize: 8)),
                                  ),
                                if (allowPriceChange)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade900.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('🏷️', style: TextStyle(fontSize: 8)),
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

              // Selected Quantity Badge (Top Corner) - hidden in rearrange mode
              if (isSelected && !_isRearrangeMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
                    ),
                    child: Text(
                      '×${currentQty.toInt()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

              // Note Badge (Top-left Corner)
              if (itemNote.isNotEmpty && !_isRearrangeMode)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade800,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
                    ),
                    child: const Text('📝', style: TextStyle(fontSize: 10)),
                  ),
                ),

              // Quick Controls when Selected (Minus & Note icons in corners) - hidden in rearrange mode
              if (isSelected && !_isRearrangeMode) ...[
                Positioned(
                  bottom: 3,
                  left: 3,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _removeItem(pid),
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                        ),
                        child: const Icon(Icons.remove, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showItemNoteDialog(pid, name),
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: (itemNote.isNotEmpty ? Colors.amber.shade700 : Colors.black54),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                        ),
                        child: const Icon(Icons.edit_note, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],

              // Rearrange Swap Indicators
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
                    child: const Text(
                      'محدد للتبديل ⇄',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

    if (!_isRearrangeMode) return cardContent;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != pid,
      onAcceptWithDetails: (details) {
        _swapItems(details.data, pid, false);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: pid,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 105,
              height: 105,
              child: Opacity(opacity: 0.85, child: cardContent),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
          child: cardContent,
        );
      },
    );
  }

  // 3. Bottom Action Bar
  Widget _buildBottomActionBar(double total, int itemCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _selectedItems.isNotEmpty ? _showOrderReviewSheet : null,
                  child: Row(
                    children: [
                      const Text(
                        'إجمالي الطلب:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${total.toStringAsFixed(0)} $_currencySymbol',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showOrderReviewSheet,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      foregroundColor: Colors.amberAccent,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text(
                      'مراجعة الطلب',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSending || _selectedItems.isEmpty ? null : _sendOrderToCashier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
                child: _isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'إرسال إلى الكاشير ($itemCount أصناف)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
