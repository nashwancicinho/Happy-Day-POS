import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/category.dart';
import 'categories_provider.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = context.watch<CategoriesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('إضافة تصنيف جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: categoriesProvider.categories.isEmpty
            ? const Center(
                child: Text('لا توجد تصنيفات مضافة حتى الآن', style: TextStyle(fontSize: 18)),
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
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Text('ID: #${cat.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showCategoryDialog(context, category: cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
    final nameController = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(category == null ? 'إضافة تصنيف جديد' : 'تعديل التصنيف'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم التصنيف (مثل: مشروبات، وجبات...)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
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
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }
}
