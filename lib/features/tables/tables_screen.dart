import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/restaurant_floor.dart';
import '../../models/restaurant_table.dart';
import '../cashier/cashier_screen.dart';
import '../orders/orders_provider.dart';
import '../settings/settings_provider.dart';
import 'floor_plan_canvas.dart';
import 'realistic_table_widget.dart';

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
    final provider = parentContext.read<TablesProvider>();
    final floors = provider.floors;
    final nameController = TextEditingController(text: table.name);
    final capacityController = TextEditingController(text: table.capacity.toString());
    String selectedShape = table.shape;
    int selectedFloorId = table.floorId;
    String? nameError;

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
                    decoration: InputDecoration(
                      labelText: "اسم الطاولة",
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) {
                      if (nameError != null) {
                        setLocalState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "السعة الاستيعابية (عدد الأشخاص)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedShape,
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
                  if (floors.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: floors.any((f) => f.id == selectedFloorId) ? selectedFloorId : floors.first.id,
                      decoration: const InputDecoration(labelText: "الطابق 🏢", border: OutlineInputBorder()),
                      items: floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() => selectedFloorId = val);
                        }
                      },
                    ),
                  ],
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

                    if (name.isEmpty) {
                      setLocalState(() => nameError = 'يرجى إدخال اسم الطاولة');
                      return;
                    }

                    // التحقق مما إذا كان الاسم مكرراً مع طاولة أخرى
                    final existingTable = provider.tables.cast<RestaurantTable?>().firstWhere(
                      (t) => t?.id != table.id && t?.name.trim().toLowerCase() == name.toLowerCase(),
                      orElse: () => null,
                    );

                    if (existingTable != null) {
                      final floorName = provider.getFloorName(existingTable.floorId);
                      final floorInfo = provider.floors.length > 1 ? ' في $floorName' : '';
                      final warnMsg = '⚠️ لا يمكن تعديل الاسم: الطاولة ($name) موجودة مسبقاً$floorInfo!';
                      setLocalState(() => nameError = 'هذه الطاولة موجودة مسبقاً$floorInfo');
                      TopNotification.showWarning(parentContext, warnMsg);
                      return;
                    }

                    final updatedTable = table.copyWith(
                      name: name,
                      capacity: capacity,
                      shape: selectedShape,
                      floorId: selectedFloorId,
                    );
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
                      separatorBuilder: (_, _) => const Divider(height: 1),
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
                          subtitle: Text('${tablesProvider.floors.length > 1 ? "الطابق: ${tablesProvider.getFloorName(table.floorId)} | " : ""}السعة: ${table.capacity} أشخاص | الشكل: ${table.shape == 'round' ? 'دائري' : (table.shape == 'rectangle' ? 'مستطيل' : 'مربع')}'),
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
                            separatorBuilder: (_, _) => const Divider(height: 1),
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

  void _showAddTableDialog(BuildContext parentContext, {int? initialFloorId}) {
    final provider = parentContext.read<TablesProvider>();
    final floors = provider.floors;
    int selectedFloorId = initialFloorId ?? provider.selectedFloorId ?? (floors.isNotEmpty ? floors.first.id! : 1);
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '4');
    String? nameError;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 26),
                  SizedBox(width: 8),
                  Text("إضافة طاولة جديدة للصالة"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "اسم الطاولة (مثال: طاولة 9)",
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) {
                      if (nameError != null) {
                        setLocalState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "السعة الاستيعابية (عدد الأشخاص)", border: OutlineInputBorder()),
                  ),
                  if (floors.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: floors.any((f) => f.id == selectedFloorId) ? selectedFloorId : floors.first.id,
                      decoration: const InputDecoration(labelText: "الطابق 🏢", border: OutlineInputBorder()),
                      items: floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() => selectedFloorId = val);
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final capacity = int.tryParse(capacityController.text.trim()) ?? 4;

                    if (name.isEmpty) {
                      setLocalState(() => nameError = 'يرجى إدخال اسم الطاولة');
                      return;
                    }

                    // التحقق مما إذا كانت الطاولة موجودة مسبقاً بنفس الاسم
                    final existingTable = provider.tables.cast<RestaurantTable?>().firstWhere(
                      (t) => t?.name.trim().toLowerCase() == name.toLowerCase(),
                      orElse: () => null,
                    );

                    if (existingTable != null) {
                      final floorName = provider.getFloorName(existingTable.floorId);
                      final floorInfo = provider.floors.length > 1 ? ' في $floorName' : '';
                      final warnMsg = '⚠️ الطاولة ($name) موجودة مسبقاً$floorInfo! يرجى اختيار اسم أو رقم مختلف.';
                      setLocalState(() => nameError = 'هذه الطاولة موجودة مسبقاً$floorInfo');
                      TopNotification.showWarning(parentContext, warnMsg);
                      return;
                    }

                    await provider.addTable(
                      name: name,
                      capacity: capacity,
                      floorId: selectedFloorId,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      TopNotification.showSuccess(parentContext, '🎉 تم إضافة الطاولة جديدة بنجاح!');
                    }
                  },
                  child: const Text("إضافة الطاولة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageFloorsDialog(BuildContext parentContext) {
    final floorNameController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (dialogCtx) => Consumer<TablesProvider>(
        builder: (ctx, provider, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final floors = provider.floors;
          final isEng = parentContext.read<SettingsProvider>().isEnglish;
          final primary = AppColors.primary;

          const suggestedNames = [
            'الطابق الثاني',
            'الطابق الثالث',
            'طابق الميزانين',
            'الروف / السطح',
            'الحديقة / خارجي',
            'صالة VIP',
          ];

          Future<void> submitAddFloor() async {
            final name = floorNameController.text.trim();
            if (name.isEmpty) return;
            await provider.addFloor(name);
            floorNameController.clear();
            if (parentContext.mounted) {
              TopNotification.showSuccess(parentContext, '🎉 تم إضافة ($name) بنجاح!');
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.layers_rounded, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  isEng ? 'Manage Floors' : 'إدارة طوابق المطعم 🏢',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEng ? 'Current Floors:' : 'الطوابق الحالية:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: floors.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                        ),
                        itemBuilder: (ctx, idx) {
                          final floor = floors[idx];
                          final count = provider.tableCountForFloor(floor.id!);
                          final isSelected = floor.id == provider.selectedFloorId;

                          return ListTile(
                            dense: true,
                            onTap: () {
                              provider.selectFloor(floor.id!);
                            },
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? primary
                                  : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade300),
                              child: Icon(
                                Icons.apartment_rounded,
                                size: 16,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  floor.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? primary : null,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isEng ? 'Active' : 'الحالي',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$count ${isEng ? "tables" : "طاولات"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                  tooltip: isEng ? 'Rename' : 'تعديل الاسم',
                                  onPressed: () => _showRenameFloorDialog(parentContext, floor),
                                ),
                                if (floors.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                    tooltip: isEng ? 'Delete' : 'حذف الطابق',
                                    onPressed: () async {
                                      final occupiedCount = provider.tables.where((t) => t.floorId == floor.id && t.status == 1).length;
                                      if (occupiedCount > 0) {
                                        TopNotification.showWarning(
                                          parentContext,
                                          isEng
                                              ? '⚠️ Cannot delete (${floor.name}) because it has $occupiedCount occupied table(s)!'
                                              : '⚠️ لا يمكن حذف (${floor.name}) لأن به $occupiedCount طاولة مشغولة حالياً بطلبات قائمة!',
                                        );
                                        return;
                                      }
                                      final ok = await provider.deleteFloor(floor.id!);
                                      if (ok && parentContext.mounted) {
                                        TopNotification.showSuccess(
                                          parentContext,
                                          isEng ? '🗑️ Floor (${floor.name}) deleted successfully' : '🗑️ تم حذف (${floor.name}) بنجاح',
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      isEng ? 'Add New Floor:' : 'إضافة طابق جديد ➕:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: floorNameController,
                      onSubmitted: (_) => submitAddFloor(),
                      decoration: InputDecoration(
                        hintText: isEng ? 'e.g. Second Floor, Rooftop...' : 'مثال: الطابق الثاني، الروف...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.teal),
                          onPressed: submitAddFloor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isEng ? 'Quick suggestions:' : 'اقتراحات سريعة:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestedNames.map((sug) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text(sug, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            floorNameController.text = sug;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isEng ? 'Close' : 'إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRenameFloorDialog(BuildContext parentContext, RestaurantFloor floor) {
    final controller = TextEditingController(text: floor.name);
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل اسم ${floor.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الطابق', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != floor.name) {
                await parentContext.read<TablesProvider>().updateFloor(floor.id!, newName);
                if (parentContext.mounted) {
                  TopNotification.showSuccess(parentContext, '✅ تم تعديل اسم الطابق إلى ($newName)');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesProvider = context.watch<TablesProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEng = settings.isEnglish;
    final showPriceOnTable = settings.showPriceOnTable;
    final currencySym = settings.currencySymbol;
    final tableCardSize = settings.tablesCardSize;
    final floors = tablesProvider.floors;
    final selectedFloorId = tablesProvider.selectedFloorId;
    final currentFloor = tablesProvider.currentFloor;
    final tables = tablesProvider.tablesForCurrentFloor;
    final primary = AppColors.primary;

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
            offset: const Offset(0, -385),
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
              } else if (value == 'floors') {
                _showManageFloorsDialog(context);
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
                value: 'floors',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_rounded, color: Colors.tealAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEng ? 'Manage Floors 🏢' : 'إضافة طوابق 🏢',
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

          // Floors Selector Bar (Shown above tables when 2 or more floors exist)
          if (floors.length >= 2)
            _buildFloorsSelectorBar(context, tablesProvider, floors, selectedFloorId, primary, isDark, isEng),

          Expanded(
            child: tables.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.table_restaurant_rounded,
                            size: 56,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          floors.length > 1 && currentFloor != null
                              ? 'لا توجد طاولات مضافة في (${currentFloor.name}) حالياً'
                              : 'لا توجد طاولات مضافة حالياً',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showAddTableDialog(context, initialFloorId: currentFloor?.id),
                          icon: const Icon(Icons.add, color: Colors.white, size: 18),
                          label: Text(
                            floors.length > 1 && currentFloor != null
                                ? 'إضافة طاولة في ${currentFloor.name} ➕'
                                : 'إضافة طاولة جديدة ➕',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : _isFloorPlanView
                    ? FloorPlanCanvas(
                        key: ValueKey('floor_canvas_$selectedFloorId'),
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
                      maxCrossAxisExtent: tableCardSize.clamp(170.0, 300.0),
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final isOccupied = table.status == 1;
                      final isReserved = table.status == 2;

                      Widget cardContent = Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDeleteMode
                                ? Colors.red.shade400
                                : (isOccupied
                                    ? Colors.red.withValues(alpha: 0.35)
                                    : (isReserved
                                        ? Colors.amber.withValues(alpha: 0.35)
                                        : Colors.green.withValues(alpha: 0.25))),
                            width: _isDeleteMode ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: RealisticRestaurantTableWidget(
                            table: table,
                            scale: (tableCardSize / 165.0).clamp(0.65, 1.15),
                            isDesignMode: false,
                            isDeleteMode: _isDeleteMode,
                            showPriceOnTable: showPriceOnTable,
                            currencySym: currencySym,
                            isEng: isEng,
                            onTap: () {
                              if (_isDeleteMode) {
                                _confirmDeleteTable(context, table);
                              } else {
                                _openCashierForTable(table);
                              }
                            },
                            onDelete: () => _confirmDeleteTable(context, table),
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

  Widget _buildFloorsSelectorBar(
    BuildContext context,
    TablesProvider provider,
    List<RestaurantFloor> floors,
    int? selectedFloorId,
    Color primary,
    bool isDark,
    bool isEng,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: floors.map((floor) {
            final isSelected = floor.id == selectedFloorId;
            final count = provider.tableCountForFloor(floor.id!);

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => provider.selectFloor(floor.id!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [primary, primary.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected
                        ? null
                        : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? primary
                          : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        floor.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
