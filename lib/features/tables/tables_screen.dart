import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/restaurant_table.dart';
import '../cashier/cashier_screen.dart';
import '../orders/orders_provider.dart';
import '../settings/settings_provider.dart';
import 'floor_plan_canvas.dart';

import 'tables_provider.dart';

class TablesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onOrderCompleted;

  const TablesScreen({super.key, this.onBack, this.onOrderCompleted});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  bool _isDeleteMode = false;
  bool _isDesignMode = false;
  final bool _isFloorPlanView = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TablesProvider>().loadTables();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_isDesignMode) {
        context.read<TablesProvider>().loadTables();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _openCashierForTable(RestaurantTable table) async {
    if (table.status == 2) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.event_seat_rounded, color: Colors.amber.shade800, size: 26),
              const SizedBox(width: 8),
              Text('طاولة محجوزة (${table.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text('طاولة (${table.name}) محجوزة مسبقاً 📅.\nهل تريد بدء الطلب وفتح الفاتورة الآن، أم إلغاء الحجز؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('إلغاء الحجز (شاغرة)'),
              onPressed: () async {
                Navigator.pop(ctx, false);
                await context.read<TablesProvider>().changeTableStatus(table.id!, 0);
                if (mounted) {
                  TopNotification.showSuccess(context, '✅ تم إلغاء حجز (${table.name}) وأصبحت شاغرة.');
                }
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              icon: const Icon(Icons.check, color: Colors.white, size: 16),
              label: const Text('بدء الطلب 🍽️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
      if (!mounted) return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CashierScreen(
          selectedTable: table,
          onBack: widget.onBack,
          onOrderCompleted: widget.onOrderCompleted,
        ),
      ),
    );

    if (!mounted) return;
    context.read<TablesProvider>().loadTables();

    if (result == true) {
      if (widget.onOrderCompleted != null) {
        widget.onOrderCompleted!();
      } else if (widget.onBack != null) {
        widget.onBack!();
      }
    }
  }

  void _confirmDeleteTable(BuildContext parentContext, RestaurantTable table) {
    if (table.status == 1) {
      showDialog(
        context: parentContext,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Text('لا يمكن مسح الطاولة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Text('لا يمكن مسح (${table.name}) لأنها مشغولة بطلب قائم حالياً!\nيرجى تفريغ الطاولة أو إتمام الطلب أولاً.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('حسناً، فهمت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('تأكيد مسح الطاولة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل أنت متأكد من مسح (${table.name}) نهائياً من الصالة والنظام؟'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (table.id != null) {
                await parentContext.read<TablesProvider>().deleteTable(table.id!);
                if (parentContext.mounted) {
                  TopNotification.showSuccess(parentContext, '🎉 تم مسح (${table.name}) بنجاح!');
                }
              }
            },
            child: const Text('مسح الطاولة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(BuildContext parentContext, RestaurantTable table) {
    final nameController = TextEditingController(text: table.name);
    final capacityController = TextEditingController(text: table.capacity.toString());
    String selectedShape = table.shape;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.indigo, size: 26),
                  const SizedBox(width: 8),
                  Text("تعديل بيانات ${table.name}"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "اسم الطاولة", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "السعة الاستيعابية (عدد الأشخاص)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedShape,
                    decoration: const InputDecoration(labelText: "شكل الطاولة في الصالة", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'square', child: Text('طاولة مربعة ⬛')),
                      DropdownMenuItem(value: 'round', child: Text('طاولة دائرية ⚪')),
                      DropdownMenuItem(value: 'rectangle', child: Text('طاولة مستطيلة ▭')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setLocalState(() => selectedShape = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final capacity = int.tryParse(capacityController.text.trim()) ?? table.capacity;

                    if (name.isEmpty) return;

                    final updatedTable = table.copyWith(name: name, capacity: capacity, shape: selectedShape);
                    await parentContext.read<TablesProvider>().updateTable(updatedTable);

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      TopNotification.showSuccess(parentContext, '🎉 تم تعديل بيانات (${table.name}) بنجاح!');
                    }
                  },
                  child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectTableToEditDialog(BuildContext context) {
    final tablesProvider = context.read<TablesProvider>();
    final tables = tablesProvider.tables;

    if (tables.isEmpty) {
      TopNotification.showWarning(context, 'لا توجد طاولات مضافة في الصالة لتعديلها.');
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Colors.blue, size: 26),
                SizedBox(width: 8),
                Text('تعديل بيانات الطاولات ✏️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختر الطاولة التي ترغب بتعديل اسمها أو سعتها أو شكلها في الصالة:',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: tables.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final table = tables[index];
                        final isOcc = table.status == 1;
                        final isRes = table.status == 2;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOcc
                                ? Colors.red.shade100
                                : (isRes ? Colors.amber.shade100 : Colors.green.shade100),
                            child: Icon(
                              table.shape == 'round' ? Icons.circle_outlined : Icons.table_restaurant,
                              color: isOcc
                                  ? Colors.red.shade800
                                  : (isRes ? Colors.amber.shade900 : Colors.green.shade800),
                            ),
                          ),
                          title: Text(table.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('السعة: ${table.capacity} أشخاص | الشكل: ${table.shape == 'round' ? 'دائري' : (table.shape == 'rectangle' ? 'مستطيل' : 'مربع')}'),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل'),
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              _showEditTableDialog(context, table);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTableReservationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final tablesProvider = context.watch<TablesProvider>();
          final tables = tablesProvider.tables;

          final vacantCount = tables.where((t) => t.status == 0).length;
          final reservedCount = tables.where((t) => t.status == 2).length;
          final occupiedCount = tables.where((t) => t.status == 1).length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.event_seat_rounded, color: Colors.amber.shade900, size: 24),
                ),
                const SizedBox(width: 10),
                const Text('إدارة حجز الطاولات 📅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: 550,
              height: 460,
              child: Column(
                children: [
                  // Summary Badges
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            children: [
                              Text('$vacantCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                              const Text('شاغرة (متاحة)', style: TextStyle(fontSize: 11, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            children: [
                              Text('$reservedCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900)),
                              const Text('محجوزة', style: TextStyle(fontSize: 11, color: Colors.amber)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            children: [
                              Text('$occupiedCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade800)),
                              const Text('مشغولة', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  // Tables List
                  Expanded(
                    child: tables.isEmpty
                        ? const Center(child: Text('لا توجد طاولات مضافة في الصالة'))
                        : ListView.separated(
                            itemCount: tables.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final table = tables[index];
                              final isOcc = table.status == 1;
                              final isRes = table.status == 2;
                              final isVac = table.status == 0;

                              Color statusColor = isOcc
                                  ? Colors.red
                                  : (isRes ? Colors.amber.shade800 : Colors.green);
                              String statusText = isOcc
                                  ? 'مشغولة حالياً'
                                  : (isRes ? 'محجوزة 📅' : 'شاغرة ومتاحة');

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    isRes ? Icons.bookmark_rounded : Icons.table_restaurant,
                                    color: statusColor,
                                    size: 18,
                                  ),
                                ),
                                title: Text(table.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('سعة ${table.capacity} أشخاص', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isVac)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade800,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.bookmark_add_rounded, size: 15),
                                        label: const Text('حجز الطاولة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          await tablesProvider.changeTableStatus(table.id!, 2);
                                          if (context.mounted) {
                                            TopNotification.showSuccess(context, '📌 تم حجز (${table.name}) بنجاح');
                                          }
                                        },
                                      ),
                                    if (isRes) ...[
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          side: BorderSide(color: Colors.red.shade300),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.cancel_outlined, size: 14),
                                        label: const Text('إلغاء الحجز', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          await tablesProvider.changeTableStatus(table.id!, 0);
                                          if (context.mounted) {
                                            TopNotification.showSuccess(context, '✅ تم إلغاء حجز (${table.name}) وأصبحت شاغرة');
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.table_bar_rounded, size: 14),
                                        label: const Text('بدء الطلب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.pop(dialogCtx);
                                          _openCashierForTable(table);
                                        },
                                      ),
                                    ],
                                    if (isOcc)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                        label: const Text('فتح الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.pop(dialogCtx);
                                          _openCashierForTable(table);
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء / إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTableDialog(BuildContext parentContext) {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '4');

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("إضافة طاولة جديدة للصالة"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "اسم الطاولة (مثال: طاولة 9)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "السعة الاستيعابية (عدد الأشخاص)", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text.trim()) ?? 4;

                if (name.isEmpty) return;

                final provider = parentContext.read<TablesProvider>();
                await provider.addTable(
                  name: name,
                  capacity: capacity,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  TopNotification.showSuccess(parentContext, '🎉 تم إضافة الطاولة جديدة بنجاح!');
                }
              },
              child: const Text("إضافة الطاولة"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesProvider = context.watch<TablesProvider>();
    final settings = context.watch<SettingsProvider>();
    final isEng = settings.isEnglish;
    final showPriceOnTable = settings.showPriceOnTable;
    final currencySym = settings.currencySymbol;
    final tableCardSize = settings.tablesCardSize;
    final tableNameFontSize = (tableCardSize * 0.104).clamp(11.5, 18.0);
    final tableAmountFontSize = (tableCardSize * 0.08).clamp(9.0, 14.0);
    final tables = tablesProvider.tables;

    String formatBillAmount(double? amount) {
      final val = amount ?? 0.0;
      final formatted = (val % 1 == 0) ? val.toInt().toString() : val.toStringAsFixed(2);
      final withCommas = formatted.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
      return '$withCommas $currencySym';
    }

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDesignMode) ...[
            FloatingActionButton.extended(
              heroTag: 'save_design_btn',
              onPressed: () {
                setState(() {
                  _isDesignMode = false;
                });
              },
              backgroundColor: Colors.purple.shade700,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('حفظ الأماكن 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
          ],
          if (_isDeleteMode) ...[
            FloatingActionButton.extended(
              heroTag: 'exit_delete_btn',
              onPressed: () {
                setState(() {
                  _isDeleteMode = false;
                });
              },
              backgroundColor: Colors.red.shade700,
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('إلغاء وضع الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
          ],
          PopupMenuButton<String>(
            tooltip: isEng ? 'Table Properties' : 'خصائص الطاولات',
            offset: const Offset(0, -320),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF1F2937),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 24),
            ),
            onSelected: (value) {
              if (value == 'add') {
                _showAddTableDialog(context);
              } else if (value == 'edit') {
                _showSelectTableToEditDialog(context);
              } else if (value == 'reservation') {
                _showTableReservationsDialog(context);
              } else if (value == 'move') {
                setState(() {
                  _isDesignMode = !_isDesignMode;
                  if (_isDesignMode) _isDeleteMode = false;
                });
              } else if (value == 'delete') {
                setState(() {
                  _isDeleteMode = !_isDeleteMode;
                  if (_isDeleteMode) _isDesignMode = false;
                });
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Add New Table ➕' : 'إضافة طاولة جديدة ➕',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.lightBlueAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Edit Table Info ✏️' : 'تعديل بيانات الطاولات ✏️',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reservation',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_seat_rounded, color: Colors.amberAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Table Reservations 📅' : 'حجز الطاولات 📅',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isDesignMode ? Icons.check : Icons.open_with_rounded,
                        color: Colors.purpleAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isDesignMode ? (isEng ? 'Save Layout 💾' : 'حفظ الأماكن 💾') : (isEng ? 'Move / Design Layout 📐' : 'تغير مكان الطاولة 📐'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isDeleteMode ? Icons.close : Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isDeleteMode ? (isEng ? 'Cancel Delete Mode' : 'إلغاء وضع الحذف') : (isEng ? 'Delete Table 🗑️' : 'حذف طاولة 🗑️'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner notice for Design Mode
          if (_isDesignMode && _isFloorPlanView)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.purple.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.open_with_rounded,
                    color: Colors.purple.shade900,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '📐 وضع التنسيق مفعّل: اضغط باستمرار على أي طاولة واسحبها بأي اتجاه في الصالة لتحديد موقعها المطابق لمطعمك.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDesignMode = false;
                      });
                    },
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text('حفظ الإحداثيات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),

          // Only show delete mode header bar when delete mode is active
          if (_isDeleteMode)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ وضع حذف الطاولات مفعّل: اضغط على أيقونة الحذف 🗑️ المقترنة بالطاولة المراد حذفها.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDeleteMode = false;
                      });
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('إنهاء وضع الحذف'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade900,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: tables.isEmpty
                ? const Center(
                    child: Text("لا توجد طاولات مضافة حالياً", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  )
                : _isFloorPlanView
                    ? FloorPlanCanvas(
                        tables: tables,
                        isDesignMode: _isDesignMode,
                        isDeleteMode: _isDeleteMode,
                        onTableTap: (table) => _openCashierForTable(table),
                        onDeleteTable: (table) => _confirmDeleteTable(context, table),
                        onTransferTable: (table) => _showTransferTableDialog(context, table),
                        onEditTable: (table) => _showEditTableDialog(context, table),
                      )
                    : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tables.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: tableCardSize,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final isOccupied = table.status == 1;
                      final isReserved = table.status == 2;
                      final bgColor = isOccupied
                          ? const Color(0xFFDC2626)
                          : (isReserved ? const Color(0xFFD97706) : const Color(0xFF16A34A));
                      final borderColor = _isDeleteMode
                          ? Colors.red.shade900
                          : (isOccupied
                              ? const Color(0xFFB91C1C)
                              : (isReserved ? const Color(0xFFB45309) : const Color(0xFF15803D)));

                      Widget cardContent = Card(
                        elevation: _isDeleteMode ? 5 : 3,
                        color: bgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: borderColor,
                            width: _isDeleteMode ? 2 : 1.5,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (_isDeleteMode) {
                              _confirmDeleteTable(context, table);
                            } else {
                              _openCashierForTable(table);
                            }
                          },
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      table.name,
                                      style: TextStyle(
                                        fontSize: tableNameFontSize + 2,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (showPriceOnTable && isOccupied && (table.currentOrderAmount ?? 0) > 0) ...[
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            formatBillAmount(table.currentOrderAmount),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: tableAmountFontSize + 1,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Mode-Specific Action Header Controls (Delete badge only in delete mode)
                              if (_isDeleteMode)
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: GestureDetector(
                                    onTap: () => _confirmDeleteTable(context, table),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );

                      // Enable Mouse Drag and Drop Reordering via Long Press / Drag
                      return DragTarget<int>(
                        onAcceptWithDetails: (details) {
                          final oldIdx = details.data;
                          if (oldIdx != index) {
                            tablesProvider.moveTableToPosition(oldIdx, index);
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovered = candidateData.isNotEmpty;
                          return LongPressDraggable<int>(
                            data: index,
                            delay: const Duration(milliseconds: 150), // Quick response for mouse hold & drag
                            feedback: Material(
                              elevation: 10,
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                              child: Container(
                                width: 190,
                                height: 125,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6)),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.table_restaurant, color: Colors.white, size: 36),
                                      const SizedBox(height: 4),
                                      Text(
                                        table.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'سحب وإسقاط الموقع 🖐️',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: cardContent,
                            ),
                            child: Container(
                              decoration: isHovered
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.green, width: 3.5),
                                    )
                                  : null,
                              child: cardContent,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransferTableDialog(BuildContext context, RestaurantTable sourceTable) async {
    final tablesProvider = context.read<TablesProvider>();
    final ordersProvider = context.read<OrdersProvider>();
    final availableTables = tablesProvider.tables.where((t) => t.id != sourceTable.id).toList();

    if (availableTables.isEmpty) {
      TopNotification.showWarning(context, 'لا توجد طاولات أخرى متاحة للتحويل إليها.');
      return;
    }

    RestaurantTable? selectedTargetTable = availableTables.first;

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تحويل فاتورة (${sourceTable.name})',
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
                  'اختر الطاولة التي تريد نقل تحويل الفاتورة والحساب إليها:',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<RestaurantTable>(
                initialValue: selectedTargetTable,
                decoration: InputDecoration(
                  labelText: 'الطاولة الهدف *',
                  prefixIcon: const Icon(Icons.table_restaurant, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: availableTables.map((table) {
                  final isOcc = table.status == 1;
                  return DropdownMenuItem<RestaurantTable>(
                    value: table,
                    child: Text(
                      '${table.name} (${isOcc ? "مشغولة - سيتم دمج الطلبات" : "شاغرة"})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOcc ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedTargetTable = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('تأكيد التحويل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (selectedTargetTable == null) return;
                Navigator.pop(ctx);

                final targetName = selectedTargetTable!.name;
                final success = await ordersProvider.transferTableOrder(
                  sourceTableId: sourceTable.id!,
                  targetTableId: selectedTargetTable!.id!,
                );

                if (!context.mounted) return;
                await tablesProvider.loadTables();
                if (!context.mounted) return;
                if (success) {
                  TopNotification.showSuccess(
                    context,
                    '🎉 تم تحويل فاتورة (${sourceTable.name}) إلى ($targetName) بنجاح!',
                  );
                } else {
                  TopNotification.showWarning(context, '⚠️ لا يوجد طلب مفتوح على هذه الطاولة للتحويل.');
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
}
