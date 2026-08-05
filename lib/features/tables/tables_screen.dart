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
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  bool _isDeleteMode = false;
  bool _isDesignMode = false;
  bool _isFloorPlanView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TablesProvider>().loadTables();
    });
  }

  void _openCashierForTable(RestaurantTable table) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashierScreen(selectedTable: table),
      ),
    );

    if (!mounted) return;
    context.read<TablesProvider>().loadTables();
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

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("تعديل بيانات ${table.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                final capacity = int.tryParse(capacityController.text.trim()) ?? table.capacity;

                if (name.isEmpty) return;

                final updatedTable = table.copyWith(name: name, capacity: capacity);
                await parentContext.read<TablesProvider>().updateTable(updatedTable);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  TopNotification.showSuccess(parentContext, '🎉 تم تعديل (${table.name}) بنجاح!');
                }
              },
              child: const Text("حفظ التعديلات"),
            ),
          ],
        );
      },
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
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final tables = tablesProvider.tables;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? "Table Management & Hall Sales" : "إدارة الطاولات ومبيعات الصالة"),
        centerTitle: true,
      ),

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
            offset: const Offset(0, -190),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: const Color(0xFF1F2937),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isEng ? 'Table Options' : 'خيارات الطاولات',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            onSelected: (value) {
              if (value == 'add') {
                _showAddTableDialog(context);
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
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final isOccupied = table.status == 1;
                      final color = isOccupied ? AppColors.danger : AppColors.success;
                      final statusText = isOccupied ? "مشغولة" : "شاغرة";

                      Widget cardContent = Card(
                        elevation: _isDeleteMode ? 5 : 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _isDeleteMode ? Colors.red : color.withValues(alpha: 0.6),
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
                                    // Table Icon & Status
                                    Icon(
                                      Icons.table_restaurant,
                                      size: 26,
                                      color: _isDeleteMode ? Colors.red : color,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      table.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      "السعة: ${table.capacity} شخص",
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Mode-Specific Action Header Controls
                              Positioned(
                                top: 4,
                                left: 4,
                                right: 4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // ONLY show delete icon badge when Delete Mode (_isDeleteMode) is ACTIVE!
                                    if (_isDeleteMode)
                                      GestureDetector(
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
                                      )
                                    else
                                      const SizedBox.shrink(),

                                    // Popup Menu options (edit / status) when delete mode is off
                                    if (!_isDeleteMode)
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade700),
                                          tooltip: isEng ? 'Table Control Options' : 'خيارات التحكم بالطاولة',
                                        onSelected: (value) async {
                                          if (value == 'transfer') {
                                            _showTransferTableDialog(context, table);
                                          } else if (value == 'edit') {
                                            _showEditTableDialog(context, table);
                                          } else if (value == 'toggle_status') {
                                            final newStatus = table.status == 1 ? 0 : 1;
                                            await tablesProvider.changeTableStatus(table.id!, newStatus);
                                          }
                                        },
                                        itemBuilder: (popCtx) => [
                                          if (isOccupied)
                                            const PopupMenuItem(
                                              value: 'transfer',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text('تحويل الفاتورة إلى طاولة أخرى'),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18, color: Colors.indigo),
                                                SizedBox(width: 8),
                                                Text('تعديل الاسم والسعة'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle_status',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  table.status == 1 ? Icons.check_circle_outline : Icons.airline_seat_recline_normal,
                                                  size: 18,
                                                  color: table.status == 1 ? Colors.green : Colors.orange,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(table.status == 1 ? 'تفريغ الطاولة (شاغرة)' : 'تحديد كـ مشغولة'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
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
      builder: (ctx) => StatefulBuilder(
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
              const Text(
                'اختر الطاولة التي تريد نقل تحويل الفاتورة والحساب إليها:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<RestaurantTable>(
                value: selectedTargetTable,
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
      ),
    );
  }
}
