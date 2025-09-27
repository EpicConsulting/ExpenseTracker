import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './screens/main_screen.dart';
import './screens/report_screen.dart';
import './screens/category_screen.dart';
// import './screens/manage_expense_screen.dart'; // <--- ลบบรรทัดนี้ออก
import './screens/payer_screen.dart';
import './screens/manage_payer_screen.dart';
import './screens/payer_expenses_detail_screen.dart';
import './screens/expense_detail_screen.dart'; // <--- !!! ต้อง import ไฟล์นี้

import './providers/category_provider.dart';
import './providers/expense_provider.dart';
import './providers/payer_provider.dart';

import './models/expense.dart'; // <--- เพิ่ม import นี้ เพื่อให้รู้จัก Expense ใน routes

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => PayerProvider()),
      ],
      child: MaterialApp(
        title: 'Expense Tracker',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
            secondary: Colors.amber, // สีรองสำหรับเน้นบางจุด
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue, // สี AppBar
            foregroundColor: Colors.white, // สีไอคอนและตัวอักษรใน AppBar
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // สีพื้นหลังปุ่ม
              foregroundColor: Colors.white, // สีข้อความปุ่ม
            ),
          ),
        ),

        initialRoute: MainScreen.routeName, // กำหนดหน้าแรกโดยใช้ชื่อ Route
        routes: {
          MainScreen.routeName: (ctx) => const MainScreen(),
          ReportScreen.routeName: (ctx) => const ReportScreen(),
          CategoryScreen.routeName: (ctx) => const CategoryScreen(),
          // ManageExpenseScreen.routeName: (ctx) => const ManageExpenseScreen(), // <--- ลบบรรทัดนี้ออก
          // เพิ่ม ExpenseDetailScreen.routeName และจัดการ arguments ที่ส่งมา
          ExpenseDetailScreen.routeName: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
            return ExpenseDetailScreen(
              selectedDate: args?['selectedDate'] as DateTime? ?? DateTime.now(),
              existingExpense: args?['existingExpense'] as Expense?,
            );
          },
          PayerScreen.routeName: (ctx) => const PayerScreen(),
          ManagePayerScreen.routeName: (ctx) => const ManagePayerScreen(),
          PayerExpensesDetailScreen.routeName: (ctx) => const PayerExpensesDetailScreen(),
        },
      ),
    );
  }
}