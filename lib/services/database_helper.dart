import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session_model.dart';

class DatabaseHelper {
  // Singleton Pattern (Biar cuma ada 1 satpam di aplikasi)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Versi skema. v1: tabel `sessions` (pengukuran lama, sekarang read-only).
  /// v2: logbook latihan, tes genggam, target mingguan, ringkasan mingguan.
  static const int schemaVersion = 2;

  // Cek: Kalau database belum ada, bikin baru. Kalau ada, pakai yang lama.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rehab_history.db');
    return _database!;
  }

  // Buka koneksi ke file database di HP
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Bikin Tabel (Mirip bikin Sheet di Excel)
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kg REAL,
        date TEXT,
        duration TEXT,
        status TEXT
      )
    ''');
    await createV2Tables(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tabel lama `sessions` tidak disentuh (riwayat read-only).
      await createV2Tables(db);
    }
  }

  /// Tabel versi 2. Dipisah supaya bisa dipanggil dari onCreate dan onUpgrade.
  static Future<void> createV2Tables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS training_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        keymap TEXT NOT NULL,
        active_min REAL NOT NULL,
        presses_f1 INTEGER NOT NULL,
        presses_f2 INTEGER NOT NULL,
        presses_f3 INTEGER NOT NULL,
        presses_f4 INTEGER NOT NULL,
        total_presses INTEGER NOT NULL,
        press_rate REAL,
        ipi_median_s REAL,
        force_median REAL,
        ble_disconnects INTEGER NOT NULL,
        qualifies_for_target INTEGER NOT NULL,
        least_used_finger INTEGER,
        end_reason TEXT,
        week_start_ms INTEGER NOT NULL,
        source TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ts_source_start ON training_sessions(source, start_ms)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS key_events (
        session_id INTEGER NOT NULL,
        char TEXT,
        action TEXT,
        t_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ke_session ON key_events(session_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS force_samples (
        session_id INTEGER,
        grip_test_id INTEGER,
        value REAL NOT NULL,
        t_ms INTEGER NOT NULL,
        phase TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fs_session ON force_samples(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fs_grip ON force_samples(grip_test_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS grip_tests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hand TEXT NOT NULL,
        t_ms INTEGER NOT NULL,
        trial1 REAL NOT NULL,
        trial2 REAL NOT NULL,
        trial3 REAL NOT NULL,
        value REAL NOT NULL,
        change_from_first_pct REAL,
        source TEXT NOT NULL,
        profile_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_target (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessions_per_week INTEGER NOT NULL,
        set_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weekly_summary (
        source TEXT NOT NULL,
        week_start_ms INTEGER NOT NULL,
        sessions_count INTEGER NOT NULL,
        qualifying_count INTEGER NOT NULL,
        active_min_total REAL NOT NULL,
        presses_f1 INTEGER NOT NULL,
        presses_f2 INTEGER NOT NULL,
        presses_f3 INTEGER NOT NULL,
        presses_f4 INTEGER NOT NULL,
        ble_disconnects INTEGER NOT NULL,
        target INTEGER NOT NULL,
        compliance_pct REAL,
        PRIMARY KEY (source, week_start_ms)
      )
    ''');
    await ensureDefaultTarget(db);
  }

  /// Target default 5 sesi/minggu dengan set_at_ms = 0, supaya setiap minggu
  /// (termasuk data lama/simulasi) punya target yang jelas.
  static Future<void> ensureDefaultTarget(DatabaseExecutor db) async {
    final c = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM weekly_target'));
    if ((c ?? 0) == 0) {
      await db.insert('weekly_target', {'sessions_per_week': 5, 'set_at_ms': 0});
    }
  }

  // --- FUNGSI CRUD (Create, Read, Update, Delete) ---

  // 1. SIMPAN DATA BARU (Create) - tabel lama, tidak dipakai lagi oleh UI baru
  Future<int> create(SessionModel session) async {
    final db = await instance.database;
    return await db.insert('sessions', session.toMap());
  }

  // 2. BACA SEMUA DATA (Read)
  Future<List<SessionModel>> readAllSessions() async {
    final db = await instance.database;
    // Ambil semua data, urutkan dari yang terbaru (DESC)
    final result = await db.query('sessions', orderBy: 'date DESC');
    return result.map((json) => SessionModel.fromMap(json)).toList();
  }

  // 3. HAPUS SEMUA DATA (Opsional, buat bersih-bersih)
  Future<void> deleteAll() async {
    final db = await instance.database;
    await db.delete('sessions');
  }
}
