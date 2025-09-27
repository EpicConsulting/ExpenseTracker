import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payer_provider.dart';
import '../models/payer.dart';
import './manage_payer_screen.dart';

class PayerScreen extends StatefulWidget {
  static const routeName = '/payers';

  const PayerScreen({super.key});

  @override
  State<PayerScreen> createState() => _PayerScreenState();
}

class _PayerScreenState extends State<PayerScreen> {
  late Future<void> _fetchPayersFuture;

  @override
  void initState() {
    super.initState();
    _fetchPayersFuture = _fetchPayers();
  }

  Future<void> _fetchPayers() async {
    // Safe (listen: false) access before any await inside this method.
    final provider = Provider.of<PayerProvider>(context, listen: false);
    await provider.fetchPayers();
  }

  Future<void> _confirmDelete(BuildContext context, Payer payer) async {
    // Capture dependencies BEFORE async gap to satisfy use_build_context_synchronously lint.
    final payerProvider = Provider.of<PayerProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${payer.name}"?'),
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
      // Check that the State is still mounted before using messenger/showing SnackBar.
      if (!mounted) return;
      try {
        await payerProvider.deletePayer(payer.id!);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Payer deleted successfully!')),
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Error deleting payer: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Payers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).pushNamed(ManagePayerScreen.routeName);
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _fetchPayersFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('An error occurred: ${snapshot.error}'),
            );
          }
          return Consumer<PayerProvider>(
            builder: (ctx, payerProvider, child) {
              if (payerProvider.payers.isEmpty) {
                return const Center(
                  child: Text('No payers added yet. Tap + to add one!'),
                );
              }
              return ListView.builder(
                itemCount: payerProvider.payers.length,
                itemBuilder: (ctx, i) {
                  final payer = payerProvider.payers[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      title: Text(payer.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                ManagePayerScreen.routeName,
                                arguments: payer,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(context, payer),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}