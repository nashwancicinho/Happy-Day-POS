import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final currencySym = settingsProvider.currencySymbol;
    final treasuryProvider = context.watch<TreasuryProvider>();
    final expenses = treasuryProvider.otherExpenses;
    final totalExpenses = treasuryProvider.totalOtherExpenses;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 850,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Icon(Icons.receipt_long_outlined, color: Colors.red.shade800, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEng ? 'Other Expenses & Outflows' : 'إدارة المصاريف والنثريات الأخرى 💸',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEng ? 'Record daily operating & petty expenses' : 'تسجيل المصاريف اليومية التشغيلية والنثريات والخزينة',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isEng ? 'Total Expenses: ' : 'مجموع المصاريف: ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${totalExpenses.toStringAsFixed(0)} $currencySym',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade900),
                      ),
                    ],
                  ),
                ),
                if (widget.isDialog && Navigator.canPop(context)) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ],
            ),
            const Divider(height: 24),

            // Form to Add Expense
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEng ? '➕ Add New Expense' : '➕ إضافة مصروف جديد',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                              decoration: InputDecoration(
                                labelText: isEng ? 'Expense Name / Description *' : 'اسم / بيان المصروف *',
                                hintText: isEng ? 'e.g. Electricity, Rent, Maintenance...' : 'مثال: كهرباء، صيانة، إيجار، ضيافة...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
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
                              decoration: InputDecoration(
                                labelText: isEng ? 'Amount *' : 'المبلغ *',
                                suffixText: currencySym,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
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
                              decoration: InputDecoration(
                                labelText: isEng ? 'Category' : 'الفئة / التصنيف',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c));
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
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Table(
                        border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.red.shade50),
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? '#' : '#', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Date & Time' : 'التاريخ والوقت', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Expense Name' : 'اسم المصروف', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Category' : 'الفئة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Amount' : 'المبلغ', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'By User' : 'بواسطة', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(10), child: Text(isEng ? 'Action' : 'إجراء', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            ],
                          ),
                          ...expenses.map((e) {
                            final dateStr = e.createdAt.length >= 16 ? e.createdAt.substring(0, 16).replaceAll('T', ' ') : e.createdAt;
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(10), child: Text('#${e.id}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(dateStr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.category, textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(10), child: Text('${e.amount.toStringAsFixed(0)} $currencySym', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900))),
                                Padding(padding: const EdgeInsets.all(10), child: Text(e.createdBy ?? 'المدير', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(isEng ? 'Confirm Delete' : 'تأكيد الحذف'),
                                          content: Text(isEng ? 'Are you sure you want to delete this expense record?' : 'هل أنت تأكد من حذف هذا المصروف؟'),
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
                    backgroundColor: Colors.grey.shade800,
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
