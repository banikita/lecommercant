import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;
  AppDatabase._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'lecommercant.db');
    return openDatabase(path, version: 1, onCreate: _creerTables);
  }

  Future<void> _creerTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE commercants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prenom TEXT NOT NULL,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL UNIQUE,
        nom_boutique TEXT NOT NULL,
        ville TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commercant_id INTEGER NOT NULL REFERENCES commercants(id),
        token TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        tentatives_pin INTEGER NOT NULL DEFAULT 0,
        derniere_activite TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commercant_id INTEGER NOT NULL REFERENCES commercants(id),
        nom_client TEXT NOT NULL,
        type TEXT NOT NULL,
        montant REAL NOT NULL,
        date TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // --- INSCRIPTION ---
  Future<int?> inscrire({
    required String prenom, required String nom,
    required String telephone, required String nomBoutique,
    required String ville, required String pin,
  }) async {
    final db = await database;
    final exist = await db.query('commercants', where: 'telephone = ?', whereArgs: [telephone]);
    if (exist.isNotEmpty) return null;

    return await db.insert('commercants', {
      'prenom': prenom, 'nom': nom, 'telephone': telephone,
      'nom_boutique': nomBoutique, 'ville': ville, 'pin_hash': hashPin(pin),
    });
  }

  // --- CONNEXION & PIN ---
  Future<Map<String, dynamic>?> chargerCommercant() async {
    final db = await database;
    final rows = await db.query('commercants', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> verifierPin(int commercantId, String pin) async {
    final db = await database;
    final rows = await db.query('commercants', where: 'id = ?', whereArgs: [commercantId]);
    if (rows.isEmpty) return false;
    return rows.first['pin_hash'] == hashPin(pin);
  }

  Future<void> mettreAJourPin(int id, String nouveauPin) async {
    final db = await database;
    await db.update('commercants', {'pin_hash': hashPin(nouveauPin)}, where: 'id = ?', whereArgs: [id]);
    await reinitialiserTentatives(id);
  }

  // --- TENTATIVES & SESSIONS ---
  Future<int> incrementerTentatives(int id) async {
    final db = await database;
    final res = await db.rawQuery('SELECT tentatives_pin FROM sessions WHERE commercant_id = ?', [id]);
    int t = (res.isNotEmpty ? (res.first['tentatives_pin'] as int) : 0) + 1;
    await db.update('sessions', {'tentatives_pin': t}, where: 'commercant_id = ?', whereArgs: [id]);
    return t;
  }

  Future<void> reinitialiserTentatives(int id) async {
    final db = await database;
    await db.update('sessions', {'tentatives_pin': 0}, where: 'commercant_id = ?', whereArgs: [id]);
  }

  Future<void> ouvrirSession(int id) async {
    final db = await database;
    await db.update('sessions', {'is_active': 0}, where: 'commercant_id = ?', whereArgs: [id]);
    await db.insert('sessions', {'commercant_id': id, 'token': 'tk_${id}', 'is_active': 1});
  }

  Future<void> fermerSession(int id) async {
    final db = await database;
    await db.update('sessions', {'is_active': 0}, where: 'commercant_id = ?', whereArgs: [id]);
  }

  // --- DASHBOARD (CORRIGÉ) ---
  Future<double> ventesAujourdhui(int id) async {
    final db = await database;
    final res = await db.rawQuery("SELECT SUM(montant) as total FROM transactions WHERE commercant_id = ? AND type = 'vente' AND date >= date('now')", [id]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> dettesEnCours(int id) async {
    final db = await database;
    final res = await db.rawQuery("SELECT SUM(montant) as total FROM transactions WHERE commercant_id = ? AND type = 'dette'", [id]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // --- CETTE MÉTHODE RÉSOUT L'ERREUR DANS DASHBORD.DART ---
  Future<List<Map<String, dynamic>>> chargerTransactionsRecentes(int id, {int limite = 5}) async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'commercant_id = ?',
      orderBy: 'date DESC',
      limit: limite,
    );
  }

  // --- SÉCURITÉ ---
  String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin + "salt_123")).toString();
  }
}