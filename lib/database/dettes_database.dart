import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dettes_model.dart';

class DetteDatabase {
  static final DetteDatabase instance = DetteDatabase._init();
  static Database? _db;
  DetteDatabase._init();

  final _supa = Supabase.instance.client;
  String? get _uid => _supa.auth.currentUser?.id;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _ouvrirDB();
    return _db!;
  }

  Future<Database> _ouvrirDB() async {
    final chemin = join(await getDatabasesPath(), 'le_commercant_dettes.db');
    return openDatabase(
      chemin,
      version: 1,
      onCreate: _creerTables,
      onUpgrade: _migrerTables,
    );
  }

  Future<void> _creerTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dettes (
        id                TEXT    PRIMARY KEY,
        commercant_id     TEXT    NOT NULL,
        nom_debiteur      TEXT    NOT NULL,
        telephone         TEXT    DEFAULT '',
        montant_initial   REAL    NOT NULL DEFAULT 0 CHECK (montant_initial > 0),
        montant_rembourse REAL    NOT NULL DEFAULT 0,
        date_debut        TEXT    NOT NULL,
        duree_jours       INTEGER NOT NULL DEFAULT 30,
        creancier         TEXT,
        statut            TEXT    NOT NULL DEFAULT 'en_cours'
                          CHECK (statut IN ('en_cours','en_retard','rembourse')),
        sync_cloud        INTEGER NOT NULL DEFAULT 0,
        created_at        TEXT    NOT NULL,
        updated_at        TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paiements (
        id            TEXT  PRIMARY KEY,
        dette_id      TEXT  NOT NULL,
        commercant_id TEXT  NOT NULL,
        montant       REAL  NOT NULL CHECK (montant > 0),
        date          TEXT  NOT NULL,
        note          TEXT,
        sync_cloud    INTEGER NOT NULL DEFAULT 0,
        created_at    TEXT  NOT NULL,
        FOREIGN KEY (dette_id) REFERENCES dettes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dettes_commercant    ON dettes    (commercant_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_paiements_dette      ON paiements (dette_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_paiements_commercant ON paiements (commercant_id)');
  }

  Future<void> _migrerTables(Database db, int ancienne, int nouvelle) async {
    await db.execute('DROP TABLE IF EXISTS paiements');
    await db.execute('DROP TABLE IF EXISTS dettes');
    await _creerTables(db, nouvelle);
  }

  String _genId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rnd = ts % 99999;
    return 'local_${ts}_$rnd';
  }

  Future<List<Dette>> chargerDettes() async {
    try {
      final db = await database;
      final uid = _uid ?? 'local';
      final rows = await db.query('dettes', where: 'commercant_id = ?', whereArgs: [uid], orderBy: 'created_at DESC');
      final dettes = <Dette>[];
      for (final row in rows) {
        final dette = Dette.fromMap(row);
        final pRows = await db.query('paiements', where: 'dette_id = ?', whereArgs: [dette.id], orderBy: 'date DESC');
        dette.paiements = pRows.map(Paiement.fromMap).toList();
        dettes.add(dette);
      }
      return dettes;
    } catch (e, st) {
      print('❌ chargerDettes ERROR: $e\n$st');
      return [];
    }
  }

  // ⚠️ CORRIGÉ : lance une exception en cas d'erreur au lieu de retourner null
  Future<Dette> insererDette(Dette dette) async {
    final db = await database;
    final uid = _uid ?? 'local';
    final now = DateTime.now().toIso8601String();
    final id = dette.id ?? _genId();

    final map = <String, dynamic>{
      'id': id,
      'commercant_id': uid,
      'nom_debiteur': dette.nomDebiteur.trim(),
      'telephone': dette.telephone.trim(),
      'montant_initial': dette.montantInitial,
      'montant_rembourse': dette.montantRembourse,
      'date_debut': dette.dateDebut.toIso8601String(),
      'duree_jours': dette.dureeJours,
      'creancier': dette.creancier,
      'statut': dette.statutCalcule,
      'sync_cloud': 0,
      'created_at': now,
      'updated_at': now,
    };

    print('🟢 Insertion locale : $map');
    try {
      await db.insert('dettes', map, conflictAlgorithm: ConflictAlgorithm.replace);
      print('🟢 Insertion réussie pour ${dette.nomDebiteur}');
    } catch (e) {
      print('❌ ERREUR SQL : $e');
      throw Exception('Erreur base de données locale : $e');
    }

    // Envoi cloud asynchrone (ne bloque pas)
    _pushDetteCloud(map);
    return Dette.fromMap(map);
  }

  Future<bool> enregistrerPaiement(String detteId, double montant, {String? note}) async {
    try {
      final db = await database;
      final uid = _uid ?? 'local';
      final now = DateTime.now().toIso8601String();
      final pid = _genId();

      final rows = await db.query('dettes', where: 'id = ?', whereArgs: [detteId]);
      if (rows.isEmpty) throw Exception('Dette introuvable');
      final dette = Dette.fromMap(rows.first);
      if (montant <= 0 || montant > dette.montantRestant) throw Exception('Montant invalide');

      final paiementMap = {
        'id': pid,
        'dette_id': detteId,
        'commercant_id': uid,
        'montant': montant,
        'date': now,
        'note': note,
        'sync_cloud': 0,
        'created_at': now,
      };
      await db.insert('paiements', paiementMap, conflictAlgorithm: ConflictAlgorithm.replace);

      final nouveauRembourse = dette.montantRembourse + montant;
      final nouveauStatut = nouveauRembourse >= dette.montantInitial ? 'rembourse' : (dette.estEchu ? 'en_retard' : 'en_cours');
      await db.update('dettes', {
        'montant_rembourse': nouveauRembourse,
        'statut': nouveauStatut,
        'updated_at': now,
        'sync_cloud': 0,
      }, where: 'id = ?', whereArgs: [detteId]);

      _pushPaiementCloud(paiementMap);
      _updateDetteCloud(detteId, nouveauRembourse, nouveauStatut, now);
      return true;
    } catch (e) {
      print('❌ enregistrerPaiement ERROR: $e');
      return false;
    }
  }

  Future<bool> supprimerDette(String id) async {
    try {
      final db = await database;
      await db.delete('dettes', where: 'id = ?', whereArgs: [id]);
      _deleteDetteCloud(id);
      return true;
    } catch (e) {
      print('❌ supprimerDette ERROR: $e');
      return false;
    }
  }

  Future<void> synchroniserAvecCloud() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final db = await database;
      final cloudDettes = await _supa.from('dettes').select().eq('commercant_id', uid).order('created_at', ascending: false);
      for (final row in cloudDettes as List<dynamic>) {
        final map = _detteCloudToLocal(row, uid);
        await db.insert('dettes', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final cloudPaiements = await _supa.from('paiements').select().eq('commercant_id', uid);
      for (final row in cloudPaiements as List<dynamic>) {
        final map = _paiementCloudToLocal(row, uid);
        await db.insert('paiements', map, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final nonSyncDettes = await db.query('dettes', where: 'sync_cloud = 0 AND commercant_id = ?', whereArgs: [uid]);
      for (final row in nonSyncDettes) await _pushDetteCloud(row);
      final nonSyncP = await db.query('paiements', where: 'sync_cloud = 0 AND commercant_id = ?', whereArgs: [uid]);
      for (final row in nonSyncP) await _pushPaiementCloud(row);
    } catch (e) {
      print('⚠️ synchroniserAvecCloud: $e');
    }
  }

  Future<void> _pushDetteCloud(Map<String, dynamic> local) async {
    try {
      final db = await database;
      final payload = {
        'id': local['id'],
        'commercant_id': local['commercant_id'],
        'nom_debiteur': local['nom_debiteur'],
        'telephone': local['telephone'],
        'montant_initial': local['montant_initial'],
        'montant_rembourse': local['montant_rembourse'],
        'date_debut': local['date_debut'],
        'duree_jours': local['duree_jours'],
        'creancier': local['creancier'],
        'statut': local['statut'],
      };
      await _supa.from('dettes').upsert(payload);
      await db.update('dettes', {'sync_cloud': 1}, where: 'id = ?', whereArgs: [local['id']]);
    } catch (_) {}
  }

  Future<void> _pushPaiementCloud(Map<String, dynamic> local) async {
    try {
      final db = await database;
      final payload = {
        'id': local['id'],
        'dette_id': local['dette_id'],
        'commercant_id': local['commercant_id'],
        'montant': local['montant'],
        'date': local['date'],
        'note': local['note'],
      };
      await _supa.from('paiements').upsert(payload);
      await db.update('paiements', {'sync_cloud': 1}, where: 'id = ?', whereArgs: [local['id']]);
    } catch (_) {}
  }

  Future<void> _updateDetteCloud(String id, double nouveauRembourse, String statut, String updatedAt) async {
    try {
      await _supa.from('dettes').update({'montant_rembourse': nouveauRembourse, 'statut': statut, 'updated_at': updatedAt}).eq('id', id);
    } catch (_) {}
  }

  Future<void> _deleteDetteCloud(String id) async {
    try { await _supa.from('dettes').delete().eq('id', id); } catch (_) {}
  }

  Map<String, dynamic> _detteCloudToLocal(Map<String, dynamic> cloud, String uid) => {
    'id': cloud['id'],
    'commercant_id': uid,
    'nom_debiteur': cloud['nom_debiteur'] ?? '',
    'telephone': cloud['telephone'] ?? '',
    'montant_initial': (cloud['montant_initial'] as num).toDouble(),
    'montant_rembourse': (cloud['montant_rembourse'] as num? ?? 0).toDouble(),
    'date_debut': cloud['date_debut'],
    'duree_jours': cloud['duree_jours'] as int? ?? 30,
    'creancier': cloud['creancier'],
    'statut': cloud['statut'] ?? 'en_cours',
    'sync_cloud': 1,
    'created_at': cloud['created_at'] ?? DateTime.now().toIso8601String(),
    'updated_at': cloud['updated_at'] ?? DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> _paiementCloudToLocal(Map<String, dynamic> cloud, String uid) => {
    'id': cloud['id'],
    'dette_id': cloud['dette_id'],
    'commercant_id': uid,
    'montant': (cloud['montant'] as num).toDouble(),
    'date': cloud['date'],
    'note': cloud['note'],
    'sync_cloud': 1,
    'created_at': cloud['created_at'] ?? DateTime.now().toIso8601String(),
  };

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}