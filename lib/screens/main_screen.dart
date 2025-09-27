import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../providers/expense_provider.dart';
import '../providers/payer_provider.dart';
import '../widgets/app_drawer.dart';
import './expense_detail_screen.dart';
import './payer_expenses_detail_screen.dart';

class MainScreen extends StatefulWidget {
  // ใช้ '/main' เพื่อไม่ชนกับกรณีมี home: ใน MaterialApp
  static const routeName = '/main';

  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<dynamic>> _events = {};

  // เก็บ reference ของ provider เพื่อไม่ lookup context ใน dispose()
  late final ExpenseProvider _expenseProvider;
  late final PayerProvider _payerProvider;

  bool _initialFetched = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // ดึง provider แบบ listen: false ได้ใน initState
    _expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    _payerProvider = Provider.of<PayerProvider>(context, listen: false);

    // ฟังการเปลี่ยนแปลงเฉพาะ expenses เพื่อ refresh calendar dots
    _expenseProvider.addListener(_onExpenseChange);

    // ทำ fetch หลัง frame แรกเพื่อหลีกเลี่ยง build context issue
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([
        _expenseProvider.fetchExpenses(),
        _payerProvider.fetchPayers(),
      ]);
      if (!mounted) return;
      await _loadExpensesForCalendar();
      if (mounted) {
        setState(() {
          _initialFetched = true;
        });
      }
    });
  }

  @override
  void dispose() {
    // ใช้ reference ที่ cache ไว้ ไม่เรียก Provider.of()
    _expenseProvider.removeListener(_onExpenseChange);
    super.dispose();
  }

  void _onExpenseChange() {
    // เรียกซ้ำเมื่อรายการ expenses เปลี่ยน
    _loadExpensesForCalendar();
  }

  Future<void> _loadExpensesForCalendar() async {
    if (!mounted) return;
    try {
      final datesWithExpenses = await _expenseProvider.getDatesWithExpensesForMonth(
        _focusedDay.year,
        _focusedDay.month,
      );

      final newEvents = <DateTime, List<dynamic>>{};
      for (final row in datesWithExpenses) {
        final raw = row['expenseDay'];
        if (raw is String && raw.isNotEmpty) {
          final date = DateTime.parse(raw);
            newEvents[DateTime(date.year, date.month, date.day)] = ['expense'];
        }
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
        });
      }
    } catch (e, st) {
      developer.log(
        'Error loading calendar events: $e',
        name: 'MainScreen',
        error: e,
        stackTrace: st,
      );
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
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
    // ใช้ watch เพื่อ rebuild ส่วนที่ต้องแสดงรายการ
    final expenseProviderWatch = context.watch<ExpenseProvider>();
    final payerProviderWatch = context.watch<PayerProvider>();

    // กรอง expenses ต่อวัน
    final expensesOnSelectedDay = _selectedDay == null
        ? <dynamic>[]
        : expenseProviderWatch.expenses.where((exp) =>
            exp.date.year == _selectedDay!.year &&
            exp.date.month == _selectedDay!.month &&
            exp.date.day == _selectedDay!.day).toList();

    // รวมยอดต่อ payer
    final payerTotals = <int, double>{};
    final payerMap = {for (var p in payerProviderWatch.payers) p.id!: p};

    for (final exp in expensesOnSelectedDay) {
      final pid = exp.payerId;
      if (pid != null) {
        payerTotals.update(pid, (v) => v + exp.amount, ifAbsent: () => exp.amount);
      }
    }

    final payerSummaries = payerTotals.entries
        .map((e) => PayerSummary(
              payerId: e.key,
              payerName: payerMap[e.key]?.name ?? 'Unknown Payer',
              totalAmount: e.value,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Calendar
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
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
                final has = _getEventsForDay(day).isNotEmpty;
                return Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: has ? Colors.green[800] : Colors.black,
                      fontWeight: has ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final has = _getEventsForDay(day).isNotEmpty;
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: has ? Colors.green[600] : Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final has = _getEventsForDay(day).isNotEmpty;
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: has ? Colors.green[400] : Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedDay == null
                    ? 'Select a day to view expenses.'
                    : 'Expenses by Payer for ${DateFormat('dd MMMM yyyy').format(_selectedDay!)}:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          // List
          Expanded(
            child: !_initialFetched
                ? const Center(child: CircularProgressIndicator())
                : payerSummaries.isEmpty
                    ? const Center(child: Text('No expenses recorded for this day.'))
                    : ListView.builder(
                        itemCount: payerSummaries.length,
                        itemBuilder: (ctx, i) {
                          final s = payerSummaries[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                            child: ListTile(
                              title: Text(s.payerName),
                              trailing: Text('${s.totalAmount.toStringAsFixed(2)} ฿'),
                              onTap: () {
                                if (_selectedDay == null) return;
                                Navigator.of(context).pushNamed(
                                  PayerExpensesDetailScreen.routeName,
                                  arguments: {
                                    'selectedDay': _selectedDay,
                                    'payerId': s.payerId,
                                    'payerName': s.payerName,
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
          Navigator.of(context)
              .pushNamed(
            ExpenseDetailScreen.routeName,
            arguments: {
              'selectedDate': _selectedDay ?? DateTime.now(),
              'existingExpense': null,
            },
          )
              .then((_) {
            if (!mounted) return;
            _expenseProvider.fetchExpenses();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

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