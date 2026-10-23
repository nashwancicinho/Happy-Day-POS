import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/other_expense.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_provider.dart';
import 'treasury_provider.dart';

class OtherExpensesDialog extends StatefulWidget {
  final bool isDialog;
  const OtherExpensesDialog({super.key, this.isDialog = true});

  @override
  State<OtherExpensesDialog> createState() => _OtherExpensesDialogState();
}

class _OtherExpensesDialogState extends State<OtherExpensesDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'عام';
  bool _showAllHistory = false;

  final List<String> _categories = [
    'عام',
    'نثرية',
    'تشغيلي',
    'صيانة',
    'فواتير ومرافق',
    'إيجار',
    'ضيافة',
    'نقل وشحن',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TreasuryProvider>().loadActiveOtherExpenses();
      context.read<TreasuryProvider>().loadOtherExpenses();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final notes = _notesController.text.trim();
    final userName = context.read<AuthProvider>().currentUserName;

    final newExpense = OtherExpenseModel(
      title: title,
      amount: amount,
      category: _selectedCategory,
      notes: notes.isNotEmpty ? notes : null,
      createdBy: userName,
      createdAt: DateTime.now().toIso8601String(),
    );

    await context.read<TreasuryProvider>().addOtherExpense(newExpense);

    _titleController.clear();
    _amountController.clear();
    _notesController.clear();
    setState(() {
      _selectedCategory = 'عام';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة المصروف بنجاح 💸'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isEng = settingsProvider.isEnglish;
    final isDark = settingsProvider.isDarkMode;
    final currencySym = settingsProvider.currencySymbol;
    final treasuryProvider = context.watch<TreasuryProvider>();
    final expenses = _showAllHistory
        ? treasuryProvider.otherExpenses
        : treasuryProvider.activeOtherExpenses;
    final totalExpenses = _showAllHistory
        ? treasuryProvider.totalOtherExpenses
        : treasuryProvider.totalActiveOtherExpenses;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.transparent),
      ),
      child: Container(
        width: 850,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100,
                  child: Icon(Icons.receipt_long_outlined, color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade800, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEng ? 'Other Expenses & Outflows' : 'إدارة المصاريف والنثريات الأخرى 💸',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _showAllHistory
                            ? (isEng ? 'All recorded historical expenses' : 'جميع المصاريف السابقة والمسجلة بالخزينة')
                            : (isEng ? 'Operating & petty expenses for current shift' : 'تسجيل ومتابعة مصاريف الشيفت واليوم الحالي'),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Period Toggle Switch
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showAllHistory = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: !_showAllHistory ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isEng ? 'Current Shift' : 'اليوم الحالي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_showAllHistory ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _showAllHistory = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _showAllHistory ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isEng ? 'History' : 'السجل الكامل',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _showAllHistory ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF991B1B) : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _showAllHistory
                            ? (isEng ? 'Total All: ' : 'مجموع السجل: ')
                            : (isEng ? 'Total Today: ' : 'مجموع اليوم: '),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade200 : Colors.black87,
                        ),
                      ),
                      Text(
                        '${totalExpenses.toStringAsFixed(0)} $currencySym',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isDialog && Navigator.canPop(context)) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ],
            ),
            Divider(height: 24, color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),

            // Form to Add Expense
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? const Color(0xFF374151) : Colors.transparent),
              ),
              color: isDark ? const Color(0xFF242F3E) : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEng ? '➕ Add New Expense' : '➕ إضافة مصروف جديد',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Expense Title
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _titleController,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Expense Name / Description *' : 'اسم / بيان المصروف *',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : null),
                                hintText: isEng ? 'e.g. Electricity, Rent, Maintenance...' : 'مثال: كهرباء، صيانة، إيجار، ضيافة...',
                                hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return isEng ? 'Required' : 'مطلوب';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Amount
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Amount *' : 'المبلغ *',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : null),
                                suffixText: currencySym,
                                suffixStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return isEng ? 'Required' : 'مطلوب';
                                }
                                if (double.tryParse(val.trim()) == null) {
                                  return isEng ? 'Invalid number' : 'رقم غير صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 3. Category Dropdown
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                labelText: isEng ? 'Category' : 'الفئة / التصنيف',
                                labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : null),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Submit Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _submitExpense,
                            icon: const Icon(Icons.add_task),
                            label: Text(isEng ? 'Add Expense' : 'إضافة المصروف'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Expenses Table List
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade400),
                          const SizedBox(height: 10),
                          Text(
                            isEng ? 'No expenses registered yet' : 'لم يتم تسجيل أي مصاريف أخرى حتى الآن',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(
                          color: isDark ? const Color(0xFF374151) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF242F3E) : Colors.red.shade50),
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? '#' : '#', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Date & Time' : 'التاريخ والوقت', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Expense Name' : 'اسم المصروف', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Category' : 'الفئة', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Amount' : 'المبلغ', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'By User' : 'بواسطة', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Action' : 'إجراء', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)),
                            ],
                          ),
                          ...expenses.map((e) {
                            final dateStr = e.createdAt.length >= 16 ? e.createdAt.substring(0, 16).replaceAll('T', ' ') : e.createdAt;
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(10), child: Text('#${e.id}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.black87))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(dateStr, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.black87))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.category, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87))),
                                Padding(padding: const EdgeInsets.all(10), child: Text('${e.amount.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.createdBy ?? 'المدير', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.black87))),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                                          title: Text(isEng ? 'Confirm Delete' : 'تأكيد الحذف', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                          content: Text(isEng ? 'Are you sure you want to delete this expense record?' : 'هل أنت متأكد من حذف هذا المصروف؟', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEng ? 'Cancel' : 'إلغاء')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(isEng ? 'Delete' : 'حذف'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true && e.id != null) {
                                        await treasuryProvider.deleteOtherExpense(e.id!);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
            ),

            if (widget.isDialog && Navigator.canPop(context)) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF374151) : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(isEng ? 'Close' : 'إغلاق'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
