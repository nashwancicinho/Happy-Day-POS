import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/settings/settings_provider.dart';
import 'top_notification.dart';

class ManagerAuthDialog extends StatefulWidget {
  final String title;
  final String reason;

  const ManagerAuthDialog({
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
    // Managers always pass automatically
    if (authProvider.isManager) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => ManagerAuthDialog(title: title, reason: reason),
    );

    return result ?? false;
  }

  @override
  State<ManagerAuthDialog> createState() => _ManagerAuthDialogState();
}

class _ManagerAuthDialogState extends State<ManagerAuthDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  bool _obscureText = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyAndSubmit() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال الرمز السري للمدير';
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final isValid = authProvider.loginAsManager(pin);

    if (isValid) {
      final isEng = context.read<SettingsProvider>().isEnglish;
      TopNotification.showSuccess(
        context,
        isEng ? 'Authorized by Manager ✅' : 'تم تأكيد إذن المدير بنجاح ✅',
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'الرمز السري للمدير غير صحيح!';
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
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title.isNotEmpty
                  ? widget.title
                  : (isEng ? 'Manager Authorization Required 🔒' : 'إذن المدير مطلوب 🔒'),
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.reason,
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEng ? 'Enter Manager PIN / Password:' : 'أدخل الرمز السري للمدير للموافقة:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinController,
              obscureText: _obscureText,
              keyboardType: TextInputType.visiblePassword,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isEng ? 'Manager Password / PIN' : 'كلمة المرور أو الرمز السري للمدير',
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
            backgroundColor: Colors.amber.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _verifyAndSubmit,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(
            isEng ? 'Authorize' : 'تأكيد وإذن المدير',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
