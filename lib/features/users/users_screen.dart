import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../models/user.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_provider.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isEng = context.watch<SettingsProvider>().isEnglish;
    final users = authProvider.users;

    String formatRole(String role) {
      if (!isEng) return role;
      if (role == 'مدير') return 'Manager';
      if (role == 'كاشير') return 'Cashier';
      return role;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEng ? 'Users & Permissions Management' : 'إدارة المستخدمين والموظفين والصلاحيات'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleAddUser(context, authProvider),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add),
        label: Text(isEng ? 'Add New User 👤+' : 'إضافة اسم مستخدم جديد'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manager Permissions Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: authProvider.isManager ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: authProvider.isManager ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    authProvider.isManager ? Icons.verified_user : Icons.lock,
                    color: authProvider.isManager ? Colors.green.shade800 : Colors.orange.shade800,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.isManager
                              ? (isEng ? 'You are logged in with System Manager privileges' : 'أنت مسجل الدخول بصلاحية مدير النظام')
                              : (isEng ? 'You are logged in with Cashier privileges' : 'أنت مسجل الدخول بصلاحية كاشير'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: authProvider.isManager ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProvider.isManager
                              ? (isEng ? 'You can add new users, delete existing users, or edit permissions.' : 'يمكنك إضافة أسماء مستخدمين جدد أو مسح مستخدمين حاليين وتعديل الصلاحيات.')
                              : (isEng ? 'Note: Adding or deleting users is restricted to Manager privileges.' : 'ملاحظة: إضافة اسم جديد أو مسح اسم مستخدم محصورة لصلاحيات المدير فقط.'),
                          style: TextStyle(
                            fontSize: 13,
                            color: authProvider.isManager ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Registered Users List
            Text(
              isEng ? 'Registered System Users List:' : 'قائمة المستخدمين المسجلين في النظام:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isCurrentSession = authProvider.currentUser?.id == user.id;

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: user.isManager ? Colors.purple.shade100 : Colors.blue.shade100,
                              child: Icon(
                                user.isManager ? Icons.admin_panel_settings : Icons.person,
                                color: user.isManager ? Colors.purple.shade900 : Colors.blue.shade900,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                ),
                                if (isCurrentSession) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isEng ? 'Current Account' : 'حسابك الحالي',
                                      style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                isEng
                                    ? 'PIN Code: ••••••  |  Role: ${formatRole(user.role)}'
                                    : 'الرمز السري: ••••••  |  الدور: ${user.role}',
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(formatRole(user.role)),
                                  backgroundColor: user.isManager ? Colors.purple.shade50 : Colors.blue.shade50,
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: user.isManager ? Colors.purple.shade900 : Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: isEng ? 'Delete User' : 'مسح اسم المستخدم',
                                  onPressed: () => _handleDeleteUser(context, authProvider, user),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAddUser(BuildContext context, AuthProvider authProvider) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    if (!authProvider.isManager) {
      TopNotification.showError(
        context,
        isEng
            ? '🛑 Sorry! Adding new users is restricted to Manager privileges only.'
            : '🛑 عذراً! إضافة اسم المستخدم محصورة لصلاحيات المدير فقط.',
      );
      return;
    }

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'كاشير';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(isEng ? 'Add New User' : 'إضافة مستخدم جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: isEng ? 'Username *' : 'اسم المستخدم *',
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isEng ? 'PIN Code / Password *' : 'الرقم السري *',
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: InputDecoration(labelText: isEng ? 'Permission Role' : 'نوع الصلاحية'),
                    items: [
                      DropdownMenuItem(value: 'كاشير', child: Text(isEng ? 'Cashier (Regular Staff)' : 'كاشير (مستخدم عادي)')),
                      DropdownMenuItem(value: 'مدير', child: Text(isEng ? 'Manager (Full Access)' : 'مدير (صلاحية كاملة)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(isEng ? 'Cancel' : 'إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final username = usernameController.text.trim();
                    final password = passwordController.text.trim();

                    if (username.isEmpty || password.isEmpty) {
                      TopNotification.showWarning(
                        ctx,
                        isEng ? 'Please enter username and PIN code' : 'يرجى كتابة اسم المستخدم والرقم السري',
                      );
                      return;
                    }

                    try {
                      await authProvider.addUser(UserModel(
                        username: username,
                        password: password,
                        role: selectedRole,
                      ));
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        TopNotification.showSuccess(
                          context,
                          isEng ? 'User added successfully! 🎉' : 'تمت إضافة المستخدم بنجاح 🎉',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        TopNotification.showError(ctx, 'خطأ: $e');
                      }
                    }
                  },
                  child: Text(isEng ? 'Add User' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleDeleteUser(BuildContext context, AuthProvider authProvider, UserModel user) {
    final isEng = context.read<SettingsProvider>().isEnglish;
    if (!authProvider.isManager) {
      TopNotification.showError(
        context,
        isEng ? '🛑 Delete restricted to Manager privileges only.' : '🛑 عذراً! مسح المستخدم محصور لصلاحيات المدير فقط.',
      );
      return;
    }

    if (authProvider.currentUser?.id == user.id) {
      TopNotification.showWarning(
        context,
        isEng ? '⚠️ Cannot delete currently active logged in account.' : '⚠️ لا يمكنك مسح الحساب الذي تستخدمه حالياً لتدوين الدخول!',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEng ? 'Confirm Delete User' : 'تأكيد مسح المستخدم'),
          content: Text(
            isEng
                ? 'Are you sure you want to delete user (${user.username})?'
                : 'هل أنت متأكد من مسح المستخدم (${user.username})؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isEng ? 'Cancel' : 'إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await authProvider.deleteUser(user.id!);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    TopNotification.showSuccess(
                      context,
                      isEng ? 'User deleted successfully 🗑️' : 'تم مسح المستخدم بنجاح 🗑️',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    TopNotification.showError(ctx, 'خطأ: $e');
                  }
                }
              },
              child: Text(isEng ? 'Delete User' : 'مسح', style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
