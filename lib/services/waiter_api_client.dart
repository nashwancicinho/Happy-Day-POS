import 'dart:convert';
import 'dart:io';
import 'network_service.dart';

class ConnectionResult {
  final bool isSuccess;
  final String? errorMessage;

  ConnectionResult({required this.isSuccess, this.errorMessage});
}

class WaiterApiClient {
  final String baseUrl;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

  WaiterApiClient({required this.baseUrl});

  static String formatBaseUrl(String ip, String port) {
    var cleanIp = ip.trim().replaceAll(' ', '');
    if (!cleanIp.startsWith('http://') && !cleanIp.startsWith('https://')) {
      cleanIp = 'http://$cleanIp';
    }
    if (cleanIp.endsWith('/')) {
      cleanIp = cleanIp.substring(0, cleanIp.length - 1);
    }
    final portMatch = RegExp(r':\d+$');
    if (!portMatch.hasMatch(cleanIp)) {
      cleanIp = '$cleanIp:${port.trim()}';
    }
    return cleanIp;
  }

  Future<ConnectionResult> checkConnectionDetailed() async {
    try {
      final uri = Uri.parse('$baseUrl/api/info');
      final request = await _client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data['status'] == 'online') {
          return ConnectionResult(isSuccess: true);
        }
        return ConnectionResult(isSuccess: false, errorMessage: 'السيرفر استجاب بحالة: ${data['status']}');
      }
      return ConnectionResult(isSuccess: false, errorMessage: 'السيرفر رَدَّ بكود خطا: ${response.statusCode}');
    } catch (e) {
      return ConnectionResult(isSuccess: false, errorMessage: '$e');
    }
  }

  Future<bool> checkConnection() async {
    final result = await checkConnectionDetailed();
    return result.isSuccess;
  }

  static Future<String?> autoDiscoverCashierServer() async {
    final localIp = await NetworkService.getLocalIpAddress();
    if (localIp == null || !localIp.contains('.')) return null;

    final parts = localIp.split('.');
    if (parts.length != 4) return null;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final portsToScan = [8080, 8081, 8082, 8085];
    final priorityOctets = [128, 100, 101, 102, 103, 104, 105, 1, 2, 3, 50, 200];

    for (final octet in priorityOctets) {
      final targetIp = '$subnet.$octet';
      for (final port in portsToScan) {
        final result = await _testServerCandidate(targetIp, port);
        if (result != null) return result;
      }
    }

    for (int batch = 1; batch <= 254; batch += 20) {
      final futures = <Future<String?>>[];
      for (int i = batch; i < batch + 20 && i <= 254; i++) {
        final targetIp = '$subnet.$i';
        for (final port in portsToScan) {
          futures.add(_testServerCandidate(targetIp, port));
        }
      }
      try {
        final batchResults = await Future.wait(futures);
        for (final candidate in batchResults) {
          if (candidate != null) return candidate;
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<String?> _testServerCandidate(String ip, int port) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final uri = Uri.parse('http://$ip:$port/api/info');
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data['status'] == 'online') {
          return ip;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final uri = Uri.parse('$baseUrl/api/users');
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    return [];
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;

    request.write(jsonEncode({
      'username': username,
      'password': password,
    }));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['user'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTables() async {
    final uri = Uri.parse('$baseUrl/api/tables');
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('فشل جلب قائمة الطاولات');
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final uri = Uri.parse('$baseUrl/api/categories');
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('فشل جلب قائمة الأقسام');
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final uri = Uri.parse('$baseUrl/api/products');
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('فشل جلب قائمة الأصناف');
  }

  Future<Map<String, dynamic>?> getTableOrder(int tableId) async {
    final uri = Uri.parse('$baseUrl/api/orders/table?table_id=$tableId');
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return data['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<bool> sendTableOrder({
    required int tableId,
    required String waiterName,
    required List<Map<String, dynamic>> items,
    required double total,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders/table');
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;

    final payload = jsonEncode({
      'table_id': tableId,
      'waiter_name': waiterName,
      'items': items,
      'total': total,
      'notes': notes,
    });

    request.write(payload);
    final response = await request.close();

    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      return data['success'] == true;
    }
    return false;
  }

  Future<bool> cancelTableOrder(int tableId) async {
    // Cancellation of orders/tables is prohibited from waiter mobile app
    return false;
  }
}
