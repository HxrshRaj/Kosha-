import 'package:flutter/material.dart';

import '../csv_import/csv_import_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/transaction_list_screen.dart';

/// Bottom-nav shell. Uses IndexedStack so switching tabs preserves each
/// screen's scroll position and provider state instead of rebuilding it.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    TransactionListScreen(),
    DashboardScreen(),
    CsvImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file_outlined),
            label: 'Import',
          ),
        ],
      ),
    );
  }
}
