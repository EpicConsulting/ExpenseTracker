import 'package:flutter/material.dart';
import '../screens/category_screen.dart'; // ตรวจสอบว่า import ถูกต้อง
import '../screens/report_screen.dart';   // ตรวจสอบว่า import ถูกต้อง
import '../screens/main_screen.dart';    // ตรวจสอบว่า import ถูกต้อง
import '../screens/payer_screen.dart';   // <--- เพิ่ม import นี้

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('Hello Friend!'),
            automaticallyImplyLeading: false, // ไม่ต้องมีปุ่มย้อนกลับใน AppBar ของ Drawer
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Expenses'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed(MainScreen.routeName); // กลับไปหน้าหลัก
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            onTap: () {
              Navigator.of(context).pushNamed(CategoryScreen.routeName);
            },
          ),
          const Divider(),
          ListTile( // <--- เพิ่มเมนู Payer ตรงนี้
            leading: const Icon(Icons.person),
            title: const Text('Payers'),
            onTap: () {
              Navigator.of(context).pushNamed(PayerScreen.routeName);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Reports'),
            onTap: () {
              Navigator.of(context).pushNamed(ReportScreen.routeName);
            },
          ),
        ],
      ),
    );
  }
}