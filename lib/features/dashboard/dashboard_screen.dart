import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HAPPY DAY POS"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (index) {},
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text("الرئيسية"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_cart),
                label: Text("الكاشير"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category),
                label: Text("التصنيفات"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fastfood),
                label: Text("الأصناف"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2),
                label: Text("المخزن"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.table_restaurant),
                label: Text("الطاولات"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text("المستخدمون"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.payments),
                label: Text("رواتب الموظفين والسُلف"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                label: Text("التقارير"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text("الإعدادات"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lock_clock),
                label: Text("إغلاق اليوم"),
              ),
            ],
          ),

          const VerticalDivider(width: 1),

          const Expanded(
            child: Center(
              child: Text(
                "مرحبًا بك في HAPPY DAY POS",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
