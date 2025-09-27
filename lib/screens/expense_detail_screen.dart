// lib/screens/expense_detail_screen.dart (เวอร์ชันรวมฟังก์ชัน)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // สำหรับการเลือกรูปภาพ
import 'package:intl/intl.dart'; // สำหรับการจัดรูปแบบวันที่
import 'dart:io'; // สำหรับ File object

import 'dart:developer' as developer; // สำหรับการทำ logging

import '../models/category.dart';
import '../models/expense.dart';
import '../models/payer.dart'; // Import Payer model
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/payer_provider.dart'; // Import PayerProvider

import '../utils/extensions.dart';

class ExpenseDetailScreen extends StatefulWidget {
  static const routeName = '/expense-detail';
  final DateTime selectedDate; // วันที่เริ่มต้นสำหรับการเพิ่มค่าใช้จ่ายใหม่
  final Expense? existingExpense; // สำหรับกรณีแก้ไขค่าใช้จ่ายที่มีอยู่

  const ExpenseDetailScreen({
    super.key,
    required this.selectedDate,
    this.existingExpense,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(); // เพิ่ม description controller
  DateTime? _selectedDate;
  Category? _selectedCategory;
  Payer? _selectedPayer; // เพิ่ม selected payer
  Expense? _editedExpense; // ใช้ field นี้เพื่อจัดการค่าใช้จ่ายที่กำลังแก้ไข
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  var _isInit = true; // Flag สำหรับการตรวจสอบการเริ่มต้นครั้งแรก

  @override
  void initState() {
    super.initState();
    // กำหนด _editedExpense จาก widget.existingExpense ทันที
    _editedExpense = widget.existingExpense;
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      // กำหนดวันที่เริ่มต้นจาก widget.selectedDate
      _selectedDate = widget.selectedDate.copyWith(
        hour: DateTime.now().hour,
        minute: DateTime.now().minute,
        second: DateTime.now().second,
      );

      // ถ้าเป็นการแก้ไขค่าใช้จ่ายที่มีอยู่ ให้ populate ข้อมูลลงในฟอร์ม
      if (_editedExpense != null) {
        _amountController.text = _editedExpense!.amount.toString();
        _descriptionController.text = _editedExpense!.description; // กำหนด description
        _selectedDate = _editedExpense!.date.copyWith( // รักษาเวลาเดิมไว้
          hour: _editedExpense!.date.hour,
          minute: _editedExpense!.date.minute,
          second: _editedExpense!.date.second,
          millisecond: _editedExpense!.date.millisecond,
          microsecond: _editedExpense!.date.microsecond,
        );
        _pickedImage = _editedExpense!.imagePath != null
            ? File(_editedExpense!.imagePath!)
            : null;

        // ดึง category และ payer จาก provider เพื่อตั้งค่า Dropdown
        final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
        final payerProvider = Provider.of<PayerProvider>(context, listen: false);

        // ตั้งค่าหมวดหมู่ที่ถูกเลือก
        _selectedCategory = categoryProvider.categories
            .firstWhereOrNull((cat) => cat.id == _editedExpense!.categoryId);

        // ตั้งค่าผู้จ่ายที่ถูกเลือก
        _selectedPayer = payerProvider.payers
            .firstWhereOrNull((p) => p.id == _editedExpense!.payerId);
      }

      // ตรวจสอบและตั้งค่าเริ่มต้นสำหรับ Dropdown หากยังไม่มีการเลือก หรือหากค่าเดิมไม่ถูกต้อง
      // ส่วนนี้จะทำงานหลังจากพยายามตั้งค่าจาก _editedExpense แล้ว
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final payerProvider = Provider.of<PayerProvider>(context, listen: false);

      if (_selectedCategory == null && categoryProvider.categories.isNotEmpty) {
        _selectedCategory = categoryProvider.categories.first; // เลือก Category ตัวแรกเป็นค่าเริ่มต้น
      }
      if (_selectedPayer == null && payerProvider.payers.isNotEmpty) {
        _selectedPayer = payerProvider.payers.first; // เลือก Payer ตัวแรกเป็นค่าเริ่มต้น
      }

      // ต้องเรียก setState() เพื่ออัปเดต UI หลังจากตั้งค่าค่าเริ่มต้นต่างๆ
      // เรียกเฉพาะเมื่อ widget ยังคง mounted อยู่
      if (mounted) {
        setState(() {});
      }
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose(); // ต้อง dispose ด้วย
    super.dispose();
  }

  // ฟังก์ชันสำหรับเลือกวันที่จาก DatePicker
  Future<void> _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(), // ใช้ _selectedDate เป็นค่าเริ่มต้น
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // ให้เลือกได้ถึงวันปัจจุบัน
    );

    if (!mounted) return; // ตรวจสอบ mounted ก่อน setState

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

  // ฟังก์ชันสำหรับเลือกรูปภาพ
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (!mounted) return;

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  // ฟังก์ชันสำหรับบันทึกค่าใช้จ่าย
  Future<void> _saveExpense() async {
    // ตรวจสอบ validation ของ Form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    if (!mounted) return;

    // ตรวจสอบว่ามีค่าที่จำเป็นครบถ้วนหรือไม่
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

    // สร้าง Expense object
    final newOrUpdatedExpense = Expense(
      id: _editedExpense?.id, // ถ้าเป็นการแก้ไข จะมี ID เดิม
      amount: double.parse(_amountController.text),
      date: _selectedDate!,
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name, // ใส่ชื่อหมวดหมู่ด้วย
      description: _descriptionController.text.trim(),
      imagePath: _pickedImage?.path, // บันทึก path ของรูปภาพ
      payerId: _selectedPayer!.id,
      payerName: _selectedPayer!.name, // ใส่ชื่อผู้จ่ายด้วย
    );

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      if (_editedExpense == null) {
        // เพิ่มค่าใช้จ่ายใหม่
        await expenseProvider.addExpense(newOrUpdatedExpense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense added successfully!')),
          );
        }
      } else {
        // อัปเดตค่าใช้จ่ายที่มีอยู่
        await expenseProvider.updateExpense(newOrUpdatedExpense);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully!')),
          );
        }
      }
      if (mounted) Navigator.of(context).pop(); // กลับไปยังหน้าจอก่อนหน้า
    } catch (error) {
      developer.log('Error saving expense: $error', name: 'ExpenseDetailScreen', error: error);
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

    // ตรวจสอบเบื้องต้นว่ามี Category หรือ Payer อยู่ในระบบหรือไม่
    // (สามารถปรับปรุงการแสดงผลให้ดีขึ้นได้ เช่น แสดงปุ่มให้เพิ่ม Category/Payer)
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
            onPressed: _saveExpense,
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
                    return 'Amount must be greater than zero.';
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
              const SizedBox(height: 20),
              // ส่วนสำหรับแนบรูปภาพ
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
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(_editedExpense == null ? 'Add Expense' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
