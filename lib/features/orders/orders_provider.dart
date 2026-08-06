import 'package:flutter/foundation.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import 'orders_repository.dart';

import '../treasury/treasury_repository.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersRepository _repository = OrdersRepository();
  final TreasuryRepository _treasuryRepository = TreasuryRepository();

  List<OrderModel> _orders = [];
  List<OrderModel> _suspendedOrders = [];
  double _netProfit = 0.0;
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  List<OrderModel> get suspendedOrders => _suspendedOrders;
  double get netProfit => _netProfit;
  bool get isLoading => _isLoading;

  String? _lastClosedTimestamp;

  void resetTodaySession(String closedAtIso) {
    _lastClosedTimestamp = closedAtIso;
    notifyListeners();
  }

  double get todaySalesTotal {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _orders.where((o) {
      if (o.status != 'COMPLETED') return false;
      if (_lastClosedTimestamp != null && o.createdAt.compareTo(_lastClosedTimestamp!) <= 0) {
        return false;
      }
      return o.createdAt.startsWith(todayStr);
    }).fold(0.0, (sum, o) => sum + o.total);
  }

  int get todayOrdersCount {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _orders.where((o) {
      if (o.status != 'COMPLETED') return false;
      if (_lastClosedTimestamp != null && o.createdAt.compareTo(_lastClosedTimestamp!) <= 0) {
        return false;
      }
      return o.createdAt.startsWith(todayStr);
    }).length;
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    _lastClosedTimestamp = await _treasuryRepository.getLastClosingTimestamp();

    _orders = await _repository.getAllOrders();
    _suspendedOrders = await _repository.getSuspendedOrders();
    _netProfit = await _repository.calculateNetProfit();

    _isLoading = false;
    notifyListeners();
  }

  Future<OrderModel?> getOpenOrderByTable(int tableId) async {
    return await _repository.getOpenOrderByTable(tableId);
  }

  Future<List<OrderItemModel>> getKitchenDeltaItems(int? existingOrderId, List<OrderItemModel> newItems) async {
    return await _repository.getKitchenDeltaItems(existingOrderId, newItems);
  }


  Future<int> holdTableOrder({
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
    final orderId = await _repository.saveOrUpdateTableOrder(
      existingOrderId: existingOrderId,
      tableId: tableId,
      items: items,
      total: total,
      subtotal: subtotal,
      discountAmount: discountAmount,
      status: status,
      cashierName: cashierName,
      shiftId: shiftId,
    );
    await loadOrders();
    return orderId;
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
    final orderId = await _repository.checkoutAndCompleteOrder(
      existingOrderId: existingOrderId,
      tableId: tableId,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      cashierName: cashierName,
      shiftId: shiftId,
      paymentMethod: paymentMethod,
      orderType: orderType,
      items: items,
      total: total,
      subtotal: subtotal,
      discountAmount: discountAmount,
    );
    await loadOrders();
    return orderId;
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
    final orderId = await _repository.checkoutCreditOrder(
      existingOrderId: existingOrderId,
      tableId: tableId,
      debtorName: debtorName,
      debtorPhone: debtorPhone,
      cashierName: cashierName,
      shiftId: shiftId,
      orderType: orderType,
      items: items,
      total: total,
      subtotal: subtotal,
      discountAmount: discountAmount,
    );
    await loadOrders();
    return orderId;
  }

  Future<void> settleDebtOrder(int orderId) async {
    await _repository.settleDebtOrder(orderId);
    await loadOrders();
  }

  Future<void> settlePartialOrFullDebt(List<OrderModel> creditOrders, double amountToPay) async {
    await _repository.settlePartialOrFullDebt(creditOrders, amountToPay);
    await loadOrders();
  }

  Future<int> placeOrder({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    final orderId = await _repository.createOrder(order, items);
    await loadOrders();
    return orderId;
  }

  Future<void> completeOrder(int orderId, int? tableId) async {
    await _repository.completeOrder(orderId, tableId);
    await loadOrders();
  }

  Future<void> deleteOrder(int orderId) async {
    await _repository.deleteOrder(orderId);
    await loadOrders();
  }

  Future<List<OrderItemModel>> getOrderItems(int orderId) async {
    return await _repository.getOrderItems(orderId);
  }

  Future<List<TopSellingProduct>> getTopSellingProducts({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    return await _repository.getTopSellingProducts(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<double> getNetProfitForPeriod({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    return await _repository.calculateNetProfitForPeriod(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<List<CashierSalesSummary>> getCashierSalesReport({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    String? selectedCashier,
    String? fallbackCashierName,
  }) async {
    return await _repository.getCashierSalesReport(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
      selectedCashier: selectedCashier,
      fallbackCashierName: fallbackCashierName,
    );
  }

  Future<List<ProductNetProfitSummary>> getProductNetProfitReport({
    String? datePrefix,
    String? fromDate,
    String? toDate,
    int? selectedCatId,
    int? selectedProdId,
  }) async {
    return await _repository.getProductNetProfitReport(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
      selectedCatId: selectedCatId,
      selectedProdId: selectedProdId,
    );
  }

  Future<bool> transferTableOrder({
    required int sourceTableId,
    required int targetTableId,
  }) async {
    final success = await _repository.transferTableOrder(
      sourceTableId: sourceTableId,
      targetTableId: targetTableId,
    );
    if (success) {
      await loadOrders();
    }
    return success;
  }

  Future<bool> refundFullOrder(int orderId) async {
    final success = await _repository.refundFullOrder(orderId);
    if (success) {
      await loadOrders();
    }
    return success;
  }

  Future<bool> refundOrderItem({
    required int orderId,
    required int orderItemId,
    required double refundQuantity,
  }) async {
    final success = await _repository.refundOrderItem(
      orderId: orderId,
      orderItemId: orderItemId,
      refundQuantity: refundQuantity,
    );
    if (success) {
      await loadOrders();
    }
    return success;
  }

  Future<bool> cancelTableOrder(int tableId) async {
    final success = await _repository.cancelTableOrder(tableId);
    if (success) {
      await loadOrders();
    }
    return success;
  }

  Future<SessionPeriodInfo> getSessionPeriodInfo({
    String? datePrefix,
    String? fromDate,
    String? toDate,
  }) async {
    return await _repository.getSessionPeriodInfo(
      datePrefix: datePrefix,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
