import 'package:flutter/material.dart';
import '../settings/settings_repository.dart';
import '../../services/waiter_api_client.dart';
import 'waiter_user_login_screen.dart';

class WaiterConnectScreen extends StatefulWidget {
  const WaiterConnectScreen({super.key});

  @override
  State<WaiterConnectScreen> createState() => _WaiterConnectScreenState();
}

class _WaiterConnectScreenState extends State<WaiterConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final SettingsRepository _settingsRepository = SettingsRepository();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedServer();
  }

  Future<void> _loadSavedServer() async {
    try {
      final settings = await _settingsRepository.getAllSettings();
      final savedIp = settings['waiter_server_ip'];
      if (mounted && savedIp != null && savedIp.trim().isNotEmpty) {
        setState(() {
          _serverController.text = savedIp.trim();
        });
      } else if (mounted) {
        setState(() {
          _serverController.text = '192.168.120.128';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverController.text = '192.168.120.128';
        });
      }
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final serverInput = _serverController.text.trim();

    final baseUrl = WaiterApiClient.formatBaseUrl(serverInput, '8080');
    final client = WaiterApiClient(baseUrl: baseUrl);

    final connResult = await client.checkConnectionDetailed();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (connResult.isSuccess) {
      await _settingsRepository.saveSetting('waiter_server_ip', serverInput);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaiterUserLoginScreen(apiClient: client),
        ),
      );
    } else {
      final detail = connResult.errorMessage ?? 'تعذر الوصول';
      setState(() {
        _errorMessage = 'تعذر الاتصال بسيرفر الكاشير ($baseUrl).\n'
            'التفاصيل: $detail\n\n'
            'تأكد من أن الموبايل وجهاز الكاشير متصلان بنفس شبكة الـ Wi-Fi.';
      });
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text(
          'تطبيق الموبايل - عنوان السيرفر',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.dns_rounded,
                      size: 52,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'كتابة عنوان السيرفر',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أدخل عنوان IP السيرفر للربط بالنظام (يتم حفظه تلقائياً)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _serverController,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.text,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'عنوان IP السيرفر (Server IP)',
                      hintText: '192.168.120.128',
                      labelStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFF374151),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'يرجى كتابة عنوان السيرفر' : null,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded),
                                SizedBox(width: 10),
                                Text(
                                  'دخول والاتصال بالسيرفر',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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
