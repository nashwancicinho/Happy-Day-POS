import 'package:flutter/foundation.dart';

import '../../models/restaurant_table.dart';
import 'tables_repository.dart';

class TablesProvider extends ChangeNotifier {
  final TablesRepository _repository = TablesRepository();

  List<RestaurantTable> _tables = [];

  List<RestaurantTable> get tables => _tables;

  Future<void> loadTables() async {
    _tables = await _repository.getAllTables();
    notifyListeners();
  }

  Future<void> addTable({required String name, int capacity = 4}) async {
    final table = RestaurantTable(name: name, capacity: capacity);

    await _repository.insertTable(table);
    await loadTables();
  }

  Future<void> updateTable(RestaurantTable table) async {
    await _repository.updateTable(table);
    await loadTables();
  }

  Future<void> deleteTable(int id) async {
    await _repository.deleteTable(id);
    await loadTables();
  }

  Future<void> changeTableStatus(int tableId, int status) async {
    await _repository.updateTableStatus(tableId, status);
    await loadTables();
  }

  Future<void> changeTableOrder(int tableId, int sortOrder) async {
    await _repository.updateTableOrder(tableId, sortOrder);
    await loadTables();
  }

  Future<void> swapTableOrder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _tables.length || newIndex < 0 || newIndex >= _tables.length) {
      return;
    }
    final item1 = _tables[oldIndex];
    final item2 = _tables[newIndex];
    if (item1.id != null && item2.id != null) {
      await _repository.updateTableOrder(item1.id!, newIndex);
      await _repository.updateTableOrder(item2.id!, oldIndex);
      await loadTables();
    }
  }

  Future<void> moveTableToPosition(int currentIndex, int targetIndex) async {
    if (currentIndex < 0 || currentIndex >= _tables.length || targetIndex < 0 || targetIndex >= _tables.length || currentIndex == targetIndex) {
      return;
    }
    final item = _tables.removeAt(currentIndex);
    _tables.insert(targetIndex, item);
    await reorderTables(_tables);
  }

  Future<void> reorderTables(List<RestaurantTable> newOrderList) async {
    for (int i = 0; i < newOrderList.length; i++) {
      final t = newOrderList[i];
      if (t.id != null) {
        await _repository.updateTableOrder(t.id!, i);
      }
    }
    await loadTables();
  }

  Future<void> changeTableShape(int tableId, String shape) async {
    await _repository.updateTableShape(tableId, shape);
    await loadTables();
  }

  void updateTableLocalPosition(int tableId, double posX, double posY, {double? width, double? height, String? shape}) {
    final index = _tables.indexWhere((t) => t.id == tableId);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        posX: posX,
        posY: posY,
        width: width,
        height: height,
        shape: shape,
      );
      notifyListeners();
    }
  }

  Future<void> saveTablePosition(int tableId, double posX, double posY, {double? width, double? height, String? shape}) async {
    updateTableLocalPosition(tableId, posX, posY, width: width, height: height, shape: shape);
    await _repository.updateTablePosition(tableId, posX, posY, width: width, height: height, shape: shape);
  }

  Future<void> autoArrangeTables({double canvasWidth = 1000, double canvasHeight = 700}) async {
    const double cardW = 130;
    const double cardH = 130;
    const double spacing = 25;
    const double paddingLeft = 30;
    const double paddingTop = 30;

    int cols = ((canvasWidth - paddingLeft) / (cardW + spacing)).floor();
    if (cols < 1) cols = 1;

    for (int i = 0; i < _tables.length; i++) {
      final t = _tables[i];
      if (t.id != null) {
        int row = i ~/ cols;
        int col = i % cols;
        double x = paddingLeft + col * (cardW + spacing);
        double y = paddingTop + row * (cardH + spacing);

        _tables[i] = t.copyWith(posX: x, posY: y);
        await _repository.updateTablePosition(t.id!, x, y);
      }
    }
    notifyListeners();
  }

  RestaurantTable? getTableById(int id) {
    try {
      return _tables.firstWhere((table) => table.id == id);
    } catch (_) {
      return null;
    }
  }
}
