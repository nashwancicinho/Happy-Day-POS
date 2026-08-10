import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cashier/cashier_screen.dart';
import '../settings/settings_provider.dart';
import '../tables/tables_screen.dart';

class HomeOperationScreen extends StatelessWidget {
  const HomeOperationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered CashBox Logo Image
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/cashbox_logo.png',
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.point_of_sale, size: 100, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 20),

          // Centered Welcome Title & Subtitle
          Text(
            isEng ? "Welcome to CASHBOX POS 👋" : "مرحباً بك في نظام CASHBOX POS 👋",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEng ? "Select operation mode to start taking orders or view tables" : "اختر نوع العملية للبدء بإدخال الطلبات أو متابعة الصالة والتقرير اليومي",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Main Operation Action Cards
          Row(
            children: [
              Expanded(
                child: _operationCard(
                  context,
                  title: isEng ? "Dine-In Hall (Tables)" : "صالة المطعم (الطاولات)",
                  subtitle: isEng ? "Manage table orders and local hall billing" : "متابعة وإدارة طلبات الطاولات والطلبات المحلية",
                  icon: Icons.table_restaurant,
                  color: Colors.blue,
                  page: const TablesScreen(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _operationCard(
                  context,
                  title: isEng ? "Takeaway / Quick POS" : "طلب سفري / كاشير سريع",
                  subtitle: isEng ? "Create direct takeaway or delivery order" : "إنشاء طلب سفري أو توصيل مباشر وبدء البيع",
                  icon: Icons.shopping_bag,
                  color: Colors.green,
                  page: const CashierScreen(initialOrderType: 'TAKEAWAY'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _operationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 38, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
