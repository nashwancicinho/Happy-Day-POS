import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/user.dart';
import '../settings/settings_provider.dart';
import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Initial Setup Controllers (empty by default for new manager creation)
  final _initManagerNameController = TextEditingController();
  final _initManagerPassController = TextEditingController();
  final _initCashierNameController = TextEditingController();
  final _initCashierPassController = TextEditingController();

  bool _isObscure = true;
  String? _selectedUsername;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _initManagerNameController.dispose();
    _initManagerPassController.dispose();
    _initCashierNameController.dispose();
    _initCashierPassController.dispose();
    super.dispose();
  }

  void _handleCompleteInitialSetup() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final managerName = _initManagerNameController.text.trim();
    final managerPass = _initManagerPassController.text.trim();
    final cashierName = _initCashierNameController.text.trim();
    final cashierPass = _initCashierPassController.text.trim();

    if (managerName.isEmpty || managerPass.isEmpty) {
      TopNotification.showWarning(
        context,
        isEng ? '⚠️ Please enter Manager name & PIN code' : '⚠️ يرجى إدخال اسم مدير النظام والرمز السري الخاص به',
      );
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.registerInitialSetup(
        managerUsername: managerName,
        managerPassword: managerPass,
        cashierUsername: cashierName,
        cashierPassword: cashierPass,
      );

      if (mounted) {
        TopNotification.showSuccess(
          context,
          isEng ? '🎉 System setup saved successfully! Welcome $managerName' : '🎉 تم حفظ الحسابات وإعداد النظام بنجاح! أهلاً بك $managerName',
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.showError(
          context,
          isEng ? 'Error saving setup: $e' : 'حدث خطأ أثناء حفظ الإعداد الأول: $e',
        );
      }
    }
  }

  Widget _buildInitialSetupCard(bool isEng) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.app_registration_rounded, size: 56, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                isEng ? 'Initial Setup - New Manager Account' : 'إعداد وتصفير النظام - حساب مدير جديد',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                isEng ? 'System database is empty. Please enter new Manager name & PIN code to get started.' : 'النظام فارغ حالياً. يرجى كتابة اسم ورمز مدير النظام الجديد للبدء.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Manager Account
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? '1. Manager Account Credentials' : '1. بيانات حساب المدير (مدير النظام)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initManagerNameController,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Manager Name *' : 'اسم مدير النظام *',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initManagerPassController,
                    obscureText: _isObscure,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Manager PIN Code *' : 'الرقم السري للمدير *',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: Cashier Account
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge, color: Colors.blue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? '2. First Cashier Account (Optional)' : '2. بيانات حساب الكاشير الأول',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initCashierNameController,
                    decoration: InputDecoration(
                      labelText: isEng ? 'First Cashier Name (Optional)' : 'اسم الكاشير الأول (اختياري)',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initCashierPassController,
                    obscureText: _isObscure,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Cashier PIN Code (Optional)' : 'الرقم السري للكاشير (اختياري)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                onPressed: _handleCompleteInitialSetup,
                icon: const Icon(Icons.check_circle_rounded, size: 24),
                label: Text(
                  isEng ? 'Save Setup & Launch System 🚀' : 'حفظ وإتمام الإعداد والدخول للنظام 🚀',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final username = _selectedUsername ?? _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      TopNotification.showWarning(
        context,
        isEng ? '⚠️ Please enter username & PIN code' : '⚠️ يرجى إدخال اسم المستخدم والرقم السري',
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(username, password);

    if (!mounted) return;

    if (!success) {
      TopNotification.showError(
        context,
        isEng ? '❌ Invalid username or PIN code!' : '❌ اسم المستخدم أو الرقم السري غير صحيح!',
      );
    }
  }

  void _showAddUserDialog() {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final authProvider = context.read<AuthProvider>();

    // Deduplicate manager list to avoid dropdown key conflicts
    final uniqueManagersMap = <String, UserModel>{};
    for (final u in authProvider.users.where((u) => u.isManager)) {
      uniqueManagersMap[u.username] = u;
    }
    final managerList = uniqueManagersMap.values.toList();

    final managerNameController = TextEditingController(
      text: managerList.isNotEmpty ? managerList.first.username : 'Nashwan',
    );
    final managerPasswordController = TextEditingController();
    final newUsernameController = TextEditingController();
    final newUserPasswordController = TextEditingController();
    String selectedRole = 'كاشير';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final activeManagerValue = managerList.any((m) => m.username == managerNameController.text)
                ? managerNameController.text
                : (managerList.isNotEmpty ? managerList.first.username : null);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person_add_alt_1, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEng ? 'Add New System User' : 'إضافة مستخدم جديد للنظام',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Manager Auth Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  isEng ? 'Manager Authorization Required' : 'صلاحية إذن المدير لتأكيد الإضافة',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEng ? 'Enter manager name & PIN code to authorize user addition:' : 'أدخل اسم المدير ورقمه السري للموافق على إضافة المستعمل:',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Manager Name
                      if (managerList.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: activeManagerValue,
                          decoration: InputDecoration(
                            labelText: isEng ? '1. Current Manager Name *' : '1. اسم المدير الحالي *',
                            prefixIcon: const Icon(Icons.security),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: managerList.map((m) {
                            return DropdownMenuItem<String>(
                              value: m.username,
                              child: Text(isEng ? '${m.username} (Manager)' : '${m.username} (مدير النظام)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                managerNameController.text = val;
                              });
                            }
                          },
                        )
                      else
                        TextField(
                          controller: managerNameController,
                          decoration: InputDecoration(
                            labelText: isEng ? '1. Current Manager Name *' : '1. اسم المدير الحالي *',
                            prefixIcon: const Icon(Icons.security),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // 2. Manager Password
                      TextField(
                        controller: managerPasswordController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isEng ? '2. Manager PIN Code *' : '2. الرقم السري للمدير *',
                          prefixIcon: const Icon(Icons.key),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const Divider(height: 30),

                      // New User Details Section
                      Text(
                        isEng ? 'New User Credentials:' : 'بيانات الحساب الجديد:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                      ),
                      const SizedBox(height: 10),

                      // 3. New Username
                      TextField(
                        controller: newUsernameController,
                        decoration: InputDecoration(
                          labelText: isEng ? '3. New Username *' : '3. اسم المستخدم الجديد *',
                          prefixIcon: const Icon(Icons.person_add),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4. New User Password
                      TextField(
                        controller: newUserPasswordController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isEng ? '4. New User PIN Code *' : '4. الرقم السري للمستخدم الجديد *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 5. New User Role
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: isEng ? '5. New User Role' : '5. نوع صلاحية المستخدم الجديد',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'كاشير',
                            child: Text(isEng ? 'Cashier (Sales Only)' : 'كاشير (صلاحية بيع فقط)'),
                          ),
                          DropdownMenuItem(
                            value: 'مدير',
                            child: Text(isEng ? 'Manager (Full Admin Access)' : 'مدير النظام (صلاحية كاملة)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedRole = val;
                            });
                          }
                        },
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
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final managerName = managerNameController.text.trim();
                    final managerPassword = managerPasswordController.text.trim();
                    final newUsername = newUsernameController.text.trim();
                    final newUserPassword = newUserPasswordController.text.trim();

                    if (managerName.isEmpty || managerPassword.isEmpty) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? '⚠️ Please enter manager credentials for authorization' : '⚠️ يرجى إدخال اسم ورقم سري المدير للموافقة',
                      );
                      return;
                    }

                    if (newUsername.isEmpty || newUserPassword.isEmpty) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? '⚠️ Please enter new username and PIN code' : '⚠️ يرجى إدخال اسم المستخدم الجديد والرمز السري الخاص به',
                      );
                      return;
                    }

                    try {
                      await authProvider.registerUserWithManagerCredentials(
                        managerUsername: managerName,
                        managerPassword: managerPassword,
                        newUser: UserModel(
                          username: newUsername,
                          password: newUserPassword,
                          role: selectedRole,
                        ),
                      );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        TopNotification.showSuccess(
                          context,
                          isEng ? '🎉 New user "$newUsername" added successfully!' : '🎉 تم إضافة المستخدم الجديد "$newUsername" بنجاح!',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        TopNotification.showError(ctx, '❌ $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    isEng ? 'Add User' : 'إضافة المستخدم',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isEng = settingsProvider.isEnglish;
    final authProvider = context.watch<AuthProvider>();

    // Deduplicate user list for main login dropdown
    final uniqueUsersMap = <String, UserModel>{};
    for (final u in authProvider.users) {
      uniqueUsersMap[u.username] = u;
    }
    final userList = uniqueUsersMap.values.toList();

    if (userList.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildInitialSetupCard(isEng),
            ),
          ),
        ),
      );
    }

    final activeLoginUserValue = userList.any((u) => u.username == _selectedUsername)
        ? _selectedUsername
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Logo & Branding
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEng ? 'Happy Day POS System' : 'نظام هابي داي لنقاط البيع',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEng ? 'Please sign in to continue' : 'يرجى تسجيل الدخول لمتابعة العمل',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 28),

                    // Username Selector Dropdown
                    if (userList.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: activeLoginUserValue,
                        hint: Text(isEng ? 'Select User or Manager...' : 'اختر اسم المستخدم أو المدير...'),
                        decoration: InputDecoration(
                          labelText: isEng ? 'Select User or Manager' : 'اختر اسم المستخدم أو المدير',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: userList.map((u) {
                          final roleLabel = isEng
                              ? (u.isManager ? 'Manager' : 'Cashier')
                              : u.role;

                          return DropdownMenuItem<String>(
                            value: u.username,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.isManager ? Colors.purple.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    roleLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: u.isManager ? Colors.purple : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedUsername = val;
                            if (val != null) {
                              _usernameController.text = val;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: isEng ? 'Username or Manager Name' : 'اسم المستخدم أو المدير',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isEng ? 'PIN Code / Password' : 'الرقم السري / كلمة المرور',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isObscure = !_isObscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.login),
                        label: Text(
                          isEng ? 'Sign In 🚪' : 'تسجيل الدخول',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Add New User Button (على شاشة الدخول الرئيسية)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _showAddUserDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          isEng ? 'Add New User 👤+' : 'إضافة مستخدم جديد',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
