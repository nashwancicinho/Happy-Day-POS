import 'package:flutter/foundation.dart';
import '../../models/product.dart';
import 'products_repository.dart';

class ProductsProvider extends ChangeNotifier {
  final ProductsRepository _repository = ProductsRepository();

  List<ProductModel> _products = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = false;

  List<ProductModel> get products {
    return _products.where((prod) {
      final matchesCategory = _selectedCategoryId == null
          ? (prod.displayLocation == 'BOTH' || prod.displayLocation == 'MAIN_ONLY')
          : (prod.categoryId == _selectedCategoryId && prod.displayLocation != 'MAIN_ONLY');
      final matchesSearch = _searchQuery.isEmpty ||
          prod.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (prod.barcode != null && prod.barcode!.toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<ProductModel> get mainScreenProducts {
    return _products.where((prod) {
      final isMainLoc = prod.displayLocation == 'BOTH' || prod.displayLocation == 'MAIN_ONLY';
      final matchesSearch = _searchQuery.isEmpty ||
          prod.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (prod.barcode != null && prod.barcode!.toLowerCase().contains(_searchQuery.toLowerCase()));
      return isMainLoc && matchesSearch;
    }).toList();
  }

  List<ProductModel> get allProducts => _products;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  // Inventory Statistics
  int get totalProductsCount => _products.length;
  
  double get totalStockUnits {
    return _products.fold(0.0, (sum, p) => sum + (p.trackStock ? p.stockQuantity : 0));
  }

  int get lowStockProductsCount {
    return _products.where((p) => p.trackStock && p.stockQuantity <= p.minStock && p.stockQuantity > 0).length;
  }

  int get outOfStockProductsCount {
    return _products.where((p) => p.trackStock && p.stockQuantity <= 0).length;
  }

  double get totalCostValue {
    return _products.fold(0.0, (sum, p) => sum + (p.trackStock ? p.stockQuantity * p.buyPrice : 0));
  }

  double get totalRetailValue {
    return _products.fold(0.0, (sum, p) => sum + (p.trackStock ? p.stockQuantity * p.price : 0));
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    _products = await _repository.getAllProducts();
    _isLoading = false;
    notifyListeners();
  }

  void selectCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<int> addProduct(ProductModel product) async {
    final id = await _repository.insertProduct(product);
    await loadProducts();
    return id;
  }

  Future<void> updateProduct(ProductModel product) async {
    await _repository.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    await loadProducts();
  }

  Future<void> toggleAvailability(ProductModel product) async {
    final updated = product.copyWith(isAvailable: !product.isAvailable);
    await updateProduct(updated);
  }

  Future<void> addStockQuantity(int productId, double quantity) async {
    await _repository.addStockQuantity(productId, quantity);
    await loadProducts();
  }

  Future<void> updateStockQuantity(int productId, double newQuantity) async {
    await _repository.updateStockQuantity(productId, newQuantity);
    await loadProducts();
  }
}
