import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/restaurant_table.dart';
import 'tables_provider.dart';

class FloorPlanCanvas extends StatefulWidget {
  final List<RestaurantTable> tables;
  final bool isDesignMode;
  final bool isDeleteMode;
  final Function(RestaurantTable) onTableTap;
  final Function(RestaurantTable) onDeleteTable;
  final Function(RestaurantTable) onTransferTable;
  final Function(RestaurantTable) onEditTable;

  const FloorPlanCanvas({
    super.key,
    required this.tables,
    required this.isDesignMode,
    required this.isDeleteMode,
    required this.onTableTap,
    required this.onDeleteTable,
    required this.onTransferTable,
    required this.onEditTable,
  });

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas> {
  final TransformationController _transformationController = TransformationController();
  final bool _snapToGrid = false;
  final double _gridSize = 15.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _snap(double value) {
    if (!_snapToGrid) return value;
    return (value / _gridSize).round() * _gridSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth > 1400 ? constraints.maxWidth : 1400.0;
        final canvasHeight = constraints.maxHeight > 900 ? constraints.maxHeight : 900.0;

        return Stack(
          children: [
            // Interactive Canvas Area with Zoom / Pan capability
            InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: EdgeInsets.zero,
              minScale: 1.0,
              maxScale: 1.0,
              panEnabled: false,
              scaleEnabled: false,
              child: Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: const Color(0xFFF3F4F6),
                child: Stack(
                  children: [
                    // Render Tables on 2D Layout Canvas
                    for (int i = 0; i < widget.tables.length; i++)
                      _buildTableItem(context, widget.tables[i], i, constraints.maxWidth, constraints.maxHeight),
                  ],
                ),
              ),
            ),

          ],
        );
      },
    );
  }

  Widget _buildTableItem(BuildContext context, RestaurantTable table, int index, double canvasW, double canvasH) {
    // Initial position calculation if table has default -1 position
    double posX = table.posX;
    double posY = table.posY;

    if (posX < 0 || posY < 0) {
      const double cardSize = 130;
      const double spacing = 20;
      const double paddingLeft = 40;
      const double paddingTop = 60;
      int cols = ((canvasW - paddingLeft) / (cardSize + spacing)).floor();
      if (cols < 1) cols = 1;
      int row = index ~/ cols;
      int col = index % cols;
      posX = paddingLeft + col * (cardSize + spacing);
      posY = paddingTop + row * (cardSize + spacing);
    }

    final isOccupied = table.status == 1;
    final statusColor = isOccupied ? AppColors.danger : AppColors.success;
    final tableWidth = table.shape == 'rectangle' ? 160.0 : 120.0;
    final tableHeight = table.shape == 'rectangle' ? 110.0 : 120.0;

    return Positioned(
      left: posX,
      top: posY,
      child: GestureDetector(
        onPanUpdate: widget.isDesignMode
            ? (details) {
                final newX = _snap((posX + details.delta.dx).clamp(10.0, canvasW - tableWidth - 10.0));
                final newY = _snap((posY + details.delta.dy).clamp(10.0, canvasH - tableHeight - 10.0));
                context.read<TablesProvider>().updateTableLocalPosition(table.id!, newX, newY);
              }
            : null,
        onPanEnd: widget.isDesignMode
            ? (_) {
                context.read<TablesProvider>().saveTablePosition(table.id!, posX, posY);
              }
            : null,
        onTap: () {
          if (widget.isDeleteMode) {
            widget.onDeleteTable(table);
          } else if (widget.isDesignMode) {
            _showShapeSelectorDialog(context, table);
          } else {
            widget.onTableTap(table);
          }
        },
        child: SizedBox(
          width: tableWidth,
          height: tableHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Chairs Surrounding Visual Representation
              _buildChairsAroundTable(table),

              // Main Table Body Box / Cylinder
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: tableWidth - 24,
                height: tableHeight - 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: table.shape == 'round' ? BorderRadius.circular(100) : BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDeleteMode
                        ? Colors.red
                        : widget.isDesignMode
                            ? Colors.purple
                            : statusColor,
                    width: widget.isDesignMode || widget.isDeleteMode ? 2.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDesignMode ? Colors.purple : statusColor).withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Table Icon or Drag Handle
                    Icon(
                      widget.isDesignMode
                          ? Icons.open_with_rounded
                          : (table.shape == 'round' ? Icons.circle_outlined : Icons.table_restaurant),
                      size: widget.isDesignMode ? 22 : 20,
                      color: widget.isDesignMode ? Colors.purple : statusColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      table.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${table.capacity} أشخاص',
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOccupied ? 'مشغولة' : 'شاغرة',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Badges / Controls in Design or Normal Mode
              if (widget.isDeleteMode)
                Positioned(
                  top: 2,
                  left: 2,
                  child: GestureDetector(
                    onTap: () => widget.onDeleteTable(table),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                    ),
                  ),
                ),

              if (widget.isDesignMode)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _showShapeSelectorDialog(context, table),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_road_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ),

              if (!widget.isDesignMode && !widget.isDeleteMode)
                Positioned(
                  top: 0,
                  left: 0,
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'transfer') {
                        widget.onTransferTable(table);
                      } else if (val == 'edit') {
                        widget.onEditTable(table);
                      } else if (val == 'toggle_status') {
                        final newStatus = table.status == 1 ? 0 : 1;
                        context.read<TablesProvider>().changeTableStatus(table.id!, newStatus);
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (isOccupied)
                        const PopupMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz, size: 16, color: Colors.orange),
                              SizedBox(width: 6),
                              Text('تحويل الفاتورة', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.indigo),
                            SizedBox(width: 6),
                            Text('تعديل البيانات', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(
                              isOccupied ? Icons.check_circle_outline : Icons.event_seat,
                              size: 16,
                              color: isOccupied ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(isOccupied ? 'تحديد كـ شاغرة' : 'تحديد كـ مشغولة', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
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

  // Visual Chair Indicators around table shape
  Widget _buildChairsAroundTable(RestaurantTable table) {
    final chairColor = Colors.grey.shade400;
    const double chairSize = 10.0;

    return Stack(
      children: [
        // Top Chair
        Positioned(
          top: 2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 24,
              height: chairSize,
              decoration: BoxDecoration(
                color: chairColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        // Bottom Chair
        Positioned(
          bottom: 2,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 24,
              height: chairSize,
              decoration: BoxDecoration(
                color: chairColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        // Left Chair
        Positioned(
          left: 2,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: chairSize,
              height: 24,
              decoration: BoxDecoration(
                color: chairColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        // Right Chair
        Positioned(
          right: 2,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: chairSize,
              height: 24,
              decoration: BoxDecoration(
                color: chairColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showShapeSelectorDialog(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تغيير شكل الطاولة (${table.name})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.crop_square, color: Colors.indigo),
              title: const Text('طاولة مربعة 🔲'),
              selected: table.shape == 'square',
              onTap: () {
                Navigator.pop(dialogCtx);
                context.read<TablesProvider>().saveTablePosition(
                      table.id!,
                      table.posX,
                      table.posY,
                      shape: 'square',
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined, color: Colors.teal),
              title: const Text('طاولة دائرية ⭕'),
              selected: table.shape == 'round',
              onTap: () {
                Navigator.pop(dialogCtx);
                context.read<TablesProvider>().saveTablePosition(
                      table.id!,
                      table.posX,
                      table.posY,
                      shape: 'round',
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.rectangle_outlined, color: Colors.orange),
              title: const Text('طاولة مستطيلة كبيرة ▭'),
              selected: table.shape == 'rectangle',
              onTap: () {
                Navigator.pop(dialogCtx);
                context.read<TablesProvider>().saveTablePosition(
                      table.id!,
                      table.posX,
                      table.posY,
                      shape: 'rectangle',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Grid Lines Painter for Floor Plan Background
class _FloorGridPainter extends CustomPainter {
  final double gridSize;
  final bool isDesignMode;

  _FloorGridPainter({required this.gridSize, required this.isDesignMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDesignMode ? Colors.purple.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorGridPainter oldDelegate) {
    return oldDelegate.isDesignMode != isDesignMode || oldDelegate.gridSize != gridSize;
  }
}
