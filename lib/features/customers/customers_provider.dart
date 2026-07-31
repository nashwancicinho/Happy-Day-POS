import 'package:flutter/foundation.dart';
import '../../models/customer.dart';
import 'customers_repository.dart';

class CustomersProvider extends ChangeNotifier {
  final CustomersRepository _repository = CustomersRepository();

  List<CustomerModel> _customers = [];
  bool _isLoading = false;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    _customers = await _repository.getAllCustomers();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _repository.insertCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _repository.updateCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await _repository.deleteCustomer(id);
    await loadCustomers();
  }

  Future<void> payDebt(int customerId, double amountPaid) async {
    await _repository.updateCustomerBalance(customerId, -amountPaid);
    await loadCustomers();
  }

  Future<void> addDebt(int customerId, double debtAmount) async {
    await _repository.updateCustomerBalance(customerId, debtAmount);
    await loadCustomers();
  }
}
