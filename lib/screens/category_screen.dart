import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart'; // สำหรับรีเฟรช Expense เมื่อลบ Category
import '../widgets/app_drawer.dart';

class CategoryScreen extends StatefulWidget {
  static const routeName = '/categories';

  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final categoryName = _categoryController.text.trim();
    if (categoryName.isNotEmpty) {
      final newCategory = Category(name: categoryName);
      try {
        await Provider.of<CategoryProvider>(context, listen: false).addCategory(newCategory);
        _categoryController.clear();
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added successfully!')),
        );
      } catch (e) {
        // จัดการกรณีชื่อซ้ำหรือ error อื่นๆ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add category: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Deleting a category will also delete all associated expenses. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // สำคัญ: ต้องรีเฟรช Expenses ด้วย (เพราะอาจมีการลบ categoryId ที่เชื่อมโยง)
        await Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
        await Provider.of<CategoryProvider>(context, listen: false).deleteCategory(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete category: ${e.toString()}')),
        );
      }
    }
  }

  // ฟังก์ชันสำหรับแสดง Dialog แก้ไข Category
  Future<void> _showEditCategoryDialog(Category category) async {
    final editController = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: editController,
            decoration: const InputDecoration(labelText: 'New Category Name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category name.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newName = editController.text.trim();
                try {
                  await Provider.of<CategoryProvider>(context, listen: false)
                      .updateCategory(category.id!, newName);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category updated successfully!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update category: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'New Category Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a category name.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (ctx, categoryProvider, child) {
                  if (categoryProvider.categories.isEmpty) {
                    return const Center(
                        child: Text('No categories added yet.'));
                  }
                  return ListView.builder(
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (ctx, i) {
                      final category = categoryProvider.categories[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(category.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min, // สำคัญ!
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditCategoryDialog(category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCategory(category.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}