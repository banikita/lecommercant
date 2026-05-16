import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _db;
  final supabase = Supabase.instance.client;
  static late SharedPreferences _prefs;

  AppDatabase._init();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

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
      // ✅ CORRECTION : garantit que les tables existent même si onCreate a échoué
      onOpen: (db) async {
        await _creerTables(db, 1).catchError((_) {});
      },
    );
  }

  // ✅ CORRECTION : utilisation de IF NOT EXISTS pour éviter les erreurs
  Future<void> _creerTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commercants (
        id INTEGER PRIMARY KEY,
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
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commercant_id INTEGER NOT NULL REFERENCES commercants(id) ON DELETE CASCADE,
        token TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        tentatives_pin INTEGER NOT NULL DEFAULT 0,
        derniere_activite TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GESTION DES COMMERÇANTS (LOCAL SQLite)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int?> inscrire({
    required String prenom,
    required String nom,
    required String telephone,
    required String nomBoutique,
    required String ville,
    required String pin,
  }) async {
    final db = await database;
    final exist = await db.query('commercants', where: 'telephone = ?', whereArgs: [telephone]);
    if (exist.isNotEmpty) return null;
    return await db.insert('commercants', {
      'prenom': prenom,
      'nom': nom,
      'telephone': telephone,
      'nom_boutique': nomBoutique,
      'ville': ville,
      'pin_hash': hashPin(pin, telephone),
    });
  }

  Future<Map<String, dynamic>?> chargerCommercant() async {
    final db = await database;
    final rows = await db.query('commercants', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<bool> verifierPin(int commercantId, String pin) async {
    final db = await database;
    final rows = await db.query('commercants', where: 'id = ?', whereArgs: [commercantId]);
    if (rows.isEmpty) return false;
    final user = rows.first;
    return user['pin_hash'] == hashPin(pin, user['telephone']);
  }

  Future<void> mettreAJourPin(int id, String nouveauPin) async {
    final db = await database;
    final user = await db.query('commercants', where: 'id = ?', whereArgs: [id]);
    if (user.isEmpty) return;

    final telephone = user.first['telephone'] as String;
    final nouveauHash = hashPin(nouveauPin, telephone);

    // 1. SQLite local
    await db.update(
      'commercants',
      {'pin_hash': nouveauHash},
      where: 'id = ?',
      whereArgs: [id],
    );

    // 2. Synchronisation Supabase
    try {
      await supabase
          .from('commercants')
          .update({'pin_hash': nouveauHash})
          .eq('id', id);
    } catch (e) {
      print("Erreur synchro Supabase du PIN : $e");
    }
    await reinitialiserTentatives(id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSIONS
  // ═══════════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD : CALCULS DEPUIS SUPABASE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<double> ventesAujourdhui(int id) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('ventes')
          .select('total_montant')
          .eq('commercant_id', id)
          .gte('date_vente', today);
      final List rows = response as List;
      return rows.fold<double>(0.0, (double sum, row) {
        final montant = row['total_montant'] ?? 0;
        return sum + (montant as num).toDouble();
      });
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> dettesEnCours(int id) async {
    try {
      final response = await supabase
          .from('dettes')
          .select('montant_initial, montant_rembourse')
          .eq('commercant_id', id)
          .eq('statut', 'en_cours');
      double total = 0;
      for (var row in response) {
        double reste = (row['montant_initial'] ?? 0).toDouble() -
            (row['montant_rembourse'] ?? 0).toDouble();
        total += reste > 0 ? reste : 0;
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> chargerTransactionsRecentes(int id,
      {int limite = 15}) async {
    try {
      final response = await supabase
          .from('v_transactions')
          .select()
          .eq('commercant_id', id)
          .order('date_vente', ascending: false)
          .limit(limite);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> recupererNotifications(int id) async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('commercant_id', id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erreur chargement notifications: $e");
      return [];
    }
  }

  Future<void> marquerNotificationLue(int notificationId) async {
    await supabase
        .from('notifications')
        .update({'est_lu': true}).eq('id', notificationId);
  }

  Future<void> toutMarquerLu(int commercantId) async {
    await supabase
        .from('notifications')
        .update({'est_lu': true}).eq('commercant_id', commercantId);
  }

  Future<void> supprimerNotification(int notificationId) async {
    await supabase.from('notifications').delete().eq('id', notificationId);
  }

  Future<void> ajouterNotification(
      int commercantId, String titre, String message) async {
    await supabase.from('notifications').insert({
      'commercant_id': commercantId,
      'titre': titre,
      'message': message,
      'est_lu': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SÉCURITÉ & BIOMÉTRIE
  // ═══════════════════════════════════════════════════════════════════════════

  String hashPin(String pin, dynamic salt) {
    return sha256.convert(utf8.encode(pin + salt.toString())).toString();
  }

  static Map<String, dynamic> getBiometrie() {
    final raw = _prefs.getString('biometrie');
    if (raw == null) {
      return {
        'empreinte': false,
        'reconnaissance': false,
        'pin': true,
        'pinValue': '1234',
        'lastAuth': "Jamais",
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveBiometrie(Map<String, dynamic> bio) async {
    await _prefs.setString('biometrie', jsonEncode(bio));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARAMÈTRES
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _settingsKey = 'app_settings';

  static Map<String, dynamic> getSettings() {
    final raw = _prefs.getString(_settingsKey);
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
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  Future<void> synchroniserPinDepuisSupabase(int id) async {
    final response = await supabase
        .from('commercants')
        .select('pin_hash')
        .eq('id', id)
        .single();
    final remoteHash = response['pin_hash'] as String?;
    if (remoteHash != null) {
      final db = await database;
      await db.update(
        'commercants',
        {'pin_hash': remoteHash},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> sauvegarderCommercantLocal(Map<String, dynamic> donnees) async {
    final db = await database;
    await db.insert(
      'commercants',
      donnees,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}