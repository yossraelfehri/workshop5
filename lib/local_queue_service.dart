import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalQueueService {
  static Database? _database;
  static const String tableName = 'local_clients';
  final bool _inMemory;
  // In-memory fallback used for tests (when inMemory = true).
  final List<Map<String, dynamic>> _inMemoryStore = [];
  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;
  Future<Database> get database async {
    if (_inMemory) throw StateError('database not available in in-memory mode');
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (_inMemory) {
      return await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'waiting_room.db');
      return openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $tableName (
id TEXT PRIMARY KEY,
name TEXT NOT NULL,
lat REAL,
lng REAL,
created_at TEXT NOT NULL,
waiting_room_id TEXT,
is_synced INTEGER NOT NULL DEFAULT 0
)
''');
    // Créer aussi la table pour les rooms en local
    await db.execute('''
CREATE TABLE IF NOT EXISTS local_rooms (
id TEXT PRIMARY KEY,
name TEXT NOT NULL,
latitude REAL NOT NULL,
longitude REAL NOT NULL,
last_synced TEXT
)
''');
  }

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    if (_inMemory) {
      // Simulate sqlite insert; ensure no duplicates by id
      _inMemoryStore.removeWhere((m) => m['id'] == client['id']);
      _inMemoryStore.add(Map<String, dynamic>.from(client));
      return;
    }

    final db = await database;
    await db.insert(
      tableName,
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (_inMemory) {
      final copy = List<Map<String, dynamic>>.from(_inMemoryStore);
      copy.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      return copy;
    }

    final db = await database;
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    if (_inMemory) {
      return _inMemoryStore.where((m) => (m['is_synced'] ?? 0) == 0).toList();
    }

    final db = await database;
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markClientAsSynced(String id) async {
    if (_inMemory) {
      final idx = _inMemoryStore.indexWhere((m) => m['id'] == id);
      if (idx != -1) {
        _inMemoryStore[idx]['is_synced'] = 1;
      }
      return;
    }

    final db = await database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteClient(String id) async {
    if (_inMemory) {
      _inMemoryStore.removeWhere((m) => m['id'] == id);
      return;
    }

    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  // Méthodes pour gérer les rooms localement
  Future<void> insertRoomLocally(Map<String, dynamic> room) async {
    if (_inMemory) {
      // Pour les tests, on ne stocke pas les rooms en mémoire
      return;
    }

    final db = await database;
    await db.insert(
      'local_rooms',
      {
        'id': room['id']?.toString(),
        'name': room['name'],
        'latitude': _toDouble(room['latitude']),
        'longitude': _toDouble(room['longitude']),
        'last_synced': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    if (_inMemory) {
      return [];
    }

    final db = await database;
    return db.query('local_rooms');
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<void> close() async {
    if (_inMemory) {
      _inMemoryStore.clear();
      return;
    }

    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
