import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notification.dart';
import '../../core/widgets/manager_auth_dialog.dart';
import '../settings/settings_provider.dart';

class LicenseActivationScreen extends StatefulWidget {
  final bool isModalDialog;
  final VoidCallback? onActivated;

  const LicenseActivationScreen({
    super.key,
    this.isModalDialog = false,
    this.onActivated,
  });

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = true;
  bool _isActivating = false;
  LicenseInfo? _licenseInfo;
  String? _generatedSampleKey;

  @override
  void initState() {
    super.initState();
    _loadLicenseStatus();
  }

  Future<void> _loadLicenseStatus() async {
    setState(() => _isLoading = true);
    final info = await LicenseService.instance.initAndGetLicenseInfo();
    if (mounted) {
      setState(() {
        _licenseInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      TopNotification.showWarning(context, 'يرجى إدخال كود التفعيل السنوي أولاً!');
      return;
    }

    setState(() => _isActivating = true);

    final success = await LicenseService.instance.activateLicense(key);

    if (!mounted) return;
    setState(() => _isActivating = false);

    if (success) {
      if (mounted) {
        TopNotification.showSuccess(context, '🎉 تم تفعيل الاشتراك السنوي بنجاح لـ 365 يوماً!');
      }
      await _loadLicenseStatus();
      if (!mounted) return;
      widget.onActivated?.call();
      if (widget.isModalDialog && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        TopNotification.showError(
          context,
          '❌ كود التفعيل غير صحيح! تأكد من إدخال الرمز بالصيغة الصحيحة (مثال: HD-XXXX-YYYY-ZZZZ)',
        );
      }
    }
  }

  void _generateAdminSampleKey() {
    final key = LicenseService.generateAnnualKey();
    setState(() {
      _generatedSampleKey = key;
      _keyController.text = key;
    });
    Clipboard.setData(ClipboardData(text: key));
    TopNotification.showSuccess(context, 'تم توليد كود تفعيل سنوي ونسخه للحافظة: $key 🔑');
  }

  @override
  Widget build(BuildContext context) {
    final isEng = context.watch<SettingsProvider>().isEnglish;

    final bodyContent = _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon & Status Badge
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _licenseInfo!.isActivated
                            ? Colors.green.shade50
                            : (_licenseInfo!.isExpired ? Colors.red.shade50 : Colors.amber.shade50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _licenseInfo!.isActivated
                            ? Icons.verified_user_rounded
                            : (_licenseInfo!.isExpired ? Icons.lock_clock_rounded : Icons.hourglass_top_rounded),
                        size: 48,
                        color: _licenseInfo!.isActivated
                            ? Colors.green
                            : (_licenseInfo!.isExpired ? Colors.red : Colors.amber.shade800),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      _licenseInfo!.isActivated
                          ? (isEng ? 'Annual Subscription Active ✅' : 'الاشتراك السنوي مفعّل ✅')
                          : (_licenseInfo!.isExpired
                              ? (isEng ? 'Trial Expired 🔒' : 'انتهت الفترة التجريبية (30 يوم) 🔒')
                              : (isEng ? 'Free Trial Period ⏳' : 'الفترة التجريبية المجانية (30 يوم) ⏳')),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _licenseInfo!.isActivated
                            ? Colors.green.shade800
                            : (_licenseInfo!.isExpired ? Colors.red.shade800 : Colors.amber.shade900),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _licenseInfo!.isActivated
                          ? (isEng
                              ? 'Subscription expires on: ${_licenseInfo!.expiryDate?.toString().split(' ').first ?? ''} (${_licenseInfo!.daysRemaining} days remaining)'
                              : 'ينتهي الاشتراك السنوي في: ${_licenseInfo!.expiryDate?.toString().split(' ').first ?? ''} (متبقي ${_licenseInfo!.daysRemaining} يوماً)')
                          : (_licenseInfo!.isExpired
                              ? (isEng
                                  ? 'Your 30-day free trial has finished. Please enter your annual subscription key to unlock POS features.'
                                  : 'لقد انتهت الفترة التجريبية المجانية للنظام (30 يوم). يرجى إدخال كود التفعيل السنوي للاستمرار في استخدام البرنامج.')
                              : (isEng
                                  ? 'Free trial active: ${_licenseInfo!.daysRemaining} days remaining out of 30 days.'
                                  : 'الفترة التجريبية المجانية شغالة: متبقي ${_licenseInfo!.daysRemaining} يوماً من أصل 30 يوماً.')),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                    ),

                    const SizedBox(height: 28),

                    // Activation Form Section
                    TextField(
                      controller: _keyController,
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Annual Subscription Key' : 'كود التفعيل السنوي (Activation Key)',
                        hintText: 'HD-XXXX-YYYY-ZZZZ',
                        prefixIcon: Icon(Icons.key, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isActivating ? null : _submitActivation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        icon: _isActivating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(
                          isEng ? 'Activate Annual Subscription' : 'تفعيل الاشتراك السنوي الآن 🚀',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Customer Support Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.support_agent_rounded, color: Colors.blue, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isEng
                                      ? 'To purchase or request an annual subscription code, please contact system support.'
                                      : 'للحصول على كود التفعيل السنوي وتجديد الاشتراك، يرجى التواصل مع خدمة العملاء أو مالك النظام.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Admin Secret Key Generator (Protected by Manager Password)
                    TextButton.icon(
                      onPressed: () async {
                        final authorized = await ManagerAuthDialog.show(
                          context,
                          title: 'رمز أمان صاحب النظام 🔒',
                          reason: 'أداة توليد كود التفعيل السنوي خاصة بمالك النظام وتتطلب كلمة سر المدير',
                        );
                        if (authorized == true) {
                          _generateAdminSampleKey();
                        }
                      },
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.grey),
                      label: Text(
                        isEng ? 'Owner / Admin Generator 🔒' : 'توليد كود تفعيل (خاص بمالك النظام 🔒)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    if (_generatedSampleKey != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'كود التفعيل المولد: $_generatedSampleKey',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

    if (widget.isModalDialog) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(isEng ? 'Software License & Subscription' : 'تفعيل اشتراك البرنامج والترخيص'),
        centerTitle: true,
      ),
      body: bodyContent,
    );
  }
}
