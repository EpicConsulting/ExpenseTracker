import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
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
  Color _selectedColor = Colors.blue;

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final categoryName = _categoryController.text.trim();
    if (categoryName.isEmpty) return;

    final newCategory = Category(
      name: categoryName,
      color: _selectedColor
          .toARGB32(), // using toARGB32 instead of deprecated .value if your Flutter version supports it
    );

    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final focusScope = FocusScope.of(context);

    try {
      await categoryProvider.addCategory(newCategory);
      _categoryController.clear();
      setState(() {
        _selectedColor = Colors.blue;
      });
      focusScope.unfocus();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to add category: $e')),
      );
    }
  }

  Future<void> _deleteCategory(int id) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Deleting a category will also delete all associated expenses. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await expenseProvider.fetchExpenses();
        await categoryProvider.deleteCategory(id);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Category deleted!')),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete category: $e')),
        );
      }
    }
  }

  Future<void> _showEditCategoryDialog(Category category) async {
    final editController = TextEditingController(text: category.name);
    final formKey = GlobalKey<FormState>();
    Color editColor = category.color != null ? Color(category.color!) : Colors.blue;

    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: editController,
                decoration: const InputDecoration(labelText: 'New Category Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Color:'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await showDialog(
                        context: dialogCtx,
                        builder: (colorDialogCtx) => AlertDialog(
                          title: const Text('Pick a category color'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: editColor,
                              onColorChanged: (color) {
                                // Safe because still within parent State
                                setState(() {
                                  editColor = color;
                                });
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(colorDialogCtx).pop(),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: editColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(dialogCtx)) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newName = editController.text.trim();
              try {
                await categoryProvider.updateCategory(
                  category.id!,
                  newName,
                  newColor: editColor.toARGB32(),
                );
                // We must guard EACH context we use across async gap:
                if (!mounted) return; // parent State context
                if (dialogCtx.mounted && Navigator.canPop(dialogCtx)) {
                  Navigator.of(dialogCtx).pop(); // close dialog safely
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Category updated successfully!')),
                );
                setState(() {}); // refresh the list
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to update category: $e')),
                );
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
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await showDialog(
                        context: context,
                        builder: (colorDialogCtx) => AlertDialog(
                          title: const Text('Pick a category color'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: _selectedColor,
                              onColorChanged: (color) {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(colorDialogCtx).pop(),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ).catchError((_) {
                        // Optional: silently ignore dialog dismissal errors
                        messenger.hideCurrentSnackBar();
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                    return const Center(child: Text('No categories added yet.'));
                  }
                  return ListView.builder(
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (ctx, i) {
                      final category = categoryProvider.categories[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.color != null
                                ? Color(category.color!)
                                : Colors.blue,
                          ),
                          title: Text(category.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
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