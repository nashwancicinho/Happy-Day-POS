import 'package:flutter/foundation.dart';
import '../../models/category.dart';
import 'categories_repository.dart';

class CategoriesProvider extends ChangeNotifier {
  final CategoriesRepository _repository = CategoriesRepository();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    final loaded = await _repository.getAllCategories();
    loaded.sort((a, b) => a.name.trim().toLowerCase().compareTo(b.name.trim().toLowerCase()));
    _categories = loaded;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final cat = CategoryModel(name: name);
    await _repository.insertCategory(cat);
    await loadCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _repository.deleteCategory(id);
    await loadCategories();
  }
}
