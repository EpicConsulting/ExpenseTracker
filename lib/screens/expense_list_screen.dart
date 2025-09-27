// lib/screens/expense_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // สำหรับจัดรูปแบบวันที่
import 'dart:developer' as developer; // สำหรับ logging

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/app_drawer.dart'; // ตรวจสอบให้แน่ใจว่า app_drawer.dart มีอยู่และอยู่ใน path ที่ถูกต้อง
import './expense_detail_screen.dart'; // สำหรับการนำทางไปเพิ่ม/แก้ไขค่าใช้จ่าย

class ExpenseListScreen extends StatefulWidget {
  static const routeName = '/expense-list';

  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  // สำหรับการเลือกเดือนและปี
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    // โหลดข้อมูลค่าใช้จ่ายสำหรับเดือนปัจจุบันเมื่อ Widget ถูกสร้าง
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses();
    });
  }

  // ฟังก์ชันสำหรับแสดง DatePicker เพื่อเลือกเดือนและปี
  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000), // กำหนดปีเริ่มต้นที่เหมาะสม
      lastDate: DateTime(2101), // กำหนดปีสิ้นสุดที่เหมาะสม
      initialDatePickerMode: DatePickerMode.year, // เริ่มต้นที่การเลือกปี
    );

    if (picked != null && picked != _selectedMonth) {
      // เมื่อเลือกปีได้แล้ว ให้เลือกเดือนต่อ
      // สร้าง Dialog เองเพื่อให้เลือกเดือนได้
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Month'),
            content: SizedBox(
              width: 300, // กำหนดความกว้าง
              height: 300, // กำหนดความสูง
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // 4 เดือนต่อแถว
                  crossAxisSpacing: 4.0,
                  mainAxisSpacing: 4.0,
                ),
                itemCount: 12, // 12 เดือน
                itemBuilder: (BuildContext context, int index) {
                  final month = index + 1;
                  final monthName = DateFormat.MMM().format(DateTime(picked.year, month));
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMonth = DateTime(picked.year, month);
                      });
                      Provider.of<ExpenseProvider>(context, listen: false).fetchExpenses(); // รีโหลดข้อมูล
                      Navigator.of(context).pop(); // ปิด dialog
                      Navigator.of(context).pop(); // ปิด date picker dialog แรก
                    },
                    child: Card(
                      color: _selectedMonth.year == picked.year && _selectedMonth.month == month
                          ? Theme.of(context).primaryColor
                          : Colors.grey[200],
                      child: Center(
                        child: Text(
                          monthName,
                          style: TextStyle(
                            color: _selectedMonth.year == picked.year && _selectedMonth.month == month
                                ? Colors.white
                                : Colors.black,
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
    // ใช้ Consumer เพื่อ rebuild เฉพาะส่วนที่ต้องการเมื่อข้อมูลเปลี่ยน
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expenses for ${DateFormat.yMMMM().format(_selectedMonth)}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectMonth(context),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              // นำทางไปหน้าเพิ่มค่าใช้จ่าย โดยส่งวันที่ที่เลือกไป
              Navigator.of(context).pushNamed(
                ExpenseDetailScreen.routeName,
                arguments: {'selectedDate': DateTime.now(), 'existingExpense': null},
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(), // แสดง AppDrawer
      body: Consumer<ExpenseProvider>(
        builder: (ctx, expenseProvider, child) {
          // กรองค่าใช้จ่ายตามเดือนที่เลือก
          final filteredExpenses = expenseProvider.expenses.where((expense) {
            return expense.date.year == _selectedMonth.year &&
                expense.date.month == _selectedMonth.month;
          }).toList();

          if (filteredExpenses.isEmpty) {
            return const Center(
              child: Text('No expenses recorded for this month.'),
            );
          }

          // คำนวณยอดรวมของเดือน
          final double totalMonthlyExpenses = filteredExpenses.fold(
              0.0, (sum, item) => sum + item.amount);

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
                    return Dismissible(
                      key: ValueKey(expense.id), // ใช้ ID ของค่าใช้จ่ายเป็น key
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
                      confirmDismiss: (direction) {
                        return showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text(
                              'Do you want to remove this expense?',
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop(false);
                                },
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop(true);
                                },
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        // ลบค่าใช้จ่ายจาก Provider
                        if (expense.id != null) {
                          await expenseProvider.deleteExpense(expense.id!);
                          ScaffoldMessenger.of(context).showSnackBar(
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
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: FittedBox(
                                child: Text(
                                  '${expense.amount.toStringAsFixed(0)}', // แสดงจำนวนเงิน (ไม่มีทศนิยม)
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
                              Text(
                                'Date: ${DateFormat.yMd().format(expense.date)}',
                              ),
                              if (expense.categoryName != null)
                                Text('Category: ${expense.categoryName}'),
                              if (expense.payerName != null)
                                Text('Payer: ${expense.payerName}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              // นำทางไปหน้าแก้ไขค่าใช้จ่าย
                              Navigator.of(context).pushNamed(
                                ExpenseDetailScreen.routeName,
                                arguments: {
                                  'selectedDate': expense.date, // ส่งวันที่เดิมไป
                                  'existingExpense': expense, // ส่ง object ค่าใช้จ่ายไปแก้ไข
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