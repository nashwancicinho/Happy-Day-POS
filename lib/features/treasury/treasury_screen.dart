import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/top_notification.dart';
import '../../models/treasury_transaction.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_provider.dart';
import 'treasury_provider.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<TreasuryProvider>().loadActiveTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final treasuryProvider = context.watch<TreasuryProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isEng = settingsProvider.isEnglish;
    final currencySym = settingsProvider.currencySymbol;

    final activeIn = treasuryProvider.activeCashIn;
    final activeOut = treasuryProvider.activeCashOut;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 26),
            const SizedBox(width: 10),
            Text(
              isEng ? 'Treasury & Safe' : 'إدارة الخزينة والسيولة النقدية',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isEng ? 'Refresh Data' : 'تحديث البيانات',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Action Buttons: Deposit (+) and Withdraw (-)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showTransactionDialog(context, isDeposit: true),
                            icon: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 26),
                            label: Text(
                              isEng ? '+ Deposit Cash In' : '+ إدخال مبلغ في الخزينة',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showTransactionDialog(context, isDeposit: false),
                            icon: const Icon(Icons.remove_circle_rounded, color: Colors.white, size: 26),
                            label: Text(
                              isEng ? '- Withdraw Cash Out' : '- إخراج مبلغ من الخزينة',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Only Two Metric Cards: Cash In (Green) & Cash Out (Red)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 600;

                    final inCard = Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isEng ? 'Cash In Amount (+)' : 'المبلغ الداخل (+)',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 28),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${activeIn.toStringAsFixed(0)} $currencySym',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isEng ? 'Total cash deposited in current day' : 'إجمالي المبالغ الداخلة المودعة بالخزينة لليوم',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );

                    final outCard = Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 1.5),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isEng ? 'Cash Out Amount (-)' : 'المبلغ الخارج (-)',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFEF4444), size: 28),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${activeOut.toStringAsFixed(0)} $currencySym',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isEng ? 'Total cash withdrawn from current day' : 'إجمالي المبالغ المسحوبة والمصروفة من الخزينة لليوم',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isSmallScreen) {
                      return Column(
                        children: [
                          inCard,
                          const SizedBox(height: 16),
                          outCard,
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: inCard),
                          const SizedBox(width: 20),
                          Expanded(child: outCard),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, {required bool isDeposit}) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final currencySym = context.read<SettingsProvider>().currencySymbol;
    final currentUser = context.read<AuthProvider>().currentUserName;

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    void appendDigit(String digit) {
      final current = amountController.text.trim();
      if (digit == '0' || digit == '00' || digit == '000') {
        if (current.isEmpty || current == '0') return;
      }
      if (digit == '.') {
        if (current.contains('.')) return;
        if (current.isEmpty) {
          amountController.text = '0.';
          amountController.selection = TextSelection.collapsed(offset: amountController.text.length);
          return;
        }
      }
      if (current == '0' && digit != '.') {
        amountController.text = digit;
      } else {
        amountController.text = '$current$digit';
      }
      amountController.selection = TextSelection.collapsed(offset: amountController.text.length);
    }

    void backspace() {
      final current = amountController.text.trim();
      if (current.isNotEmpty) {
        amountController.text = current.substring(0, current.length - 1);
        amountController.selection = TextSelection.collapsed(offset: amountController.text.length);
      }
    }

    void clearAll() {
      amountController.text = '';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget numBtn(
            String label, {
            VoidCallback? onTap,
            Color? bg,
            Color? borderCol,
            Color? fg,
            IconData? icon,
            double fontSize = 20,
          }) {
            return Material(
              color: bg ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol ?? Colors.grey.shade300, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: icon != null
                      ? Icon(icon, color: fg ?? Colors.black87, size: 22)
                      : Text(
                          label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: fg ?? Colors.black87,
                          ),
                        ),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isDeposit
                      ? (isEng ? 'Deposit Cash in Safe' : 'إدخال مبلغ في الخزينة (+)')
                      : (isEng ? 'Withdraw Cash from Safe' : 'إخراج مبلغ من الخزينة (-)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Amount Display Input (NO dollar icon!)
                      Text(
                        isEng ? 'Amount ($currencySym):' : 'المبلغ المراد ${isDeposit ? "إدخاله" : "إخراجه"} ($currencySym):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          letterSpacing: 1.0,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          suffixText: currencySym,
                          suffixStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          filled: true,
                          fillColor: isDeposit ? Colors.green.shade50.withValues(alpha: 0.35) : Colors.red.shade50.withValues(alpha: 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDeposit ? Colors.green.shade300 : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDeposit ? Colors.green.shade300 : Colors.red.shade300,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              width: 2.0,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return isEng ? 'Please enter amount' : 'يرجى إدخال المبلغ أولاً';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return isEng ? 'Enter a valid positive amount' : 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // 2. Numeric Keypad (لوحة الأرقام لإدخال المبلغ)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          children: [
                            // Row 1: 1, 2, 3
                            Row(
                              children: [
                                Expanded(child: numBtn('1', onTap: () => setDialogState(() => appendDigit('1')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('2', onTap: () => setDialogState(() => appendDigit('2')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('3', onTap: () => setDialogState(() => appendDigit('3')))),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Row 2: 4, 5, 6
                            Row(
                              children: [
                                Expanded(child: numBtn('4', onTap: () => setDialogState(() => appendDigit('4')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('5', onTap: () => setDialogState(() => appendDigit('5')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('6', onTap: () => setDialogState(() => appendDigit('6')))),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Row 3: 7, 8, 9
                            Row(
                              children: [
                                Expanded(child: numBtn('7', onTap: () => setDialogState(() => appendDigit('7')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('8', onTap: () => setDialogState(() => appendDigit('8')))),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('9', onTap: () => setDialogState(() => appendDigit('9')))),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Row 4: C, 0, ⌫
                            Row(
                              children: [
                                Expanded(
                                  child: numBtn(
                                    'C',
                                    bg: Colors.red.shade50,
                                    borderCol: Colors.red.shade200,
                                    fg: Colors.red.shade800,
                                    fontSize: 18,
                                    onTap: () => setDialogState(clearAll),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: numBtn('0', onTap: () => setDialogState(() => appendDigit('0')))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: numBtn(
                                    '⌫',
                                    bg: Colors.orange.shade50,
                                    borderCol: Colors.orange.shade200,
                                    fg: Colors.orange.shade900,
                                    icon: Icons.backspace_outlined,
                                    onTap: () => setDialogState(backspace),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 3. Note Input Below Numbers (إدخال ملاحظة أسفل الأرقام)
                      Text(
                        isEng ? 'Note:' : 'إدخال ملاحظة:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: isEng ? 'Write note or transaction details...' : 'اكتب ملاحظة أو بيان العملية هنا...',
                          prefixIcon: const Icon(Icons.edit_note_rounded, size: 24),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isEng ? 'Cancel' : 'إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final amount = double.parse(amountController.text.trim());
                  final noteText = notesController.text.trim();
                  final defaultReason = isDeposit
                      ? (isEng ? 'Cash Deposit' : 'إيداع نقدي بالخزينة')
                      : (isEng ? 'Cash Withdrawal' : 'سحب نقدي من الخزينة');

                  final reason = noteText.isNotEmpty ? noteText : defaultReason;

                  final transaction = TreasuryTransactionModel(
                    type: isDeposit ? 'IN' : 'OUT',
                    amount: amount,
                    reason: reason,
                    notes: noteText.isNotEmpty ? noteText : null,
                    createdBy: currentUser,
                    isClosed: 0,
                    createdAt: DateTime.now().toIso8601String(),
                  );

                  Navigator.pop(dialogCtx);

                  await context.read<TreasuryProvider>().addTreasuryTransaction(transaction);
                  _loadData();

                  if (context.mounted) {
                    TopNotification.showSuccess(
                      context,
                      isDeposit
                          ? (isEng ? 'Cash deposited into safe successfully! ✅' : 'تم إدخال المبلغ في الخزينة بنجاح! ✅')
                          : (isEng ? 'Cash withdrawn from safe successfully! ✅' : 'تم إخراج المبلغ من الخزينة بنجاح! ✅'),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: Text(
                  isDeposit ? (isEng ? 'Confirm Deposit' : 'تأكيد الإدخال') : (isEng ? 'Confirm Withdrawal' : 'تأكيد الإخراج'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
