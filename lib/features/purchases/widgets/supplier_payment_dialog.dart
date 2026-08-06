import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/top_notification.dart';
import '../../../models/supplier.dart';
import '../../settings/settings_provider.dart';
import '../purchases_provider.dart';

class SupplierPaymentDialog extends StatefulWidget {
  final SupplierModel supplier;

  const SupplierPaymentDialog({super.key, required this.supplier});

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  String _paymentMethod = 'CASH';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.supplier.balance.toStringAsFixed(0));
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.green, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEng ? 'Pay Debt to Supplier: ${widget.supplier.name}' : 'تسديد دين للمورد: ${widget.supplier.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Debt Info Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEng ? 'Current Debt Payable to Supplier:' : 'الدين المستحق حالياً للمورد:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      '${widget.supplier.balance.toStringAsFixed(0)} $currencySymbol',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isEng ? 'Paid Amount for Settlement ($currencySymbol) *' : 'المبلغ المدفوع للتسديد ($currencySymbol) *',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Text(
                        currencySymbol,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return isEng ? 'Please enter payment amount' : 'يرجى إدخال مبلغ التسديد';
                  }
                  final amount = double.tryParse(val.trim());
                  if (amount == null || amount <= 0) {
                    return isEng ? 'Please enter valid amount greater than 0' : 'يرجى إدخال مبلغ صحيح أكبر من 0';
                  }
                  if (amount > widget.supplier.balance) {
                    return isEng ? 'Paid amount is greater than total debt due!' : 'المبلغ المدفوع أكبر من إجمالي الدين المستحق!';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: InputDecoration(
                  labelText: isEng ? 'Payment Method' : 'طريقة الدفع',
                  prefixIcon: const Icon(Icons.payment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  DropdownMenuItem(value: 'CASH', child: Text(isEng ? 'Cash (Drawer Treasury)' : 'نقداً (من خزينة الكاشير)')),
                  DropdownMenuItem(value: 'BANK', child: Text(isEng ? 'Bank Transfer / Card' : 'تحويل بانكي / كارت')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: isEng ? 'Notes / Reference No' : 'ملاحظات / رقم الحوالة',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isEng ? 'Cancel' : 'إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(
            isEng ? 'Confirm & Disburse Payment' : 'تأكيد التسديد وصرف المبلغ',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final dialogCtx = context;
            final amount = double.parse(_amountController.text.trim());
            final provider = dialogCtx.read<PurchasesProvider>();

            final success = await provider.paySupplierDebt(
              supplierId: widget.supplier.id!,
              supplierName: widget.supplier.name,
              amount: amount,
              paymentMethod: _paymentMethod,
              notes: _notesController.text.trim(),
            );

            if (!mounted) return;
            if (success) {
              TopNotification.showSuccess(
                dialogCtx,
                isEng
                    ? '🎉 Paid ${amount.toStringAsFixed(0)} $currencySymbol to supplier (${widget.supplier.name}) successfully!'
                    : '🎉 تم تسديد مبلغ ${amount.toStringAsFixed(0)} $currencySymbol للمورد (${widget.supplier.name}) وتسجيل الصرف بنجاح!',
              );
            } else {
              TopNotification.showWarning(
                dialogCtx,
                isEng ? '⚠️ Error recording payment operation.' : '⚠️ حدث خطأ أثناء تسجيل عملية الدفع.',
              );
            }
            Navigator.pop(dialogCtx);
          },
        ),
      ],
    );
  }
}
