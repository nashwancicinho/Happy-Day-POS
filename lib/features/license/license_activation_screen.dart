import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/license_service.dart';
import '../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isEng = settings.isEnglish;
    final isDark = settings.isDarkMode;

    final bodyContent = _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon & Status Badge
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _licenseInfo!.isActivated
                            ? (isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50)
                            : (_licenseInfo!.isExpired
                                ? (isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade50)
                                : (isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade50)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _licenseInfo!.isActivated
                            ? Icons.verified_user_rounded
                            : (_licenseInfo!.isExpired ? Icons.lock_clock_rounded : Icons.hourglass_top_rounded),
                        size: 48,
                        color: _licenseInfo!.isActivated
                            ? (isDark ? const Color(0xFF34D399) : Colors.green)
                            : (_licenseInfo!.isExpired ? (isDark ? const Color(0xFFF87171) : Colors.red) : (isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800)),
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
                            ? (isDark ? const Color(0xFF34D399) : Colors.green.shade800)
                            : (_licenseInfo!.isExpired ? (isDark ? const Color(0xFFF87171) : Colors.red.shade800) : (isDark ? const Color(0xFFFBBF24) : Colors.amber.shade900)),
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
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, height: 1.4),
                    ),

                    const SizedBox(height: 20),

                    // Customer Machine ID Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF374151) : Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isEng ? 'Machine ID Code:' : 'رقم معرّف هذا الجهاز (Machine ID):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  foregroundColor: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
                                  side: BorderSide(color: isDark ? const Color(0xFF4B5563) : Colors.grey.shade300),
                                ),
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFFBBF24) : AppColors.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEng
                                ? 'Send this Machine ID code via WhatsApp to get your custom activation key.'
                                : 'أرسل رقم الجهاز أعلاه للمالك عبر الواتساب للحصول على كود التفعيل المخصص لهذا الجهاز فقط.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Activation Form Section
                    TextField(
                      controller: _keyController,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: isEng ? 'Annual Subscription Key' : 'كود التفعيل السنوي المخصص (Activation Key)',
                        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                        hintText: 'HD-XXXX-YYYY-ZZZZ',
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                        prefixIcon: Icon(Icons.key, color: isDark ? const Color(0xFFFBBF24) : AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF4B5563) : Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF4B5563) : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF111827) : Colors.grey.shade50,
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
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(isEng ? 'Software License & Subscription' : 'تفعيل اشتراك البرنامج والترخيص'),
        centerTitle: true,
      ),
      body: bodyContent,
    );
  }
}
