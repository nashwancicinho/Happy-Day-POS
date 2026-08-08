import 'package:flutter/foundation.dart';
import '../../models/product_recipe.dart';
import '../../models/raw_material.dart';
import 'raw_materials_repository.dart';

class RawMaterialsProvider extends ChangeNotifier {
  final RawMaterialsRepository _repository = RawMaterialsRepository();

  List<RawMaterialModel> _rawMaterials = [];
  bool _isLoading = false;

  List<RawMaterialModel> get rawMaterials => _rawMaterials;
  bool get isLoading => _isLoading;

  int get totalRawMaterialsCount => _rawMaterials.length;

  int get lowStockCount => _rawMaterials.where((rm) => rm.isLowStock).length;

  Future<void> loadRawMaterials() async {
    _isLoading = true;
    notifyListeners();

    _rawMaterials = await _repository.getAllRawMaterials();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addRawMaterial(RawMaterialModel item) async {
    final id = await _repository.insertRawMaterial(item);
    await loadRawMaterials();
    return id > 0;
  }

  Future<bool> updateRawMaterial(RawMaterialModel item) async {
    final count = await _repository.updateRawMaterial(item);
    await loadRawMaterials();
    return count > 0;
  }

  Future<bool> deleteRawMaterial(int id) async {
    final count = await _repository.deleteRawMaterial(id);
    await loadRawMaterials();
    return count > 0;
  }

  Future<void> addStockQuantity(int rawMaterialId, double qtyToAdd, {double? newCostPerUnit}) async {
    await _repository.addStockQuantity(rawMaterialId, qtyToAdd, newCostPerUnit: newCostPerUnit);
    await loadRawMaterials();
  }

  Future<List<ProductRecipeItemModel>> getProductRecipes(int productId) async {
    return await _repository.getProductRecipes(productId);
  }

  Future<void> saveProductRecipes(int productId, List<ProductRecipeItemModel> recipes) async {
    await _repository.saveProductRecipes(productId, recipes);
    notifyListeners();
  }

  Future<void> deductRecipeStockForSoldProduct(int productId, double soldQuantity) async {
    await _repository.deductRecipeStockForSoldProduct(productId, soldQuantity);
    await loadRawMaterials();
  }
}
