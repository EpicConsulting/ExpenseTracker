// lib/screens/payer_expenses_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/category.dart'; // <--- !!! สำคัญมาก: ตรวจสอบให้แน่ใจว่ามีและ Path ถูกต้อง !!!
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart'; // เพื่อดึงชื่อหมวดหมู่
import '../providers/payer_provider.dart'; // เพื่อดึงชื่อผู้จ่าย (ถ้าจำเป็น)
import './expense_detail_screen.dart'; // สำหรับการนำทางไปแก้ไขค่าใช้จ่าย

class PayerExpensesDetailScreen extends StatelessWidget {
  static const routeName = '/payer-expenses-detail';

  const PayerExpensesDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // รับ arguments ที่ส่งมาจาก MainScreen
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final DateTime selectedDay = args['selectedDay'] as DateTime;
    final int payerId = args['payerId'] as int;
    final String payerName = args['payerName'] as String;

    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context); // สำหรับดึงชื่อหมวดหมู่

    // กรองค่าใช้จ่ายสำหรับวันที่เลือกและผู้จ่ายที่เลือก
    final expensesForPayerOnDay = expenseProvider.expenses.where((exp) {
      return exp.date.year == selectedDay.year &&
          exp.date.month == selectedDay.month &&
          exp.date.day == selectedDay.day &&
          exp.payerId == payerId;
    }).toList();

    // คำนวณยอดรวมของ Payer สำหรับวันนี้
    final double totalPayerExpensesToday = expensesForPayerOnDay.fold(
        0.0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('${payerName}\'s Expenses on ${DateFormat('dd MMMM yyyy').format(selectedDay)}'),
      ),
      body: Column(
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
                      'Total for ${payerName}:',
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
              child: Text('No expenses recorded for this payer on this day.'),
            )
                : ListView.builder(
              itemCount: expensesForPayerOnDay.length,
              itemBuilder: (ctx, index) {
                final expense = expensesForPayerOnDay[index];
                // ดึงหมวดหมู่จาก provider หรือใช้ค่าเริ่มต้น
                final category = categoryProvider.categories.firstWhere(
                      (cat) => cat.id == expense.categoryId,
                  orElse: () => Category(id: -1, name: 'Unknown Category', color: Colors.grey.value),
                );

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(category.color ?? Colors.grey.value), // ใช้สีจากหมวดหมู่ หรือสีเทาถ้าเป็น null
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: FittedBox(
                          child: Text(
                            '${expense.amount.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    title: Text(expense.description ?? 'No Description'),
                    subtitle: Text(category.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          ExpenseDetailScreen.routeName,
                          arguments: {'selectedDate': expense.date, 'existingExpense': expense},
                        ).then((_) {
                          // หลังจากแก้ไข ให้กลับมาหน้าเดิมและโหลดข้อมูลใหม่
                          // เนื่องจากหน้านี้เป็น StatelessWidget จึงต้องให้ MainScreen จัดการการอัปเดต
                          // หรืออาจจะต้องใช้ Consumer/Provider.of(listen: true) ในหน้านี้ด้วย
                          // เพื่อให้หน้านี้ rebuild เมื่อข้อมูล ExpenseProvider เปลี่ยน
                        });
                      },
                    ),
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: const Text('Are you sure you want to delete this expense?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await Provider.of<ExpenseProvider>(context, listen: false).deleteExpense(expense.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense deleted!')),
                        );
                        // ไม่ต้อง pop หน้าจอ เพราะ MainScreen จะ rebuild เอง
                        // แต่ถ้าต้องการให้หน้านี้อัปเดตทันที ต้องใช้ Consumer ที่นี่
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