import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import '../settings/settings_provider.dart';
import 'categories_provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = context.watch<CategoriesProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;

    String formatCategoryName(String rawName) {
      if (!isEng) return rawName;
      switch (rawName.trim()) {
        case 'عام':
          return 'General';
        case 'كيك':
          return 'Cakes';
        case 'بقلاوة':
          return 'Baklava & Sweets';
        case 'مشروبات':
          return 'Beverages / Drinks';
        case 'وجبات':
          return 'Meals';
        default:
          return rawName;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Categories Management' : 'إدارة التصنيفات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: Text(isEng ? 'Add New Category ➕' : 'إضافة تصنيف جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: categoriesProvider.categories.isEmpty
            ? Center(
                child: Text(
                  isEng ? 'No categories added yet' : 'لا توجد تصنيفات مضافة حتى الآن',
                  style: const TextStyle(fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: categoriesProvider.categories.length,
                itemBuilder: (context, index) {
                  final cat = categoriesProvider.categories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.category, color: Colors.white),
                      ),
                      title: Text(
                        formatCategoryName(cat.name),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text('ID: #${cat.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: isEng ? 'Edit Category' : 'تعديل التصنيف',
                            onPressed: () => _showCategoryDialog(context, category: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: isEng ? 'Delete Category' : 'حذف التصنيف',
                            onPressed: () => categoriesProvider.deleteCategory(cat.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, {CategoryModel? category}) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final nameController = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            category == null
                ? (isEng ? 'Add New Category' : 'إضافة تصنيف جديد')
                : (isEng ? 'Edit Category' : 'تعديل التصنيف'),
          ),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: isEng ? 'Category Name (e.g. Drinks, Cakes...)' : 'اسم التصنيف (مثل: مشروبات، وجبات...)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isEng ? 'Cancel' : 'إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final catProvider = context.read<CategoriesProvider>();
                if (category == null) {
                  await catProvider.addCategory(name);
                } else {
                  await catProvider.updateCategory(CategoryModel(id: category.id, name: name));
                }

                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(isEng ? 'Save Category' : 'حفظ'),
            ),
          ],
        );
      },
    );
  }
}
