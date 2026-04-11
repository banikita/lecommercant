import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:le_commercant/models/dettes_model.dart';

// ══════════════════════════════════════════════════════════════
//  BASE DE DONNÉES — SQLite LOCAL + Supabase CLOUD
// ══════════════════════════════════════════════════════════════

class DetteDatabase {
  static final DetteDatabase instance = DetteDatabase._init();
  static Database? _db;
  DetteDatabase._init();

  // ── Supabase client
  final _supabase = Supabase.instance.client;

  // ── ID commerçant
  Future<String> get _commercantId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('commercant_id') ?? 'local';
  }

  // ══════════════════════════════════════
  //  INITIALISATION SQLite
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
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dettes (
        id                TEXT PRIMARY KEY,
        nom_debiteur      TEXT NOT NULL,
        telephone         TEXT,
        montant_initial   REAL NOT NULL,
        montant_rembourse REAL DEFAULT 0,
        date_debut        TEXT NOT NULL,
        duree_jours       INTEGER NOT NULL,
        creancier         TEXT,
        statut            TEXT DEFAULT 'en_cours',
        sync_cloud        INTEGER DEFAULT 0,
        created_at        TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE paiements (
        id          TEXT PRIMARY KEY,
        dette_id    TEXT NOT NULL,
        montant     REAL NOT NULL,
        date        TEXT NOT NULL,
        note        TEXT,
        sync_cloud  INTEGER DEFAULT 0,
        FOREIGN KEY (dette_id) REFERENCES dettes(id)
      )
    ''');
  }

  String _genId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';

  // ══════════════════════════════════════
  //  CRUD DETTES — LOCAL D'ABORD
  // ══════════════════════════════════════

  Future<List<Dette>> chargerDettes() async {
    final db   = await database;
    final rows = await db.query('dettes', orderBy: 'created_at DESC');
    final dettes = <Dette>[];

    for (final row in rows) {
      final dette = Dette.fromMap(row);
      final pRows = await db.query(
        'paiements',
        where: 'dette_id = ?',
        whereArgs: [dette.id],
        orderBy: 'date DESC',
      );
      dette.paiements = pRows.map(Paiement.fromMap).toList();
      dettes.add(dette);
    }
    return dettes;
  }

  Future<Dette> ajouterDette(Dette dette) async {
    final db  = await database;
    final id  = dette.id ?? _genId();
    final map = dette.toMap()..['id'] = id;
    await db.insert('dettes', map, conflictAlgorithm: ConflictAlgorithm.replace);

    final nouvelleDette = Dette.fromMap({...map, 'id': id});
    _syncDetteCloud(nouvelleDette);
    return nouvelleDette;
  }

  Future<void> enregistrerPaiement(String detteId, double montant, {String? note}) async {
    final db = await database;

    // Utilisation d'une transaction pour garantir l'intégrité locale
    await db.transaction((txn) async {
      // 1. Créer le paiement
      final paiementId = _genId();
      final paiement = Paiement(
        id:       paiementId,
        detteId:  detteId,
        montant:  montant,
        date:     DateTime.now(),
        note:     note,
      );
      await txn.insert('paiements', paiement.toMap()..['id'] = paiementId);

      // 2. Récupérer la dette pour calculer le nouveau solde
      final rows = await txn.query('dettes', where: 'id = ?', whereArgs: [detteId]);
      if (rows.isEmpty) return;

      final dette = Dette.fromMap(rows.first);
      final nouveauRembourse = dette.montantRembourse + montant;
      final nouveauStatut = nouveauRembourse >= dette.montantInitial
          ? 'rembourse'
          : (dette.estEchu ? 'en_retard' : 'en_cours');

      await txn.update(
        'dettes',
        {
          'montant_rembourse': nouveauRembourse,
          'statut': nouveauStatut,
          'sync_cloud': 0,
        },
        where: 'id = ?',
        whereArgs: [detteId],
      );

      // 3. Sync cloud après succès de la transaction locale
      _syncPaiementCloud(paiement, detteId, nouveauRembourse, nouveauStatut);
    });
  }

  Future<void> supprimerDette(String id) async {
    final db = await database;
    await db.delete('dettes',    where: 'id = ?', whereArgs: [id]);
    await db.delete('paiements', where: 'dette_id = ?', whereArgs: [id]);
    _deleteDetteCloud(id);
  }

  // ══════════════════════════════════════
  //  SYNCHRONISATION CLOUD (Supabase)
  // ══════════════════════════════════════

  bool get _cloudDisponible {
    try {
      return _supabase.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncDetteCloud(Dette dette) async {
    if (!_cloudDisponible) return;
    try {
      final cId = await _commercantId;
      await _supabase.from('dettes').upsert(dette.toCloud(cId));
      
      final db = await database;
      await db.update('dettes', {'sync_cloud': 1},
          where: 'id = ?', whereArgs: [dette.id]);
    } catch (e) { /* Silencieux */ }
  }

  Future<void> _syncPaiementCloud(
      Paiement p, String detteId, double nouveauRembourse, String statut) async {
    if (!_cloudDisponible) return;
    try {
      final cId = await _commercantId;
      await _supabase.from('paiements').upsert(p.toCloud(cId));
      await _supabase.from('dettes').update({
        'montant_rembourse': nouveauRembourse,
        'statut': statut,
      }).eq('id', detteId);

      final db = await database;
      await db.update('paiements', {'sync_cloud': 1},
          where: 'id = ?', whereArgs: [p.id]);
    } catch (e) { /* Sera re-synced plus tard */ }
  }

  Future<void> _deleteDetteCloud(String id) async {
    if (!_cloudDisponible) return;
    try {
      await _supabase.from('paiements').delete().eq('dette_id', id);
      await _supabase.from('dettes').delete().eq('id', id);
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  SYNCHRONISATION COMPLÈTE AU DÉMARRAGE
  // ══════════════════════════════════════
  Future<void> synchroniserAvecCloud() async {
    if (!_cloudDisponible) return;
    try {
      final cId = await _commercantId;
      final db  = await database;

      // Pull dettes
      final cloudDettes = await _supabase.from('dettes').select().eq('commercant_id', cId);
      for (final row in cloudDettes as List) {
        final dette = Dette.fromCloud(row);
        await db.insert('dettes', dette.toMap()..['sync_cloud'] = 1,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Pull paiements
      final cloudPaiements = await _supabase.from('paiements').select().eq('commercant_id', cId);
      for (final row in cloudPaiements as List) {
        final p = Paiement.fromCloud(row);
        await db.insert('paiements', p.toMap()..['sync_cloud'] = 1,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Push dettes non-synced
      final nonSyncedDettes = await db.query('dettes', where: 'sync_cloud = 0');
      for (final row in nonSyncedDettes) {
        final dette = Dette.fromMap(row);
        await _supabase.from('dettes').upsert(dette.toCloud(cId));
        await db.update('dettes', {'sync_cloud': 1}, where: 'id = ?', whereArgs: [dette.id]);
      }

      // Push paiements non-synced
      final nonSyncedP = await db.query('paiements', where: 'sync_cloud = 0');
      for (final row in nonSyncedP) {
        final p = Paiement.fromMap(row);
        await _supabase.from('paiements').upsert(p.toCloud(cId));
        await db.update('paiements', {'sync_cloud': 1}, where: 'id = ?', whereArgs: [p.id]);
      }
    } catch (e) { /* Gestion erreur silencieuse */ }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}