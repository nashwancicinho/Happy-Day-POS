import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _errorMessage;

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordFocused = true;
  bool _isArabicKeyboard = false;

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(() {
      if (_usernameFocusNode.hasFocus) {
        setState(() => _isPasswordFocused = false);
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setState(() => _isPasswordFocused = true);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _initManagerNameController.dispose();
    _initManagerPassController.dispose();
    _initCashierNameController.dispose();
    _initCashierPassController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onVirtualKeyPress(String char) {
    setState(() {
      _errorMessage = null;
    });
    final targetController = _isPasswordFocused ? _passwordController : _usernameController;
    targetController.text = targetController.text + char;
  }

  void _onVirtualKeyBackspace() {
    setState(() {
      _errorMessage = null;
    });
    final targetController = _isPasswordFocused ? _passwordController : _usernameController;
    if (targetController.text.isNotEmpty) {
      targetController.text = targetController.text.substring(0, targetController.text.length - 1);
    }
  }

  void _onVirtualKeyClear() {
    setState(() {
      _errorMessage = null;
    });
    final targetController = _isPasswordFocused ? _passwordController : _usernameController;
    targetController.clear();
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
        isEng ? '⚠️ Please enter Manager name & PIN code' : '⚠️ يرجى إدخال اسم المدير والرمز السري الخاص به',
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

  Widget _buildInitialSetupCard(bool isEng, [bool isDark = false]) {
    return Card(
      elevation: 8,
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                  color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
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
                isEng ? 'System database is empty. Please enter new Manager name & PIN code to get started.' : 'النظام فارغ حالياً. يرجى كتابة اسم ورمز المدير الجديد للبدء.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Manager Account
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.purple.shade900.withValues(alpha: 0.3) : Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isEng ? '1. Manager Account Credentials' : '1. بيانات حساب المدير',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.purple.shade200 : Colors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initManagerNameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: isEng ? 'Manager Name *' : 'اسم المدير *',
                      labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                      prefixIcon: Icon(Icons.person, color: isDark ? Colors.grey.shade300 : null),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initManagerPassController,
                    obscureText: _isObscure,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: isEng ? 'Manager PIN Code *' : 'الرقم السري للمدير *',
                      labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : null),
                      prefixIcon: Icon(Icons.lock, color: isDark ? Colors.grey.shade300 : null),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off, color: isDark ? Colors.grey.shade300 : null),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111827) : Colors.white,
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

  String _normalizeArabicNumerals(String input) {
    const easternArabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernArabic = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(easternArabic[i], westernArabic[i]);
    }
    return result;
  }

  void _handleLogin() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final username = _selectedUsername ?? _usernameController.text.trim();
    final password = _normalizeArabicNumerals(_passwordController.text.trim());

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = isEng
            ? '⚠️ Please enter username & PIN code'
            : '⚠️ يرجى إدخال اسم المستخدم والرقم السري';
      });
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
      setState(() {
        _errorMessage = isEng
            ? 'اسم المستخدم أو الرقم السري غير صحيح'
            : 'اسم المستخدم أو الرقم السري غير صحيح';
      });
      TopNotification.showError(
        context,
        isEng ? '❌ Invalid username or PIN code!' : '❌ اسم المستخدم أو الرقم السري غير صحيح!',
      );
    } else {
      setState(() {
        _errorMessage = null;
      });
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
            final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          color: isDark ? Colors.purple.shade900.withValues(alpha: 0.3) : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade200),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.purple.shade200 : Colors.purple),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEng ? 'Enter manager name & PIN code to authorize user addition:' : 'أدخل اسم المدير ورقمه السري للموافق على إضافة المستعمل:',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
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
                              child: Text(isEng ? '${m.username} (Manager)' : '${m.username} (مدير)'),
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
                            child: Text(isEng ? 'Manager (Full Admin Access)' : 'مدير (صلاحية كاملة)'),
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

  Future<void> _confirmExitApp() async {
    final settings = context.read<SettingsProvider>();
    final isEng = settings.isEnglish;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.power_settings_new_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Text(
              isEng ? 'Confirm Exit Application' : 'تأكيد إغلاق وخروج من البرنامج',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          isEng
              ? 'Are you sure you want to exit the POS application completely?'
              : 'هل أنت متأكد من رغبتك في إغلاق برنامج نقاط البيع والخروج بالكامل؟',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              isEng ? 'Cancel' : 'لا (إلغاء)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.power_settings_new_rounded, size: 18),
            onPressed: () => Navigator.pop(dialogContext, true),
            label: Text(
              isEng ? 'Yes, Exit App' : 'نعم، إغلاق البرنامج',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isEng = settingsProvider.isEnglish;
    final isDark = settingsProvider.isDarkMode;
    final authProvider = context.watch<AuthProvider>();

    // Deduplicate user list for main login dropdown
    final uniqueUsersMap = <String, UserModel>{};
    for (final u in authProvider.users) {
      uniqueUsersMap[u.username] = u;
    }
    final userList = uniqueUsersMap.values.toList();

    if (userList.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _confirmExitApp();
          },
          child: SafeArea(
            child: Stack(
              children: [
                PositionedDirectional(
                  top: 10,
                  end: 14,
                  child: Tooltip(
                    message: isEng ? 'Exit Application' : 'إغلاق البرنامج بالكامل',
                    child: OutlinedButton.icon(
                      onPressed: _confirmExitApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: isDark ? Colors.red.shade800 : Colors.red.shade200, width: 1.2),
                        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.red),
                      label: Text(
                        isEng ? 'Exit App' : 'إغلاق البرنامج',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildInitialSetupCard(isEng, isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeLoginUserValue = userList.any((u) => u.username == _selectedUsername)
        ? _selectedUsername
        : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _confirmExitApp();
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Top Bar Floating Exit Button
              PositionedDirectional(
                top: 10,
                end: 14,
                child: Tooltip(
                  message: isEng ? 'Exit Application' : 'إغلاق البرنامج وخروج بالكامل',
                  child: OutlinedButton.icon(
                    onPressed: _confirmExitApp,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: isDark ? Colors.red.shade800 : Colors.red.shade200, width: 1.2),
                      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.red),
                    label: Text(
                      isEng ? 'Exit Application' : 'إغلاق البرنامج',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),

              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Login Card (Moved Higher Up)
                Card(
                  elevation: 8,
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Logo & Branding
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF242F3E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/cashbox_logo.png',
                              height: 85,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Icon(
                                Icons.point_of_sale,
                                size: 65,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                isEng ? 'CashBox POS System' : 'نظام CashBox POS لنقاط البيع',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEng ? 'Please sign in to continue' : 'يرجى تسجيل الدخول لمتابعة العمل',
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Username Selector Dropdown / Field
                        if (userList.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: activeLoginUserValue,
                            dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                            ),
                            hint: Text(
                              isEng ? 'Select User or Manager' : 'اختر اسم المستخدم أو المدير',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF374151),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            decoration: InputDecoration(
                              labelText: isEng ? 'Select User or Manager' : 'اختر اسم المستخدم أو المدير',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF374151),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                    Text(
                                      u.username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: u.isManager
                                            ? (isDark ? Colors.purple.shade900.withValues(alpha: 0.5) : Colors.purple.shade50)
                                            : (isDark ? Colors.blue.shade900.withValues(alpha: 0.5) : Colors.blue.shade50),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: u.isManager
                                              ? (isDark ? Colors.purple.shade200 : Colors.purple)
                                              : (isDark ? Colors.blue.shade200 : Colors.blue),
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
                                _errorMessage = null;
                                if (val != null) {
                                   _usernameController.text = val;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          TextField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () => setState(() => _isPasswordFocused = false),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: isEng ? 'Username or Manager Name' : 'اسم المستخدم أو المدير',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF374151),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Password Field
                        TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _isObscure,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          onTap: () => setState(() => _isPasswordFocused = true),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: isEng ? 'PIN Code / Password' : 'الرقم السري / كلمة المرور',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF374151),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure ? Icons.visibility : Icons.visibility_off,
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                              ),
                              onPressed: () => setState(() => _isObscure = !_isObscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _handleLogin(),
                        ),

                        // Inline Error Message Box
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade300, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Buttons Action Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 48,
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
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _showAddUserDialog,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(color: AppColors.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                                  label: Text(
                                    isEng ? 'Add User' : 'إضافة مستخدم',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Touchscreen Virtual Keyboard (اسفل شاشه الدخول بالعرض)
                _buildTouchscreenKeyboard(isEng, isDark),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
),
);
  }

  Widget _buildTouchscreenKeyboard(bool isEng, [bool isDark = false]) {
    final numbersRow = _isArabicKeyboard
        ? ['١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '٠']
        : ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

    final letterRow1 = _isArabicKeyboard
        ? ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج', 'د']
        : ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];

    final letterRow2 = _isArabicKeyboard
        ? ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط']
        : ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];

    final letterRow3 = _isArabicKeyboard
        ? ['ئ', 'ء', 'ؤ', 'ر', 'لا', 'ى', 'ة', 'و', 'ز', 'ظ']
        : ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 0: Number Row
              Row(
                children: numbersRow.map((numStr) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: numStr,
                        bgColor: isDark ? const Color(0xFF334155) : Colors.purple.shade50,
                        textColor: isDark ? const Color(0xFFF1F5F9) : Colors.purple.shade900,
                        fontSize: 18,
                        onPressed: () => _onVirtualKeyPress(numStr),
                        isDark: isDark,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 3),

              // Row 1: Top Letter Row (QWERTY / ضصثقفغعهخحجد)
              Row(
                children: letterRow1.map((char) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: _isArabicKeyboard ? char : char.toUpperCase(),
                        bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        textColor: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        onPressed: () => _onVirtualKeyPress(char),
                        isDark: isDark,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 3),

              // Row 2: Middle Letter Row (ASDFGHJKL / شسيبلاتنمكط)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: letterRow2.map((char) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: _buildKeyCap(
                          label: _isArabicKeyboard ? char : char.toUpperCase(),
                          bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          textColor: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                          onPressed: () => _onVirtualKeyPress(char),
                          isDark: isDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 3),

              // Row 3: Bottom Letter Row (ZXCVBNM / ئءؤرلاىةوزظ)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: letterRow3.map((char) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: _buildKeyCap(
                          label: _isArabicKeyboard ? char : char.toUpperCase(),
                          bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          textColor: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                          onPressed: () => _onVirtualKeyPress(char),
                          isDark: isDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 5),

              // Row 4: Controls, Language Switcher & Spacebar Row
              Row(
                children: [
                  // Language Switcher Key (اسفل الكيبورد)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: _isArabicKeyboard ? '🌐 EN' : '🌐 عربي',
                        bgColor: _isArabicKeyboard
                            ? (isDark ? const Color(0xFF134E4A) : Colors.teal.shade100)
                            : (isDark ? const Color(0xFF581C87) : Colors.purple.shade100),
                        textColor: _isArabicKeyboard
                            ? (isDark ? const Color(0xFF5EEAD4) : Colors.teal.shade900)
                            : (isDark ? const Color(0xFFE9D5FF) : Colors.purple.shade900),
                        fontSize: 13,
                        onPressed: () => setState(() => _isArabicKeyboard = !_isArabicKeyboard),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  // Spacebar
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: isEng ? 'Space' : 'مسافة',
                        bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        textColor: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        onPressed: () => _onVirtualKeyPress(' '),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  // Backspace
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: isEng ? 'Delete ⌫' : 'مسح ⌫',
                        bgColor: isDark ? const Color(0xFF78350F) : Colors.amber.shade100,
                        textColor: isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                        fontSize: 12,
                        icon: Icons.backspace_outlined,
                        onPressed: _onVirtualKeyBackspace,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  // Clear All
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: isEng ? 'Clear 🧹' : 'تفريغ 🧹',
                        bgColor: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100,
                        textColor: isDark ? const Color(0xFFFECACA) : Colors.red.shade900,
                        fontSize: 12,
                        icon: Icons.clear_all_rounded,
                        onPressed: _onVirtualKeyClear,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  // Submit Login
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildKeyCap(
                        label: isEng ? 'Sign In 🚪' : 'دخول 🚪',
                        bgColor: AppColors.primary,
                        textColor: Colors.white,
                        fontSize: 13,
                        icon: Icons.check_circle_rounded,
                        onPressed: _handleLogin,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyCap({
    required String label,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onPressed,
    double fontSize = 14,
    IconData? icon,
    bool isDark = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : Colors.black.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            offset: const Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: textColor),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
