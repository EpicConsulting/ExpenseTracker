import 'package:flutter/material.dart';
import '../screens/category_screen.dart';
import '../screens/report_screen.dart';
import '../screens/main_screen.dart';
import '../screens/payer_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('Hello Friend!'),
            automaticallyImplyLeading: false,
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Expenses'),
            onTap: () {
              Navigator.of(context).pushReplacementNamed(MainScreen.routeName); // '/main'
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            onTap: () => Navigator.of(context).pushNamed(CategoryScreen.routeName),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Payers'),
            onTap: () => Navigator.of(context).pushNamed(PayerScreen.routeName),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Reports'),
            onTap: () => Navigator.of(context).pushNamed(ReportScreen.routeName),
          ),
        ],
      ),
    );
  }
}