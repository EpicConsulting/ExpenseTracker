import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart'; // <--- ลบ import นี้ออกไป
import '../models/payer.dart';
import '../providers/payer_provider.dart';

class ManagePayerScreen extends StatefulWidget {
  static const routeName = '/manage-payer';

  const ManagePayerScreen({super.key});

  @override
  State<ManagePayerScreen> createState() => _ManagePayerScreenState();
}

class _ManagePayerScreenState extends State<ManagePayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Payer? _editedPayer; // เก็บ Payer ที่กำลังแก้ไข (ถ้ามี)
  var _isInit = true; // ตรวจสอบว่าเป็นการเริ่มต้นครั้งแรก

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final Payer? existingPayer = ModalRoute.of(context)!.settings.arguments as Payer?;
      if (existingPayer != null) {
        _editedPayer = existingPayer;
        _nameController.text = _editedPayer!.name;
      }
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return; // ฟอร์มไม่ถูกต้อง
    }
    _formKey.currentState!.save();

    final String payerName = _nameController.text.trim();

    try {
      final payerProvider = Provider.of<PayerProvider>(context, listen: false);

      if (_editedPayer == null) {
        // เพิ่มผู้จ่ายใหม่
        final newPayer = Payer(name: payerName); // <--- ไม่ต้องใส่ id: const Uuid().v4() แล้ว
        await payerProvider.addPayer(newPayer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payer added successfully!')),
        );
      } else {
        // อัปเดตผู้จ่ายที่มีอยู่
        final updatedPayer = Payer(id: _editedPayer!.id, name: payerName);
        await payerProvider.updatePayer(updatedPayer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payer updated successfully!')),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payer: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... โค้ดที่เหลือเหมือนเดิม
    return Scaffold(
      appBar: AppBar(
        title: Text(_editedPayer == null ? 'Add Payer' : 'Edit Payer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Payer Name'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveForm(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a payer name.';
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