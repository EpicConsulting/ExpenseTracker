import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import './expense_detail_screen.dart';

class PayerExpensesDetailScreen extends StatelessWidget {
  static const routeName = '/payer-expenses-detail';

  const PayerExpensesDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final DateTime selectedDay = args['selectedDay'] as DateTime;
    final int payerId = args['payerId'] as int;
    final String payerName = args['payerName'] as String;

    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    final expensesForPayerOnDay = expenseProvider.expenses.where((exp) {
      return exp.date.year == selectedDay.year &&
          exp.date.month == selectedDay.month &&
          exp.date.day == selectedDay.day &&
          exp.payerId == payerId;
    }).toList();

    final double totalPayerExpensesToday =
        expensesForPayerOnDay.fold(0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "$payerName's Expenses on ${DateFormat('dd MMMM yyyy').format(selectedDay)}",
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total for $payerName:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${totalPayerExpensesToday.toStringAsFixed(2)} ฿',
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: expensesForPayerOnDay.isEmpty
                ? const Center(
                    child: Text(
                        'No expenses recorded for this payer on this day.'),
                  )
                : ListView.builder(
                    itemCount: expensesForPayerOnDay.length,
                    itemBuilder: (ctx, index) {
                      final expense = expensesForPayerOnDay[index];

                      final category = categoryProvider.categories.firstWhere(
                        (cat) => cat.id == expense.categoryId,
                        orElse: () => Category(
                          id: -1,
                          name: 'Unknown Category',
                          // Use a literal ARGB int instead of deprecated .value
                          color: 0xFF9E9E9E,
                        ),
                      );

                      final Color avatarColor = category.color != null
                          ? Color(category.color!)
                          : const Color(0xFF9E9E9E);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: avatarColor,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: FittedBox(
                                child: Text(
                                  expense.amount.toStringAsFixed(0),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          title: Text(expense.description),
                          subtitle: Text(category.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                ExpenseDetailScreen.routeName,
                                arguments: {
                                  'selectedDate': expense.date,
                                  'existingExpense': expense
                                },
                              );
                            },
                          ),
                          onLongPress: () async {
                            // Capture provider & messenger before async gap
                            final expenseProv = Provider.of<ExpenseProvider>(
                                ctx,
                                listen: false);
                            final messenger = ScaffoldMessenger.of(ctx);

                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: const Text(
                                    'Are you sure you want to delete this expense?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogCtx).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && ctx.mounted) {
                              await expenseProv.deleteExpense(expense.id!);
                              if (!ctx.mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text('Expense deleted!')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}