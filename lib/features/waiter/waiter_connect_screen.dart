import 'package:flutter/material.dart';
import '../../services/network_service.dart';
import '../../services/waiter_api_client.dart';
import 'waiter_user_login_screen.dart';

class WaiterConnectScreen extends StatefulWidget {
  const WaiterConnectScreen({super.key});

  @override
  State<WaiterConnectScreen> createState() => _WaiterConnectScreenState();
}

class _WaiterConnectScreenState extends State<WaiterConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController(text: '192.168.120.128');
  final _portController = TextEditingController(text: '8080');
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String? _myIp;

  @override
  void initState() {
    super.initState();
    _fetchMyIp();
  }

  Future<void> _fetchMyIp() async {
    final ip = await NetworkService.getLocalIpAddress();
    if (mounted && ip != null) {
      setState(() {
        _myIp = ip;
        final parts = ip.split('.');
        if (parts.length == 4) {
          _ipController.text = '${parts[0]}.${parts[1]}.${parts[2]}.128';
        }
      });
    }
  }

  Future<void> _autoSearchCashier() async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    final discoveredIp = await WaiterApiClient.autoDiscoverCashierServer();

    if (!mounted) return;

    setState(() => _isSearching = false);

    if (discoveredIp != null) {
      _ipController.text = discoveredIp;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم العثور تلقائياً على سيرفر الكاشير ($discoveredIp) 🎉'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _connect();
    } else {
      setState(() {
        _errorMessage = 'لم يتم العثور تلقائياً. تأكد أن الموبايل والكمبيوتر متصلان بنفس شبكة الـ Wi-Fi مع إيقاف بيانات الهاتف (4G/5G).';
      });
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    final baseUrl = WaiterApiClient.formatBaseUrl(ip, port);
    final client = WaiterApiClient(baseUrl: baseUrl);

    final connResult = await client.checkConnectionDetailed();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (connResult.isSuccess) {
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
            'تفاصيل الخطأ: $detail\n\n'
            '📌 خطوتان سريعتان لحل المشكلة:\n'
            '1. قم بإيقاف "بيانات الهاتف (4G/5G)" في الموبايل وترك الـ Wi-Fi فقط.\n'
            '2. تأكد من إيقاف جدار الحماية (Firewall/VPN) في جهاز الكمبيوتر.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text('تطبيق الموبايل - الربط بالسيرفر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_tethering_rounded,
                      size: 48,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الربط بسيرفر الكاشير',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أدخل عنوان IP جهاز الكاشير للاتصال بقاعدة البيانات',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                  if (_myIp != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'عنوان IP الموبايل الحالي: $_myIp',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Auto search button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isSearching ? null : _autoSearchCashier,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSearching
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                          : const Icon(Icons.search, size: 18),
                      label: Text(_isSearching ? 'جاري فحص الـ Wi-Fi...' : '🔍 البحث التلقائي عن سيرفر الكاشير'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _ipController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'عنوان IP الكاشير',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(Icons.dns, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: const Color(0xFF374151),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _portController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المنفذ (Port)',
                            labelStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFF374151),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                        ),
                      ),
                    ],
                  ),

                  // Quick IP fill chips
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('192.168.120.128', style: TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: const Color(0xFF374151),
                        onPressed: () {
                          setState(() {
                            _ipController.text = '192.168.120.128';
                          });
                        },
                      ),
                    ],
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
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
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.link),
                                SizedBox(width: 8),
                                Text(
                                  'الربط بسيرفر الكاشير',
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
