import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/waiter_api_client.dart';
import 'waiter_connect_screen.dart';
import 'waiter_order_screen.dart';

class WaiterTablesScreen extends StatefulWidget {
  final WaiterApiClient apiClient;
  final String waiterName;

  const WaiterTablesScreen({
    super.key,
    required this.apiClient,
    required this.waiterName,
  });

  @override
  State<WaiterTablesScreen> createState() => _WaiterTablesScreenState();
}

class _WaiterTablesScreenState extends State<WaiterTablesScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTables();
    // Auto refresh every 5 seconds so table statuses update when Cashier or other waiters make updates
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadTables(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTables({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final tables = await widget.apiClient.getTables();
      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _tables.where((t) => (t['status'] ?? 0) == 0).length;
    final busyCount = _tables.where((t) => (t['status'] ?? 0) == 1).length;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'طاولات المطعم - ${widget.waiterName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.apiClient.baseUrl.replaceAll('http://', ''),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadTables(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تغيير السيرفر',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WaiterConnectScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1F2937).withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCounterChip('إجمالي الطاولات', '${_tables.length}', Colors.blueAccent),
                _buildCounterChip('طاولات متاحة', '$availableCount', const Color(0xFF10B981)),
                _buildCounterChip('مشغولة (بها طلب)', '$busyCount', Colors.orangeAccent),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.signal_wifi_off, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text('خطأ في الاتصال: $_error', style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadTables(),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              child: const Text('إعادة المحاولة'),
                            )
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadTables(),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            childAspectRatio: 1.05,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _tables.length,
                          itemBuilder: (context, index) {
                            final table = _tables[index];
                            final id = table['id'] as int;
                            final name = table['name'] as String? ?? 'طاولة $id';
                            final capacity = table['capacity'] as int? ?? 4;
                            final status = table['status'] as int? ?? 0;
                            final isBusy = status == 1;

                            return Card(
                              elevation: 3,
                              color: isBusy ? const Color(0xFF374151) : const Color(0xFF1F2937),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isBusy ? Colors.orangeAccent : const Color(0xFF10B981).withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WaiterOrderScreen(
                                        apiClient: widget.apiClient,
                                        tableId: id,
                                        tableName: name,
                                        waiterName: widget.waiterName,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadTables();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(
                                            Icons.table_restaurant,
                                            color: isBusy ? Colors.orangeAccent : const Color(0xFF10B981),
                                            size: 22,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: (isBusy ? Colors.orangeAccent : const Color(0xFF10B981)).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isBusy ? 'طلب مفتوح' : 'متاحة',
                                              style: TextStyle(
                                                color: isBusy ? Colors.orangeAccent : const Color(0xFF10B981),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.people, size: 13, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$capacity أشخاص',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
