import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<void> ensureInitialized() async {
    await database; // triggers initialization
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'cards_app.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedData(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        suit TEXT NOT NULL,
        rank INTEGER NOT NULL,
        image_url TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX idx_cards_folder_id ON cards(folder_id);');
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Insert folders with fixed IDs so we can reference them when seeding cards
    final suitsWithId = const [
      {'id': 1, 'name': 'Hearts'},
      {'id': 2, 'name': 'Spades'},
      {'id': 3, 'name': 'Diamonds'},
      {'id': 4, 'name': 'Clubs'},
    ];

    final batch = db.batch();

    for (final s in suitsWithId) {
      batch.insert('folders', {
        'id': s['id'],
        'name': s['name'],
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed cards: 1-13 for each suit
    // rank 1=Ace, 11=Jack, 12=Queen, 13=King
    for (final s in suitsWithId) {
      final suit = s['name'] as String;
      final folderId = s['id'] as int;
      for (int rank = 1; rank <= 13; rank++) {
        final name = _cardName(suit, rank);
        final imageUrl = _assetPathForCard(suit, rank);
        batch.insert('cards', {
          'name': name,
          'suit': suit,
          'rank': rank,
          'image_url': imageUrl,
          'folder_id': folderId,
        });
      }
    }

    await batch.commit(noResult: true);
  }

  String _cardName(String suit, int rank) {
    switch (rank) {
      case 1:
        return 'Ace of $suit';
      case 11:
        return 'Jack of $suit';
      case 12:
        return 'Queen of $suit';
      case 13:
        return 'King of $suit';
      default:
        return '$rank of $suit';
    }
  }

  String _assetPathForCard(String suit, int rank) {
    final folder = suit.toLowerCase();
    return 'assets/images/cards/$folder/$rank.png';
  }

  // --------- Queries & Mutations ---------

  Future<List<Map<String, dynamic>>> fetchFoldersSimple() async {
    final db = await database;
    return db.query('folders', columns: ['id', 'name'], orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> fetchFolderSummaries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT f.id,
             f.name,
             COUNT(c.id) AS card_count,
             (
               SELECT image_url FROM cards
               WHERE folder_id = f.id
               ORDER BY rank ASC
               LIMIT 1
             ) AS preview_url
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name
      ORDER BY f.id ASC;
    ''');
  }

  Future<List<Map<String, dynamic>>> fetchCardsByFolder(int folderId) async {
    final db = await database;
    return db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'rank ASC',
    );
  }

  Future<int> countCardsInFolder(int folderId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM cards WHERE folder_id = ?',
      [folderId],
    );
    final value = res.first['cnt'];
    return (value as num).toInt();
  }

  Future<int> insertCard({
    required int folderId,
    required String suit,
    required int rank,
    String? name,
    String? imageUrl,
  }) async {
    final db = await database;
    final cardName = name ?? _cardName(suit, rank);
    final url = imageUrl ?? _assetPathForCard(suit, rank);
    return db.insert('cards', {
      'name': cardName,
      'suit': suit,
      'rank': rank,
      'image_url': url,
      'folder_id': folderId,
    });
  }

  Future<int> updateCard({
    required int id,
    String? name,
    int? rank,
    String? imageUrl,
    int? folderId,
    String? suit,
  }) async {
    final db = await database;
    final values = <String, Object?>{};
    if (name != null) values['name'] = name;
    if (rank != null) values['rank'] = rank;
    if (imageUrl != null) values['image_url'] = imageUrl;
    if (folderId != null) values['folder_id'] = folderId;
    if (suit != null) values['suit'] = suit;
    if (values.isEmpty) return 0;
    return db.update('cards', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCard(int id) async {
    final db = await database;
    return db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  // --------- Folder CRUD (optional bonus) ---------

  Future<int> insertFolder(String name) async {
    final db = await database;
    return db.insert('folders', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateFolderName(int id, String name) async {
    final db = await database;
    return db.update(
      'folders',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await database;
    return db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }
}
