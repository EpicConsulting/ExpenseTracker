import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/app_drawer.dart';
import './expense_detail_screen.dart';
import '../models/category.dart';

class ExpenseListScreen extends StatefulWidget {
  static const routeName = '/expense-list';

  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Fetch after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
    });
  }

  /// Fixed for use_build_context_synchronously:
  /// 1. Capture any BuildContext / providers BEFORE awaiting.
  /// 2. Use State.mounted and also (optionally) context.mounted after async gaps.
  Future<void> _selectMonth() async {
    // Capture the root context & any providers BEFORE the async gap
    final rootContext = context;
    final expenseProvider = Provider.of<ExpenseProvider>(rootContext, listen: false);

    final DateTime? picked = await showDatePicker(
      context: rootContext,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (!mounted) return; // guard State.context

    if (picked != null && picked != _selectedMonth) {
      // Show month selector dialog (still safe, we captured rootContext earlier)
      if (!rootContext.mounted) return; // guard the BuildContext itself (Flutter 3.7+)
      await showDialog<void>(
        context: rootContext,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('Select Month'),
            content: SizedBox(
              width: 300,
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 4.0,
                  mainAxisSpacing: 4.0,
                ),
                itemCount: 12,
                itemBuilder: (itemCtx, index) {
                  final month = index + 1;
                  final monthName = DateFormat.MMM().format(DateTime(picked.year, month));
                  final bool isSelected =
                      _selectedMonth.year == picked.year && _selectedMonth.month == month;
                  return InkWell(
                    onTap: () {
                      // Update selected month
                      setState(() {
                        _selectedMonth = DateTime(picked.year, month);
                      });
                      // Refetch (no async gap here, safe to use rootContext)
                      expenseProvider.fetchExpenses();
                      // Close inner dialog
                      if (Navigator.canPop(itemCtx)) Navigator.of(itemCtx).pop();
                      // Close original date picker (already popped automatically when we returned here)
                    },
                    child: Card(
                      color: isSelected ? Theme.of(rootContext).primaryColor : Colors.grey[200],
                      child: Center(
                        child: Text(
                          monthName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expenses for ${DateFormat.yMMMM().format(_selectedMonth)}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectMonth, // updated to call method without passing context
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed(
                ExpenseDetailScreen.routeName,
                arguments: {'selectedDate': DateTime.now(), 'existingExpense': null},
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Consumer<ExpenseProvider>(
        builder: (ctx, expenseProvider, child) {
          final filteredExpenses = expenseProvider.expenses.where((expense) {
            return expense.date.year == _selectedMonth.year &&
                expense.date.month == _selectedMonth.month;
          }).toList();

          if (filteredExpenses.isEmpty) {
            return const Center(
              child: Text('No expenses recorded for this month.'),
            );
          }

          final double totalMonthlyExpenses =
              filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Expenses (${DateFormat.MMMM().format(_selectedMonth)}):',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${totalMonthlyExpenses.toStringAsFixed(2)} ฿',
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
                child: ListView.builder(
                  itemCount: filteredExpenses.length,
                  itemBuilder: (ctx, i) {
                    final expense = filteredExpenses[i];
                    final category = categoryProvider.categories.firstWhere(
                      (cat) => cat.id == expense.categoryId,
                      orElse: () => Category(
                        id: -1,
                        name: 'Unknown',
                        color: 0xFF9E9E9E, // fallback int literal
                      ),
                    );

                    return Dismissible(
                      key: ValueKey(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text('Do you want to remove this expense?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.of(ctx2).pop(false),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx2).pop(true),
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                        return result ?? false;
                      },
                      onDismissed: (direction) async {
                        if (expense.id != null) {
                          final messenger = ScaffoldMessenger.of(context);
                          await expenseProvider.deleteExpense(expense.id!);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Expense deleted!')),
                          );
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        elevation: 5,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.color != null
                                ? Color(category.color!)
                                : Colors.blue,
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
                          title: Text(
                            expense.description,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${DateFormat.yMd().format(expense.date)}'),
                              if (expense.categoryName != null)
                                Text('Category: ${expense.categoryName}'),
                              if (expense.payerName != null)
                                Text('Payer: ${expense.payerName}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                ExpenseDetailScreen.routeName,
                                arguments: {
                                  'selectedDate': expense.date,
                                  'existingExpense': expense,
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}