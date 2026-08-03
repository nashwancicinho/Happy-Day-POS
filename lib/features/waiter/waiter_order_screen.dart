import 'package:flutter/material.dart';
import '../../services/waiter_api_client.dart';

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
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  int? _selectedCategoryId;
  String _searchQuery = '';

  // Order items map: productId -> Map with product info, quantity, notes
  final Map<int, Map<String, dynamic>> _selectedItems = {};

  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _orderNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final categories = await widget.apiClient.getCategories();
      final products = await widget.apiClient.getProducts();

      // Check if table has an active order
      final existingOrderData = await widget.apiClient.getTableOrder(widget.tableId);

      if (existingOrderData != null && existingOrderData['items'] != null) {
        final rawItems = existingOrderData['items'] as List<dynamic>;
        for (final item in rawItems) {
          final pid = item['product_id'] as int;
          final pName = item['product_name'] as String? ?? 'صنف $pid';
          final qty = (item['quantity'] as num).toDouble();
          final price = (item['price'] as num).toDouble();
          final notes = item['notes'] as String?;

          _selectedItems[pid] = {
            'product_id': pid,
            'product_name': pName,
            'price': price,
            'quantity': qty,
            'notes': notes ?? '',
          };
        }
      }

      if (mounted) {
        setState(() {
          _categories = categories;
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
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
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesCategory = _selectedCategoryId == null || p['category_id'] == _selectedCategoryId;
        final matchesSearch = _searchQuery.isEmpty ||
            (p['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
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
          'product_id': pid,
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

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('إلغاء الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت تأكد من رغبتك في إلغاء فاتورة ${widget.tableName} وإخلاء الطاولة بالكامل؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، إلغاء وإخلاء الطاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSending = true);

      final success = await widget.apiClient.cancelTableOrder(widget.tableId);

      if (!mounted) return;

      setState(() => _isSending = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إلغاء فاتورة ${widget.tableName} وإخلاء الطاولة ❌'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إلغاء الفاتورة، تأكد من الاتصال.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();
    final itemCount = _selectedItems.values.fold<int>(0, (sum, i) => sum + (i['quantity'] as double).toInt());

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: Text(
          'طلب جديد - ${widget.tableName}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            tooltip: 'إلغاء الفاتورة وإخلاء الطاولة',
            onPressed: _isSending ? null : _cancelOrder,
          ),
          if (_selectedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$itemCount أصناف',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
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
                // Category Filter Tabs
                Container(
                  height: 50,
                  color: const Color(0xFF1F2937),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    itemCount: _categories.length + 1,
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final catId = isAll ? null : _categories[index - 1]['id'] as int;
                      final catName = isAll ? 'الكل' : _categories[index - 1]['name'] as String;
                      final isSelected = _selectedCategoryId == catId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(catName),
                          selected: isSelected,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF374151),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade300,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryId = isAll ? null : catId;
                              _filterProducts();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'بحث عن وجبة أو مشروب...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _filterProducts();
                    },
                  ),
                ),

                // Product List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final pid = product['id'] as int;
                      final name = product['name'] as String;
                      final price = (product['price'] as num).toDouble();
                      final currentQty = (_selectedItems[pid]?['quantity'] as double?) ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: currentQty > 0
                              ? Border.all(color: const Color(0xFF10B981), width: 1.5)
                              : Border.all(color: Colors.transparent),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                          ),
                          subtitle: Text(
                            '${price.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                          trailing: currentQty == 0
                              ? ElevatedButton.icon(
                                  onPressed: () => _addItem(product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('إضافة'),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, color: Colors.redAccent, size: 18),
                                        onPressed: () => _removeItem(pid),
                                      ),
                                      Text(
                                        '${currentQty.toInt()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, color: Color(0xFF10B981), size: 18),
                                        onPressed: () => _addItem(product),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Bar (Total & Send Button)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي الطلب:',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            Text(
                              '${total.toStringAsFixed(0)} د.ع',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isSending || _selectedItems.isEmpty ? null : _sendOrderToCashier,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade800,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: _isSending
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.send_rounded),
                                      const SizedBox(width: 8),
                                      Text(
                                        'إرسال إلى الكاشير (${_selectedItems.length} أصناف)',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
