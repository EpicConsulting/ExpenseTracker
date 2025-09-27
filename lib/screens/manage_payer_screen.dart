import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  Payer? _editedPayer;
  var _isInit = true;

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
      return;
    }
    _formKey.currentState!.save();

    final String payerName = _nameController.text.trim();

    try {
      final payerProvider = Provider.of<PayerProvider>(context, listen: false);

      if (_editedPayer == null) {
        final newPayer = Payer(name: payerName);
        await payerProvider.addPayer(newPayer);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payer added successfully!')),
        );
      } else {
        final updatedPayer = Payer(id: _editedPayer!.id, name: payerName);
        await payerProvider.updatePayer(updatedPayer);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payer updated successfully!')),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payer: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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