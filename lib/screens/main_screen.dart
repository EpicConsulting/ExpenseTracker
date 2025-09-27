import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../models/payer.dart';
import '../providers/expense_provider.dart';
import '../providers/payer_provider.dart';
import '../widgets/app_drawer.dart';
import './expense_detail_screen.dart';
import './payer_expenses_detail_screen.dart';

class MainScreen extends StatefulWidget {
  static const routeName = '/';

  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month; // Made final

  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
      Provider.of<PayerProvider>(context, listen: false).fetchPayers();
    });

    _loadExpensesForCalendar();
    Provider.of<ExpenseProvider>(context, listen: false).addListener(_onExpenseChange);
  }

  @override
  void dispose() {
    Provider.of<ExpenseProvider>(context, listen: false).removeListener(_onExpenseChange);
    super.dispose();
  }

  void _onExpenseChange() {
    _loadExpensesForCalendar();
  }

  Future<void> _loadExpensesForCalendar() async {
    // Only use context if mounted
    if (!mounted) {
      developer.log('MainScreen: _loadExpensesForCalendar called but not mounted', name: 'MainScreen');
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final datesWithExpenses = await expenseProvider.getDatesWithExpensesForMonth(
      _focusedDay.year,
      _focusedDay.month,
    );

    final newEvents = <DateTime, List<dynamic>>{};
    for (var dateString in datesWithExpenses) {
      if (dateString['expenseDay'] != null) {
        final DateTime date = DateTime.parse(dateString['expenseDay']!);
        newEvents[date] = ['expense'];
      }
    }

    if (mounted) {
      setState(() {
        _events = newEvents;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final pureDay = DateTime(day.year, day.month, day.day);
    return _events[pureDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadExpensesForCalendar();
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final payerProvider = Provider.of<PayerProvider>(context);

    // Filter expenses for the selected day
    final expensesOnSelectedDay = _selectedDay != null
        ? expenseProvider.expenses.where((exp) =>
            exp.date.year == _selectedDay!.year &&
            exp.date.month == _selectedDay!.month &&
            exp.date.day == _selectedDay!.day
          ).toList()
        : [];

    // Calculate totals per payer
    Map<int, double> payerTotals = {};
    Map<int, Payer> payerMap = {for (var p in payerProvider.payers) p.id!: p};

    for (var expense in expensesOnSelectedDay) {
      if (expense.payerId != null) {
        payerTotals.update(
          expense.payerId!,
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }
    }

    // Convert Map to List of PayerSummary for display
    List<PayerSummary> payerSummaries = payerTotals.entries.map((entry) {
      final payer = payerMap[entry.key];
      return PayerSummary(
        payerId: entry.key,
        payerName: payer?.name ?? 'Unknown Payer',
        totalAmount: entry.value,
      );
    }).toList();

    payerSummaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onDaySelected: _onDaySelected,
            onPageChanged: _onPageChanged,
            eventLoader: _getEventsForDay,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: Colors.black87),
              weekendTextStyle: TextStyle(color: Colors.red),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final bool hasEvents = _events[DateTime(day.year, day.month, day.day)] != null &&
                    _events[DateTime(day.year, day.month, day.day)]!.isNotEmpty;

                return Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: hasEvents ? Colors.green[800] : Colors.black,
                      fontWeight: hasEvents ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final bool hasEvents = _events[DateTime(day.year, day.month, day.day)] != null &&
                    _events[DateTime(day.year, day.month, day.day)]!.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasEvents ? Colors.green[600] : Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final bool hasEvents = _events[DateTime(day.year, day.month, day.day)] != null &&
                    _events[DateTime(day.year, day.month, day.day)]!.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasEvents ? Colors.green[400] : Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _selectedDay != null
                  ? 'Expenses by Payer for ${DateFormat('dd MMMM yyyy').format(_selectedDay!)}:'
                  : 'Select a day to view expenses.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: payerSummaries.isEmpty
                ? const Center(
                    child: Text('No expenses recorded for this day.'),
                  )
                : ListView.builder(
                    itemCount: payerSummaries.length,
                    itemBuilder: (ctx, index) {
                      final summary = payerSummaries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                        child: ListTile(
                          title: Text(summary.payerName),
                          trailing: Text('${summary.totalAmount.toStringAsFixed(2)} ฿'),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              PayerExpensesDetailScreen.routeName,
                              arguments: {
                                'selectedDay': _selectedDay,
                                'payerId': summary.payerId,
                                'payerName': summary.payerName,
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
          Navigator.of(context).pushNamed(
            ExpenseDetailScreen.routeName,
            arguments: {'selectedDate': _selectedDay ?? DateTime.now(), 'existingExpense': null},
          ).then((_) {
            if (!mounted) return;
            expenseProvider.fetchExpenses();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Class สำหรับเก็บข้อมูลสรุปของผู้จ่าย
class PayerSummary {
  final int payerId;
  final String payerName;
  final double totalAmount;

  PayerSummary({
    required this.payerId,
    required this.payerName,
    required this.totalAmount,
  });
}