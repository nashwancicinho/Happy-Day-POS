import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  static Future<String> getAppDatabaseDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      final appDir = Directory(join(dir.path, 'HappyDayPOS'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return appDir.path;
    } else {
      return await getDatabasesPath();
    }
  }

  static Future<String> getAppDatabaseFilePath() async {
    final dbDirPath = await getAppDatabaseDirectory();
    return join(dbDirPath, 'restaurant_pos.db');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    await _ensureColumnsExist(_database!);
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = await getAppDatabaseFilePath();

    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }


  Future<void> _addColumnIfMissing(Database db, String table, String column, String typeWithDefault) async {
    try {
      final columns = await db.rawQuery("PRAGMA table_info($table)");
      final exists = columns.any((c) => c['name']?.toString().toLowerCase() == column.toLowerCase());
      if (!exists) {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $typeWithDefault;");
      }
    } catch (_) {}
  }

  Future<void> _ensureColumnsExist(Database db) async {
    // Users table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'كاشير',
          is_active INTEGER DEFAULT 1,
          created_at TEXT
        );
      ''');

      // Ensure users table exists without forcing hardcoded default users
      final usersCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
      // If table is empty, keep it empty so Onboarding Initial Setup flow is triggered
      if (usersCount == 0) {
        // Intentionally empty
      }
    } catch (_) {}

    await _addColumnIfMissing(db, 'users', 'permissions', 'TEXT');
    await _addColumnIfMissing(db, 'orders', 'customer_phone', 'TEXT');

    await _addColumnIfMissing(db, 'orders', 'customer_address', 'TEXT');
    await _addColumnIfMissing(db, 'orders', 'cashier_name', 'TEXT');
    await _addColumnIfMissing(db, 'order_items', 'print_to_kitchen', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'products', 'unit', "TEXT DEFAULT 'قطعة'");
    await _addColumnIfMissing(db, 'products', 'is_weighted', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'products', 'allow_price_change', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'products', 'barcode', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'buy_price', 'REAL DEFAULT 0');
    await _addColumnIfMissing(db, 'products', 'stock_quantity', 'REAL DEFAULT 100');
    await _addColumnIfMissing(db, 'products', 'track_stock', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'products', 'min_stock', 'REAL DEFAULT 5');
    await _addColumnIfMissing(db, 'products', 'print_to_kitchen', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'products', 'kitchen_printer', 'TEXT');
    await _addColumnIfMissing(db, 'order_items', 'kitchen_printer', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'color', 'TEXT');
    await _addColumnIfMissing(db, 'categories', 'color', 'TEXT');
    await _addColumnIfMissing(db, 'categories', 'image', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_tables', 'pos_x', 'REAL DEFAULT -1.0');

    await _addColumnIfMissing(db, 'restaurant_tables', 'pos_y', 'REAL DEFAULT -1.0');
    await _addColumnIfMissing(db, 'restaurant_tables', 'width', 'REAL DEFAULT 120.0');
    await _addColumnIfMissing(db, 'restaurant_tables', 'height', 'REAL DEFAULT 120.0');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM settings')) ?? 0;
      if (count == 0) {
        await db.insert('settings', {'key': 'store_name', 'value': 'HAPPY DAY POS'});
        await db.insert('settings', {'key': 'store_phone', 'value': ''});
        await db.insert('settings', {'key': 'store_address', 'value': ''});
        await db.insert('settings', {'key': 'tax_rate', 'value': '0.0'});
        await db.insert('settings', {'key': 'currency_symbol', 'value': 'د.ع'});
        await db.insert('settings', {'key': 'receipt_header', 'value': 'أهلاً وسهلاً بكم'});
        await db.insert('settings', {'key': 'receipt_footer', 'value': 'شكراً لزيارتكم'});
      }
    } catch (_) {}

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_treasury(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          daily_income REAL NOT NULL,
          daily_expense REAL NOT NULL,
          net_income REAL NOT NULL,
          notes TEXT,
          closed_by TEXT,
          created_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}

    // Suppliers table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          notes TEXT,
          balance REAL DEFAULT 0.0,
          created_at TEXT
        );
      ''');
    } catch (_) {}

    // Purchases table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          supplier_name TEXT,
          invoice_number TEXT NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL,
          remaining_amount REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'PAID',
          payment_method TEXT NOT NULL DEFAULT 'CASH',
          notes TEXT,
          created_at TEXT NOT NULL
        );
      ''');
    } catch (_) {}

    // Purchase Items table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          product_id INTEGER,
          item_name TEXT NOT NULL,
          unit_price REAL NOT NULL,
          quantity REAL NOT NULL,
          subtotal REAL NOT NULL,
          FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
        );
      ''');
    } catch (_) {}

    // Supplier Payments table
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER NOT NULL,
          purchase_id INTEGER,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          payment_method TEXT NOT NULL DEFAULT 'CASH',
          notes TEXT,
          FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE
        );
      ''');
    } catch (_) {}
  }

  Future<void> _onCreate(Database db, int version) async {
    // Categories
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // Products
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        barcode TEXT,
        buy_price REAL DEFAULT 0,
        price REAL NOT NULL,
        unit TEXT DEFAULT 'قطعة',
        is_weighted INTEGER DEFAULT 0,
        allow_price_change INTEGER DEFAULT 0,
        stock_quantity REAL DEFAULT 100,
        track_stock INTEGER DEFAULT 0,
        min_stock REAL DEFAULT 5,
        tax_rate REAL DEFAULT 0,
        image TEXT,
        is_available INTEGER DEFAULT 1,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      )
    ''');

    // Restaurant Tables
    await db.execute('''
      CREATE TABLE restaurant_tables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        capacity INTEGER DEFAULT 4,
        status INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        shape TEXT DEFAULT 'square',
        pos_x REAL DEFAULT -1.0,
        pos_y REAL DEFAULT -1.0,
        width REAL DEFAULT 120.0,
        height REAL DEFAULT 120.0
      )
    ''');

    // Shifts
    await db.execute('''
      CREATE TABLE shifts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_name TEXT,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash REAL DEFAULT 0,
        closing_cash_expected REAL DEFAULT 0,
        closing_cash_actual REAL DEFAULT 0,
        status TEXT DEFAULT 'OPEN'
      )
    ''');

    // Cash Transactions (In / Out)
    await db.execute('''
      CREATE TABLE cash_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(shift_id) REFERENCES shifts(id)
      )
    ''');

    // Customers
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT,
        notes TEXT,
        balance REAL DEFAULT 0
      )
    ''');

    // Settings
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Orders
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER,
        table_id INTEGER,
        customer_id INTEGER,
        order_type TEXT DEFAULT 'DINE_IN',
        subtotal REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'CASH',
        status TEXT DEFAULT 'OPEN',
        notes TEXT,
        created_at TEXT,
        FOREIGN KEY(customer_id) REFERENCES customers(id)
      )
    ''');

    // Order Items
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        buy_price REAL DEFAULT 0,
        quantity INTEGER DEFAULT 1,
        price REAL NOT NULL,
        discount REAL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');

    // Seed Minimal Empty Defaults
    await _seedMinimalDefaults(db);
  }

  Future<void> _seedMinimalDefaults(Database db) async {
    // Default Settings
    await db.insert('settings', {'key': 'store_name', 'value': 'HAPPY DAY POS'});
    await db.insert('settings', {'key': 'store_phone', 'value': ''});
    await db.insert('settings', {'key': 'store_address', 'value': ''});
    await db.insert('settings', {'key': 'tax_rate', 'value': '0.0'});
    await db.insert('settings', {'key': 'currency_symbol', 'value': 'د.ع'});
    await db.insert('settings', {'key': 'receipt_header', 'value': 'أهلاً وسهلاً بكم'});
    await db.insert('settings', {'key': 'receipt_footer', 'value': 'شكراً لزيارتكم، نتمنى لكم يوماً سعيداً!'});

    // Default Customer
    await db.insert('customers', {
      'name': 'زبون عام (نقدي)',
      'phone': '0000',
      'address': '',
      'balance': 0.0,
    });

    // Seed Tables (1 to 8)
    for (int i = 1; i <= 8; i++) {
      await db.insert('restaurant_tables', {
        'name': 'طاولة $i',
        'capacity': (i % 2 == 0) ? 6 : 4,
        'status': 0,
        'sort_order': i,
        'shape': 'square',
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await _ensureColumnsExist(db);
    }
  }

  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('products');
      await txn.delete('categories');
      await txn.delete('cash_transactions');
      await txn.delete('shifts');
      await txn.delete('restaurant_tables');
      await txn.delete('settings');
      await txn.delete('users');
      await txn.delete('customers');
      await txn.delete('daily_treasury');
    });
    await _seedMinimalDefaults(db);
    await _ensureColumnsExist(db);
  }

  Future<void> deleteDatabaseFile() async {
    final path = await getAppDatabaseFilePath();

    await deleteDatabase(path);
    _database = null;
  }

  Future<File> backupDatabase(String targetDirectoryOrFilePath) async {
    final db = await database;
    try {
      await db.execute('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}

    final currentDbPath = await getAppDatabaseFilePath();
    final currentDbFile = File(currentDbPath);
    if (!await currentDbFile.exists()) {
      throw Exception('ملف قاعدة البيانات الأساسية غير موجود.');
    }

    String destinationPath = targetDirectoryOrFilePath;
    final isDirectory = await FileSystemEntity.isDirectory(targetDirectoryOrFilePath);

    if (isDirectory) {
      final now = DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}";
      final fileName = 'happy_day_pos_backup_$dateStr.db';
      destinationPath = join(targetDirectoryOrFilePath, fileName);
    }

    final targetFile = File(destinationPath);
    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return await currentDbFile.copy(destinationPath);
  }

  Future<void> restoreDatabase(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('ملف النسخة الاحتياطية المحدد غير موجود.');
    }

    final bytes = await backupFile.readAsBytes();
    if (bytes.length < 16) {
      throw Exception('الملف المحدد ليس ملف قاعدة بيانات صحيح.');
    }
    final header = String.fromCharCodes(bytes.sublist(0, 16));
    if (!header.startsWith('SQLite format 3')) {
      throw Exception('الملف المحدد ليس ملف قاعدة بيانات SQLite مخصص للنظام.');
    }

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    final currentDbPath = await getAppDatabaseFilePath();
    final currentDbFile = File(currentDbPath);

    final walFile = File('$currentDbPath-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    final shmFile = File('$currentDbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }

    await backupFile.copy(currentDbFile.path);

    _database = await _initDatabase();
    await _ensureColumnsExist(_database!);
  }
}

