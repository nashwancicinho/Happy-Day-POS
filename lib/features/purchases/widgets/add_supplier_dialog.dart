import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/top_notification.dart';
import '../../../models/supplier.dart';
import '../../settings/settings_provider.dart';
import '../purchases_provider.dart';

class AddSupplierDialog extends StatefulWidget {
  final SupplierModel? supplierToEdit;

  const AddSupplierDialog({super.key, this.supplierToEdit});

  @override
  State<AddSupplierDialog> createState() => _AddSupplierDialogState();
}

class _AddSupplierDialogState extends State<AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  late TextEditingController _initialDebtController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplierToEdit?.name ?? '');
    _phoneController = TextEditingController(text: widget.supplierToEdit?.phone ?? '');
    _addressController = TextEditingController(text: widget.supplierToEdit?.address ?? '');
    _notesController = TextEditingController(text: widget.supplierToEdit?.notes ?? '');
    _initialDebtController = TextEditingController(text: widget.supplierToEdit?.balance.toStringAsFixed(0) ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _initialDebtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final isEditing = widget.supplierToEdit != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(isEditing ? Icons.edit : Icons.person_add_alt_1, color: AppColors.primary, size: 26),
          const SizedBox(width: 10),
          Text(
            isEditing
                ? (isEng ? 'Edit Supplier Info' : 'تعديل بيانات المورد')
                : (isEng ? 'Add New Supplier 🚚' : 'إضافة مورد جديد 🚚'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Supplier / Company Name *' : 'اسم المورد / الشركة *',
                    prefixIcon: const Icon(Icons.business_center),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? (isEng ? 'Please enter supplier name' : 'يرجى إدخال اسم المورد')
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Phone Number' : 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Address / Location' : 'العنوان / الموقع',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                if (!isEditing) ...[
                  TextFormField(
                    controller: _initialDebtController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Initial Previous Debt (If any)' : 'الدين السابق المتبقي للمورد (إن وجد)',
                      prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: isEng ? 'Enter amount if you owe previous debt before using system' : 'أدخل المبلغ إذا كان لديك دين سابق للمورد قبل استخدام النظام',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isEng ? 'Additional Notes' : 'ملاحظات إضافية',
                    prefixIcon: const Icon(Icons.note_alt),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
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
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check, color: Colors.white),
          label: Text(
            isEditing ? (isEng ? 'Save Changes' : 'حفظ التعديلات') : (isEng ? 'Add Supplier' : 'إضافة المورد'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final provider = context.read<PurchasesProvider>();
            final initialDebt = double.tryParse(_initialDebtController.text.trim()) ?? 0.0;

            if (isEditing) {
              final updated = widget.supplierToEdit!.copyWith(
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                notes: _notesController.text.trim(),
              );
              await provider.updateSupplier(updated);
              if (!context.mounted) return;
              TopNotification.showSuccess(context, isEng ? '🎉 Supplier updated successfully.' : '🎉 تم تحديث بيانات المورد بنجاح.');
              Navigator.pop(context);
            } else {
              final newSupplier = SupplierModel(
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                notes: _notesController.text.trim(),
                balance: initialDebt,
              );
              await provider.addSupplier(newSupplier);
              if (!context.mounted) return;
              TopNotification.showSuccess(context, isEng ? '🎉 New supplier added successfully!' : '🎉 تمت إضافة المورد الجديد بنجاح!');
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
