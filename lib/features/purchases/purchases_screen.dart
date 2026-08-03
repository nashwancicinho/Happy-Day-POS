import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import 'purchases_provider.dart';
import 'widgets/add_purchase_dialog.dart';
import 'widgets/add_supplier_dialog.dart';
import 'widgets/supplier_payment_dialog.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchasesProvider>().loadAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchasesProvider>();
    final query = _searchController.text.trim().toLowerCase();

    final filteredPurchases = provider.purchases.where((p) {
      if (query.isEmpty) return true;
      return p.invoiceNumber.toLowerCase().contains(query) ||
          p.supplierName.toLowerCase().contains(query) ||
          (p.notes != null && p.notes!.toLowerCase().contains(query));
    }).toList();

    final filteredSuppliers = provider.suppliers.where((s) {
      if (query.isEmpty) return true;
      return s.name.toLowerCase().contains(query) ||
          (s.phone != null && s.phone!.contains(query)) ||
          (s.address != null && s.address!.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المشتريات والموردين والديون'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'فواتير المشتريات (Invoices)'),
            Tab(icon: Icon(Icons.group_outlined), text: 'دليل الموردين وديونهم (Suppliers)'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddPurchaseDialog(context);
          } else {
            _showAddSupplierDialog(context);
          }
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'فاتورة مشتريات جديدة 📦' : 'إضافة مورد جديد 🚚',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Summary Statistics Cards Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'إجمالي المشتريات',
                          value: '${provider.totalPurchasesAmount.toStringAsFixed(0)} د.ع',
                          icon: Icons.shopping_bag,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'المبالغ المدفوعة',
                          value: '${provider.totalPaidAmount.toStringAsFixed(0)} د.ع',
                          icon: Icons.check_circle_outline,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'ديون الموردين (كم أنا مدين له)',
                          value: '${provider.totalSuppliersDebt.toStringAsFixed(0)} د.ع',
                          icon: Icons.error_outline,
                          color: Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'إجمالي الموردين',
                          value: '${provider.suppliers.length} مورد',
                          icon: Icons.group,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم المورد، رقم الفاتورة، الوصل، الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),

                // TabBar View Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: PURCHASES INVOICES LIST
                      _buildInvoicesTab(context, filteredPurchases),

                      // TAB 2: SUPPLIERS LIST & DEBTS
                      _buildSuppliersTab(context, filteredSuppliers),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTab(BuildContext context, List<PurchaseInvoiceModel> purchases) {
    if (purchases.isEmpty) {
      return const Center(
        child: Text('لا توجد فواتير مشتريات مسجلة حالياً', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final invoice = purchases[index];
        final isPaid = invoice.paymentStatus == 'PAID';
        final isPartial = invoice.paymentStatus == 'PARTIAL';

        final statusColor = isPaid
            ? Colors.green
            : isPartial
                ? Colors.orange
                : Colors.red;
        final statusText = isPaid
            ? 'مدفوعة بالكامل 🟢'
            : isPartial
                ? 'مدفوعة جزئياً 🟡'
                : 'آجل / غير مدفوعة 🔴';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.receipt, color: statusColor),
            ),
            title: Row(
              children: [
                Text(
                  'وصل #${invoice.invoiceNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'المورد: ${invoice.supplierName} • التاريخ: ${invoice.createdAt.split("T").first}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            trailing: Text(
              '${invoice.totalAmount.toStringAsFixed(0)} د.ع',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المبلغ المدفوع: ${invoice.paidAmount.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('الدين المتبقي للمورد: ${invoice.remainingAmount.toStringAsFixed(0)} د.ع', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                      ],
                    ),
                    if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('ملاحظات: ${invoice.notes}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                    ],
                    const Divider(),

                    const Text('المواد والمشتريات بالمشروعات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),

                    for (var item in invoice.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('• ${item.itemName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            Text('${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} د.ع = ', style: const TextStyle(fontSize: 12)),
                            Text('${item.subtotal.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('مسح الفاتورة', style: TextStyle(color: Colors.red)),
                        onPressed: () => _confirmDeleteInvoice(context, invoice),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuppliersTab(BuildContext context, List<SupplierModel> suppliers) {
    if (suppliers.isEmpty) {
      return const Center(
        child: Text('لا يوجد موردون مسجلون حالياً', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: suppliers.length,
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        final hasDebt = supplier.balance > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: hasDebt ? Colors.red.shade100 : Colors.teal.shade100,
                  child: Icon(
                    Icons.business_center,
                    color: hasDebt ? Colors.red.shade800 : Colors.teal.shade800,
                  ),
                ),
                const SizedBox(width: 14),

                // Supplier Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'هاتف: ${supplier.phone ?? "غير محدد"} • العنوان: ${supplier.address ?? "غير محدد"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (supplier.notes != null && supplier.notes!.isNotEmpty)
                        Text('ملاحظات: ${supplier.notes}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),

                // Debt Amount Badge & Pay Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الدين المستحق له:', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    Text(
                      '${supplier.balance.toStringAsFixed(0)} د.ع',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: hasDebt ? Colors.red.shade800 : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDebt)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.payments, color: Colors.white, size: 16),
                            label: const Text('تسديد دين 💳', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => SupplierPaymentDialog(supplier: supplier),
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.indigo, size: 20),
                          tooltip: 'تعديل البيانات',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AddSupplierDialog(supplierToEdit: supplier),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'حذف المورد',
                          onPressed: () => _confirmDeleteSupplier(context, supplier),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddPurchaseDialog(),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddSupplierDialog(),
    );
  }

  void _confirmDeleteSupplier(BuildContext context, SupplierModel supplier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد مسح المورد'),
        content: Text('هل أنت متأكد من مسح المورد (${supplier.name})؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (supplier.id != null) {
                await context.read<PurchasesProvider>().deleteSupplier(supplier.id!);
                if (context.mounted) {
                  TopNotification.showSuccess(context, '🎉 تم مسح المورد بنجاح.');
                }
              }
            },
            child: const Text('مسح المورد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInvoice(BuildContext context, PurchaseInvoiceModel invoice) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد مسح فاتورة المشتريات'),
        content: Text('هل أنت متأكد من مسح الفاتورة رقم (#${invoice.invoiceNumber}) للمورد (${invoice.supplierName})؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (invoice.id != null) {
                await context.read<PurchasesProvider>().deletePurchaseInvoice(invoice.id!);
                if (context.mounted) {
                  TopNotification.showSuccess(context, '🎉 تم مسح الفاتورة بنجاح.');
                }
              }
            },
            child: const Text('مسح الفاتورة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
