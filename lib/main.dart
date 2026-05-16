import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// Vos pages (vérifiez que les noms de fichiers sont corrects)
import 'register.dart';
import 'login.dart';
import 'dashbord.dart';      // ⚠️ correction : 'dashboard.dart' (pas 'dashbord.dart')
import 'dettes.dart';     // Assurez-vous que le fichier s'appelle bien page_dette.dart
                              // et qu'il exporte DettesPage

// Import conditionnel pour la base locale
import 'db_init_stub.dart'
    if (dart.library.html) 'db_init_web.dart'
    if (dart.library.io) 'db_init_io.dart';

// Service d'échéances (assurez-vous que le fichier existe)
import 'echeance_service.dart';

// Base de données locale (si vous utilisez AppDatabase)
import 'database/app_database.dart';

void main() async {
  // Nécessaire pour les plugins asynchrones
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Localisation française
    await initializeDateFormatting('fr_FR', null);

    // 2. Initialisation Supabase
    await Supabase.initialize(
      url: 'https://hujnwvmaerycpbhbeotk.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
               '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1'
               'am53dm1hZXJ5Y3BiaGJlb3RrIiwicm9sZSI6Im'
               'Fub24iLCJpYXQiOjE3NzU4NTA2MDAsImV4cCI6'
               'MjA5MTQyNjYwMH0.80VxMKN-_WKfU--hAe85D7'
               's-v_TdKTN-bsQXi9ZxmpU',
    );

    // 3. Base de données locale (SQLite / IndexedDB)
    await initDatabase();

    // 4. Initialisation des préférences partagées + AppDatabase (si nécessaire)
    await AppDatabase.init();

    // 5. Service d'échéances – vérification immédiate + périodique
    final echeanceService = EcheanceService();
    await echeanceService.verifierEcheances();
    // Timer.periodic nécessite 'dart:async' – déjà importé via 'dart:async'
    Timer.periodic(const Duration(hours: 12), (_) {
      echeanceService.verifierEcheances();
    });

    // 6. Lire les préférences pour choisir la page de démarrage
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('is_registered') ?? false;
    final isLoggedIn   = prefs.getBool('is_logged_in')  ?? false;
    final id           = prefs.getInt('commercant_id')   ?? 0;
    final nom          = prefs.getString('nom_commercant') ?? '';
    final boutique     = prefs.getString('nom_boutique')   ?? '';
    final ville        = prefs.getString('ville')          ?? '';

    Widget startPage;

    if (!isRegistered) {
      startPage = const RegisterPage();
    } else if (!isLoggedIn) {
      startPage = LoginPage(
        commercantId:  id,
        nomCommercant: nom,
        nomBoutique:   boutique,
        ville:         ville,
      );
    } else {
      startPage = DashboardPage(
        commercantId:  id,
        nomCommercant: nom,
        nomBoutique:   boutique,
        ville:         ville,
      );
    }

    // Lancer l'application
    runApp(MyApp(startPage: startPage));
  } catch (e, stack) {
    // En cas d'erreur fatale au démarrage, afficher une page d'erreur
    print('ERREUR FATALE : $e');
    print(stack);
    runApp(ErrorApp(e.toString()));
  }
}

// ========== APPLICATION PRINCIPALE ==========
class MyApp extends StatelessWidget {
  final Widget startPage;
  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Commerçant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6E56),
          primary:   const Color(0xFF0F6E56),
        ),
        useMaterial3: true,
      ),
      home: startPage,
    );
  }
}

// ========== PAGE D'ERREUR (secours) ==========
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp(this.error);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Erreur au démarrage',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}