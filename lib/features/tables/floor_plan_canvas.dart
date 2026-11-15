import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/restaurant_table.dart';
import '../settings/settings_provider.dart';
import 'realistic_table_widget.dart';
import 'tables_provider.dart';

/// Custom painter for drawing a subtle, architectural floor grid pattern in the dining hall.
class FloorGridPainter extends CustomPainter {
  final bool isDark;

  const FloorGridPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    const dotRadius = 1.2;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FloorGridPainter oldDelegate) => oldDelegate.isDark != isDark;
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
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
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                child: CustomPaint(
                  painter: FloorGridPainter(isDark: isDark),
                  child: Stack(
                    children: [
                      // Render Tables on 2D Layout Canvas
                      for (int i = 0; i < widget.tables.length; i++)
                        _buildTableItem(context, widget.tables[i], i, constraints.maxWidth, constraints.maxHeight),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableItem(BuildContext context, RestaurantTable table, int index, double canvasW, double canvasH) {
    final tablesCardSize = context.watch<SettingsProvider>().tablesCardSize;
    final scale = (tablesCardSize / 135.0).clamp(0.65, 1.8);

    final componentSize = RealisticRestaurantTableWidget.getComponentSize(table.shape, scale);
    final tableWidth = componentSize.width;
    final tableHeight = componentSize.height;

    // Initial position calculation if table has default -1 position
    double posX = table.posX;
    double posY = table.posY;

    if (posX < 0 || posY < 0) {
      final double spacing = 18 * scale;
      const double paddingLeft = 30;
      const double paddingTop = 35;
      int cols = ((canvasW - paddingLeft) / (tableWidth + spacing)).floor();
      if (cols < 1) cols = 1;
      int row = index ~/ cols;
      int col = index % cols;
      posX = paddingLeft + col * (tableWidth + spacing);
      posY = paddingTop + row * (tableHeight + spacing);
    }

    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    final showPriceOnTable = context.watch<SettingsProvider>().showPriceOnTable;

    return Positioned(
      key: ValueKey('table_${table.id}'),
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
        child: RealisticRestaurantTableWidget(
          table: table,
          scale: scale,
          isDesignMode: widget.isDesignMode,
          isDeleteMode: widget.isDeleteMode,
          onTap: () {
            if (widget.isDeleteMode) {
              widget.onDeleteTable(table);
            } else if (widget.isDesignMode) {
              _showShapeSelectorDialog(context, table);
            } else {
              widget.onTableTap(table);
            }
          },
          onDelete: () => widget.onDeleteTable(table),
          onEditShape: () => _showShapeSelectorDialog(context, table),
          showPriceOnTable: showPriceOnTable,
          currencySym: currencySym,
          isEng: isEng,
        ),
      ),
    );
  }

  void _showShapeSelectorDialog(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.table_restaurant_rounded, color: Colors.purple, size: 26),
            const SizedBox(width: 8),
            Text('تغيير شكل الطاولة (${table.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.crop_square_rounded, color: Colors.indigo, size: 28),
              title: const Text('طاولة مربعة 🔲', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('تصميم مربع متناسق وأنيق'),
              selected: table.shape == 'square',
              selectedTileColor: Colors.indigo.withValues(alpha: 0.1),
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
            const SizedBox(height: 4),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.circle_outlined, color: Colors.teal, size: 28),
              title: const Text('طاولة دائرية ⭕', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('تصميم دائري انسيابي عصري'),
              selected: table.shape == 'round',
              selectedTileColor: Colors.teal.withValues(alpha: 0.1),
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
            const SizedBox(height: 4),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.rectangle_outlined, color: Colors.orange, size: 28),
              title: const Text('طاولة مستطيلة كبيرة ▭', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('تصميم مستطيل فسيح للطاولات الكبيرة'),
              selected: table.shape == 'rectangle',
              selectedTileColor: Colors.orange.withValues(alpha: 0.1),
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
