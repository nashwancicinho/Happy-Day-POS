import 'package:flutter/material.dart';

import '../../models/restaurant_table.dart';

/// A realistic restaurant table widget with luxury wood/modern tabletop,
/// status lighting, table name, and order bill amount (without surrounding chairs or capacity numbers).
class RealisticRestaurantTableWidget extends StatelessWidget {
  final RestaurantTable table;
  final double scale;
  final bool isDesignMode;
  final bool isDeleteMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEditShape;
  final bool showPriceOnTable;
  final String currencySym;
  final bool isEng;

  const RealisticRestaurantTableWidget({
    super.key,
    required this.table,
    this.scale = 1.0,
    this.isDesignMode = false,
    this.isDeleteMode = false,
    this.isSelected = false,
    this.onTap,
    this.onDelete,
    this.onEditShape,
    this.showPriceOnTable = true,
    this.currencySym = 'د.ع',
    this.isEng = false,
  });

  // Calculate component outer bounds
  static Size getComponentSize(String shape, double scale) {
    if (shape == 'rectangle') {
      return Size(132.0 * scale, 90.0 * scale);
    }
    return Size(100.0 * scale, 100.0 * scale);
  }

  // Calculate inner table top size (matches component size with safe margin for glow/badges)
  static Size getTableTopSize(String shape, double scale) {
    if (shape == 'rectangle') {
      return Size(122.0 * scale, 80.0 * scale);
    }
    return Size(90.0 * scale, 90.0 * scale);
  }

  @override
  Widget build(BuildContext context) {
    final shape = table.shape;
    final isRound = shape == 'round';
    final isOccupied = table.status == 1;
    final isReserved = table.status == 2;

    final componentSize = getComponentSize(shape, scale);
    final tableTopSize = getTableTopSize(shape, scale);

    // Table status colors & gradients (Luxury Wood Texture & Finish)
    final List<Color> tableGradient = isOccupied
        ? [const Color(0xFFB91C1C), const Color(0xFF7F1D1D)] // Deep Ruby / Mahogany
        : (isReserved
            ? [const Color(0xFFD97706), const Color(0xFF92400E)] // Rich Amber / Teak
            : [const Color(0xFF15803D), const Color(0xFF14532D)]); // Deep Emerald / Oak

    final Color statusBorderColor = isDeleteMode
        ? Colors.red.shade900
        : isDesignMode
            ? Colors.purpleAccent
            : (isOccupied
                ? const Color(0xFFEF4444)
                : (isReserved ? const Color(0xFFFBBF24) : const Color(0xFF22C55E)));

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isRound ? 100 : 18 * scale),
      child: SizedBox(
        width: componentSize.width,
        height: componentSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Main Realistic Table Top
            Container(
              width: tableTopSize.width,
              height: tableTopSize.height,
              decoration: BoxDecoration(
                shape: isRound ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRound
                    ? null
                    : BorderRadius.circular((16.0 * scale).clamp(10.0, 24.0)),
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.35),
                  radius: 0.95,
                  colors: tableGradient,
                ),
                border: Border.all(
                  color: statusBorderColor,
                  width: isDesignMode || isDeleteMode ? 2.8 * scale : 2.0 * scale,
                ),
                boxShadow: [
                  // Ambient table elevation shadow onto floor
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 7.0 * scale,
                    spreadRadius: 1.0 * scale,
                    offset: Offset(0, 3.0 * scale),
                  ),
                  // Status glow illumination
                  BoxShadow(
                    color: statusBorderColor.withValues(alpha: 0.35),
                    blurRadius: 9.0 * scale,
                    spreadRadius: 0.5 * scale,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: isRound
                    ? BorderRadius.circular(100)
                    : BorderRadius.circular((14.0 * scale).clamp(8.0, 22.0)),
                child: Stack(
                  children: [
                    // Polished reflection highlight sheen across top
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: tableTopSize.height * 0.45,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Center Table Content (Icon, Name, and Amount/Status)
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5.0 * scale, vertical: 3.0 * scale),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Dining / Status icon (Clean without capacity count)
                              Icon(
                                isOccupied
                                    ? Icons.restaurant_rounded
                                    : (isReserved ? Icons.event_seat_rounded : Icons.table_restaurant_rounded),
                                size: (15.0 * scale).clamp(11.0, 20.0),
                                color: Colors.white.withValues(alpha: 0.95),
                              ),

                              SizedBox(height: 2.0 * scale),

                              // Table Name
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatTableName(table.name),
                                  style: TextStyle(
                                    fontSize: (14.0 * scale).clamp(11.0, 19.0),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              // Active Bill Amount Pill or Status Text
                              if (isOccupied && showPriceOnTable && (table.currentOrderAmount ?? 0) > 0) ...[
                                SizedBox(height: 2.5 * scale),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 5.0 * scale, vertical: 1.5 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(8.0 * scale),
                                    border: Border.all(
                                      color: Colors.amberAccent.withValues(alpha: 0.8),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      formatBillAmount(table.currentOrderAmount),
                                      style: TextStyle(
                                        fontSize: (11.0 * scale).clamp(9.0, 15.0),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                SizedBox(height: 2.0 * scale),
                                Text(
                                  isOccupied
                                      ? (isEng ? 'Occupied' : 'مشغولة')
                                      : (isReserved
                                          ? (isEng ? 'Reserved' : 'محجوزة')
                                          : (isEng ? 'Available' : 'شاغرة')),
                                  style: TextStyle(
                                    fontSize: (9.5 * scale).clamp(8.0, 12.0),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Delete Mode Badge Action (in top-left corner)
            if (isDeleteMode)
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
                  ),
                ),
              ),

            // 3. Design Mode Shape Selector Action (in top-right corner)
            if (isDesignMode) ...[
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEditShape,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit_road_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: isRound ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: isRound ? null : BorderRadius.circular(16.0 * scale),
                      border: Border.all(color: Colors.amberAccent, width: 3),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
