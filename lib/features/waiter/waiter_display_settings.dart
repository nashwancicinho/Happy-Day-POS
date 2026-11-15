import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaiterDisplaySettings {
  static const String _keyColumns = 'waiter_grid_columns';
  static const String _keyItemScale = 'waiter_item_scale';
  static const String _keyCardRatio = 'waiter_card_aspect_ratio';
  static const String _keyTableSize = 'waiter_table_card_size';

  // 0 = Auto, 2 = 2 columns, 3 = 3 columns, 4 = 4 columns, 5 = 5 columns
  static int columns = 0;
  // Multiplier for item scale (0.80 to 1.40)
  static double itemScale = 1.0;
  // Aspect ratio of the card
  static double cardRatio = 0.98;
  // Max extent for tables cards
  static double tableSize = 170.0;

  static bool _isLoaded = false;

  static Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      columns = prefs.getInt(_keyColumns) ?? 0;
      itemScale = (prefs.getDouble(_keyItemScale) ?? 1.0).clamp(0.80, 1.40);
      cardRatio = (prefs.getDouble(_keyCardRatio) ?? 0.98).clamp(0.80, 1.30);
      tableSize = (prefs.getDouble(_keyTableSize) ?? 170.0).clamp(120.0, 240.0);
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading WaiterDisplaySettings: $e');
    }
  }

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyColumns, columns);
      await prefs.setDouble(_keyItemScale, itemScale);
      await prefs.setDouble(_keyCardRatio, cardRatio);
      await prefs.setDouble(_keyTableSize, tableSize);
    } catch (e) {
      debugPrint('Error saving WaiterDisplaySettings: $e');
    }
  }

  static Future<void> reset() async {
    columns = 0;
    itemScale = 1.0;
    cardRatio = 0.98;
    tableSize = 170.0;
    await save();
  }

  static SliverGridDelegate buildItemsGridDelegate() {
    if (columns > 0) {
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: cardRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      );
    } else {
      final maxExtent = (130.0 * itemScale).clamp(95.0, 220.0);
      return SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: cardRatio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      );
    }
  }

  static SliverGridDelegate buildTablesGridDelegate() {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: tableSize,
      childAspectRatio: 1.05,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
  }
}
