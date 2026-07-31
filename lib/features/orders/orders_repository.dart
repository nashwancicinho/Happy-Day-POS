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
    String status = 'OPEN',
    String? cashierName,
    int? shiftId,
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      int orderId;

      if (existingOrderId != null) {
        orderId = existingOrderId;
        await txn.update(
          'orders',
          {
            'total': total,
            'status': status,
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
          orderType: 'DINE_IN',
          total: total,
          status: status,
          createdAt: DateTime.now().toIso8601String(),
        );
        orderId = await txn.insert('orders', newOrder.toMap());
      }

      for (final item in items) {
        final itemWithOrderId = item.copyWith(orderId: orderId);
        await txn.insert('order_items', itemWithOrderId.toMap());
      }

      // Mark table as occupied
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
  }) async {
    final db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      int orderId;

      if (existingOrderId != null) {
        orderId = existingOrderId;
        await txn.update(
          'orders',
          {
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
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);

    return maps.map((e) => OrderItemModel.fromMap(e, productName: e['product_name'] as String?)).toList();
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
}
