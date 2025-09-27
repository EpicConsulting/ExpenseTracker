import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../models/expense.dart';
import '../models/category.dart';
import '../models/payer.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/payer_provider.dart';
import '../utils/extensions.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ManageExpenseScreen extends StatefulWidget {
  static const routeName = '/manage-expense';

  const ManageExpenseScreen({super.key});

  @override
  State<ManageExpenseScreen> createState() => _ManageExpenseScreenState();
}

class _ManageExpenseScreenState extends State<ManageExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  Category? _selectedCategory;
  Payer? _selectedPayer;
  Expense? _editedExpense;
  var _isInit = true;
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  String _selectedPaymentType = 'cash'; // <<<<<< ADD HERE

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final dynamic args = ModalRoute.of(context)!.settings.arguments;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
        final payerProvider = Provider.of<PayerProvider>(context, listen: false);

        if (args is Expense) {
          _editedExpense = args;
          _amountController.text = _editedExpense!.amount.toString();
          _descriptionController.text = _editedExpense!.description;
          _selectedDate = _editedExpense!.date.copyWith(
            hour: _editedExpense!.date.hour,
            minute: _editedExpense!.date.minute,
            second: _editedExpense!.date.second,
            millisecond: _editedExpense!.date.millisecond,
            microsecond: _editedExpense!.date.microsecond,
          );
          _selectedCategory = categoryProvider.categories.firstWhereOrNull((cat) => cat.id == _editedExpense!.categoryId);
          _selectedPayer = payerProvider.payers.firstWhereOrNull((p) => p.id == _editedExpense!.payerId);
          // Set payment type if available
          _selectedPaymentType = _editedExpense?.paymentType ?? 'cash';
        } else if (args is DateTime) {
          _selectedDate = args.copyWith(
            hour: DateTime.now().hour,
            minute: DateTime.now().minute,
            second: DateTime.now().second,
          );
        } else {
          _selectedDate = DateTime.now();
        }
        if (_selectedCategory == null && categoryProvider.categories.isNotEmpty) {
          _selectedCategory = categoryProvider.categories.first;
        }
        if (_selectedPayer == null && payerProvider.payers.isNotEmpty) {
          _selectedPayer = payerProvider.payers.first;
        }
        if (mounted) {
          setState(() {});
        }
      });
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate.copyWith(
          hour: _selectedDate?.hour ?? DateTime.now().hour,
          minute: _selectedDate?.minute ?? DateTime.now().minute,
          second: _selectedDate?.second ?? DateTime.now().second,
        );
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (!mounted) return;
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    if (!mounted) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date.')),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }
    if (_selectedPayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payer.')),
      );
      return;
    }

    final newExpense = Expense(
      id: _editedExpense?.id,
      amount: double.parse(_amountController.text),
      date: _selectedDate!,
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name,
      description: _descriptionController.text.trim(),
      imagePath: _pickedImage?.path,
      payerId: _selectedPayer!.id,
      payerName: _selectedPayer!.name,
      paymentType: _selectedPaymentType, // <<<<<< ADD HERE
    );

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (_editedExpense == null) {
        await expenseProvider.addExpense(newExpense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully!')),
          );
        }
      } else {
        await expenseProvider.updateExpense(newExpense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully!')),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      developer.log('Error saving expense: $error', name: 'ManageExpenseScreen', error: error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: ${error.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final payerProvider = Provider.of<PayerProvider>(context);

    if (categoryProvider.categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_editedExpense == null ? 'Add Expense' : 'Edit Expense')),
        body: const Center(
          child: Text('No categories available. Please add some categories first.'),
        ),
      );
    }

    if (payerProvider.payers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_editedExpense == null ? 'Add Expense' : 'Edit Expense')),
        body: const Center(
          child: Text('No payers available. Please add some payers first.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editedExpense == null ? 'Add Expense' : 'Edit Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount.';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid amount.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'No Date Chosen!'
                          : 'Picked Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _presentDatePicker,
                    child: const Text(
                      'Choose Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedPaymentType,
                decoration: const InputDecoration(
                  labelText: 'Payment Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('เงินสด'),
                  ),
                  DropdownMenuItem(
                    value: 'credit_card',
                    child: Text('บัตรเครดิต'),
                  ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) setState(() => _selectedPaymentType = newValue);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณาเลือกประเภทการจ่าย';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Category>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categoryProvider.categories
                    .map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat.name),
                ))
                    .toList(),
                onChanged: (Category? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Payer>(
                value: _selectedPayer,
                decoration: const InputDecoration(
                  labelText: 'Payer',
                  border: OutlineInputBorder(),
                ),
                items: payerProvider.payers
                    .map((payer) => DropdownMenuItem(
                  value: payer,
                  child: Text(payer.name),
                ))
                    .toList(),
                onChanged: (Payer? newValue) {
                  setState(() {
                    _selectedPayer = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a payer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _pickedImage == null
                        ? const Text('No Image Attached')
                        : Image.file(
                      _pickedImage!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Attach Photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}