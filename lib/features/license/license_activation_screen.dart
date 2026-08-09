import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/owner_auth_dialog.dart';
import '../../core/widgets/top_notification.dart';
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
  final _adminMachineIdController = TextEditingController();
  bool _isLoading = true;
  bool _isActivating = false;
  LicenseInfo? _licenseInfo;

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
        _adminMachineIdController.text = info.machineId;
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
        TopNotification.showSuccess(context, '🎉 تم تفعيل الاشتراك السنوي بنجاح لهذا الجهاز لـ 365 يوماً!');
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
          '❌ كود التفعيل غير صحيح أو مخصص لجهاز آخر! تأكد من الكود الخاص بهذا الجهاز.',
        );
      }
    }
  }

  void _showOwnerKeyGeneratorDialog() async {
    final isEng = context.read<SettingsProvider>().isEnglish;
    final authorized = await OwnerAuthDialog.show(
      context,
      title: 'رمز إذن مالك البرنامج (المبرمج) 🔒',
      reason: 'توليد أكواد التفعيل السنوية مقتصر فقط على (مالك البرنامج). مدير المطعم لا يملك صلاحية توليد الأكواد.',
    );

    if (authorized != true || !mounted) return;

    String? generatedKey;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Colors.purple),
              const SizedBox(width: 10),
              Text(
                isEng ? 'Owner Single-Use Key Generator 🔑' : 'أداة توليد كود مفرد لجهاز عميل 🔑',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEng
                    ? 'Enter customer Machine ID to generate a 1-time annual key locked to their PC:'
                    : 'أدخل رقم معرّف جهاز العميل (Machine ID) لتوليد كود تفعيل سنوي يعمل على جهازه فقط:',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _adminMachineIdController,
                decoration: InputDecoration(
                  labelText: isEng ? 'Customer Machine ID' : 'رقم جهاز العميل (Machine ID)',
                  hintText: 'HD-XXXX-YYYY',
                  prefixIcon: const Icon(Icons.important_devices, color: Colors.purple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final targetId = _adminMachineIdController.text.trim();
                    if (targetId.isEmpty) {
                      TopNotification.showWarning(dialogCtx, 'يرجى كتابة رقم جهاز العميل أولاً!');
                      return;
                    }
                    final key = LicenseService.generateAnnualKeyForMachine(targetId);
                    setDialogState(() {
                      generatedKey = key;
                    });
                    Clipboard.setData(ClipboardData(text: key));
                    TopNotification.showSuccess(dialogCtx, 'تم توليد كود التفعيل المخصص ونسخه للحافظة! 🔑');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.key_rounded),
                  label: Text(isEng ? 'Generate Key for Machine' : 'توليد كود التفعيل لهذا الجهاز 🔑'),
                ),
              ),
              if (generatedKey != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text('كود التفعيل السنوي المخصص للعميل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                      const SizedBox(height: 4),
                      SelectableText(
                        generatedKey!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      const Text('(تم نسخ الكود للحافظة تلقائياً لإرساله بالواتساب)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(isEng ? 'Close' : 'إغلاق'),
            ),
          ],
        ),
      ),
    );
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

                    const SizedBox(height: 20),

                    // Customer Machine ID Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEng ? 'Machine ID Code:' : 'رقم معرّف هذا الجهاز (Machine ID):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _licenseInfo!.machineId));
                                  TopNotification.showSuccess(context, 'تم نسخ رقم الجهاز للحافظة! 📋');
                                },
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: Text(isEng ? 'Copy ID' : 'نسخ رقم الجهاز 📋', style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _licenseInfo!.machineId,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEng
                                ? 'Send this Machine ID code via WhatsApp to get your custom activation key.'
                                : 'أرسل رقم الجهاز أعلاه للمالك عبر الواتساب للحصول على كود التفعيل المخصص لهذا الجهاز فقط.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Activation Form Section
                    TextField(
                      controller: _keyController,
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Annual Subscription Key' : 'كود التفعيل السنوي المخصص (Activation Key)',
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

                    const SizedBox(height: 20),

                    // Admin Secret Key Generator (Protected by Manager Password)
                    TextButton.icon(
                      onPressed: _showOwnerKeyGeneratorDialog,
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.grey),
                      label: Text(
                        isEng ? 'Owner Key Generator (Locked) 🔒' : 'توليد كود جهاز لعميل (خاص بمالك النظام 🔒)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
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
