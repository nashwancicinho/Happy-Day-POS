import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/print_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/employee.dart';
import '../../models/employee_advance.dart';
import '../../models/salary_payment.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_provider.dart';
import 'payroll_provider.dart';

class PayrollScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PayrollScreen({super.key, this.onBack});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _payoutFilter = 'ALL'; // 'ALL', 'MONTHLY', 'DAILY'
  final TextEditingController _payoutSearchController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  DateTime? _historySelectedDate;
  String _historyQuickDate = 'ALL'; // 'ALL', 'TODAY', 'MONTH'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _payoutSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final payrollProvider = context.watch<PayrollProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySym = settingsProvider.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,
        leading: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          label: Text(
            isEng ? 'Management' : 'لوحة الإدارة',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(isEng ? 'Employee Payroll & Salaries' : 'إدارة رواتب الموظفين والسُلف والمستحقات'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(icon: const Icon(Icons.badge), text: isEng ? 'Employees & Salaries' : 'الموظفون والرواتب'),
            Tab(icon: const Icon(Icons.account_balance_wallet), text: isEng ? 'Advances & Deductions' : 'السُلف والخصومات'),
            Tab(icon: const Icon(Icons.payments), text: isEng ? 'Salary Payouts' : 'صرف الرواتب المستحقة'),
            Tab(icon: const Icon(Icons.history), text: isEng ? 'Payout History' : 'سجل الرواتب المصروفة'),
          ],
        ),
      ),
      body: payrollProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(context, payrollProvider, isEng, currencySym),
                _buildAdvancesTab(context, payrollProvider, isEng, currencySym),
                _buildPayoutTab(context, payrollProvider, isEng, currencySym),
                _buildHistoryTab(context, payrollProvider, isEng, currencySym),
              ],
            ),
    );
  }

  // --- TAB 1: EMPLOYEES LIST ---
  Widget _buildEmployeesTab(BuildContext context, PayrollProvider provider, bool isEng, String currencySym) {
    final employees = provider.employees;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditEmployeeDialog(context, provider, isEng),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add),
        label: Text(isEng ? 'Add New Employee' : 'إضافة موظف جديد'),
      ),
      body: employees.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    isEng ? 'No employees registered yet.' : 'لا يوجد موظفين مسجلين حالياً في النظام.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditEmployeeDialog(context, provider, isEng),
                    icon: const Icon(Icons.add),
                    label: Text(isEng ? 'Add Employee' : 'إضافة موظف جديد'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                final salaryInfo = provider.calculateEmployeeCurrentMonthNetSalary(emp);
                final netSalary = salaryInfo['netSalary'] ?? 0.0;
                final totalAdvances = salaryInfo['totalAdvances'] ?? 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        emp.name.isNotEmpty ? emp.name.substring(0, 1) : '👤',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade200),
                          ),
                          child: Text(
                            emp.role,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: emp.isDaily
                                ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                                : (isDark ? Colors.teal.shade900.withValues(alpha: 0.3) : Colors.teal.shade50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: emp.isDaily
                                  ? (isDark ? Colors.amber.shade700 : Colors.amber.shade600)
                                  : (isDark ? Colors.teal.shade700 : Colors.teal.shade300),
                            ),
                          ),
                          child: Text(
                            emp.isDaily ? (isEng ? 'Daily ☀️' : 'عامل يومية ☀️') : (isEng ? 'Monthly 🗓️' : 'شهري 🗓️'),
                            style: TextStyle(
                              fontSize: 11,
                              color: emp.isDaily
                                  ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                                  : (isDark ? Colors.teal.shade300 : Colors.teal.shade900),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          emp.isDaily
                              ? (isEng
                                  ? 'Daily Wage: ${emp.baseSalary.toStringAsFixed(0)} $currencySym / day | Advances: ${totalAdvances.toStringAsFixed(0)} $currencySym'
                                  : 'أجر اليومية: ${emp.baseSalary.toStringAsFixed(0)} $currencySym / يوم | السُلف: ${totalAdvances.toStringAsFixed(0)} $currencySym')
                              : (isEng
                                  ? 'Base Salary: ${emp.baseSalary.toStringAsFixed(0)} $currencySym | Advances: ${totalAdvances.toStringAsFixed(0)} $currencySym'
                                  : 'الراتب الأساسي: ${emp.baseSalary.toStringAsFixed(0)} $currencySym | السُلف الحالية: ${totalAdvances.toStringAsFixed(0)} $currencySym'),
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                        if (emp.phone != null && emp.phone!.isNotEmpty)
                          Text('الهاتف: ${emp.phone}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              emp.isDaily
                                  ? (isEng ? 'Net Daily Wage:' : 'صافي اليومية:')
                                  : (isEng ? 'Net Payable:' : 'الصافي المستحق:'),
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey),
                            ),
                            Text(
                              '${netSalary.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.green.shade400 : Colors.green.shade800),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditEmployeeDialog(context, provider, isEng, employee: emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteEmployee(context, provider, emp, isEng),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // --- TAB 2: ADVANCES, BONUSES & DEDUCTIONS ---
  Widget _buildAdvancesTab(BuildContext context, PayrollProvider provider, bool isEng, String currencySym) {
    final advances = provider.advances;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdvanceDialog(context, provider, isEng),
        backgroundColor: Colors.orange.shade800,
        icon: const Icon(Icons.add_card),
        label: Text(isEng ? 'Record Advance / Bonus' : 'تسجيل سلفة / مكافأة / خصم'),
      ),
      body: advances.isEmpty
          ? Center(
              child: Text(
                isEng ? 'No advance or deduction transactions recorded.' : 'لا توجد سُلف أو خصومات مسجلة حتى الآن.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: advances.length,
              itemBuilder: (context, index) {
                final item = advances[index];

                Color typeColor = Colors.orange.shade800;
                String typeTitle = 'سلفة مالية';
                IconData typeIcon = Icons.money_off;

                if (item.type == 'BONUS') {
                  typeColor = Colors.green.shade700;
                  typeTitle = 'مكافأة تشجيعية';
                  typeIcon = Icons.card_giftcard;
                } else if (item.type == 'DEDUCTION') {
                  typeColor = Colors.red.shade700;
                  typeTitle = 'خصم / جزاء';
                  typeIcon = Icons.remove_circle_outline;
                }

                final isSettled = item.status == 'SETTLED';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 22),
                    ),
                    title: Row(
                      children: [
                        Text(item.employeeName ?? 'موظف', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(typeTitle, style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text('التاريخ: ${item.date} ${item.notes != null && item.notes!.isNotEmpty ? '• ${item.notes}' : ''}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.amount.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: typeColor),
                            ),
                            Text(
                              isSettled ? 'تمت التسوية ✅' : 'معلقة (مستحقة) ⏳',
                              style: TextStyle(fontSize: 11, color: isSettled ? Colors.green : Colors.orange.shade900, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (!isSettled)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () async {
                              await provider.deleteAdvance(item.id!);
                              if (context.mounted) {
                                TopNotification.showSuccess(context, 'تم حذف السجل بنجاح');
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // --- TAB 3: SALARY PAYOUT & SETTLEMENT ---
  Widget _buildPayoutTab(BuildContext context, PayrollProvider provider, bool isEng, String currencySym) {
    final employees = provider.employees;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (employees.isEmpty) {
      return Center(
        child: Text(
          isEng ? 'No employees available to process salary payout.' : 'يرجى إضافة موظفين أولاً للتمكن من صرف الرواتب.',
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    final monthlyCount = employees.where((e) => !e.isDaily).length;
    final dailyCount = employees.where((e) => e.isDaily).length;
    final payoutQuery = _payoutSearchController.text.trim().toLowerCase();

    final filteredEmployees = employees.where((e) {
      if (_payoutFilter == 'MONTHLY' && e.isDaily) return false;
      if (_payoutFilter == 'DAILY' && !e.isDaily) return false;
      if (payoutQuery.isNotEmpty) {
        final name = e.name.toLowerCase();
        final role = e.role.toLowerCase();
        if (!name.contains(payoutQuery) && !role.contains(payoutQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter & Search row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Text(
                isEng ? 'Filter:' : 'تصفية:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(isEng ? 'All (${employees.length})' : 'الكل (${employees.length})'),
                selected: _payoutFilter == 'ALL',
                onSelected: (selected) {
                  if (selected) setState(() => _payoutFilter = 'ALL');
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(isEng ? 'Monthly ($monthlyCount)' : 'شهري ($monthlyCount)'),
                selected: _payoutFilter == 'MONTHLY',
                selectedColor: Colors.blue.withValues(alpha: 0.2),
                onSelected: (selected) {
                  if (selected) setState(() => _payoutFilter = 'MONTHLY');
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(isEng ? 'Daily ($dailyCount)' : 'يومية ($dailyCount)'),
                selected: _payoutFilter == 'DAILY',
                selectedColor: Colors.amber.withValues(alpha: 0.25),
                onSelected: (selected) {
                  if (selected) setState(() => _payoutFilter = 'DAILY');
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _payoutSearchController,
                    decoration: InputDecoration(
                      hintText: isEng ? 'Search employee name...' : 'البحث باسم الموظف أو الدور...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _payoutSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _payoutSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredEmployees.isEmpty
              ? Center(
                  child: Text(
                    isEng ? 'No employees matching selected filter.' : 'لا يوجد عمال أو موظفين ضمن الفئة المحددة.',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = filteredEmployees[index];
                    final info = provider.calculateEmployeeCurrentMonthNetSalary(emp);
                    final netSalary = info['netSalary'] ?? 0.0;
                    final baseSalary = info['baseSalary'] ?? 0.0;
                    final advances = info['totalAdvances'] ?? 0.0;
                    final bonuses = info['totalBonuses'] ?? 0.0;
                    final deductions = info['totalDeductions'] ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: emp.isDaily
                                          ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade100)
                                          : AppColors.primary.withValues(alpha: 0.15),
                                      child: Icon(
                                        emp.isDaily ? Icons.wb_sunny_rounded : Icons.person,
                                        color: emp.isDaily ? (isDark ? Colors.amber.shade300 : Colors.orange.shade800) : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: emp.isDaily
                                                    ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                                                    : (isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: emp.isDaily
                                                      ? (isDark ? Colors.amber.shade700 : Colors.amber.shade600)
                                                      : (isDark ? Colors.blue.shade800 : Colors.blue.shade200),
                                                ),
                                              ),
                                              child: Text(
                                                emp.isDaily ? (isEng ? 'Daily ☀️' : 'عامل يومية ☀️') : (isEng ? 'Monthly 🗓️' : 'شهري 🗓️'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: emp.isDaily
                                                      ? (isDark ? Colors.amber.shade300 : Colors.orange.shade900)
                                                      : (isDark ? Colors.blue.shade200 : Colors.blue.shade800),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text('المسمى الوظيفي: ${emp.role}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: emp.isDaily ? Colors.amber.shade800 : Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _processEmployeePayout(context, provider, emp, info, isEng),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: Text(
                                    emp.isDaily
                                        ? (isEng ? 'Payout Wage ☀️' : 'صرف اليومية 💵')
                                        : (isEng ? 'Payout Salary 💵' : 'صرف وتسوية الراتب'),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _salaryMetricBox(
                                    emp.isDaily ? 'أجر اليومية' : 'الراتب الأساسي',
                                    '${baseSalary.toStringAsFixed(0)} $currencySym',
                                    emp.isDaily ? Colors.amber.shade900 : Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _salaryMetricBox('+ المكافآت', '${bonuses.toStringAsFixed(0)} $currencySym', Colors.green.shade800)),
                                const SizedBox(width: 8),
                                Expanded(child: _salaryMetricBox('- السُلف', '${advances.toStringAsFixed(0)} $currencySym', Colors.orange.shade800)),
                                const SizedBox(width: 8),
                                Expanded(child: _salaryMetricBox('- الخصومات', '${deductions.toStringAsFixed(0)} $currencySym', Colors.red.shade800)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: emp.isDaily
                                    ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                                    : (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: emp.isDaily
                                      ? (isDark ? Colors.amber.shade800 : Colors.amber.shade300)
                                      : (isDark ? Colors.green.shade800 : Colors.green.shade200),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    emp.isDaily
                                        ? (isEng ? 'Daily Wage Net (1 Day):' : 'صافي أجر اليومية الواحدة:')
                                        : (isEng ? 'Net Salary To Pay:' : 'صافي الراتب النقدية الواجب صرفه للموظف:'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: emp.isDaily
                                          ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                                          : (isDark ? Colors.green.shade300 : Colors.green.shade900),
                                    ),
                                  ),
                                  Text(
                                    '${netSalary.toStringAsFixed(0)} $currencySym',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: emp.isDaily
                                          ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                                          : (isDark ? Colors.green.shade300 : Colors.green.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _salaryMetricBox(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  // --- TAB 4: PAID SALARIES HISTORY ---
  Widget _buildHistoryTab(BuildContext context, PayrollProvider provider, bool isEng, String currencySym) {
    final payments = provider.payments;
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = _historySearchController.text.trim().toLowerCase();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final monthStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final selectedDateStr = _historySelectedDate?.toIso8601String().substring(0, 10);

    final filteredPayments = payments.where((p) {
      // 1. Text Search (Employee name, period, notes, date, paidBy)
      if (query.isNotEmpty) {
        final name = (p.employeeName ?? '').toLowerCase();
        final period = p.monthYear.toLowerCase();
        final notes = (p.notes ?? '').toLowerCase();
        final date = p.paymentDate.toLowerCase();
        final paidBy = (p.paidBy ?? '').toLowerCase();
        if (!name.contains(query) &&
            !period.contains(query) &&
            !notes.contains(query) &&
            !date.contains(query) &&
            !paidBy.contains(query)) {
          return false;
        }
      }

      // 2. Specific Date Filter
      if (_historySelectedDate != null && selectedDateStr != null) {
        if (!p.paymentDate.startsWith(selectedDateStr) && !p.createdAt.startsWith(selectedDateStr)) {
          return false;
        }
      }

      // 3. Quick Date Filter
      if (_historyQuickDate == 'TODAY') {
        if (!p.paymentDate.startsWith(todayStr) && !p.createdAt.startsWith(todayStr)) {
          return false;
        }
      } else if (_historyQuickDate == 'MONTH') {
        if (!p.paymentDate.startsWith(monthStr) && !p.createdAt.startsWith(monthStr) && !p.monthYear.contains(monthStr)) {
          return false;
        }
      }

      return true;
    }).toList();

    final totalPaid = filteredPayments.fold<double>(0.0, (sum, p) => sum + p.netSalary);
    final bool isFilterActive = query.isNotEmpty || _historySelectedDate != null || _historyQuickDate != 'ALL';

    return Column(
      children: [
        // Top Search & Date Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Search by name / period / notes / date
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _historySearchController,
                        decoration: InputDecoration(
                          hintText: isEng
                              ? 'Search by employee name or period...'
                              : 'البحث باسم الموظف أو الفترة أو التاريخ...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _historySearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _historySearchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Date Picker Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      backgroundColor: _historySelectedDate != null
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : null,
                      side: BorderSide(
                        color: _historySelectedDate != null ? AppColors.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                        width: _historySelectedDate != null ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _historySelectedDate != null ? AppColors.primary : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    label: Text(
                      _historySelectedDate != null
                          ? selectedDateStr!
                          : (isEng ? 'Pick Date' : 'تحديد تاريخ 📅'),
                      style: TextStyle(
                        fontWeight: _historySelectedDate != null ? FontWeight.bold : FontWeight.normal,
                        color: _historySelectedDate != null ? AppColors.primary : null,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _historySelectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() {
                          _historySelectedDate = picked;
                          _historyQuickDate = 'CUSTOM';
                        });
                      }
                    },
                  ),
                  if (_historySelectedDate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      tooltip: isEng ? 'Clear Date' : 'إلغاء فلتر التاريخ',
                      onPressed: () {
                        setState(() {
                          _historySelectedDate = null;
                          _historyQuickDate = 'ALL';
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Quick Date Chips + Summary Count/Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        isEng ? 'Quick Filter:' : 'فترة سريعة:',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(isEng ? 'All' : 'الكل'),
                        selected: _historyQuickDate == 'ALL' && _historySelectedDate == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _historyQuickDate = 'ALL';
                              _historySelectedDate = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(isEng ? 'Today ☀️' : 'اليوم ☀️'),
                        selected: _historyQuickDate == 'TODAY',
                        selectedColor: Colors.amber.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _historyQuickDate = 'TODAY';
                              _historySelectedDate = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(isEng ? 'This Month 🗓️' : 'هذا الشهر 🗓️'),
                        selected: _historyQuickDate == 'MONTH',
                        selectedColor: Colors.blue.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _historyQuickDate = 'MONTH';
                              _historySelectedDate = null;
                            });
                          }
                        },
                      ),
                      if (isFilterActive) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: Text(isEng ? 'Reset' : 'إعادة ضبط'),
                          onPressed: () {
                            setState(() {
                              _historySearchController.clear();
                              _historySelectedDate = null;
                              _historyQuickDate = 'ALL';
                            });
                          },
                        ),
                      ],
                    ],
                  ),

                  // Metrics summary (Total Count & Total Amount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF132A1C) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.green.shade800 : Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${isEng ? "Records:" : "عدد السندات:"} ${filteredPayments.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${isEng ? "Total:" : "المجموع:"} ${totalPaid.toStringAsFixed(0)} $currencySym',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Content
        Expanded(
          child: filteredPayments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        payments.isEmpty
                            ? (isEng ? 'No paid salary receipts in history.' : 'لا يوجد سجل رواتب مصروفة سابقاً.')
                            : (isEng
                                ? 'No salary records matching your search or date filter.'
                                : 'لا توجد سجلات رواتب تطابق الاسم أو التاريخ المحدد.'),
                        style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      if (isFilterActive) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _historySearchController.clear();
                              _historySelectedDate = null;
                              _historyQuickDate = 'ALL';
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(isEng ? 'Show All History' : 'عرض كافة السجلات'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPayments.length,
                  itemBuilder: (context, index) {
                    final p = filteredPayments[index];
                    final isDaily = p.monthYear.contains('يومية');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDaily ? Colors.amber.shade700 : Colors.teal,
                          child: Icon(
                            isDaily ? Icons.wb_sunny_rounded : Icons.receipt_long,
                            color: Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              p.employeeName ?? (isDaily ? "عامل" : "موظف"),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDaily
                                    ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                                    : (isDark ? Colors.teal.shade900.withValues(alpha: 0.3) : Colors.teal.shade50),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDaily
                                      ? (isDark ? Colors.amber.shade700 : Colors.amber.shade600)
                                      : (isDark ? Colors.teal.shade700 : Colors.teal.shade300),
                                ),
                              ),
                              child: Text(
                                p.monthYear,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDaily
                                      ? (isDark ? Colors.amber.shade300 : Colors.orange.shade900)
                                      : (isDark ? Colors.teal.shade200 : Colors.teal.shade800),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Text('تاريخ الصرف: ${p.paymentDate} • المنفذ: ${p.paidBy ?? "النظام"}'),
                            if (p.notes != null && p.notes!.isNotEmpty)
                              Text(
                                'ملاحظات: ${p.notes}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${p.netSalary.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.print, color: isDaily ? Colors.amber.shade800 : Colors.teal),
                              tooltip: isEng ? 'Print Receipt Slip' : 'طباعة سند الصرف',
                              onPressed: () async {
                                final success = await PrintService.printSalarySlip(payment: p, settings: settingsProvider);
                                if (context.mounted) {
                                  if (success) {
                                    TopNotification.showSuccess(context, '🖨️ تم طباعة سند صرف الراتب بنجاح!');
                                  } else {
                                    TopNotification.showInfo(context, '🖨️ تم إرسال سند الصرف لنظام الطباعة المباشرة');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- DIALOGS & ACTIONS ---
  void _showAddEditEmployeeDialog(BuildContext context, PayrollProvider provider, bool isEng, {EmployeeModel? employee}) {
    final isEdit = employee != null;
    final nameController = TextEditingController(text: employee?.name ?? '');
    final roleController = TextEditingController(text: employee?.role ?? 'موظف');
    final phoneController = TextEditingController(text: employee?.phone ?? '');
    final salaryController = TextEditingController(text: employee != null ? employee.baseSalary.toStringAsFixed(0) : '0');
    final notesController = TextEditingController(text: employee?.notes ?? '');
    String selectedSalaryType = employee?.salaryType ?? 'MONTHLY';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isDaily = selectedSalaryType == 'DAILY';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(isEdit ? Icons.edit : Icons.person_add, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(isEdit ? (isEng ? 'Edit Employee Data' : 'تعديل بيانات الموظف') : (isEng ? 'Add New Employee' : 'إضافة موظف جديد')),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم الموظف الثلاثي *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['موظف', 'كاشير', 'شيف', 'صالة', 'مدير', 'عامل'].contains(roleController.text) ? roleController.text : 'موظف',
                      decoration: const InputDecoration(labelText: 'المسمى الوظيفي / الدور', border: OutlineInputBorder()),
                      items: ['موظف', 'كاشير', 'شيف', 'صالة', 'مدير', 'عامل'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) roleController.text = val;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Salary Type Selector: Monthly vs Daily
                    Text(
                      isEng ? 'Employment & Wage System: *' : 'نظام العمل واحتساب الأجر: *',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                selectedSalaryType = 'MONTHLY';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !isDaily
                                    ? (isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !isDaily ? Colors.blue : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  width: !isDaily ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month, size: 18, color: !isDaily ? Colors.blue : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEng ? 'Monthly Salary 🗓️' : 'راتب شهري 🗓️',
                                    style: TextStyle(
                                      fontWeight: !isDaily ? FontWeight.bold : FontWeight.normal,
                                      color: !isDaily ? (isDark ? Colors.blue.shade200 : Colors.blue.shade800) : Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setDialogState(() {
                                selectedSalaryType = 'DAILY';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDaily
                                    ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.4) : Colors.amber.shade50)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDaily ? Colors.amber.shade700 : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  width: isDaily ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wb_sunny_rounded, size: 18, color: isDaily ? Colors.amber.shade700 : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEng ? 'Daily Worker ☀️' : 'عامل يومي (يومية) ☀️',
                                    style: TextStyle(
                                      fontWeight: isDaily ? FontWeight.bold : FontWeight.normal,
                                      color: isDaily ? (isDark ? Colors.amber.shade200 : Colors.orange.shade900) : Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    TextField(
                      controller: salaryController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isDaily
                            ? (isEng ? 'Daily Wage (Per Day) *' : 'أجر اليومية (لليوم الواحد) *')
                            : (isEng ? 'Monthly Base Salary *' : 'الراتب الشهري الأساسي *'),
                        hintText: isDaily ? 'مثال: 25000' : 'مثال: 600000',
                        helperText: isDaily
                            ? 'يتم احتساب الراتب عند الصرف بناءً على عدد الأيام التي عمل بها'
                            : 'الراتب الثابت المستحق شهرياً للموظف',
                        prefixIcon: Icon(isDaily ? Icons.wb_sunny_outlined : Icons.account_balance_wallet_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'ملاحظات إضافية', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEng ? 'Cancel' : 'إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    TopNotification.showWarning(context, 'يرجى كتابة اسم الموظف');
                    return;
                  }
                  final salaryVal = double.tryParse(salaryController.text.trim()) ?? 0.0;

                  final emp = EmployeeModel(
                    id: employee?.id,
                    name: nameController.text.trim(),
                    role: roleController.text.trim(),
                    phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                    baseSalary: salaryVal,
                    salaryType: selectedSalaryType,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );

                  if (isEdit) {
                    await provider.updateEmployee(emp);
                  } else {
                    await provider.addEmployee(emp);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    TopNotification.showSuccess(context, isEdit ? 'تم تحديث بيانات الموظف' : 'تم إضافة الموظف بنجاح');
                  }
                },
                child: Text(isEdit ? (isEng ? 'Save Changes' : 'حفظ التعديلات') : (isEng ? 'Add Employee' : 'إضافة الموظف')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteEmployee(BuildContext context, PayrollProvider provider, EmployeeModel emp, bool isEng) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEng ? 'Confirm Delete' : 'تأكيد حذف الموظف'),
        content: Text(isEng ? 'Are you sure you want to delete ${emp.name}?' : 'هل أنت تأكد من رغبتك في حذف الموظف [${emp.name}]؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEng ? 'Cancel' : 'إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await provider.deleteEmployee(emp.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                TopNotification.showSuccess(context, 'تم حذف الموظف بنجاح');
              }
            },
            child: Text(isEng ? 'Delete' : 'حذف'),
          ),
        ],
      ),
    );
  }

  void _showAddAdvanceDialog(BuildContext context, PayrollProvider provider, bool isEng) {
    int? selectedEmployeeId = provider.employees.isNotEmpty ? provider.employees.first.id : null;
    String selectedType = 'ADVANCE';
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_card, color: Colors.orange),
              const SizedBox(width: 10),
              Text(isEng ? 'Record Advance / Deduction' : 'تسجيل سلفة / مكافأة / خصم'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedEmployeeId,
                  decoration: const InputDecoration(labelText: 'اختر الموظف *', border: OutlineInputBorder()),
                  items: provider.employees.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'))).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedEmployeeId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'نوع المعاملة *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'ADVANCE', child: Text('سلفة مالية على الراتب (-)')),
                    DropdownMenuItem(value: 'BONUS', child: Text('مكافأة / إضافي (+)')),
                    DropdownMenuItem(value: 'DEDUCTION', child: Text('خصم / جزاء (-)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'السبب / ملاحظات', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEng ? 'Cancel' : 'إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedEmployeeId == null) {
                  TopNotification.showWarning(context, 'يرجى اختيار الموظف');
                  return;
                }
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) {
                  TopNotification.showWarning(context, 'يرجى إدخال مبلغ صحيح');
                  return;
                }

                final nowStr = DateTime.now().toIso8601String();

                final adv = EmployeeAdvanceModel(
                  employeeId: selectedEmployeeId!,
                  type: selectedType,
                  amount: amount,
                  date: nowStr.substring(0, 10),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  status: 'PENDING',
                  createdAt: nowStr,
                );

                await provider.addAdvance(adv);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  TopNotification.showSuccess(context, 'تم تسجيل المعاملة بنجاح');
                }
              },
              child: Text(isEng ? 'Save Record' : 'تسجيل وتأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  void _processEmployeePayout(
    BuildContext context,
    PayrollProvider provider,
    EmployeeModel employee,
    Map<String, double> info,
    bool isEng,
  ) {
    final baseSalary = info['baseSalary'] ?? 0.0;
    final advances = info['totalAdvances'] ?? 0.0;
    final bonuses = info['totalBonuses'] ?? 0.0;
    final deductions = info['totalDeductions'] ?? 0.0;

    int daysWorked = 1;
    final daysController = TextEditingController(text: '1');
    final dailyRate = employee.baseSalary;
    double currentBaseSalary = employee.isDaily ? (dailyRate * daysWorked) : baseSalary;
    double originalNetSalary = (currentBaseSalary + bonuses - advances - deductions).clamp(0.0, double.infinity);

    final currentMonthStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final notesController = TextEditingController();
    final customDeductionController = TextEditingController();
    final deductionReasonController = TextEditingController();
    final paidAmountController = TextEditingController(text: originalNetSalary.toStringAsFixed(0));
    final currentUsername = context.read<AuthProvider>().currentUserName;
    final settingsProvider = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void recalculateFromDays() {
              currentBaseSalary = dailyRate * daysWorked;
              final currentSubtotal = currentBaseSalary + bonuses - advances - deductions;
              final ded = double.tryParse(customDeductionController.text.trim()) ?? 0.0;
              final newNet = (currentSubtotal - ded).clamp(0.0, double.infinity);
              paidAmountController.text = newNet.toStringAsFixed(0);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(employee.isDaily ? Icons.wb_sunny_rounded : Icons.payments, color: employee.isDaily ? Colors.amber.shade700 : Colors.green, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    employee.isDaily
                        ? (isEng ? 'Confirm Daily Wage Payout' : 'تأكيد صرف اليومية والتصفية')
                        : (isEng ? 'Confirm Salary Payout' : 'تأكيد صرف الراتب والتصفية'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${employee.isDaily ? "العامل" : "الموظف"}: ${employee.name} (${employee.role})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employee.isDaily
                            ? 'أجر يومي • تاريخ اليوم: ${DateTime.now().toIso8601String().substring(0, 10)}'
                            : 'عن شهر / سنة: $currentMonthStr',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const Divider(height: 20),

                      // Days worked selector for daily workers
                      if (employee.isDaily) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2415) : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.amber.shade800 : Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.date_range, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEng ? 'Days worked:' : 'عدد أيام العمل المستحقة:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: daysWorked > 1
                                        ? () {
                                            daysWorked--;
                                            daysController.text = daysWorked.toString();
                                            recalculateFromDays();
                                            setDialogState(() {});
                                          }
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: TextField(
                                      controller: daysController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        final parsed = int.tryParse(val.trim()) ?? 1;
                                        daysWorked = parsed > 0 ? parsed : 1;
                                        recalculateFromDays();
                                        setDialogState(() {});
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.green),
                                    onPressed: () {
                                      daysWorked++;
                                      daysController.text = daysWorked.toString();
                                      recalculateFromDays();
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            employee.isDaily
                                ? 'أجر الأيام المستحقة ($daysWorked × ${dailyRate.toStringAsFixed(0)} ${settingsProvider.currencySymbol}):'
                                : 'الراتب الشهري الأساسي:',
                          ),
                          Text(
                            '${currentBaseSalary.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (bonuses > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('+ المكافآت التشجيعية:'),
                            Text(
                              '+${bonuses.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                              style: TextStyle(color: isDark ? Colors.green.shade300 : Colors.green.shade700, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      if (advances > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('- مجموع السُلف المسحوبة:'),
                            Text(
                              '-${advances.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                              style: TextStyle(color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      if (deductions > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('- الخصومات السابقة:'),
                            Text(
                              '-${deductions.toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                              style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المستحق الأصلي قبل الخصم الجديد:', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                          Text(
                            '${(currentBaseSalary + bonuses - advances - deductions).clamp(0.0, double.infinity).toStringAsFixed(0)} ${settingsProvider.currencySymbol}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                          ),
                        ],
                      ),

                      const Divider(height: 22),

                      // Deduction Section (Absence / Penalty / Other)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A1C24) : Colors.red.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.red.shade900 : Colors.red.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.remove_circle_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade800, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  employee.isDaily
                                      ? 'خصم من اليومية (غياب، تأخير، أو جزاءات):'
                                      : 'خصم راتب (غياب، تأخير، أو جزاءات):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.red.shade300 : Colors.red.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: customDeductionController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'مبلغ الخصم (${settingsProvider.currencySymbol})',
                                      hintText: '0',
                                      prefixIcon: const Icon(Icons.money_off, size: 20),
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (val) {
                                      final ded = double.tryParse(val.trim()) ?? 0.0;
                                      final currentSubtotal = currentBaseSalary + bonuses - advances - deductions;
                                      final newNet = (currentSubtotal - ded).clamp(0.0, double.infinity);
                                      paidAmountController.text = newNet.toStringAsFixed(0);
                                      setDialogState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    controller: deductionReasonController,
                                    decoration: InputDecoration(
                                      labelText: 'سبب الخصم (اختياري)',
                                      hintText: employee.isDaily ? 'مثال: تأخير، جزاء...' : 'مثال: غياب يومين، تأخير...',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Final Net Paid Amount (Editable Directly)
                      TextField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                        ),
                        decoration: InputDecoration(
                          labelText: employee.isDaily
                              ? 'المبلغ الفعلي المدفوع نقدياً للعامل 💵'
                              : 'المبلغ الفعلي المدفوع نقدياً للموظف 💵',
                          prefixIcon: const Icon(Icons.payments, color: Colors.green),
                          suffixText: settingsProvider.currencySymbol,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.green.shade700 : Colors.green.shade400, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.green, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF132A1C) : Colors.green.shade50,
                        ),
                        onChanged: (val) {
                          final paid = double.tryParse(val.trim()) ?? 0.0;
                          final currentSubtotal = currentBaseSalary + bonuses - advances - deductions;
                          final diff = (currentSubtotal - paid);
                          if (diff > 0) {
                            customDeductionController.text = diff.toStringAsFixed(0);
                          } else {
                            customDeductionController.text = '0';
                          }
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      // General Notes
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات الصرف العامة (اختياري)',
                          hintText: employee.isDaily
                              ? 'أي ملاحظات إضافية بخصوص تسليم اليومية...'
                              : 'أي ملاحظات إضافية بخصوص تسليم الراتب...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: employee.isDaily ? Colors.amber.shade800 : Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final actualPaid = double.tryParse(paidAmountController.text.trim()) ?? -1.0;
                    if (actualPaid < 0) {
                      TopNotification.showWarning(context, 'يرجى إدخال مبلغ صحيح للمبلغ المدفوع نقدياً');
                      return;
                    }

                    final extraDeduction = double.tryParse(customDeductionController.text.trim()) ?? 0.0;
                    final deductionReason = deductionReasonController.text.trim();

                    final pendingList = provider.getPendingAdvancesForEmployee(employee.id!);
                    final pendingIds = pendingList.map((a) => a.id!).toList();
                    final nowStr = DateTime.now().toIso8601String();

                    // If an extra deduction was entered (e.g. absence), record it as a settled deduction
                    if (extraDeduction > 0) {
                      final reasonText = deductionReason.isNotEmpty
                          ? deductionReason
                          : (employee.isDaily ? 'خصم من اليومية' : 'خصم راتب (غياب/تسوية شهري)');
                      final deductionAdv = EmployeeAdvanceModel(
                        employeeId: employee.id!,
                        employeeName: employee.name,
                        type: 'DEDUCTION',
                        amount: extraDeduction,
                        date: nowStr.substring(0, 10),
                        notes: reasonText,
                        status: 'SETTLED',
                        createdAt: nowStr,
                      );
                      await provider.addAdvance(deductionAdv);
                    }

                    // Combined notes
                    String finalNotes = notesController.text.trim();
                    if (employee.isDaily) {
                      final daysNote = 'أجر $daysWorked ${daysWorked == 1 ? "يوم" : "أيام"} (${dailyRate.toStringAsFixed(0)} ${settingsProvider.currencySymbol} / يوم)';
                      finalNotes = finalNotes.isEmpty ? daysNote : '$daysNote | $finalNotes';
                    }
                    if (extraDeduction > 0) {
                      final dedNote = 'خصم: ${extraDeduction.toStringAsFixed(0)} ${settingsProvider.currencySymbol}${deductionReason.isNotEmpty ? " ($deductionReason)" : ""}';
                      if (finalNotes.isNotEmpty) {
                        finalNotes = '$finalNotes | $dedNote';
                      } else {
                        finalNotes = dedNote;
                      }
                    }

                    final totalCombinedDeductions = deductions + extraDeduction;

                    final periodStr = employee.isDaily
                        ? (daysWorked > 1
                            ? 'يومية ${DateTime.now().toIso8601String().substring(0, 10)} ($daysWorked أيام)'
                            : 'يومية ${DateTime.now().toIso8601String().substring(0, 10)}')
                        : currentMonthStr;

                    final paymentRecord = SalaryPaymentModel(
                      employeeId: employee.id!,
                      employeeName: employee.name,
                      monthYear: periodStr,
                      baseSalary: currentBaseSalary,
                      totalAdvances: advances,
                      totalBonuses: bonuses,
                      totalDeductions: totalCombinedDeductions,
                      netSalary: actualPaid,
                      paymentDate: nowStr.substring(0, 10),
                      paidBy: currentUsername,
                      notes: finalNotes.isEmpty ? null : finalNotes,
                      createdAt: nowStr,
                    );

                    await provider.processSalaryPayment(
                      payment: paymentRecord,
                      pendingAdvanceIdsToSettle: pendingIds,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);

                    if (context.mounted) {
                      TopNotification.showSuccess(
                        context,
                        employee.isDaily
                            ? '🔒 تم صرف يومية (${employee.name}) بمبلغ (${actualPaid.toStringAsFixed(0)} ${settingsProvider.currencySymbol}) بنجاح! ☀️'
                            : '🔒 تم صرف راتب (${employee.name}) بمبلغ (${actualPaid.toStringAsFixed(0)} ${settingsProvider.currencySymbol}) وتصفية المستحقات بنجاح! 🎉',
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    employee.isDaily
                        ? (isEng ? 'Confirm Wage Payout 💵' : 'تأكيد صرف اليومية والتصفية 💵')
                        : (isEng ? 'Confirm Salary Payout' : 'تأكيد صرف الراتب والتصفية 💵'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
