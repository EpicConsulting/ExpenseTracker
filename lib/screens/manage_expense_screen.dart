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

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final dynamic args = ModalRoute.of(context)!.settings.arguments;

      // ใช้ WidgetsBinding.instance.addPostFrameCallback เพื่อเข้าถึง Provider หลังจาก build
      // และเพื่อให้แน่ใจว่า context ยัง mounted อยู่
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // ตรวจสอบ mounted ก่อนใช้ context

        final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
        final payerProvider = Provider.of<PayerProvider>(context, listen: false);

        if (args is Expense) {
          // *** กรณีแก้ไข Expense ***
          _editedExpense = args;
          _amountController.text = _editedExpense!.amount.toString();
          _descriptionController.text = _editedExpense!.description ?? '';

          // ตั้งค่า _selectedDate โดยรวมเวลาปัจจุบันเข้าไปด้วย เพื่อไม่ให้เวลากลายเป็นเที่ยงคืน
          _selectedDate = _editedExpense!.date.copyWith(
            hour: _editedExpense!.date.hour,
            minute: _editedExpense!.date.minute,
            second: _editedExpense!.date.second,
            millisecond: _editedExpense!.date.millisecond,
            microsecond: _editedExpense!.date.microsecond,
          );

          // ดึง category จาก provider
          _selectedCategory = categoryProvider.categories
              .firstWhereOrNull((cat) => cat.id == _editedExpense!.categoryId);

          // ดึง payer จาก provider
          _selectedPayer = payerProvider.payers
              .firstWhereOrNull((p) => p.id == _editedExpense!.payerId);

        } else if (args is DateTime) {
          // *** กรณีเพิ่ม Expense สำหรับวันที่เลือกจากหน้า MainScreen ***
          _selectedDate = args.copyWith(
            hour: DateTime.now().hour,
            minute: DateTime.now().minute,
            second: DateTime.now().second,
          );
        } else {
          // *** กรณีเพิ่ม Expense ทั่วไป (ไม่มีวันที่ถูกเลือกจากหน้าหลัก) ***
          _selectedDate = DateTime.now();
        }

        // *** กำหนดค่าเริ่มต้นสำหรับ Dropdown หากยังไม่มีการเลือก หรือหากค่าเดิมไม่ถูกต้อง ***
        // นี่คือส่วนสำคัญที่ช่วยให้ Dropdown มีค่าเริ่มต้นเมื่อเปิดหน้าครั้งแรก
        if (_selectedCategory == null && categoryProvider.categories.isNotEmpty) {
          _selectedCategory = categoryProvider.categories.first; // เลือก Category ตัวแรกเป็นค่าเริ่มต้น
        }
        if (_selectedPayer == null && payerProvider.payers.isNotEmpty) {
          _selectedPayer = payerProvider.payers.first; // เลือก Payer ตัวแรกเป็นค่าเริ่มต้น
        }


        // ต้องเรียก setState() เพื่ออัปเดต UI หลังจากตั้งค่า _selectedCategory และ _selectedPayer
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

    // ตรวจสอบ mounted ก่อน setState
    if (!mounted) return;

    if (pickedDate != null) {
      setState(() {
        // รักษาเวลาปัจจุบันไว้ (หรือเวลาเดิมถ้า _selectedDate ไม่ใช่ null)
        _selectedDate = pickedDate.copyWith(
          hour: _selectedDate?.hour ?? DateTime.now().hour,
          minute: _selectedDate?.minute ?? DateTime.now().minute,
          second: _selectedDate?.second ?? DateTime.now().second,
        );
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    // ตรวจสอบ mounted ก่อนใช้ context
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
      imagePath: null, // หรือเพิ่ม logic จัดการ imagePath ในอนาคต
      payerId: _selectedPayer!.id,
      payerName: _selectedPayer!.name,
    );

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (_editedExpense == null) {
        await expenseProvider.addExpense(newExpense);
        // ตรวจสอบ mounted ก่อนแสดง SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully!')),
          );
        }
      } else {
        await expenseProvider.updateExpense(newExpense);
        // ตรวจสอบ mounted ก่อนแสดง SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully!')),
          );
        }
      }
      // ตรวจสอบ mounted ก่อน pop
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      developer.log('Error saving expense: $error', name: 'ManageExpenseScreen', error: error);
      // ตรวจสอบ mounted ก่อนแสดง SnackBar
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

    // ตรวจสอบให้แน่ใจว่า Dropdown มีรายการให้เลือก
    if (categoryProvider.categories.isEmpty) {
      // อาจแสดงข้อความหรือ Widget โหลดข้อมูล หรือให้ผู้ใช้เพิ่ม Category ก่อน
      return Scaffold(
        appBar: AppBar(title: Text(_editedExpense == null ? 'Add Expense' : 'Edit Expense')),
        body: const Center(
          child: Text('No categories available. Please add some categories first.'),
        ),
      );
    }

    if (payerProvider.payers.isEmpty) {
      // อาจแสดงข้อความหรือ Widget โหลดข้อมูล หรือให้ผู้ใช้เพิ่ม Payer ก่อน
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
              // Dropdown สำหรับเลือก Category
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
              // Dropdown สำหรับเลือก Payer
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
            ],
          ),
        ),
      ),
    );
  }
}

// Extension เพื่อช่วยในการหา Element ใน List
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}