import 'package:flutter/foundation.dart';

import '../../models/purchase.dart';
import '../../models/supplier.dart';
import 'purchases_repository.dart';

class PurchasesProvider extends ChangeNotifier {
  final PurchasesRepository _repository = PurchasesRepository();

  List<SupplierModel> _suppliers = [];
  List<PurchaseInvoiceModel> _purchases = [];
  bool _isLoading = false;

  List<SupplierModel> get suppliers => _suppliers;
  List<PurchaseInvoiceModel> get purchases => _purchases;
  bool get isLoading => _isLoading;

  double get totalPurchasesAmount => _purchases.fold(0.0, (sum, item) => sum + item.totalAmount);
  double get totalPaidAmount => _purchases.fold(0.0, (sum, item) => sum + item.paidAmount);
  double get totalSuppliersDebt => _suppliers.fold(0.0, (sum, item) => sum + item.balance);

  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _suppliers = await _repository.getAllSuppliers();
      _purchases = await _repository.getAllPurchases();
    } catch (e) {
      debugPrint('Error loading purchases and suppliers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSupplier(SupplierModel supplier) async {
    final id = await _repository.insertSupplier(supplier);
    await loadAllData();
    return id > 0;
  }

  Future<bool> updateSupplier(SupplierModel supplier) async {
    final count = await _repository.updateSupplier(supplier);
    await loadAllData();
    return count > 0;
  }

  Future<bool> deleteSupplier(int id) async {
    final count = await _repository.deleteSupplier(id);
    await loadAllData();
    return count > 0;
  }

  Future<bool> addPurchaseInvoice({
    required PurchaseInvoiceModel invoice,
    required bool updateInventory,
  }) async {
    final success = await _repository.createPurchaseInvoice(
      invoice: invoice,
      updateInventory: updateInventory,
    );
    await loadAllData();
    return success;
  }

  Future<bool> deletePurchaseInvoice(int id) async {
    final success = await _repository.deletePurchaseInvoice(id);
    await loadAllData();
    return success;
  }

  Future<bool> paySupplierDebt({
    required int supplierId,
    required String supplierName,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final success = await _repository.paySupplierDebt(
      supplierId: supplierId,
      supplierName: supplierName,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
    await loadAllData();
    return success;
  }

  Future<List<Map<String, dynamic>>> getSupplierPayments(int supplierId) async {
    return await _repository.getSupplierPayments(supplierId);
  }
}
