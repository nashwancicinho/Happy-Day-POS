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
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        title: Text(isEng ? 'Employee Payroll & Salaries' : 'إدارة رواتب الموظفين والسُلف والمستحقات'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            emp.role,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          isEng
                              ? 'Base Salary: ${emp.baseSalary.toStringAsFixed(0)} $currencySym | Advances: ${totalAdvances.toStringAsFixed(0)} $currencySym'
                              : 'الراتب الأساسي: ${emp.baseSalary.toStringAsFixed(0)} $currencySym | السُلف الحالية: ${totalAdvances.toStringAsFixed(0)} $currencySym',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        if (emp.phone != null && emp.phone!.isNotEmpty)
                          Text('الهاتف: ${emp.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(isEng ? 'Net Payable:' : 'الصافي المستحق:', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              '${netSalary.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade800),
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

    return employees.isEmpty
        ? Center(
            child: Text(
              isEng ? 'No employees available to process salary payout.' : 'يرجى إضافة موظفين أولاً للتمكن من صرف الرواتب.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final emp = employees[index];
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
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: Icon(Icons.person, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('المسمى الوظيفي: ${emp.role}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _processEmployeePayout(context, provider, emp, info, isEng),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(isEng ? 'Payout Salary 💵' : 'صرف وتسوية الراتب'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(child: _salaryMetricBox('الراتب الأساسي', '${baseSalary.toStringAsFixed(0)} $currencySym', Colors.blue.shade800)),
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEng ? 'Net Salary To Pay:' : 'صافي الراتب النقدية الواجب صرفه للموظف:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade900),
                            ),
                            Text(
                              '${netSalary.toStringAsFixed(0)} $currencySym',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

    return payments.isEmpty
        ? Center(
            child: Text(
              isEng ? 'No paid salary receipts in history.' : 'لا يوجد سجل رواتب مصروفة سابقاً.',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.receipt_long, color: Colors.white),
                  ),
                  title: Text(
                    '${p.employeeName ?? "موظف"} (${p.monthYear})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text('تاريخ الصرف: ${p.paymentDate} • المنفذ: ${p.paidBy ?? "النظام"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${p.netSalary.toStringAsFixed(0)} $currencySym',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.teal),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.person_add, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(isEdit ? (isEng ? 'Edit Employee Data' : 'تعديل بيانات الموظف') : (isEng ? 'Add New Employee' : 'إضافة موظف جديد')),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الراتب الشهري الأساسي *', border: OutlineInputBorder()),
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
    final netSalary = info['netSalary'] ?? 0.0;
    final baseSalary = info['baseSalary'] ?? 0.0;
    final advances = info['totalAdvances'] ?? 0.0;
    final bonuses = info['totalBonuses'] ?? 0.0;
    final deductions = info['totalDeductions'] ?? 0.0;

    final currentMonthStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final notesController = TextEditingController();
    final currentUsername = context.read<AuthProvider>().currentUserName;
    final settingsProvider = context.read<SettingsProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.payments, color: Colors.green),
            const SizedBox(width: 10),
            Text(isEng ? 'Confirm Salary Payout' : 'تأكيد صرف الراتب والتصفية'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الموظف: ${employee.name} (${employee.role})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('عن شهر / سنة: $currentMonthStr', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الراتب الشهري الأساسي:'),
                  Text('${baseSalary.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (bonuses > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('+ المكافآت التشجيعية:'),
                    Text('+${bonuses.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              if (advances > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('- مجموع السُلف المسحوبة:'),
                    Text('-${advances.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              if (deductions > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('- مجموع الخصومات:'),
                    Text('-${deductions.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي المبلغ المدفوع نقدياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${netSalary.toStringAsFixed(0)} ${settingsProvider.currencySymbol}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات الصرف', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEng ? 'Cancel' : 'إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              final pendingList = provider.getPendingAdvancesForEmployee(employee.id!);
              final pendingIds = pendingList.map((a) => a.id!).toList();

              final nowStr = DateTime.now().toIso8601String();

              final paymentRecord = SalaryPaymentModel(
                employeeId: employee.id!,
                employeeName: employee.name,
                monthYear: currentMonthStr,
                baseSalary: baseSalary,
                totalAdvances: advances,
                totalBonuses: bonuses,
                totalDeductions: deductions,
                netSalary: netSalary,
                paymentDate: nowStr.substring(0, 10),
                paidBy: currentUsername,
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                createdAt: nowStr,
              );

              await provider.processSalaryPayment(
                payment: paymentRecord,
                pendingAdvanceIdsToSettle: pendingIds,
              );

              if (ctx.mounted) Navigator.pop(ctx);

              if (context.mounted) {
                TopNotification.showSuccess(context, '🔒 تم تسجيل صرف الراتب وتصفية السُلف بنجاح! 🎉');
                // Automatically prompt/print receipt slip
                await PrintService.printSalarySlip(payment: paymentRecord, settings: settingsProvider);
              }
            },
            icon: const Icon(Icons.print),
            label: Text(isEng ? 'Confirm & Print Slip' : 'تأكيد الصرف وطباعة السند'),
          ),
        ],
      ),
    );
  }
}
