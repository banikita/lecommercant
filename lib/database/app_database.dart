import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;
  final supabase = Supabase.instance.client;

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

  // ── INSCRIPTION ──────────────────────────────────────────────────────────
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

  // ── CONNEXION & PIN ───────────────────────────────────────────────────────
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

  // ── SESSIONS ──────────────────────────────────────────────────────────────
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
    await db.insert('sessions', {'commercant_id': id, 'token': 'tk_$id', 'is_active': 1});
  }

  Future<void> fermerSession(int id) async {
    final db = await database;
    await db.update('sessions', {'is_active': 0}, where: 'commercant_id = ?', whereArgs: [id]);
  }

  // ── DASHBOARD : VENTES DU JOUR ────────────────────────────────────────────
  // Lit depuis la table 'ventes' (ventes payées cash au comptant)
  Future<double> ventesAujourdhui(int id) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('ventes')
          .select('montant_total')
          .eq('commercant_id', id)
          .gte('created_at', today);
      double total = 0;
      for (var row in response) {
        total += (row['montant_total'] ?? 0).toDouble();
      }
      return total;
    } catch (_) {
      // Fallback : lit les dettes du jour si table ventes absente
      try {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final response = await supabase
            .from('dettes')
            .select('montant_initial')
            .eq('commercant_id', id)
            .gte('created_at', today);
        double total = 0;
        for (var row in response) {
          total += (row['montant_initial'] ?? 0).toDouble();
        }
        return total;
      } catch (e) {
        return 0.0;
      }
    }
  }

  // ── DASHBOARD : DETTES EN COURS ───────────────────────────────────────────
  Future<double> dettesEnCours(int id) async {
    try {
      final response = await supabase
          .from('dettes')
          .select('montant_initial, montant_rembourse')
          .eq('commercant_id', id)
          .eq('statut', 'en_cours');
      double total = 0;
      for (var row in response) {
        double ini = (row['montant_initial'] ?? 0).toDouble();
        double rem = (row['montant_rembourse'] ?? 0).toDouble();
        total += (ini - rem).clamp(0, double.infinity);
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // ── DASHBOARD : TRANSACTIONS RÉCENTES ─────────────────────────────────────
  // Fusionne 3 sources :
  //   1. 'ventes'   → ventes payées comptant          (type: 'vente_cash')
  //   2. 'dettes'   → crédits accordés                (type: 'credit')
  //   3. 'paiements'→ remboursements partiels/totaux   (type: 'remboursement')
  Future<List<Map<String, dynamic>>> chargerTransactionsRecentes(
      int id, {int limite = 10}) async {
    final List<Map<String, dynamic>> toutes = [];

    // ── 1. Ventes payées comptant ──
    try {
      final ventes = await supabase
          .from('ventes')
          .select('id, created_at, montant_total, produits_details, nom_client')
          .eq('commercant_id', id)
          .order('created_at', ascending: false)
          .limit(limite);
      for (var v in ventes) {
        toutes.add({
          'type': 'vente_cash',
          'label': v['nom_client'] ?? 'Client',
          'produit': _extrairePremierProduit(v['produits_details']),
          'produits_details': v['produits_details'] ?? '',
          'montant': (v['montant_total'] ?? 0).toDouble(),
          'created_at': v['created_at'] ?? '',
          'statut': 'paye',
          'image_categorie': _devinerCategorie(v['produits_details']),
        });
      }
    } catch (_) {}

    // ── 2. Crédits accordés (dettes) ──
    try {
      final dettes = await supabase
          .from('dettes')
          .select('id, created_at, montant_initial, montant_rembourse, produits_details, nom_debiteur, photo_url, statut')
          .eq('commercant_id', id)
          .order('created_at', ascending: false)
          .limit(limite);
      for (var d in dettes) {
        double ini = (d['montant_initial'] ?? 0).toDouble();
        double rem = (d['montant_rembourse'] ?? 0).toDouble();
        bool solde = rem >= ini;
        toutes.add({
          'type': 'credit',
          'label': d['nom_debiteur'] ?? 'Client',
          'produit': _extrairePremierProduit(d['produits_details']),
          'produits_details': d['produits_details'] ?? '',
          'montant': ini,
          'montant_rembourse': rem,
          'reste': (ini - rem).clamp(0, double.infinity),
          'created_at': d['created_at'] ?? '',
          'statut': solde ? 'paye' : 'impaye',
          'photo_url': d['photo_url'],
          'image_categorie': _devinerCategorie(d['produits_details']),
        });
      }
    } catch (_) {}

    // ── 3. Paiements / remboursements partiels ──
    try {
      final paiements = await supabase
          .from('paiements')
          .select('id, created_at, montant, methode_paiement, dette_id')
          .eq('commercant_id', id)
          .order('created_at', ascending: false)
          .limit(limite);
      for (var p in paiements) {
        toutes.add({
          'type': 'remboursement',
          'label': 'Remboursement',
          'produit': 'Versement reçu',
          'produits_details': p['methode_paiement'] ?? 'Cash',
          'montant': (p['montant'] ?? 0).toDouble(),
          'created_at': p['created_at'] ?? '',
          'statut': 'paye',
          'image_categorie': 'paiement',
        });
      }
    } catch (_) {}

    // Trie par date décroissante et limite
    toutes.sort((a, b) {
      try {
        return DateTime.parse(b['created_at'])
            .compareTo(DateTime.parse(a['created_at']));
      } catch (_) {
        return 0;
      }
    });

    return toutes.take(limite).toList();
  }

  // ── HELPERS INTERNES ──────────────────────────────────────────────────────
  String _extrairePremierProduit(dynamic details) {
    if (details == null || details.toString().isEmpty) return 'Produit';
    // Format possible: "2x Pain, 1x Sucre" ou "Pain, Sucre"
    final str = details.toString();
    final parts = str.split(',');
    if (parts.isEmpty) return str;
    final premier = parts.first.trim();
    // Enlève le préfixe quantité "2x "
    final regex = RegExp(r'^\d+x\s+');
    return premier.replaceFirst(regex, '').trim();
  }

  String _devinerCategorie(dynamic details) {
    if (details == null) return 'Autre';
    final str = details.toString().toLowerCase();
    if (str.contains('pain') || str.contains('riz') || str.contains('aliment') ||
        str.contains('farine') || str.contains('huile') || str.contains('sucre')) {
      return 'Alimentaire';
    }
    if (str.contains('eau') || str.contains('jus') || str.contains('boisson') ||
        str.contains('lait') || str.contains('café')) {
      return 'Boissons';
    }
    if (str.contains('savon') || str.contains('hygiène') || str.contains('detergen') ||
        str.contains('lessive') || str.contains('shampooing')) {
      return 'Hygiène';
    }
    return 'Autre';
  }

  // ── SÉCURITÉ ──────────────────────────────────────────────────────────────
  String hashPin(String pin) {
    return sha256.convert(utf8.encode(pin + "salt_123")).toString();
  }
}