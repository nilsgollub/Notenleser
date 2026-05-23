import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/song.dart';

/// Lokale SQLite-Bibliothek aller erfassten Lieder.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'notenleser.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE songs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            composer TEXT,
            key_signature TEXT,
            time_signature TEXT,
            tempo_bpm INTEGER,
            notes_json TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<Song> insert(Song song) async {
    final db = await _database;
    final id = await db.insert('songs', song.toDbMap());
    return song.copyWith(id: id);
  }

  Future<List<Song>> getAll({String query = ''}) async {
    final db = await _database;
    final rows = await db.query(
      'songs',
      where: query.isEmpty ? null : 'title LIKE ?',
      whereArgs: query.isEmpty ? null : ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(Song.fromDbMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }
}
