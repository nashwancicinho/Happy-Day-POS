import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/services/print_service.dart';
import '../database/database_helper.dart';
import '../features/orders/orders_repository.dart';
import '../features/settings/settings_provider.dart';
import '../features/settings/settings_repository.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'network_service.dart';

class LocalServerService extends ChangeNotifier {
  static final LocalServerService instance = LocalServerService._();
  LocalServerService._();

  HttpServer? _server;
  bool _isRunning = false;
  int _port = 8080;
  String? _serverIp;
  final List<WebSocket> _connectedClients = [];
  VoidCallback? _onTableOrderUpdated;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get serverIp => _serverIp;
  String get serverUrl => _serverIp != null ? 'http://$_serverIp:$_port' : 'غير متصل';

  void setTableUpdateCallback(VoidCallback callback) {
    _onTableOrderUpdated = callback;
  }

  Future<bool> startServer({int port = 8080}) async {
    if (_isRunning && _server != null) {
      _serverIp = await NetworkService.getLocalIpAddress();
      notifyListeners();
      return true;
    }

    if (_server != null) {
      try {
        await _server?.close(force: true);
      } catch (_) {}
      _server = null;
    }

    final portsToTry = [port, 8080, 8081, 8082, 8085, 8088, 8090];
    for (final tryPort in portsToTry) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, tryPort, shared: true);
        _port = tryPort;
        _isRunning = true;
        _serverIp = await NetworkService.getLocalIpAddress();
        notifyListeners();

        _server!.listen(_handleRequest, onError: (e) {
          if (kDebugMode) print('Local Server Error: $e');
        });

        if (kDebugMode) print('Local POS Server running at http://$_serverIp:$_port');
        return true;
      } catch (e) {
        if (kDebugMode) print('Failed to bind port $tryPort: $e');
      }
    }

    _isRunning = false;
    notifyListeners();
    return false;
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;
    try {
      for (final client in _connectedClients) {
        await client.close();
      }
      _connectedClients.clear();
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error stopping server: $e');
    }
  }

  void _addCorsHeaders(HttpResponse response) {
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      // WebSocket upgrade endpoint
      if (path == '/api/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _connectedClients.add(socket);
        socket.listen(
          (data) {},
          onDone: () => _connectedClients.remove(socket),
          onError: (_) => _connectedClients.remove(socket),
        );
        return;
      }

      if (request.method == 'GET' && path == '/api/info') {
        await _jsonResponse(request.response, {
          'status': 'online',
          'appName': 'Happy Day POS',
          'ip': _serverIp,
          'port': _port,
        });
      } else if (request.method == 'GET' && path == '/api/users') {
        await _handleGetUsers(request.response);
      } else if (request.method == 'POST' && path == '/api/auth/login') {
        await _handleUserLogin(request);
      } else if (request.method == 'GET' && path == '/api/tables') {
        await _handleGetTables(request.response);
      } else if (request.method == 'GET' && path == '/api/categories') {
        await _handleGetCategories(request.response);
      } else if (request.method == 'GET' && path == '/api/products') {
        await _handleGetProducts(request.response);
      } else if (request.method == 'GET' && path == '/api/orders/table') {
        final tableIdStr = request.uri.queryParameters['table_id'];
        final tableId = int.tryParse(tableIdStr ?? '');
        if (tableId == null) {
          await _jsonResponse(request.response, {'error': 'Missing table_id'}, statusCode: 400);
        } else {
          await _handleGetTableOrder(request.response, tableId);
        }
      } else if (request.method == 'POST' && path == '/api/orders/table') {
        await _handleSaveTableOrder(request);
      } else if (request.method == 'POST' && path == '/api/orders/cancel') {
        await _handleCancelTableOrder(request);
      } else {
        await _jsonResponse(request.response, {'error': 'Endpoint not found'}, statusCode: 404);
      }
    } catch (e) {
      if (kDebugMode) print('HTTP request error ($path): $e');
      await _jsonResponse(request.response, {'error': e.toString()}, statusCode: 500);
    }
  }

  Future<void> _jsonResponse(HttpResponse response, dynamic data, {int statusCode = 200}) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _handleGetUsers(HttpResponse response) async {
    final db = await DatabaseHelper.instance.database;
    final users = await db.query('users', columns: ['id', 'username', 'role'], where: 'is_active = 1');
    await _jsonResponse(response, {'success': true, 'data': users});
  }

  Future<void> _handleUserLogin(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final username = data['username'] as String? ?? '';
    final password = data['password'] as String? ?? '';

    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'users',
      where: 'username = ? AND password = ? AND is_active = 1',
      whereArgs: [username, password],
    );

    if (maps.isNotEmpty) {
      final user = maps.first;
      await _jsonResponse(request.response, {
        'success': true,
        'user': {
          'id': user['id'],
          'username': user['username'],
          'role': user['role'],
        }
      });
    } else {
      await _jsonResponse(request.response, {
        'success': false,
        'message': 'اسم المستخدم أو كلمة المرور غير صحيحة'
      }, statusCode: 401);
    }
  }

  Future<void> _handleGetTables(HttpResponse response) async {
    final db = await DatabaseHelper.instance.database;
    final tables = await db.query('restaurant_tables', orderBy: 'sort_order ASC, id ASC');
    await _jsonResponse(response, {'success': true, 'data': tables});
  }

  Future<void> _handleGetCategories(HttpResponse response) async {
    final db = await DatabaseHelper.instance.database;
    final categories = await db.query('categories', orderBy: 'id ASC');
    await _jsonResponse(response, {'success': true, 'data': categories});
  }

  Future<void> _handleGetProducts(HttpResponse response) async {
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products', where: 'is_available = 1', orderBy: 'category_id ASC, name ASC');
    await _jsonResponse(response, {'success': true, 'data': products});
  }

  Future<void> _handleGetTableOrder(HttpResponse response, int tableId) async {
    final repo = OrdersRepository();
    final openOrder = await repo.getOpenOrderByTable(tableId);

    if (openOrder == null) {
      await _jsonResponse(response, {'success': true, 'data': null});
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final items = await db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [openOrder.id]);

    await _jsonResponse(response, {
      'success': true,
      'data': {
        'order': openOrder.toMap(),
        'items': items,
      }
    });
  }

  Future<void> _handleSaveTableOrder(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    final data = jsonDecode(content) as Map<String, dynamic>;

    final tableId = data['table_id'] as int?;
    final waiterName = data['waiter_name'] as String? ?? 'نادل الموبايل';
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final total = (data['total'] as num? ?? 0.0).toDouble();

    if (tableId == null) {
      await _jsonResponse(request.response, {'error': 'table_id required'}, statusCode: 400);
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final productsList = await db.query('products');
    final productsMap = {for (var p in productsList) p['id'] as int: p};

    final items = rawItems.map((item) {
      final pId = item['product_id'] as int;
      final prod = productsMap[pId];
      final pName = prod != null ? prod['name'] as String : null;
      final printToKit = prod != null ? ((prod['print_to_kitchen'] as int? ?? 1) == 1) : true;
      final kitPrinter = prod != null ? prod['kitchen_printer'] as String? : null;

      return OrderItemModel(
        productId: pId,
        productName: pName,
        quantity: (item['quantity'] as num).toDouble(),
        price: (item['price'] as num).toDouble(),
        notes: item['notes'] as String?,
        printToKitchen: printToKit,
        kitchenPrinter: kitPrinter,
      );
    }).toList();

    final repo = OrdersRepository();
    final existingOrder = await repo.getOpenOrderByTable(tableId);

    List<OrderItemModel> combinedItems = List.from(items);
    double combinedTotal = total;

    if (existingOrder != null) {
      final existingItems = await repo.getOrderItems(existingOrder.id!);
      final List<OrderItemModel> merged = List.from(existingItems);

      for (final newItem in items) {
        final idx = merged.indexWhere((e) =>
          e.productId == newItem.productId && (e.notes ?? '').trim() == (newItem.notes ?? '').trim()
        );
        if (idx >= 0) {
          final oldItem = merged[idx];
          merged[idx] = oldItem.copyWith(quantity: oldItem.quantity + newItem.quantity);
        } else {
          merged.add(newItem);
        }
      }

      combinedItems = merged;
      combinedTotal = combinedItems.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    }

    // Kitchen delta items: the newly sent items from this mobile round
    final List<OrderItemModel> kitchenDeltaItems = items.where((i) => i.printToKitchen).toList();

    final orderId = await repo.saveOrUpdateTableOrder(
      existingOrderId: existingOrder?.id,
      tableId: tableId,
      items: combinedItems,
      total: combinedTotal,
      status: 'OPEN',
      cashierName: waiterName,
    );

    // Automatic Kitchen Order Ticket Print for delta items
    if (kitchenDeltaItems.isNotEmpty) {
      try {
        final tableMaps = await db.query('restaurant_tables', where: 'id = ?', whereArgs: [tableId]);
        final tableName = tableMaps.isNotEmpty ? tableMaps.first['name'] as String : 'طاولة $tableId';

        final heldOrder = OrderModel(
          id: orderId,
          tableId: tableId,
          orderType: 'DINE_IN',
          total: combinedTotal,
          status: 'OPEN',
          createdAt: DateTime.now().toIso8601String(),
        );

        final settingsRepo = SettingsRepository();
        final allSettingsMap = await settingsRepo.getAllSettings();
        final settingsProvider = SettingsProvider();
        await settingsProvider.updateAllSettings(allSettingsMap);

        PrintService.printKitchenTicket(
          order: heldOrder,
          items: kitchenDeltaItems,
          settings: settingsProvider,
          tableName: tableName,
        ).catchError((e) {
          debugPrint('Kitchen print error on server order save: $e');
          return false;
        });
      } catch (e) {
        debugPrint('Auto kitchen print error in server: $e');
      }
    }


    // Notify WebSocket clients
    _broadcastEvent({'type': 'TABLE_UPDATED', 'table_id': tableId, 'order_id': orderId});

    // Notify Cashier Local App Callback
    _onTableOrderUpdated?.call();

    await _jsonResponse(request.response, {
      'success': true,
      'order_id': orderId,
      'message': 'تم إرسال الطلب بنجاح إلى الكاشير والمطبخ',
    });
  }

  Future<void> _handleCancelTableOrder(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final tableId = data['table_id'] as int?;

    if (tableId == null) {
      await _jsonResponse(request.response, {'error': 'table_id required'}, statusCode: 400);
      return;
    }

    final repo = OrdersRepository();
    await repo.cancelTableOrder(tableId);

    _broadcastEvent({'type': 'TABLE_UPDATED', 'table_id': tableId});
    _onTableOrderUpdated?.call();

    await _jsonResponse(request.response, {
      'success': true,
      'message': 'تم إلغاء الفاتورة وإخلاء الطاولة بنجاح',
    });
  }

  void _broadcastEvent(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    for (final client in List<WebSocket>.from(_connectedClients)) {
      try {
        client.add(payload);
      } catch (_) {
        _connectedClients.remove(client);
      }
    }
  }
}
