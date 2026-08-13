import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../settings/settings_provider.dart';
import 'other_expenses_dialog.dart';

class OtherExpensesScreen extends StatelessWidget {
  const OtherExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Other Expenses & Outflows' : 'إدارة المصاريف والنثريات الأخرى 💸'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: OtherExpensesDialog(isDialog: false),
        ),
      ),
    );
  }
}
