import 'package:flutter/material.dart';
import '../../services/waiter_api_client.dart';
import 'waiter_connect_screen.dart';
import 'waiter_tables_screen.dart';

class WaiterUserLoginScreen extends StatefulWidget {
  final WaiterApiClient apiClient;

  const WaiterUserLoginScreen({super.key, required this.apiClient});

  @override
  State<WaiterUserLoginScreen> createState() => _WaiterUserLoginScreenState();
}

class _WaiterUserLoginScreenState extends State<WaiterUserLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Map<String, dynamic>> _cashierUsers = [];
  bool _isLoadingUsers = true;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await widget.apiClient.getUsers();
      if (mounted) {
        setState(() {
          _cashierUsers = users;
          _isLoadingUsers = false;
          if (users.isNotEmpty) {
            _usernameController.text = users.first['username'] as String? ?? '';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final user = await widget.apiClient.login(username, password);

    if (!mounted) return;

    setState(() => _isLoggingIn = false);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaiterTablesScreen(
            apiClient: widget.apiClient,
            waiterName: user['username'] as String? ?? username,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة في الكاشير.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: const Text('دخول المستخدم - الكاشير', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: Color(0xFF10B981)),
            tooltip: 'تغيير IP الكاشير',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WaiterConnectScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(20),
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
                  // Server connection badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'متصل بالكاشير: ${widget.apiClient.baseUrl.replaceAll("http://", "")}',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.account_circle_rounded, size: 54, color: Color(0xFF10B981)),
                  const SizedBox(height: 12),
                  const Text(
                    'دخول مستخدم الكاشير',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'سجل دخولك باستخدام حسابك المسجل في قاعدة بيانات الكاشير',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Users List dropdown or text input
                  _isLoadingUsers
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(color: Color(0xFF10B981)),
                        )
                      : Column(
                          children: [
                            if (_cashierUsers.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _cashierUsers.any((u) => u['username'] == _usernameController.text)
                                    ? _usernameController.text
                                    : _cashierUsers.first['username'] as String,
                                dropdownColor: const Color(0xFF374151),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'اختر مستخدم الكاشير',
                                  labelStyle: TextStyle(color: Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.person, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: const Color(0xFF374151),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                items: _cashierUsers.map((u) {
                                  final uname = u['username'] as String;
                                  final urole = u['role'] as String? ?? 'مستخدم';
                                  return DropdownMenuItem<String>(
                                    value: uname,
                                    child: Text('$uname ($urole)'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _usernameController.text = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                            ] else ...[
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'اسم المستخدم',
                                  labelStyle: TextStyle(color: Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.person, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: const Color(0xFF374151),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                labelStyle: TextStyle(color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.lock, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: const Color(0xFF374151),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                            ),
                          ],
                        ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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

                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoggingIn ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: _isLoggingIn
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login),
                                SizedBox(width: 8),
                                Text(
                                  'دخول النظام',
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
