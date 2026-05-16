import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // ✅ Ajouté pour détecter le mode Web

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;
  static late SharedPreferences _prefs;

  final supabase = Supabase.instance.client;

  AppDatabase._init();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }
Future<void> debugUsers() async {
  final db = await database;

  var result = await db.query("commercants"); // 🔥 ici
  print("CONTENU TABLE commercants: $result");
}
  Future<Database> _initDB() async {
    const dbName = 'lecommercant.db';
    
    // ✅ CORRECTION : Sur le Web, on ne demande pas le chemin système (null)
    if (kIsWeb) {
      return openDatabase(dbName, version: 1, onCreate: _creerTables);
    } else {
      final path = join(await getDatabasesPath(), dbName);
      return openDatabase(path, version: 1, onCreate: _creerTables);
    }
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
    await db.insert('sessions', {
      'commercant_id': id,
      'token': 'tk_$id', 
      'is_active': 1,
    });
  }

  Future<void> fermerSession(int id) async {
    final db = await database;
    await db.update('sessions', {'is_active': 0}, where: 'commercant_id = ?', whereArgs: [id]);
  }

  // ── DASHBOARD : VENTES DU JOUR ────────────────────────────────────────────
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
  Future<List<Map<String, dynamic>>> chargerTransactionsRecentes(
      int id, {int limite = 10}) async {
    final List<Map<String, dynamic>> toutes = [];

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
    final str = details.toString();
    final parts = str.split(',');
    if (parts.isEmpty) return str;
    final premier = parts.first.trim();
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
    return sha256.convert(utf8.encode('$pin salt_123')).toString();
  }

  // ── USER (SharedPreferences) ──────────────────────────────────────────────
  static Map<String, String> getUser() {
    final raw = _prefs.getString('user');
    if (raw == null) {
      return {
        'name': 'Merlia Ndiaye',
        'role': 'Cerveb Caisse',
        'email': 'merlia.ndiaye@cerveb.com',
        'phone': '+221 77 000 00 00',
        'avatar': 'MN',
        'joined': 'Janvier 2024',
      };
    }
    return Map<String, String>.from(jsonDecode(raw));
  }

  static Future<void> saveUser(Map<String, String> user) async {
    await _prefs.setString('user', jsonEncode(user));
  }

  // ── NOTIFICATIONS (SharedPreferences) ────────────────────────────────────
  static List<Map<String, dynamic>> getNotifications() {
    final raw = _prefs.getString('notifications');
    if (raw == null) {
      return [
        {'id': 1, 'title': 'Nouvelle vente enregistrée', 'body': 'Une vente de 25 000 F a été effectuée.', 'time': 'Il y a 5 min', 'read': false, 'type': 'vente'},
        {'id': 2, 'title': 'Rapport hebdomadaire prêt', 'body': 'Votre rapport de la semaine est disponible.', 'time': 'Il y a 1h', 'read': false, 'type': 'rapport'},
        {'id': 3, 'title': 'Connexion détectée', 'body': 'Connexion depuis un nouvel appareil.', 'time': 'Hier', 'read': true, 'type': 'securite'},
        {'id': 4, 'title': 'Mise à jour disponible', 'body': 'Version 2.4.1 disponible.', 'time': 'Il y a 2j', 'read': true, 'type': 'systeme'},
      ];
    }
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveNotifications(List<Map<String, dynamic>> notifs) async {
    await _prefs.setString('notifications', jsonEncode(notifs));
  }

  // ── SETTINGS (SharedPreferences) ─────────────────────────────────────────
  static Map<String, dynamic> getSettings() {
    final raw = _prefs.getString('settings');
    if (raw == null) {
      return {
        'langue': 'Français',
        'devise': 'XOF (F CFA)',
        'notifications': true,
        'sons': true,
        'vibration': true,
        'syncAuto': true,
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString('settings', jsonEncode(settings));
  }

  // ── BIOMÉTRIE (SharedPreferences) ────────────────────────────────────────
  static Map<String, dynamic> getBiometrie() {
    final raw = _prefs.getString('biometrie');
    if (raw == null) {
      return {
        'empreinte': false,
        'reconnaissance': false,
        'pin': true,
        'pinValue': '1234',
        'lastAuth': "Aujourd'hui à 08:32",
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveBiometrie(Map<String, dynamic> bio) async {
    await _prefs.setString('biometrie', jsonEncode(bio));
  }
}