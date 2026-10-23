import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/restaurant_table.dart';
import '../settings/settings_provider.dart';
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
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
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

    final tablesCardSize = context.watch<SettingsProvider>().tablesCardSize;
    final scale = (tablesCardSize / 135.0).clamp(0.65, 1.8);

    if (posX < 0 || posY < 0) {
      final double cardSize = 105 * scale;
      final double spacing = 16 * scale;
      const double paddingLeft = 30;
      const double paddingTop = 45;
      int cols = ((canvasW - paddingLeft) / (cardSize + spacing)).floor();
      if (cols < 1) cols = 1;
      int row = index ~/ cols;
      int col = index % cols;
      posX = paddingLeft + col * (cardSize + spacing);
      posY = paddingTop + row * (cardSize + spacing);
    }

    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySym = context.watch<SettingsProvider>().currencySymbol;
    final showPriceOnTable = context.watch<SettingsProvider>().showPriceOnTable;
    final isOccupied = table.status == 1;
    final isReserved = table.status == 2;
    final tableBgColor = isOccupied
        ? const Color(0xFFDC2626)
        : (isReserved ? const Color(0xFFD97706) : const Color(0xFF16A34A));
    final borderColor = widget.isDeleteMode
        ? Colors.red.shade900
        : widget.isDesignMode
            ? Colors.purple
            : (isOccupied
                ? const Color(0xFFB91C1C)
                : (isReserved ? const Color(0xFFB45309) : const Color(0xFF15803D)));
    final tableWidth = (table.shape == 'rectangle' ? 130.0 : 98.0) * scale;
    final tableHeight = (table.shape == 'rectangle' ? 90.0 : 98.0) * scale;

    String formatTableName(String rawName) {
      if (!isEng) return rawName;
      return rawName.replaceAll('طاولة', 'Table');
    }

    String formatBillAmount(double? amount) {
      final val = amount ?? 0.0;
      final formatted = (val % 1 == 0) ? val.toInt().toString() : val.toStringAsFixed(2);
      final withCommas = formatted.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
      return '$withCommas $currencySym';
    }

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
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Main Table Body Box / Cylinder
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: tableWidth,
                height: tableHeight,
                decoration: BoxDecoration(
                  color: tableBgColor,
                  borderRadius: table.shape == 'round' ? BorderRadius.circular(100) : BorderRadius.circular((13 * scale).clamp(8.0, 20.0)),
                  border: Border.all(
                    color: borderColor,
                    width: widget.isDesignMode || widget.isDeleteMode ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDesignMode ? Colors.purple : tableBgColor).withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isDesignMode) ...[
                      Icon(
                        Icons.open_with_rounded,
                        size: 16 * scale,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        formatTableName(table.name),
                        style: TextStyle(
                          fontSize: (14.0 * scale).clamp(11.0, 20.0),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (showPriceOnTable) ...[
                      SizedBox(height: 4 * scale),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatBillAmount(isOccupied ? table.currentOrderAmount : 0.0),
                            style: TextStyle(
                              fontSize: (11.5 * scale).clamp(9.5, 17.0),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
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
            ],
          ),
        ),
      ),
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
