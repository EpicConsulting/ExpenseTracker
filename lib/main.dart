import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './screens/main_screen.dart';
import './screens/report_screen.dart';
import './screens/category_screen.dart';
import './screens/payer_screen.dart';
import './screens/manage_payer_screen.dart';
import './screens/payer_expenses_detail_screen.dart';
import './screens/expense_detail_screen.dart';
import './screens/lock_screen.dart'; // <--- เพิ่ม

import './providers/category_provider.dart';
import './providers/expense_provider.dart';
import './providers/payer_provider.dart';
import './providers/auth_provider.dart'; // <--- เพิ่ม

import './models/expense.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lock แอพเมื่อกลับมาจาก background (optional)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // lock เมื่อออก
      final auth = _authProvider;
      auth?.lock();
    }
  }

  AuthProvider? get _authProvider {
    try {
      return Provider.of<AuthProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => PayerProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()), // <--- เพิ่ม
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Expense Tracker',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
                secondary: Colors.amber,
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            // ถ้ายังไม่ปลดล็อค แสดง LockScreen
            home: auth.unlocked ? const MainScreen() : const LockScreen(),
            routes: {
              MainScreen.routeName: (ctx) => const MainScreen(),
              ReportScreen.routeName: (ctx) => const ReportScreen(),
              CategoryScreen.routeName: (ctx) => const CategoryScreen(),
              ExpenseDetailScreen.routeName: (ctx) {
                final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
                return ExpenseDetailScreen(
                  selectedDate: args?['selectedDate'] as DateTime? ?? DateTime.now(),
                  existingExpense: args?['existingExpense'] as Expense?,
                );
              },
              PayerScreen.routeName: (ctx) => const PayerScreen(),
              ManagePayerScreen.routeName: (ctx) => const ManagePayerScreen(),
              PayerExpensesDetailScreen.routeName: (ctx) =>
                  const PayerExpensesDetailScreen(),
            },
          );
        },
      ),
    );
  }
}