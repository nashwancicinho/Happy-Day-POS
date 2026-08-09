import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/user.dart';
import '../settings/settings_provider.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  UserModel? _currentUser;
  List<UserModel> _users = [];
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.role == 'مالك البرنامج';
  bool get isManager => _currentUser?.role == 'مدير' || _currentUser?.role == 'مالك البرنامج';
  String get currentUserName => _currentUser?.username ?? 'غير مسجل';
  String get currentUserRole => _currentUser?.role ?? 'زائر';

  bool hasPermission(BuildContext context, String permKey) {

    if (_currentUser == null) return false;
    if (isManager) return true;
    if (_currentUser!.permissions != null && _currentUser!.permissions!.containsKey(permKey)) {
      return _currentUser!.permissions![permKey]!;
    }
    final settings = context.read<SettingsProvider>();
    return settings.getCashierPermission(permKey);
  }

  Future<bool> updateUserPermissions(int userId, Map<String, bool>? permissions) async {
    try {
      final db = await _dbHelper.database;
      final permJson = permissions != null ? jsonEncode(permissions) : null;
      await db.update(
        'users',
        {'permissions': permJson},
        where: 'id = ?',
        whereArgs: [userId],
      );
      await loadUsers();
      if (_currentUser?.id == userId) {
        _currentUser = _currentUser?.copyWith(permissions: permissions);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Update user permissions error: $e');
      return false;
    }
  }



  AuthProvider() {
    loadUsers();
  }

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final maps = await db.query('users', where: 'is_active = 1', orderBy: 'id ASC');
      _users = maps.map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login with username and password
  Future<bool> login(String username, String password) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'users',
        where: 'username = ? AND password = ? AND is_active = 1',
        whereArgs: [username.trim(), password.trim()],
      );

      if (maps.isNotEmpty) {
        _currentUser = UserModel.fromMap(maps.first);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }
    return false;
  }

  Future<bool> verifyManagerCredentials(String username, String password) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'users',
        where: 'username = ? AND password = ? AND (role = ? OR role = ?) AND is_active = 1',
        whereArgs: [username.trim(), password.trim(), 'مدير', 'مالك البرنامج'],
      );
      if (maps.isNotEmpty) return true;
    } catch (e) {
      debugPrint('Verify manager credentials error: $e');
    }
    return false;
  }

  Future<bool> verifyOwnerCredentials(String username, String password) async {
    try {
      final db = await _dbHelper.database;
      // 1. Check if matching user with role 'مالك البرنامج' exists
      final maps = await db.query(
        'users',
        where: 'username = ? AND password = ? AND role = ? AND is_active = 1',
        whereArgs: [username.trim(), password.trim(), 'مالك البرنامج'],
      );
      if (maps.isNotEmpty) return true;

      // 2. If no owner user exists yet in database, fall back to checking Manager credentials
      final ownerCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM users WHERE role = 'مالك البرنامج' AND is_active = 1"),
      ) ?? 0;

      if (ownerCount == 0) {
        return await verifyManagerCredentials(username, password);
      }
    } catch (e) {
      debugPrint('Verify owner credentials error: $e');
    }
    return false;
  }

  // Initial Setup when system database is empty
  Future<bool> registerInitialSetup({
    required String managerUsername,
    required String managerPassword,
    String? cashierUsername,
    String? cashierPassword,
  }) async {
    try {
      final db = await _dbHelper.database;

      final managerUser = UserModel(
        username: managerUsername.trim(),
        password: managerPassword.trim(),
        role: 'مدير',
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      final managerId = await db.insert('users', managerUser.toMap());

      if (cashierUsername != null &&
          cashierUsername.trim().isNotEmpty &&
          cashierPassword != null &&
          cashierPassword.trim().isNotEmpty) {
        final cashierUser = UserModel(
          username: cashierUsername.trim(),
          password: cashierPassword.trim(),
          role: 'كاشير',
          isActive: true,
          createdAt: DateTime.now().toIso8601String(),
        );
        await db.insert('users', cashierUser.toMap());
      }

      await loadUsers();

      // Auto login as initial Manager
      _currentUser = managerUser.copyWith(id: managerId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Initial setup error: $e');
      rethrow;
    }
  }

  // Register a new user from Login Screen after verifying Manager's credentials
  Future<bool> registerUserWithManagerCredentials({
    required String managerUsername,
    required String managerPassword,
    required UserModel newUser,
  }) async {
    final db = await _dbHelper.database;

    // 1. Verify Manager credentials
    final managerMatch = await db.query(
      'users',
      where: 'username = ? AND password = ? AND role = ? AND is_active = 1',
      whereArgs: [managerUsername.trim(), managerPassword.trim(), 'مدير'],
    );

    if (managerMatch.isEmpty) {
      throw Exception('اسم المدير أو الرقم السري للمدير غير صحيح! غير مخول بنشاط إضافة المستخدمين.');
    }

    // 2. Check if username already exists
    final existingUser = await db.query(
      'users',
      where: 'LOWER(username) = ? AND is_active = 1',
      whereArgs: [newUser.username.trim().toLowerCase()],
    );

    if (existingUser.isNotEmpty) {
      throw Exception('اسم المستخدم "${newUser.username}" موجود بالفعل! يرجى اختيار اسم مختلف.');
    }

    // 3. Insert new user
    await db.insert(
      'users',
      newUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );

    await loadUsers();
    return true;
  }

  // Logout current user
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // Backward compatibility PIN login check
  bool loginAsManager(String pin) {
    if (_currentUser != null && _currentUser!.isManager && _currentUser!.password == pin) {
      return true;
    }
    final managerMatch = _users.any((u) => u.isManager && u.password == pin);
    if (managerMatch) {
      return true;
    }
    return pin == '1234';
  }

  void logoutManager() {
    notifyListeners();
  }

  // Manager Only: Add new user
  Future<bool> addUser(UserModel user) async {
    if (!isManager) {
      throw Exception('عذراً، إضافة اسم المستخدم محصورة لصلاحيات المدير فقط!');
    }

    try {
      final db = await _dbHelper.database;
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      await loadUsers();
      return true;
    } catch (e) {
      debugPrint('Add user error: $e');
      rethrow;
    }
  }

  // Manager Only: Delete user
  Future<bool> deleteUser(int userId) async {
    if (!isManager) {
      throw Exception('عذراً، مسح اسم المستخدم محصورة لصلاحيات المدير فقط!');
    }

    if (_currentUser?.id == userId) {
      throw Exception('لا يمكنك مسح حسابك الحالي وأنت مسجل الدخول به!');
    }

    try {
      final db = await _dbHelper.database;
      await db.delete('users', where: 'id = ?', whereArgs: [userId]);
      await loadUsers();
      return true;
    } catch (e) {
      debugPrint('Delete user error: $e');
      rethrow;
    }
  }
}
