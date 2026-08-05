import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/user.dart';
import '../auth/auth_provider.dart';
import 'settings_provider.dart';

class CashierPermissionsCard extends StatefulWidget {
  final int? targetUserId;

  const CashierPermissionsCard({
    super.key,
    this.targetUserId,
  });

  @override
  State<CashierPermissionsCard> createState() => _CashierPermissionsCardState();
}

class _CashierPermissionsCardState extends State<CashierPermissionsCard> {
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.targetUserId;
  }

  UserModel? _getSelectedUser(AuthProvider authProvider) {
    if (_selectedUserId == null) return null;
    try {
      return authProvider.users.firstWhere((u) => u.id == _selectedUserId);
    } catch (_) {
      return null;
    }
  }

  bool _getPermissionValue(
    String key,
    SettingsProvider settingsProvider,
    AuthProvider authProvider,
  ) {
    final user = _getSelectedUser(authProvider);
    if (user != null && user.permissions != null && user.permissions!.containsKey(key)) {
      return user.permissions![key]!;
    }
    return settingsProvider.getCashierPermission(key);
  }

  Future<void> _setPermissionValue(
    String key,
    bool val,
    SettingsProvider settingsProvider,
    AuthProvider authProvider,
  ) async {
    final user = _getSelectedUser(authProvider);
    if (user != null && user.id != null) {
      final Map<String, bool> updatedPerms = Map.from(user.permissions ?? {});
      if (user.permissions == null) {
        for (final k in SettingsProvider.defaultCashierPermissions.keys) {
          updatedPerms[k] = settingsProvider.getCashierPermission(k);
        }
      }
      updatedPerms[key] = val;
      await authProvider.updateUserPermissions(user.id!, updatedPerms);
    } else {
      await settingsProvider.setCashierPermission(key, val);
    }
  }

  Future<void> _setAllPermissions(
    bool val,
    SettingsProvider settingsProvider,
    AuthProvider authProvider,
  ) async {
    final user = _getSelectedUser(authProvider);
    if (user != null && user.id != null) {
      final Map<String, bool> updatedPerms = {};
      for (final k in SettingsProvider.defaultCashierPermissions.keys) {
        updatedPerms[k] = val;
      }
      await authProvider.updateUserPermissions(user.id!, updatedPerms);
    } else {
      await settingsProvider.setAllCashierPermissions(val);
    }
  }

  Future<void> _resetPermissions(
    SettingsProvider settingsProvider,
    AuthProvider authProvider,
  ) async {
    final user = _getSelectedUser(authProvider);
    if (user != null && user.id != null) {
      await authProvider.updateUserPermissions(user.id!, null);
    } else {
      await settingsProvider.resetCashierPermissionsToDefault();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isEng = settingsProvider.isEnglish;

    final cashierUsers = authProvider.users.where((u) => u.role == 'كاشير').toList();
    final selectedUser = _getSelectedUser(authProvider);

    final List<Map<String, dynamic>> screenPermissions = [
      {
        'key': 'perm_cashier_access_day_closing',
        'title': isEng ? 'Access Day Closing Screen' : 'إغلاق اليومية والتصفية',
        'subtitle': isEng ? 'Allows opening the day closing screen' : 'يسمح للكاشير بإغلاق التصفية اليومية وسحب كشف الحساب النهائي',
        'icon': Icons.lock_clock_outlined,
      },
      {
        'key': 'perm_cashier_access_debts',
        'title': isEng ? 'Access Debts Log Screen' : 'سجل الديون والعملاء',
        'subtitle': isEng ? 'Allows viewing customer debts & balances' : 'يسمح برؤية كشف الديون وحسابات الزبائن الأجل',
        'icon': Icons.request_quote_outlined,
      },
      {
        'key': 'perm_cashier_access_reports',
        'title': isEng ? 'Access Reports & Analytics' : 'التقارير والإحصائيات',
        'subtitle': isEng ? 'Allows viewing sales and analytics reports' : 'يسمح للكاشير بالدخول لصفحة التقارير والرسوم البيانية',
        'icon': Icons.bar_chart_outlined,
      },
      {
        'key': 'perm_cashier_access_products',
        'title': isEng ? 'Access Products Screen' : 'الأصناف والمنتجات',
        'subtitle': isEng ? 'Allows viewing and managing products list' : 'يسمح بالدخول لشاشة المنتجات وقائمة الطعام',
        'icon': Icons.fastfood_outlined,
      },
      {
        'key': 'perm_cashier_access_categories',
        'title': isEng ? 'Access Categories Screen' : 'التصنيفات الأقسام',
        'subtitle': isEng ? 'Allows managing main product categories' : 'يسمح بالدخول لشاشة الأقسام وتعديلها',
        'icon': Icons.category_outlined,
      },
      {
        'key': 'perm_cashier_access_inventory',
        'title': isEng ? 'Access Inventory Screen' : 'المخزن والكميات',
        'subtitle': isEng ? 'Allows viewing stock levels & raw materials' : 'يسمح بالدخول لشاشة جرد المخزون وتعديل الكميات',
        'icon': Icons.inventory_2_outlined,
      },
      {
        'key': 'perm_cashier_access_purchases',
        'title': isEng ? 'Access Purchases & Suppliers' : 'المشتريات والموردين',
        'subtitle': isEng ? 'Allows managing supplier bills & purchase records' : 'يسمح بالدخول لشاشة شراء المواد وفواتير الموردين',
        'icon': Icons.shopping_bag_outlined,
      },
      {
        'key': 'perm_cashier_access_settings',
        'title': isEng ? 'Access System Settings' : 'إعدادات النظام والطابعات',
        'subtitle': isEng ? 'Allows accessing app printers & store info settings' : 'يسمح بالدخول لصفحة إعدادات النظام والطابعات',
        'icon': Icons.settings_outlined,
      },
    ];

    final List<Map<String, dynamic>> posOperationsPermissions = [
      {
        'key': 'perm_cashier_allow_discount',
        'title': isEng ? 'Allow Order Discount' : 'تطبيق خصم على الفاتورة',
        'subtitle': isEng ? 'Allows cashier to apply manual discounts on cart' : 'إمكانية إعطاء خصم مالي أو نسبة مئوية للفاتورة مباشرة',
        'icon': Icons.discount_outlined,
      },
      {
        'key': 'perm_cashier_allow_price_change',
        'title': isEng ? 'Allow Changing Product Price' : 'تعديل سعر المادة / سعر يدوي',
        'subtitle': isEng ? 'Allows changing price per item dynamically' : 'إمكانية تعديل سعر الصنف في السلة أثناء البيع',
        'icon': Icons.price_change_outlined,
      },
      {
        'key': 'perm_cashier_allow_delete_item',
        'title': isEng ? 'Allow Deleting Item from Cart' : 'حذف عنصر من الطلب',
        'subtitle': isEng ? 'Allows removing an added item from open order' : 'إمكانية حذف مادة مضافة مسبقاً من السلة بدون إذن مدير',
        'icon': Icons.delete_sweep_outlined,
      },
      {
        'key': 'perm_cashier_allow_cancel_order',
        'title': isEng ? 'Allow Cancelling Entire Order' : 'إلغاء الفاتورة بالكامل',
        'subtitle': isEng ? 'Allows clearing cart or evacuating active table' : 'إمكانية تفريغ السلة وإلغاء الطلب بالكامل وإخلاء الطاولة',
        'icon': Icons.cancel_outlined,
      },
      {
        'key': 'perm_cashier_allow_debt_sale',
        'title': isEng ? 'Allow Debt / Credit Sale' : 'البيع بالآجل / إضافة دين',
        'subtitle': isEng ? 'Allows closing sales on credit balance for customers' : 'إمكانية البيع بالآجل وتحويل المبلغ لدين على حساب الزبون',
        'icon': Icons.person_add_disabled_outlined,
      },
      {
        'key': 'perm_cashier_allow_settle_debt',
        'title': isEng ? 'Allow Customer Debt Settlement' : 'تسوية وسداد ديون الزبائن',
        'subtitle': isEng ? 'Allows receiving debt repayments from customer' : 'إمكانية استلام مبالغ تسديد الديون من الزبائن',
        'icon': Icons.payments_outlined,
      },
      {
        'key': 'perm_cashier_allow_cash_trans',
        'title': isEng ? 'Allow Treasury Cash In / Cash Out' : 'إدخال وإخراج نقدية من الخزينة',
        'subtitle': isEng ? 'Allows adding or withdrawing cash from active shift' : 'إمكانية إجراء سحب أو إيداع نقدي في صندوق الشفت',
        'icon': Icons.account_balance_wallet_outlined,
      },
      {
        'key': 'perm_cashier_view_profit_reports',
        'title': isEng ? 'Allow Viewing Financial Profit Reports' : 'عرض تقارير الأرباح المالية',
        'subtitle': isEng ? 'Allows viewing exact gross/net profits breakdown' : 'إمكانية رؤية أرباح المواد وصافي الأرباح في التقارير',
        'icon': Icons.trending_up_outlined,
      },
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEng ? 'Cashier Permissions Management' : 'إدارة وتخصيص صلاحيات الكاشير',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isEng
                            ? 'Select a specific cashier account or edit default template rights'
                            : 'اختر اسم الكاشير وحدد صلاحياته الخاصة أو قم بتعديل النموذج العام للكاشيرية',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            // Cashier User Dropdown Selector
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_search, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? 'Select Cashier Account to Edit:' : 'اختر حساب الكاشير المراد تخصيص صلاحياته:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedUserId,

                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.amber.shade300),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Row(
                          children: [
                            const Icon(Icons.groups, color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              isEng ? '👤 Default Template (All Cashiers)' : '👤 النموذج الافتراضي العام (لكافة الكاشيرية)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      ...cashierUsers.map(
                        (user) => DropdownMenuItem<int?>(
                          value: user.id,
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.blue, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '${user.username} (كاشير مخصص)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (user.permissions != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isEng ? 'Customized' : 'صلاحيات مخصصة',
                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedUserId = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Preset Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _setAllPermissions(true, settingsProvider, authProvider);
                      if (context.mounted) {
                        TopNotification.showSuccess(
                          context,
                          selectedUser != null
                              ? (isEng ? 'All permissions granted to ${selectedUser.username} ✅' : 'تم تمكين كافة الصلاحيات للكاشير (${selectedUser.username}) بنجاح ✅')
                              : (isEng ? 'All default permissions granted ✅' : 'تم تمكين كافة الصلاحيات الافتراضية بنجاح ✅'),
                        );
                      }
                    },
                    icon: const Icon(Icons.select_all, color: Colors.white, size: 18),
                    label: Text(
                      isEng ? 'Grant All Rights' : 'تمكين كافة الصلاحيات',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _setAllPermissions(false, settingsProvider, authProvider);
                      if (context.mounted) {
                        TopNotification.showSuccess(
                          context,
                          selectedUser != null
                              ? (isEng ? 'All permissions restricted for ${selectedUser.username} 🔒' : 'تم تقييد كافة الصلاحيات عن الكاشير (${selectedUser.username}) 🔒')
                              : (isEng ? 'All default permissions restricted 🔒' : 'تم تقييد كافة الصلاحيات الافتراضية 🔒'),
                        );
                      }
                    },
                    icon: const Icon(Icons.deselect, color: Colors.white, size: 18),
                    label: Text(
                      isEng ? 'Restrict All' : 'تعطيل كافة الصلاحيات',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _resetPermissions(settingsProvider, authProvider);
                      if (context.mounted) {
                        TopNotification.showSuccess(
                          context,
                          selectedUser != null
                              ? (isEng ? 'Reset ${selectedUser.username} rights to default 🔄' : 'تمت إعادة صلاحيات (${selectedUser.username}) للنموذج الافتراضي 🔄')
                              : (isEng ? 'Default permissions reset 🔄' : 'تمت إعادة الصلاحيات للوضع الافتراضي 🔄'),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(
                      selectedUser != null
                          ? (isEng ? 'Reset to Default Template' : 'إعادة للنموذج الافتراضي')
                          : (isEng ? 'Reset Default' : 'إعادة للافتراضي'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 1: Screen Access Permissions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.desktop_windows_outlined, color: Colors.blue.shade800),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? '1. Screen Access & Navigation Permissions' : '1. صلاحيات الوصول للشاشات والقوائم الرئيسية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ...screenPermissions.map((perm) {
              final isEnabled = _getPermissionValue(perm['key'] as String, settingsProvider, authProvider);
              return Card(
                elevation: 0,
                color: isEnabled ? Colors.green.shade50.withValues(alpha: 0.4) : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isEnabled ? Colors.green.shade200 : Colors.grey.shade300),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: isEnabled ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(
                      perm['icon'] as IconData,
                      color: isEnabled ? Colors.green.shade900 : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(
                    perm['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    perm['subtitle'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  value: isEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    _setPermissionValue(perm['key'] as String, val, settingsProvider, authProvider);
                  },
                ),
              );
            }),

            const SizedBox(height: 24),

            // Section 2: POS Operational Permissions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.point_of_sale_outlined, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? '2. POS Operations & Sales Permissions' : '2. صلاحيات العمليات والبيع داخل شاشة الكاشير',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber.shade900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ...posOperationsPermissions.map((perm) {
              final isEnabled = _getPermissionValue(perm['key'] as String, settingsProvider, authProvider);
              return Card(
                elevation: 0,
                color: isEnabled ? Colors.green.shade50.withValues(alpha: 0.4) : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isEnabled ? Colors.green.shade200 : Colors.grey.shade300),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: isEnabled ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(
                      perm['icon'] as IconData,
                      color: isEnabled ? Colors.green.shade900 : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(
                    perm['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    perm['subtitle'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  value: isEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    _setPermissionValue(perm['key'] as String, val, settingsProvider, authProvider);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
