import 'package:flutter/material.dart';
import '../../services/local_server_service.dart';
import '../../services/network_service.dart';

class SyncQrDialog extends StatefulWidget {
  const SyncQrDialog({super.key});

  @override
  State<SyncQrDialog> createState() => _SyncQrDialogState();
}

class _SyncQrDialogState extends State<SyncQrDialog> {
  final LocalServerService _serverService = LocalServerService.instance;
  List<String> _allIps = [];

  @override
  void initState() {
    super.initState();
    _loadIps();
  }

  Future<void> _loadIps() async {
    if (!_serverService.isRunning) {
      await _serverService.startServer();
    }
    final ips = await NetworkService.getAllLocalIpAddresses();
    if (mounted) {
      setState(() {
        _allIps = ips;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _serverService,
      builder: (context, _) {
        final isRunning = _serverService.isRunning;
        final primaryIp = _allIps.isNotEmpty ? _allIps.first : (_serverService.serverIp ?? 'جاري البحث...');
        final port = _serverService.port;

        return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1F2937),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 28),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ربط تطبيق النادل (Waiter App)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isRunning ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (isRunning ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    isRunning ? Icons.check_circle : Icons.error,
                    color: isRunning ? const Color(0xFF10B981) : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRunning ? 'السيرفر المحلي شغال وجاهز للربط' : 'السيرفر المحلي متوقف',
                      style: TextStyle(
                        color: isRunning ? const Color(0xFF10B981) : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'عنوان الـ IP الرئيسي لاتصال الموبايل:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Primary IP Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SelectableText(
                    primaryIp,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('المنفذ (Port): $port', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            if (_allIps.length > 1) ...[
              const SizedBox(height: 12),
              const Text(
                'عناوين شبكات أخرى متاحة على هذا الجهاز:',
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _allIps.skip(1).map((ip) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: SelectableText(
                      '$ip:$port',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Instructions
            const Text(
              'خطوات الربط بالموبايل:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildStepRow('1', 'تأكد أن الموبايل والكاشير متصلان بنفس شبكة الـ Wi-Fi.'),
            _buildStepRow('2', 'افتح تطبيق النادل على الموبايل.'),
            _buildStepRow('3', 'أدخل عنوان الـ IP اعلاه والمنفذ 8080 واضغط تسجيل الدخول.'),
            _buildStepRow('4', 'تستطيع الآن إرسال طلبات الطاولات مباشرة للكاشير!'),
          ],
        ),
      ),
      actions: [
        if (!isRunning)
          ElevatedButton.icon(
            onPressed: () async {
              await _serverService.startServer();
              await _loadIps();
              setState(() {});
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('تشغيل السيرفر'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
      },
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
