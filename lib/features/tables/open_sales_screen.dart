import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/restaurant_table.dart';
import '../cashier/cashier_screen.dart';
import '../settings/settings_provider.dart';
import 'tables_provider.dart';

class OpenTableSale {
  final RestaurantTable table;
  final int? orderId;
  final double amount;
  final String? createdAt;
  final int itemsCount;
  final String? itemsSummary;
  final String? notes;

  OpenTableSale({
    required this.table,
    this.orderId,
    required this.amount,
    this.createdAt,
    this.itemsCount = 0,
    this.itemsSummary,
    this.notes,
  });
}

class OpenSalesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;
  final Function(int)? onNavigate;

  const OpenSalesScreen({
    super.key,
    this.onBack,
    this.onOpenMenu,
    this.onNavigate,
  });

  @override
  State<OpenSalesScreen> createState() => _OpenSalesScreenState();
}

class _OpenSalesScreenState extends State<OpenSalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<OpenTableSale> _openSales = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOpenSales();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadOpenSales(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOpenSales({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT 
          t.id AS table_id,
          t.name AS table_name,
          t.capacity AS table_capacity,
          t.shape AS table_shape,
          t.status AS table_status,
          t.pos_x,
          t.pos_y,
          t.sort_order,
          t.floor_id,
          o.id AS order_id,
          COALESCE(o.total, 0.0) AS order_total,
          o.created_at AS order_created_at,
          o.notes AS order_notes,
          (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS items_count,
          (SELECT GROUP_CONCAT(p.name || ' (x' || oi.quantity || ')', '، ') 
           FROM order_items oi 
           JOIN products p ON oi.product_id = p.id 
           WHERE oi.order_id = o.id) AS items_summary
        FROM restaurant_tables t
        LEFT JOIN orders o ON o.table_id = t.id AND o.status IN ('OPEN', 'SUSPENDED')
        WHERE t.status = 1 OR (o.id IS NOT NULL AND o.status IN ('OPEN', 'SUSPENDED'))
        ORDER BY t.sort_order ASC, t.id ASC
      ''');

      final List<OpenTableSale> list = [];
      for (final r in rows) {
        final table = RestaurantTable(
          id: r['table_id'] as int?,
          name: (r['table_name'] as String?) ?? '',
          capacity: (r['table_capacity'] as int?) ?? 4,
          shape: (r['table_shape'] as String?) ?? 'round',
          status: (r['table_status'] as int?) ?? 1,
          posX: (r['pos_x'] as num?)?.toDouble() ?? -1,
          posY: (r['pos_y'] as num?)?.toDouble() ?? -1,
          sortOrder: (r['sort_order'] as int?) ?? 0,
          currentOrderAmount: (r['order_total'] as num?)?.toDouble() ?? 0.0,
          floorId: (r['floor_id'] as int?) ?? 1,
        );

        list.add(OpenTableSale(
          table: table,
          orderId: r['order_id'] as int?,
          amount: (r['order_total'] as num?)?.toDouble() ?? 0.0,
          createdAt: r['order_created_at'] as String?,
          itemsCount: (r['items_count'] as int?) ?? 0,
          itemsSummary: r['items_summary'] as String?,
          notes: r['order_notes'] as String?,
        ));
      }

      if (mounted) {
        setState(() {
          _openSales = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading open sales: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalOpenAmount {
    return _openSales.fold(0.0, (sum, item) => sum + item.amount);
  }

  List<OpenTableSale> get _filteredSales {
    if (_searchQuery.trim().isEmpty) return _openSales;
    final q = _searchQuery.trim().toLowerCase();
    return _openSales.where((s) => s.table.name.toLowerCase().contains(q)).toList();
  }

  String _formatAmount(double amount, String currencySym) {
    final formatted = (amount % 1 == 0) ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final withCommas = formatted.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$withCommas $currencySym';
  }

  Future<void> _openTableInCashier(RestaurantTable table) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashierScreen(
          selectedTable: table,
          onBack: () => Navigator.pop(context),
          onOrderCompleted: () {
            Navigator.pop(context);
            context.read<TablesProvider>().loadTables();
          },
        ),
      ),
    );
    if (mounted) {
      _loadOpenSales();
      context.read<TablesProvider>().loadTables();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isEng = settings.isEnglish;
    final currencySym = settings.currencySymbol;
    final primary = AppColors.primary;

    final filtered = _filteredSales;
    final totalAmount = _totalOpenAmount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            if (widget.onOpenMenu != null)
              IconButton(
                icon: const Icon(Icons.menu, size: 28, color: Colors.white),
                tooltip: isEng ? 'Menu' : 'القائمة الرئيسية',
                onPressed: widget.onOpenMenu,
              )
            else if (widget.onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.white),
                tooltip: isEng ? 'Back' : 'رجوع',
                onPressed: widget.onBack,
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEng ? 'Open Sales (Active Tables)' : 'المبيعات المفتوحة (طاولات الصالة)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  isEng ? 'Live view of occupied tables & current bills' : 'متابعة حية للطاولات المشغولة وحساب كل طاولة',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: isEng ? 'Refresh' : 'تحديث القائمة',
            onPressed: () => _loadOpenSales(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Summary Cards Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Total Open Amount Card
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: isDark ? 0.28 : 0.12),
                          primary.withValues(alpha: isDark ? 0.15 : 0.05),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: primary,
                          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEng ? 'Total Open Sales' : 'مجموع المبيعات المفتوحة',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatAmount(totalAmount, currencySym),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amberAccent : primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Occupied Tables Count Card
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _openSales.isNotEmpty ? Colors.red.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _openSales.isNotEmpty ? Colors.red.shade700 : Colors.green.shade700,
                          child: Icon(
                            _openSales.isNotEmpty ? Icons.table_restaurant_rounded : Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEng ? 'Occupied Tables' : 'الطاولات المشغولة',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_openSales.length} ${isEng ? "Tables" : "طاولة"}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _openSales.isNotEmpty ? Colors.redAccent : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search & Quick Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: isEng ? 'Search occupied tables...' : 'بحث عن طاولة مشغولة باسم أو رقم الطاولة...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // 3. Main Open Sales List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
                                size: 64,
                                color: _searchQuery.isNotEmpty ? Colors.grey : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? (isEng ? 'No matching occupied tables' : 'لا توجد طاولات مطابقة للبحث')
                                  : (isEng ? 'No Open Sales at the moment' : 'لا توجد مبيعات مفتوحة حالياً 🎉'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? (isEng ? 'Try a different table name' : 'تأكد من رقم أو اسم الطاولة')
                                  : (isEng ? 'All dine-in tables are vacant and clear' : 'جميع طاولات الصالة شاغرة وفارغة وجاهزة لاستقبال الزبائن'),
                              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13.5),
                            ),
                            if (widget.onNavigate != null && _searchQuery.isEmpty) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => widget.onNavigate!(1),
                                icon: const Icon(Icons.table_restaurant_rounded, color: Colors.white),
                                label: Text(
                                  isEng ? 'Go to Tables Map' : 'الانتقال إلى مخطط الطاولات',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openTableInCashier(item.table),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                child: Row(
                                  children: [
                                    // Table Number / Icon
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Table Name / Number Only
                                    Expanded(
                                      child: Text(
                                        item.table.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // Table Amount
                                    Text(
                                      _formatAmount(item.amount, currencySym),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amberAccent : const Color(0xFF047857),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
