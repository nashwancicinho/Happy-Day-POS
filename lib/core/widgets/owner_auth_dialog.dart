import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/settings/settings_provider.dart';
import 'top_notification.dart';

class OwnerAuthDialog extends StatefulWidget {
  final String title;
  final String reason;

  const OwnerAuthDialog({
    super.key,
    required this.title,
    required this.reason,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String reason,
  }) async {
    final authProvider = context.read<AuthProvider>();
    // Software Owners pass automatically
    if (authProvider.isOwner) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => OwnerAuthDialog(title: title, reason: reason),
    );

    return result ?? false;
  }

  @override
  State<OwnerAuthDialog> createState() => _OwnerAuthDialogState();
}

class _OwnerAuthDialogState extends State<OwnerAuthDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _errorMessage;
  bool _obscureText = true;

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSubmit() async {
    final pin = _pinController.text.trim();
    final username = _usernameController.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال الرمز السري لمالك البرنامج';
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final isValid = await authProvider.verifyOwnerCredentials(
      username.isNotEmpty ? username : 'owner',
      pin,
    );

    if (!mounted) return;

    if (isValid) {
      final isEng = context.read<SettingsProvider>().isEnglish;
      TopNotification.showSuccess(
        context,
        isEng ? 'Authorized by Software Owner ✅' : 'تم تأكيد إذن مالك البرنامج بنجاح ✅',
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'اسم المستخدم أو الرمز السري لمالك البرنامج غير صحيح! لا تملك صلاحية توليد الأكواد.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title.isNotEmpty
                  ? widget.title
                  : (isEng ? 'Software Owner Authorization Required 🔒' : 'إذن مالك البرنامج مطلوب 🔒'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.reason,
                      style: TextStyle(fontSize: 12.5, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: isEng ? 'Owner Username (e.g. owner)' : 'اسم مستخدم مالك البرنامج (مثال: owner)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              obscureText: _obscureText,
              keyboardType: TextInputType.visiblePassword,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isEng ? 'Owner Password / PIN' : 'كلمة المرور أو الرمز السري لمالك البرنامج',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _verifyAndSubmit(),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(isEng ? 'Cancel' : 'إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _verifyAndSubmit,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(
            isEng ? 'Authorize Owner' : 'تأكيد وإذن المالك 🔒',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
