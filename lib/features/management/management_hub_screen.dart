import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/manager_auth_dialog.dart';
import '../auth/auth_provider.dart';
import '../cashier/widgets/refund_dialog.dart';
import '../categories/categories_provider.dart';
import '../orders/orders_provider.dart';
import '../payroll/payroll_provider.dart';
import '../products/products_provider.dart';
import '../purchases/purchases_provider.dart';
import '../raw_materials/raw_materials_provider.dart';
import '../settings/settings_provider.dart';

class ManagementHubScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const ManagementHubScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final authProvider = context.watch<AuthProvider>();
    final isCashier = !authProvider.isManager;

    final productsCount = context.watch<ProductsProvider>().products.length;
    final categoriesCount = context.watch<CategoriesProvider>().categories.length;
    final rawMaterialsCount = context.watch<RawMaterialsProvider>().rawMaterials.length;
    final purchasesCount = context.watch<PurchasesProvider>().purchases.length;
    final usersCount = context.watch<AuthProvider>().users.length;
    final employeesCount = context.watch<PayrollProvider>().employees.length;
    final todayOrdersCount = context.watch<OrdersProvider>().todayOrdersCount;

    final List<Map<String, dynamic>> managementSections = [
      {
        'index': 3,
        'title': isEng ? 'Products' : 'الأصناف',
        'subtitle': isEng ? 'Menu items, recipes & prices' : 'إدارة قائمة الطعام والأسعار والوصفات',
        'icon': Icons.fastfood_rounded,
        'color': Colors.orange.shade700,
        'bgColor': Colors.orange.shade50,
        'stat': isEng ? '$productsCount Products' : '$productsCount صنف',
        'permKey': 'perm_cashier_access_products',
      },
      {
        'index': 4,
        'title': isEng ? 'Categories' : 'التصنيفات',
        'subtitle': isEng ? 'Product groups & sections' : 'ترتيب وتصنيف الأقسام والمجموعات',
        'icon': Icons.category_rounded,
        'color': Colors.purple.shade700,
        'bgColor': Colors.purple.shade50,
        'stat': isEng ? '$categoriesCount Categories' : '$categoriesCount تصنيف',
        'permKey': 'perm_cashier_access_categories',
      },
      {
        'index': 5,
        'title': isEng ? 'Inventory' : 'المخزن',
        'subtitle': isEng ? 'Raw materials & stock levels' : 'مراقبة المواد الخام ومستويات المخزون',
        'icon': Icons.inventory_2_rounded,
        'color': Colors.blue.shade700,
        'bgColor': Colors.blue.shade50,
        'stat': isEng ? '$rawMaterialsCount Materials' : '$rawMaterialsCount مادة',
        'permKey': 'perm_cashier_access_inventory',
      },
      {
        'index': 6,
        'title': isEng ? 'Purchases & Suppliers' : 'المشتريات والموردين',
        'subtitle': isEng ? 'Supplier bills & stock entries' : 'فواتير الشراء وحسابات الموردين',
        'icon': Icons.shopping_bag_rounded,
        'color': Colors.teal.shade700,
        'bgColor': Colors.teal.shade50,
        'stat': isEng ? '$purchasesCount Invoices' : '$purchasesCount فاتورة شراء',
        'permKey': 'perm_cashier_access_purchases',
      },
      {
        'index': 8,
        'title': isEng ? 'Users & Permissions' : 'المستخدمون',
        'subtitle': isEng ? 'System users & cashier roles' : 'إدارة حسابات الكاشيرية والصلاحيات',
        'icon': Icons.people_alt_rounded,
        'color': Colors.indigo.shade700,
        'bgColor': Colors.indigo.shade50,
        'stat': isEng ? '$usersCount Accounts' : '$usersCount مستخدم',
        'permKey': 'perm_cashier_access_settings',
      },
      {
        'index': 10,
        'title': isEng ? 'Employee Payroll & Advances' : 'رواتب الموظفين والسُلف',
        'subtitle': isEng ? 'Salaries, deductions & loans' : 'مسير الرواتب والسلف والخصومات',
        'icon': Icons.payments_rounded,
        'color': Colors.red.shade700,
        'bgColor': Colors.red.shade50,
        'stat': isEng ? '$employeesCount Staff' : '$employeesCount موظف',
        'permKey': 'perm_cashier_access_settings',
      },
      {
        'index': 11,
        'title': isEng ? 'Reports & Analytics' : 'التقارير',
        'subtitle': isEng ? 'Sales summaries, profits & costs' : 'تقارير المبيعات والأرباح والمصاريف',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.green.shade700,
        'bgColor': Colors.green.shade50,
        'stat': isEng ? '$todayOrdersCount Orders Today' : '$todayOrdersCount طلب اليوم',
        'permKey': 'perm_cashier_access_reports',
      },
      {
        'index': -1,
        'isAction': true,
        'title': isEng ? 'Refund & Returns' : 'استرجاع الفواتير',
        'subtitle': isEng ? 'Search invoices & refund items' : 'البحث عن الفواتير واسترجاع المبالغ والمواد',
        'icon': Icons.assignment_return_rounded,
        'color': Colors.red.shade800,
        'bgColor': Colors.red.shade50,
        'stat': isEng ? 'Refund Center' : 'إدارة المرتجعات',
        'permKey': 'perm_cashier_access_settings',
        'action': (BuildContext ctx) {
          showDialog(
            context: ctx,
            builder: (_) => const RefundDialog(),
          );
        },
      },
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Banner (Compact & Sleek)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEng ? 'Administration & Operations Hub' : 'قسم الإدارة والتحكم العام',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isEng
                                  ? 'Unified control center for products, inventory, suppliers, staff, and financial reports'
                                  : 'لوحة موحدة لإدارة الأصناف، المخزون، الموردين، حسابات الموظفين، والتقارير المالية',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Section Title
                Row(
                  children: [
                    Icon(Icons.dashboard_customize_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isEng ? 'MANAGEMENT SECTIONS (8)' : 'أقسام الإدارة والعمليات (٨)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Responsive Grid of Management Cards (Compact 4 columns on desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 650 ? 3 : 2);
                    final childAspectRatio = crossAxisCount == 4 ? 1.55 : (crossAxisCount == 3 ? 1.85 : 1.6);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: managementSections.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, i) {
                        final item = managementSections[i];
                        final targetIndex = item['index'] as int;
                        final permKey = item['permKey'] as String?;
                        final isRestricted = isCashier && permKey != null && !authProvider.hasPermission(context, permKey);
                        final itemColor = item['color'] as Color;
                        final itemBgColor = item['bgColor'] as Color;

                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              if (isRestricted) {
                                final authorized = await ManagerAuthDialog.show(
                                  context,
                                  title: 'إذن المدير مطلوب 🔒',
                                  reason: 'الدخول إلى (${item['title']}) محصورة وتتطلب إذن المدير',
                                );
                                if (!authorized) return;
                              }
                              if (!context.mounted) return;
                              if (item['isAction'] == true) {
                                final action = item['action'] as Function(BuildContext);
                                action(context);
                              } else {
                                onNavigate(targetIndex);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: isDark ? itemColor.withValues(alpha: 0.2) : itemBgColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          item['icon'] as IconData,
                                          color: itemColor,
                                          size: 20,
                                        ),
                                      ),
                                      if (isRestricted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.orange.shade200),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, size: 10, color: Colors.orange),
                                              SizedBox(width: 3),
                                              Text(
                                                'إذن مدير',
                                                style: TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? itemColor.withValues(alpha: 0.2) : itemBgColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item['stat'] as String,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: itemColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        isEng ? 'Open' : 'دخول',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: itemColor,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(Icons.arrow_forward_rounded, size: 12, color: itemColor),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
