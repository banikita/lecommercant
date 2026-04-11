import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

// ══════════════════════════════════════════════════════════════
//  APP DATABASE — Base de données locale SQLite
//
//  Couvre :
//    • RegisterPage  → créer le compte commerçant
//    • LoginPage     → vérifier le PIN, gérer les sessions
//    • DashboardPage → lire les stats, transactions récentes
//
//  Tables :
//    ┌─────────────────┐
//    │   commercants   │  ← créé au Register
//    ├─────────────────┤
//    │    sessions     │  ← créé au Login
//    ├─────────────────┤
//    │  transactions   │  ← affiché dans le Dashboard
//    └─────────────────┘
// ══════════════════════════════════════════════════════════════

class AppDatabase {
  // Singleton — une seule instance dans toute l'app
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;
  AppDatabase._init();

  // ══════════════════════════════════════
  //  INITIALISATION
  // ══════════════════════════════════════
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'lecommercant.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _creerTables,
    );
  }

  Future<void> _creerTables(Database db, int version) async {

    // ── TABLE : commercants
    // Créée à l'inscription (RegisterPage)
    await db.execute('''
      CREATE TABLE commercants (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        prenom          TEXT    NOT NULL,
        nom             TEXT    NOT NULL,
        telephone       TEXT    NOT NULL UNIQUE,
        nom_boutique    TEXT    NOT NULL,
        ville           TEXT    NOT NULL,
        pin_hash        TEXT    NOT NULL,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── TABLE : sessions
    // Créée au Login réussi, effacée à la déconnexion
    await db.execute('''
      CREATE TABLE sessions (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        commercant_id   INTEGER NOT NULL REFERENCES commercants(id),
        token           TEXT    NOT NULL,
        is_active       INTEGER NOT NULL DEFAULT 1,
        tentatives_pin  INTEGER NOT NULL DEFAULT 0,
        derniere_activite TEXT  NOT NULL DEFAULT (datetime('now')),
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── TABLE : transactions
    // Chargée dans le Dashboard (transactions récentes)
    await db.execute('''
      CREATE TABLE transactions (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        commercant_id   INTEGER NOT NULL REFERENCES commercants(id),
        nom_client      TEXT    NOT NULL,
        type            TEXT    NOT NULL
                        CHECK(type IN ('vente','dette','stock','remboursement')),
        montant         REAL    NOT NULL,
        is_credit       INTEGER NOT NULL DEFAULT 1,
        date            TEXT    NOT NULL DEFAULT (datetime('now')),
        note            TEXT
      )
    ''');

    // ── INDEX pour accélérer les requêtes
    await db.execute('CREATE INDEX idx_sessions_commercant ON sessions(commercant_id)');
    await db.execute('CREATE INDEX idx_transactions_commercant ON transactions(commercant_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date DESC)');
  }

  // ══════════════════════════════════════
  //  REGISTER — Inscription
  // ══════════════════════════════════════

  /// Vérifier si un compte existe déjà (pour main.dart)
  Future<bool> compteExiste() async {
    final db   = await database;
    final rows = await db.query('commercants', limit: 1);
    return rows.isNotEmpty;
  }

  /// Créer un nouveau compte commerçant
  /// Retourne l'ID créé, ou null si le téléphone est déjà utilisé
  Future<int?> inscrire({
    required String prenom,
    required String nom,
    required String telephone,
    required String nomBoutique,
    required String ville,
    required String pin,
  }) async {
    final db = await database;

    // Vérifier doublon téléphone
    final exist = await db.query('commercants',
        where: 'telephone = ?', whereArgs: [telephone]);
    if (exist.isNotEmpty) return null; // téléphone déjà utilisé

    // Hasher le PIN (jamais stocker en clair)
    final pinHash = _hashPin(pin);

    final id = await db.insert('commercants', {
      'prenom':       prenom,
      'nom':          nom,
      'telephone':    telephone,
      'nom_boutique': nomBoutique,
      'ville':        ville,
      'pin_hash':     pinHash,
      'created_at':   DateTime.now().toIso8601String(),
      'updated_at':   DateTime.now().toIso8601String(),
    });

    // Insérer quelques transactions de démonstration
    await _insererTransactionsDemoDemo(db, id);

    return id;
  }

  // Données de démonstration pour le dashboard initial
  Future<void> _insererTransactionsDemoDemo(Database db, int commercantId) async {
    final demo = [
      {'nom_client': 'Aminata Baldé',      'type': 'vente',         'montant': 12500.0, 'is_credit': 1},
      {'nom_client': 'Oumar Diallo',       'type': 'dette',         'montant': 8000.0,  'is_credit': 0},
      {'nom_client': 'Fourni-Stock Dakar', 'type': 'stock',         'montant': 45000.0, 'is_credit': 0},
      {'nom_client': 'Mariama Kouyaté',   'type': 'vente',         'montant': 22000.0, 'is_credit': 1},
      {'nom_client': 'Ibrahima Sarr',      'type': 'remboursement', 'montant': 5000.0,  'is_credit': 1},
    ];
    for (final t in demo) {
      await db.insert('transactions', {
        ...t,
        'commercant_id': commercantId,
        'date': DateTime.now().subtract(
          Duration(hours: demo.indexOf(t) * 3)).toIso8601String(),
      });
    }
  }

  // ══════════════════════════════════════
  //  LOGIN — Connexion PIN
  // ══════════════════════════════════════

  /// Charger le commerçant par son téléphone (pour l'affichage)
  Future<Map<String, dynamic>?> chargerCommercant() async {
    final db   = await database;
    final rows = await db.query('commercants', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Vérifier le PIN saisi
  /// Retourne true si correct, false sinon
  Future<bool> verifierPin(int commercantId, String pin) async {
    final db   = await database;
    final rows = await db.query('commercants',
        where: 'id = ?', whereArgs: [commercantId]);
    if (rows.isEmpty) return false;

    final stored = rows.first['pin_hash'] as String;
    return stored == _hashPin(pin);
  }

  /// Incrémenter le compteur de tentatives échouées
  Future<int> incrementerTentatives(int commercantId) async {
    final db   = await database;
    final rows = await db.query('sessions',
        where: 'commercant_id = ? AND is_active = 1',
        whereArgs: [commercantId], limit: 1);

    if (rows.isEmpty) {
      // Créer une session temporaire pour compter les tentatives
      await db.insert('sessions', {
        'commercant_id':    commercantId,
        'token':            '',
        'is_active':        0,
        'tentatives_pin':   1,
        'derniere_activite': DateTime.now().toIso8601String(),
        'created_at':       DateTime.now().toIso8601String(),
      });
      return 1;
    }

    final tentatives = (rows.first['tentatives_pin'] as int) + 1;
    await db.update('sessions',
        {'tentatives_pin': tentatives},
        where: 'id = ?', whereArgs: [rows.first['id']]);
    return tentatives;
  }

  /// Remettre le compteur d'erreurs à zéro après succès
  Future<void> reinitialiserTentatives(int commercantId) async {
    final db = await database;
    await db.update('sessions',
        {'tentatives_pin': 0},
        where: 'commercant_id = ? AND is_active = 1',
        whereArgs: [commercantId]);
  }

  /// Créer une session active après connexion réussie
  Future<void> ouvrirSession(int commercantId) async {
    final db    = await database;
    final token = _genToken(commercantId);

    // Désactiver les anciennes sessions
    await db.update('sessions', {'is_active': 0},
        where: 'commercant_id = ?', whereArgs: [commercantId]);

    // Créer la nouvelle session
    await db.insert('sessions', {
      'commercant_id':    commercantId,
      'token':            token,
      'is_active':        1,
      'tentatives_pin':   0,
      'derniere_activite': DateTime.now().toIso8601String(),
      'created_at':       DateTime.now().toIso8601String(),
    });
  }

  /// Vérifier si une session active existe (pour main.dart)
  Future<bool> sessionActive() async {
    final db   = await database;
    final rows = await db.query('sessions',
        where: 'is_active = 1', limit: 1);
    return rows.isNotEmpty;
  }

  /// Fermer la session (déconnexion)
  Future<void> fermerSession(int commercantId) async {
    final db = await database;
    await db.update('sessions', {'is_active': 0},
        where: 'commercant_id = ?', whereArgs: [commercantId]);
  }

  /// Mettre à jour le PIN (réinitialisation)
  Future<void> mettreAJourPin(int commercantId, String nouveauPin) async {
    final db = await database;
    await db.update('commercants',
        {'pin_hash': _hashPin(nouveauPin), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [commercantId]);
  }

  // ══════════════════════════════════════
  //  DASHBOARD — Données affichées
  // ══════════════════════════════════════

  /// Charger les N dernières transactions (liste du dashboard)
  Future<List<Map<String, dynamic>>> chargerTransactionsRecentes(
      int commercantId, {int limite = 10}) async {
    final db = await database;
    return db.query('transactions',
        where: 'commercant_id = ?',
        whereArgs: [commercantId],
        orderBy: 'date DESC',
        limit: limite);
  }

  /// Total des ventes du jour
  Future<double> ventesAujourdhui(int commercantId) async {
    final db  = await database;
    final auj = DateTime.now();
    final debut = DateTime(auj.year, auj.month, auj.day).toIso8601String();
    final fin   = DateTime(auj.year, auj.month, auj.day, 23, 59, 59).toIso8601String();

    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) as total
      FROM transactions
      WHERE commercant_id = ?
        AND type = 'vente'
        AND is_credit = 1
        AND date BETWEEN ? AND ?
    ''', [commercantId, debut, fin]);

    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total des dettes en cours (non remboursées)
  Future<double> dettesEnCours(int commercantId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) as total
      FROM transactions
      WHERE commercant_id = ?
        AND type = 'dette'
        AND is_credit = 0
    ''', [commercantId]);

    // Soustraire les remboursements
    final rowsR = await db.rawQuery('''
      SELECT COALESCE(SUM(montant), 0) as total
      FROM transactions
      WHERE commercant_id = ?
        AND type = 'remboursement'
        AND is_credit = 1
    ''', [commercantId]);

    final dettes = (rows.first['total'] as num?)?.toDouble() ?? 0.0;
    final rembours = (rowsR.first['total'] as num?)?.toDouble() ?? 0.0;
    return (dettes - rembours).clamp(0, double.infinity);
  }

  /// Ajouter une transaction (nouvelle vente, dette, etc.)
  Future<int> ajouterTransaction({
    required int commercantId,
    required String nomClient,
    required String type,
    required double montant,
    required bool isCredit,
    String? note,
  }) async {
    final db = await database;
    return db.insert('transactions', {
      'commercant_id': commercantId,
      'nom_client':    nomClient,
      'type':          type,
      'montant':       montant,
      'is_credit':     isCredit ? 1 : 0,
      'date':          DateTime.now().toIso8601String(),
      'note':          note,
    });
  }

  // ══════════════════════════════════════
  //  UTILITAIRES PRIVÉS
  // ══════════════════════════════════════

  /// Hasher le PIN avec SHA-256 (jamais stocker en clair)
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'lecommercant_salt_2024');
    return sha256.convert(bytes).toString();
  }

  /// Générer un token de session
  String _genToken(int commercantId) {
    final bytes = utf8.encode('$commercantId${DateTime.now().millisecondsSinceEpoch}');
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _db = null;
  }
}