import 'package:flutter/foundation.dart';

import '../../models/restaurant_floor.dart';
import '../../models/restaurant_table.dart';
import 'tables_repository.dart';

class TablesProvider extends ChangeNotifier {
  final TablesRepository _repository = TablesRepository();

  List<RestaurantTable> _tables = [];
  List<RestaurantFloor> _floors = [];
  int? _selectedFloorId;

  List<RestaurantTable> get tables => _tables;
  List<RestaurantFloor> get floors => _floors;
  int? get selectedFloorId => _selectedFloorId;

  RestaurantFloor? get currentFloor {
    if (_floors.isEmpty) return null;
    return _floors.firstWhere(
      (f) => f.id == _selectedFloorId,
      orElse: () => _floors.first,
    );
  }

  List<RestaurantTable> get tablesForCurrentFloor {
    if (_floors.length <= 1) return _tables;
    final activeId = _selectedFloorId ?? (_floors.isNotEmpty ? _floors.first.id : 1);
    return _tables.where((t) => t.floorId == activeId).toList();
  }

  List<RestaurantTable> tablesForFloor(int floorId) {
    return _tables.where((t) => t.floorId == floorId).toList();
  }

  int tableCountForFloor(int floorId) {
    return _tables.where((t) => t.floorId == floorId).length;
  }

  String getFloorName(int floorId) {
    for (final f in _floors) {
      if (f.id == floorId) return f.name;
    }
    return 'الطابق الأرضي';
  }

  void selectFloor(int floorId) {
    if (_selectedFloorId != floorId) {
      _selectedFloorId = floorId;
      notifyListeners();
    }
  }

  Future<void> loadFloors() async {
    _floors = await _repository.getAllFloors();
    if (_floors.isEmpty) {
      final defaultFloor = const RestaurantFloor(name: 'الطابق الأرضي', sortOrder: 0);
      await _repository.insertFloor(defaultFloor);
      _floors = await _repository.getAllFloors();
    }

    if (_selectedFloorId == null || !_floors.any((f) => f.id == _selectedFloorId)) {
      _selectedFloorId = _floors.first.id;
    }
  }

  Future<void> loadTables() async {
    await loadFloors();
    _tables = await _repository.getAllTables();
    notifyListeners();
  }

  Future<RestaurantFloor> addFloor(String name) async {
    final floor = RestaurantFloor(name: name, sortOrder: _floors.length);
    final id = await _repository.insertFloor(floor);
    await loadFloors();
    _selectedFloorId = id;
    notifyListeners();
    return floor.copyWith(id: id);
  }

  Future<void> updateFloor(int id, String newName) async {
    final index = _floors.indexWhere((f) => f.id == id);
    if (index != -1) {
      final updated = _floors[index].copyWith(name: newName);
      await _repository.updateFloor(updated);
      await loadFloors();
      notifyListeners();
    }
  }

  Future<bool> deleteFloor(int id) async {
    final hasOccupied = _tables.any((t) => t.floorId == id && t.status == 1);
    if (hasOccupied) {
      return false;
    }
    await _repository.deleteTablesByFloor(id);
    await _repository.deleteFloor(id);
    if (_selectedFloorId == id) {
      _selectedFloorId = null;
    }
    await loadTables();
    return true;
  }

  Future<void> addTable({required String name, int capacity = 4, int? floorId}) async {
    final targetFloorId = floorId ?? _selectedFloorId ?? (_floors.isNotEmpty ? _floors.first.id : 1) ?? 1;
    final table = RestaurantTable(
      name: name,
      capacity: capacity,
      floorId: targetFloorId,
    );

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

    final targetTables = tablesForCurrentFloor;
    for (int i = 0; i < targetTables.length; i++) {
      final t = targetTables[i];
      if (t.id != null) {
        int row = i ~/ cols;
        int col = i % cols;
        double x = paddingLeft + col * (cardW + spacing);
        double y = paddingTop + row * (cardH + spacing);

        final idx = _tables.indexWhere((table) => table.id == t.id);
        if (idx != -1) {
          _tables[idx] = t.copyWith(posX: x, posY: y);
        }
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
