import '../../database/database_helper.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';

class TopSellingProduct {
  final int productId;
  final String productName;
  final int quantitySold;
  final double totalRevenue;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
  });
}

class CashierSalesSummary {
  final String cashierName;
  final int totalOrders;
  final double totalSales;
  final double cashSales;
  final double cardSales;
  final double creditSales;
  final double avgOrderValue;

  CashierSalesSummary({
    required this.cashierName,
    required this.totalOrders,
    required this.totalSales,
    required this.cashSales,
    required this.cardSales,
    required this.creditSales,
    required this.avgOrderValue,
  });
}

class ProductNetProfitSummary {
  final int productId;
  final String productName;
  final double buyPrice;
  final double sellPrice;
  final double quantitySold;
  final double totalRevenue;
  final double totalCost;
  final double netProfit;
  final double profitPercentage;

  ProductNetProfitSummary({
    required this.productId,
    required this.productName,
    required this.buyPrice,
    required this.sellPrice,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalCost,
    required this.netProfit,
    required this.profitPercentage,
  });
}

class OrdersRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<OrderModel?> getOpenOrderByTable(int tableId) async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT o.*, c.name as customer_name
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.table_id = ? AND o.status IN ('OPEN', 'SUSPENDED')
      ORDER BY o.id DESC
      LIMIT 1
    ''', [tableId]);

    if (maps.isEmpty) return null;
    return OrderModel.fromMap(maps.first, customerName: maps.first['customer_name'] as String?);
  }

  Future<int> createOrder(OrderModel order, List<OrderItemModel> items) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      final orderId = await txn.insert('orders', order.toMap());

      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert('order_items', itemWithOrderId.toMap());

        if (order.status == 'COMPLETED') {
          await txn.rawUpdate('''
            UPDATE products
            SET stock_quantity = stock_quantity - ?
            WHERE id = ? AND track_stock = 1
          ''', [item.quantity, item.productId]);
        }
      }

      if (order.orderType == 'DINE_IN' && order.tableId != null) {
        final tableStatus = order.status == 'COMPLETED' ? 0 : 1;
        await txn.update(
          'restaurant_tables',
          {'status': tableStatus},
          where: 'id = ?',
          whereArgs: [order.tableId],
        );
      }

      return orderId;
    });
  }

  Future<int> saveOrUpdateTableOrder({
    int? existingOrderId,
    required int tableId,
    required List<OrderItemModel> items,
    required double total,
    double subtotal = 0.0,
    double discountAmount = 0.0,
    String status = 'OPEN',
    String? cashierName,
    int? shiftId,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      int orderId;

      // Find ALL open orders for this table to prevent duplicate open order records
      final openOrdersRows = await txn.rawQuery('''
        SELECT id FROM orders
        WHERE table_id = ? AND status IN ('OPEN', 'SUSPENDED')
        ORDER BY id ASC
      ''', [tableId]);

      final List<int> openOrderIds = openOrdersRows.map((r) => r['id'] as int).toList();

      if (existingOrderId != null && !openOrderIds.contains(existingOrderId)) {
        openOrderIds.add(existingOrderId);
      }

      final List<OrderItemModel> finalItems = List.from(items);

      if (openOrderIds.isNotEmpty) {
        // Use the earliest open order as the main active order
        orderId = openOrderIds.first;

        // Fetch ALL existing items across any open order for this table
        for (final oid in openOrderIds) {
          final dbItemsRows = await txn.query('order_items', where: 'order_id = ?', whereArgs: [oid]);
          final dbItems = dbItemsRows.map((e) => OrderItemModel.fromMap(e)).toList();

          for (final dbItem in dbItems) {
            final idx = finalItems.indexWhere((e) =>
              e.productId == dbItem.productId && (e.notes ?? '').trim() == (dbItem.notes ?? '').trim()
            );
            if (idx < 0) {
              finalItems.add(dbItem);
            } else {
              if (dbItem.quantity > finalItems[idx].quantity) {
                finalItems[idx] = finalItems[idx].copyWith(quantity: dbItem.quantity);
              }
            }
          }
        }

        final calculatedTotal = finalItems.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
        final calcSubtotal = calculatedTotal + discountAmount;

        // Update the primary order
        await txn.update(
          'orders',
          {
            'subtotal': subtotal > 0 ? subtotal : calcSubtotal,
            'discount_amount': discountAmount,
            'total': calculatedTotal,
            'status': status,
            'cashier_name': cashierName,
            'shift_id': shiftId,
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );

        // Delete order_items from ALL open orders for this table
        for (final oid in openOrderIds) {
          await txn.delete('order_items', where: 'order_id = ?', whereArgs: [oid]);
        }

        // Clean up any duplicate open order rows
        if (openOrderIds.length > 1) {
          final duplicateIds = openOrderIds.sublist(1);
          for (final dupId in duplicateIds) {
            await txn.delete('orders', where: 'id = ?', whereArgs: [dupId]);
          }
        }
      } else {
        // No open order exists yet for this table, create a new one
        final newOrder = OrderModel(
          tableId: tableId,
          shiftId: shiftId,
          cashierName: cashierName,
          orderType: 'DINE_IN',
          subtotal: subtotal > 0 ? subtotal : total + discountAmount,
          discountAmount: discountAmount,
          total: total,
          status: status,
          createdAt: DateTime.now().toIso8601String(),
        );
        orderId = await txn.insert('orders', newOrder.toMap());
      }

      // Insert all merged final items under the primary order
      for (final item in finalItems) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert('order_items', itemWithOrderId.toMap());
      }

      // Mark table as occupied (status = 1)
      await txn.update(
        'restaurant_tables',
        {'status': 1},
        where: 'id = ?',
        whereArgs: [tableId],
      );

      return orderId;
    });
  }

  Future<int> checkoutAndCompleteOrder({
    int? existingOrderId,
    int? tableId,
    String? customerPhone,
    String? customerAddress,
    String? cashierName,
    int? shiftId,
    String paymentMethod = 'CASH',
    required String orderType,
    required List<OrderItemModel> items,
    required double total,
    double subtotal = 0.0,
    double discountAmount = 0.0,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      int orderId;

      if (existingOrderId != null) {
        orderId = existingOrderId;
        await txn.update(
          'orders',
          {
            'subtotal': subtotal > 0 ? subtotal : total + discountAmount,
            'discount_amount': discountAmount,
            'total': total,
            'status': 'COMPLETED',
            'payment_method': paymentMethod,
            'customer_phone': customerPhone,
            'customer_address': customerAddress,
            'cashier_name': cashierName,
            'shift_id': shiftId,
            'created_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      } else {
        final newOrder = OrderModel(
          tableId: tableId,
          shiftId: shiftId,
          cashierName: cashierName,
          orderType: orderType,
          paymentMethod: paymentMethod,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          subtotal: subtotal > 0 ? subtotal : total + discountAmount,
          discountAmount: discountAmount,
          total: total,
          status: 'COMPLETED',
          createdAt: DateTime.now().toIso8601String(),
        );
        orderId = await txn.insert('orders', newOrder.toMap());
      }

      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert('order_items', itemWithOrderId.toMap());

        // Deduct inventory stock
        await txn.rawUpdate('''
          UPDATE products
          SET stock_quantity = stock_quantity - ?
          WHERE id = ? AND track_stock = 1
        ''', [item.quantity, item.productId]);
      }

      // Free table if Dine-In
      if (tableId != null) {
        await txn.update(
          'restaurant_tables',
          {'status': 0},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      return orderId;
    });
  }

  Future<int> checkoutCreditOrder({
    int? existingOrderId,
    int? tableId,
    required String debtorName,
    String? debtorPhone,
    String? cashierName,
    int? shiftId,
    required String orderType,
    required List<OrderItemModel> items,
    required double total,
    double subtotal = 0.0,
    double discountAmount = 0.0,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      int orderId;
      final notesStr = 'دين على الزبون: $debtorName${debtorPhone != null && debtorPhone.isNotEmpty ? ' ($debtorPhone)' : ''}';

      if (existingOrderId != null) {
        orderId = existingOrderId;
        await txn.update(
          'orders',
          {
            'subtotal': subtotal > 0 ? subtotal : total + discountAmount,
            'discount_amount': discountAmount,
            'total': total,
            'status': 'CREDIT',
            'payment_method': 'CREDIT',
            'notes': notesStr,
            'customer_phone': debtorPhone,
            'cashier_name': cashierName,
            'shift_id': shiftId,
            'created_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      } else {
        final newOrder = OrderModel(
          tableId: tableId,
          shiftId: shiftId,
          cashierName: cashierName,
          orderType: orderType,
          paymentMethod: 'CREDIT',
          status: 'CREDIT',
          notes: notesStr,
          customerPhone: debtorPhone,
          subtotal: subtotal > 0 ? subtotal : total + discountAmount,
          discountAmount: discountAmount,
          total: total,
          createdAt: DateTime.now().toIso8601String(),
        );
        orderId = await txn.insert('orders', newOrder.toMap());
      }

      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert('order_items', itemWithOrderId.toMap());

        // Deduct inventory stock
        await txn.rawUpdate('''
          UPDATE products
          SET stock_quantity = stock_quantity - ?
          WHERE id = ? AND track_stock = 1
        ''', [item.quantity, item.productId]);
      }

      // Free table if Dine-In
      if (tableId != null) {
        await txn.update(
          'restaurant_tables',
          {'status': 0},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }

      return orderId;
    });
  }

  Future<void> settleDebtOrder(int orderId) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'status': 'COMPLETED',
          'payment_method': 'CASH',
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  Future<void> settlePartialOrFullDebt(List<OrderModel> creditOrders, double amountToPay) async {
    final db = await _databaseHelper.database;
    if (creditOrders.isEmpty || amountToPay <= 0) return;

    final firstOrder = creditOrders.first;
    final nowStr = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final debtorTitle = firstOrder.notes ?? firstOrder.customerName ?? 'سداد دين';
      final newOrder = OrderModel(
        shiftId: firstOrder.shiftId,
        cashierName: firstOrder.cashierName ?? 'المدير',
        orderType: firstOrder.orderType,
        paymentMethod: 'CASH',
        status: 'COMPLETED',
        subtotal: amountToPay,
        total: amountToPay,
        notes: debtorTitle,
        customerPhone: firstOrder.customerPhone,
        createdAt: nowStr,
      );
      await txn.insert('orders', newOrder.toMap());

      // 2. Deduct amountToPay from the credit orders list
      double remainingToDeduct = amountToPay;
      for (final order in creditOrders) {
        if (remainingToDeduct <= 0) break;

        if (remainingToDeduct >= order.total) {
          remainingToDeduct -= order.total;
          await txn.update(
            'orders',
            {
              'status': 'SETTLED',
              'total': 0.0,
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );
        } else {
          final newTotal = order.total - remainingToDeduct;
          remainingToDeduct = 0;
          await txn.update(
            'orders',
            {
              'total': newTotal,
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );
        }
      }
    });
  }

  Future<List<OrderModel>> getAllOrders() async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT o.*, c.name as customer_name
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      ORDER BY o.id DESC
    ''');
    return maps.map((e) => OrderModel.fromMap(e, customerName: e['customer_name'] as String?)).toList();
  }

  Future<List<OrderModel>> getSuspendedOrders() async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT o.*, c.name as customer_name
      FROM orders o
      LEFT JOIN customers c ON o.customer_id = c.id
      WHERE o.status IN ('SUSPENDED', 'OPEN')
      ORDER BY o.id DESC
    ''');
    return maps.map((e) => OrderModel.fromMap(e, customerName: e['customer_name'] as String?)).toList();
  }

  Future<List<OrderItemModel>> getOrderItems(int orderId) async {
    final db = await _databaseHelper.database;
    final maps = await db.rawQuery('''
      SELECT oi.*, p.name as product_name, COALESCE(oi.print_to_kitchen, p.print_to_kitchen, 1) as item_print_to_kitchen
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);

    return maps.map((e) {
      final isPrint = (e['item_print_to_kitchen'] as int? ?? 1) == 1;
      return OrderItemModel.fromMap(e, productName: e['product_name'] as String?, printToKitchen: isPrint);
    }).toList();
  }

  /// يرجع العناصر الجديدة فقط (الزيادة بالكمية أو الأصناف المضافة حديثاً) لطباعة المطبخ
  Future<List<OrderItemModel>> getKitchenDeltaItems(int? existingOrderId, List<OrderItemModel> newItems) async {
    final List<OrderItemModel> kitchenItems = newItems.where((i) => i.printToKitchen).toList();
    if (kitchenItems.isEmpty) return [];

    if (existingOrderId == null) {
      return kitchenItems;
    }

    final oldItems = await getOrderItems(existingOrderId);
    if (oldItems.isEmpty) {
      return kitchenItems;
    }

    final List<OrderItemModel> deltaItems = [];

    for (final newItem in kitchenItems) {
      final oldMatches = oldItems.where(
        (o) => o.productId == newItem.productId && (o.price - newItem.price).abs() < 0.01,
      );

      double oldQty = 0.0;
      if (oldMatches.isNotEmpty) {
        oldQty = oldMatches.fold(0.0, (sum, o) => sum + o.quantity);
      }

      final deltaQty = newItem.quantity - oldQty;
      if (deltaQty > 0.001) {
        deltaItems.add(newItem.copyWith(quantity: deltaQty));
      }
    }

    return deltaItems;
  }


  Future<void> completeOrder(int orderId, int? tableId) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {'status': 'COMPLETED'},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final items = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = (item['quantity'] as num).toDouble();
        await txn.rawUpdate('''
          UPDATE products
          SET stock_quantity = stock_quantity - ?
          WHERE id = ? AND track_stock = 1
        ''', [qty, productId]);
      }

      if (tableId != null) {
        await txn.update(
          'restaurant_tables',
          {'status': 0},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      }
    });
  }

  Future<void> deleteOrder(int orderId) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    });
  }

  Future<double> calculateNetProfit() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT SUM((oi.price - oi.buy_price) * oi.quantity - oi.discount) as net_profit
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      WHERE o.status = 'COMPLETED'
    ''');
    final val = result.first['net_profit'];
    return (val as num? ?? 0.0).toDouble();
  }

  Future<List<TopSellingProduct>> getTopSellingProducts({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = "WHERE o.status = 'COMPLETED'";
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause += " AND o.created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    final maps = await db.rawQuery('''
      SELECT oi.product_id, p.name as product_name, SUM(oi.quantity) as total_qty, SUM(oi.quantity * oi.price) as total_sales
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN products p ON oi.product_id = p.id
      $whereClause
      GROUP BY oi.product_id, p.name
      ORDER BY total_qty DESC, total_sales DESC
      LIMIT 10
    ''', whereArgs);

    return maps.map((m) => TopSellingProduct(
      productId: m['product_id'] as int,
      productName: m['product_name'] as String? ?? 'صنف غير معروف',
      quantitySold: (m['total_qty'] as num? ?? 0).toInt(),
      totalRevenue: (m['total_sales'] as num? ?? 0.0).toDouble(),
    )).toList();
  }

  Future<double> calculateNetProfitForPeriod({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = "WHERE o.status = 'COMPLETED'";
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause += " AND o.created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    final result = await db.rawQuery('''
      SELECT SUM((oi.price - oi.buy_price) * oi.quantity - oi.discount) as net_profit
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      $whereClause
    ''', whereArgs);
    final val = result.first['net_profit'];
    return (val as num? ?? 0.0).toDouble();
  }

  Future<List<CashierSalesSummary>> getCashierSalesReport({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    String? selectedCashier,
    String? fallbackCashierName,
  }) async {
    final db = await _databaseHelper.database;

    // Automatically reassign any unassigned or 'الكاشير العام' orders to the first registered user or fallback
    String defaultUser = fallbackCashierName ?? 'الكاشير';
    try {
      final userRows = await db.query('users', orderBy: 'id ASC', limit: 1);
      if (userRows.isNotEmpty && userRows.first['username'] != null) {
        defaultUser = userRows.first['username'] as String;
      }
    } catch (_) {}

    await db.rawUpdate('''
      UPDATE orders
      SET cashier_name = ?
      WHERE cashier_name IS NULL OR cashier_name = '' OR cashier_name = 'الكاشير العام'
    ''', [defaultUser]);

    String whereClause = "WHERE o.status = 'COMPLETED'";
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause += " AND o.created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    if (selectedCashier != null && selectedCashier.isNotEmpty && selectedCashier != 'ALL') {
      whereClause += " AND (o.cashier_name = ? OR s.user_name = ?)";
      whereArgs.add(selectedCashier);
      whereArgs.add(selectedCashier);
    }

    final maps = await db.rawQuery('''
      SELECT 
        COALESCE(NULLIF(o.cashier_name, ''), NULLIF(s.user_name, ''), ?) AS cashier_name,
        COUNT(o.id) AS total_orders,
        SUM(o.total) AS total_sales,
        SUM(CASE WHEN o.payment_method = 'CASH' THEN o.total ELSE 0 END) AS cash_sales,
        SUM(CASE WHEN o.payment_method = 'CARD' THEN o.total ELSE 0 END) AS card_sales,
        SUM(CASE WHEN o.payment_method = 'CREDIT' THEN o.total ELSE 0 END) AS credit_sales
      FROM orders o
      LEFT JOIN shifts s ON o.shift_id = s.id
      $whereClause
      GROUP BY 1
      ORDER BY total_sales DESC
    ''', [defaultUser, ...whereArgs]);

    return maps.map((m) {
      final tOrders = (m['total_orders'] as num? ?? 0).toInt();
      final tSales = (m['total_sales'] as num? ?? 0.0).toDouble();
      final cSales = (m['cash_sales'] as num? ?? 0.0).toDouble();
      final cardSales = (m['card_sales'] as num? ?? 0.0).toDouble();
      final crSales = (m['credit_sales'] as num? ?? 0.0).toDouble();
      final avgVal = tOrders > 0 ? tSales / tOrders : 0.0;

      return CashierSalesSummary(
        cashierName: m['cashier_name'] as String? ?? defaultUser,
        totalOrders: tOrders,
        totalSales: tSales,
        cashSales: cSales,
        cardSales: cardSales,
        creditSales: crSales,
        avgOrderValue: avgVal,
      );
    }).toList();
  }

  Future<List<ProductNetProfitSummary>> getProductNetProfitReport({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    int? selectedCatId,
    int? selectedProdId,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = "WHERE o.status = 'COMPLETED'";
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause += " AND DATE(o.created_at) >= DATE(?) AND DATE(o.created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause += " AND o.created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    if (selectedCatId != null) {
      whereClause += " AND p.category_id = ?";
      whereArgs.add(selectedCatId);
    }

    if (selectedProdId != null) {
      whereClause += " AND oi.product_id = ?";
      whereArgs.add(selectedProdId);
    }

    final maps = await db.rawQuery('''
      SELECT 
        oi.product_id,
        p.name AS product_name,
        COALESCE(NULLIF(oi.buy_price, 0.0), p.buy_price, 0.0) AS buy_price,
        AVG(oi.price) AS sell_price,
        SUM(oi.quantity) AS total_qty,
        SUM((oi.price * oi.quantity) - oi.discount) AS total_revenue,
        SUM(oi.quantity * COALESCE(NULLIF(oi.buy_price, 0.0), p.buy_price, 0.0)) AS total_cost,
        SUM((oi.price * oi.quantity) - oi.discount - (oi.quantity * COALESCE(NULLIF(oi.buy_price, 0.0), p.buy_price, 0.0))) AS net_profit
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      JOIN products p ON oi.product_id = p.id
      $whereClause
      GROUP BY oi.product_id, p.name
      ORDER BY net_profit DESC
    ''', whereArgs);

    return maps.map((m) {
      final bPrice = (m['buy_price'] as num? ?? 0.0).toDouble();
      final sPrice = (m['sell_price'] as num? ?? 0.0).toDouble();
      final qty = (m['total_qty'] as num? ?? 0.0).toDouble();
      final revenue = (m['total_revenue'] as num? ?? 0.0).toDouble();
      final cost = (m['total_cost'] as num? ?? 0.0).toDouble();
      final profit = (m['net_profit'] as num? ?? 0.0).toDouble();
      final marginPct = revenue > 0 ? (profit / revenue) * 100 : 0.0;

      return ProductNetProfitSummary(
        productId: m['product_id'] as int,
        productName: m['product_name'] as String? ?? 'صنف غير معروف',
        buyPrice: bPrice,
        sellPrice: sPrice,
        quantitySold: qty,
        totalRevenue: revenue,
        totalCost: cost,
        netProfit: profit,
        profitPercentage: marginPct,
      );
    }).toList();
  }

  Future<SessionPeriodInfo> getSessionPeriodInfo({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _databaseHelper.database;
    String whereClause = "WHERE status = 'COMPLETED'";
    List<dynamic> whereArgs = [];

    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      whereClause += " AND DATE(created_at) >= DATE(?) AND DATE(created_at) <= DATE(?)";
      whereArgs.add(fromDate);
      whereArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      whereClause += " AND created_at LIKE ?";
      whereArgs.add('$datePrefix%');
    }

    final firstOrderMap = await db.rawQuery('''
      SELECT created_at FROM orders
      $whereClause
      ORDER BY id ASC
      LIMIT 1
    ''', whereArgs);

    String? firstOrderTime;
    if (firstOrderMap.isNotEmpty && firstOrderMap.first['created_at'] != null) {
      firstOrderTime = firstOrderMap.first['created_at'] as String;
    }

    String treasuryWhere = "";
    List<dynamic> treasuryArgs = [];
    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      treasuryWhere = "WHERE DATE(date) >= DATE(?) AND DATE(date) <= DATE(?)";
      treasuryArgs.add(fromDate);
      treasuryArgs.add(toDate);
    } else if (datePrefix != null && datePrefix.isNotEmpty) {
      treasuryWhere = "WHERE date LIKE ?";
      treasuryArgs.add('$datePrefix%');
    }

    final treasuryMap = await db.rawQuery('''
      SELECT created_at, closed_by FROM daily_treasury
      $treasuryWhere
      ORDER BY id DESC
      LIMIT 1
    ''', treasuryArgs);

    String? closingTime;
    String? closedBy;
    bool isClosed = false;

    if (treasuryMap.isNotEmpty && treasuryMap.first['created_at'] != null) {
      closingTime = treasuryMap.first['created_at'] as String;
      closedBy = treasuryMap.first['closed_by'] as String?;
      isClosed = true;
    } else {
      final lastOrderMap = await db.rawQuery('''
        SELECT created_at FROM orders
        $whereClause
        ORDER BY id DESC
        LIMIT 1
      ''', whereArgs);
      if (lastOrderMap.isNotEmpty && lastOrderMap.first['created_at'] != null) {
        closingTime = lastOrderMap.first['created_at'] as String;
      }
    }

    return SessionPeriodInfo(
      firstOrderTime: firstOrderTime,
      closingTime: closingTime,
      closedBy: closedBy,
      isClosed: isClosed,
    );
  }

  /// تحويل الفاتورة المفتوحة من طاولة إلى طاولة أخرى (دمج الأصناف إذا كانت الطاولة المستقبلة مشغولة)
  Future<bool> transferTableOrder({
    required int sourceTableId,
    required int targetTableId,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      // 1. Get open order for source table
      final sourceOrders = await txn.rawQuery('''
        SELECT id FROM orders
        WHERE table_id = ? AND status IN ('OPEN', 'SUSPENDED')
        ORDER BY id DESC
        LIMIT 1
      ''', [sourceTableId]);

      if (sourceOrders.isEmpty) return false;
      final sourceOrderId = sourceOrders.first['id'] as int;

      // 2. Check if target table has an open order
      final targetOrders = await txn.rawQuery('''
        SELECT id FROM orders
        WHERE table_id = ? AND status IN ('OPEN', 'SUSPENDED')
        ORDER BY id DESC
        LIMIT 1
      ''', [targetTableId]);

      if (targetOrders.isNotEmpty) {
        final targetOrderId = targetOrders.first['id'] as int;

        // Copy source order items to target order
        final sourceItems = await txn.query('order_items', where: 'order_id = ?', whereArgs: [sourceOrderId]);
        for (final itemMap in sourceItems) {
          final itemMapToInsert = Map<String, dynamic>.from(itemMap);
          itemMapToInsert.remove('id');
          itemMapToInsert['order_id'] = targetOrderId;
          await txn.insert('order_items', itemMapToInsert);
        }

        // Recalculate target order total
        final allTargetItems = await txn.rawQuery('''
          SELECT SUM((price * quantity) - discount) as new_total
          FROM order_items
          WHERE order_id = ?
        ''', [targetOrderId]);

        final newTotal = (allTargetItems.first['new_total'] as num? ?? 0.0).toDouble();
        await txn.update('orders', {'total': newTotal}, where: 'id = ?', whereArgs: [targetOrderId]);

        // Delete source order
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [sourceOrderId]);
        await txn.delete('orders', where: 'id = ?', whereArgs: [sourceOrderId]);
      } else {
        // Transfer source order to target table
        await txn.update(
          'orders',
          {'table_id': targetTableId},
          where: 'id = ?',
          whereArgs: [sourceOrderId],
        );
      }

      // 3. Update table statuses: source -> vacant (0), target -> occupied (1)
      await txn.update('restaurant_tables', {'status': 0}, where: 'id = ?', whereArgs: [sourceTableId]);
      await txn.update('restaurant_tables', {'status': 1}, where: 'id = ?', whereArgs: [targetTableId]);

      return true;
    });
  }

  /// استرجاع الفاتورة بالكامل (Refund Full Order) - إعادة المخزن وخفض المبيعات والوارد
  Future<bool> refundFullOrder(int orderId) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final orderMaps = await txn.query('orders', where: 'id = ?', whereArgs: [orderId]);
      if (orderMaps.isEmpty) return false;

      final orderStatus = orderMaps.first['status'] as String;
      if (orderStatus == 'REFUNDED') return false; // Already refunded

      // 1. Restock items into inventory
      final items = await txn.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        final productId = item['product_id'] as int;
        final qty = (item['quantity'] as num).toDouble();
        await txn.rawUpdate('''
          UPDATE products
          SET stock_quantity = stock_quantity + ?
          WHERE id = ? AND track_stock = 1
        ''', [qty, productId]);
      }

      // 2. Update order status to REFUNDED
      await txn.update(
        'orders',
        {'status': 'REFUNDED'},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // 3. Free table if linked
      final tableId = orderMaps.first['table_id'] as int?;
      if (tableId != null) {
        await txn.update('restaurant_tables', {'status': 0}, where: 'id = ?', whereArgs: [tableId]);
      }

      return true;
    });
  }

  /// استرجاع جزئي لصنف محدد في الفاتورة (Partial Item Refund) - إعادة الكمية وإعادة حساب المجموع
  Future<bool> refundOrderItem({
    required int orderId,
    required int orderItemId,
    required double refundQuantity,
  }) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final itemMaps = await txn.query('order_items', where: 'id = ? AND order_id = ?', whereArgs: [orderItemId, orderId]);
      if (itemMaps.isEmpty) return false;

      final currentQty = (itemMaps.first['quantity'] as num).toDouble();
      final productId = itemMaps.first['product_id'] as int;

      final actualRefundQty = refundQuantity > currentQty ? currentQty : refundQuantity;

      // 1. Restock returned quantity in inventory
      await txn.rawUpdate('''
        UPDATE products
        SET stock_quantity = stock_quantity + ?
        WHERE id = ? AND track_stock = 1
      ''', [actualRefundQty, productId]);

      if (actualRefundQty >= currentQty) {
        // Remove item completely
        await txn.delete('order_items', where: 'id = ?', whereArgs: [orderItemId]);
      } else {
        // Reduce item quantity
        final newQty = currentQty - actualRefundQty;
        await txn.update('order_items', {'quantity': newQty}, where: 'id = ?', whereArgs: [orderItemId]);
      }

      // 2. Recalculate order total
      final remainingItems = await txn.rawQuery('''
        SELECT SUM((price * quantity) - discount) as new_total
        FROM order_items
        WHERE order_id = ?
      ''', [orderId]);

      final newTotal = (remainingItems.first['new_total'] as num? ?? 0.0).toDouble();

      if (newTotal <= 0) {
        await txn.update('orders', {'status': 'REFUNDED', 'total': 0}, where: 'id = ?', whereArgs: [orderId]);
      } else {
        await txn.update('orders', {'total': newTotal}, where: 'id = ?', whereArgs: [orderId]);
      }

      return true;
    });
  }

  Future<bool> cancelTableOrder(int tableId) async {
    final db = await _databaseHelper.database;
    return await db.transaction((txn) async {
      final openOrders = await txn.rawQuery('''
        SELECT id FROM orders
        WHERE table_id = ? AND status NOT IN ('COMPLETED', 'REFUNDED')
      ''', [tableId]);

      for (final orderMap in openOrders) {
        final orderId = orderMap['id'] as int;
        await txn.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        await txn.update(
          'orders',
          {'status': 'CANCELLED', 'total': 0},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }

      await txn.update(
        'restaurant_tables',
        {'status': 0},
        where: 'id = ?',
        whereArgs: [tableId],
      );

      return true;
    });
  }
}

class SessionPeriodInfo {
  final String? firstOrderTime;
  final String? closingTime;
  final String? closedBy;
  final bool isClosed;

  const SessionPeriodInfo({
    this.firstOrderTime,
    this.closingTime,
    this.closedBy,
    this.isClosed = false,
  });
}
