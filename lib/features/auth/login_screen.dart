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
  String? _errorMessage;

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordFocused = true;

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
                isEng ? 'System database is empty. Please enter new Manager name & PIN code to get started.' : 'النظام فارغ حالياً. يرجى كتابة اسم ورمز المدير الجديد للبدء.',
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
                        isEng ? '1. Manager Account Credentials' : '1. بيانات حساب المدير',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _initManagerNameController,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Manager Name *' : 'اسم المدير *',
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Login Card (Moved Higher Up)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Logo & Branding
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEng ? 'Happy Day POS System' : 'نظام هابي داي لنقاط البيع',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  isEng ? 'Please sign in to continue' : 'يرجى تسجيل الدخول لمتابعة العمل',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Username Selector Dropdown / Field
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
                            onTap: () => setState(() => _isPasswordFocused = false),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: isEng ? 'Username or Manager Name' : 'اسم المستخدم أو المدير',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              filled: true,
                              fillColor: Colors.white,
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
                          onTap: () => setState(() => _isPasswordFocused = true),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
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
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                                  label: Text(
                                    isEng ? 'Add User 👤+' : 'إضافة مستخدم',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                _buildTouchscreenKeyboard(isEng),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTouchscreenKeyboard(bool isEng) {
    final activeFieldName = _isPasswordFocused
        ? (isEng ? 'PIN Code / Password' : 'الرقم السري / كلمة المرور')
        : (isEng ? 'Username' : 'اسم المستخدم');

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active Focus Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      isEng ? 'Touchscreen Virtual Keyboard ⌨️' : 'لوحة مفاتيح الشاشة باللمس ⌨️',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEng ? 'Target: $activeFieldName' : 'الكتابة في: $activeFieldName',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Number Row (1 2 3 4 5 6 7 8 9 0)
            Row(
              children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'].map((numStr) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton(
                      onPressed: () => _onVirtualKeyPress(numStr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(numStr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 2),

            // QWERTY Row
            Row(
              children: ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'].map((char) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton(
                      onPressed: () => _onVirtualKeyPress(char),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(char.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 2),

            // ASDF Row
            Row(
              children: ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'].map((char) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton(
                      onPressed: () => _onVirtualKeyPress(char),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(char.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 2),

            // ZXCV & Action Row (Z X C V B N M  Backspace Clear Enter)
            Row(
              children: [
                ...['z', 'x', 'c', 'v', 'b', 'n', 'm'].map((char) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: ElevatedButton(
                        onPressed: () => _onVirtualKeyPress(char),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(char.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }),
                // Backspace
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton.icon(
                      onPressed: _onVirtualKeyBackspace,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade100,
                        foregroundColor: Colors.amber.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.backspace_outlined, size: 16),
                      label: Text(isEng ? 'Delete' : 'مسح ⌫', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                // Clear
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton.icon(
                      onPressed: _onVirtualKeyClear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.clear_all_rounded, size: 16),
                      label: Text(isEng ? 'Clear' : 'تفريغ 🧹', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                // Submit Login
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: ElevatedButton.icon(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(isEng ? 'Sign In 🚪' : 'دخول 🚪', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
