import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Pour kIsWeb
import 'package:sqflite/sqflite.dart'; // Ajoute ça !
import 'register.dart';
import 'login.dart';
import 'dashbord.dart'; // Attention à l'orthographe (dashboard.dart ?)
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
if (kIsWeb) {
    // Initialise la base de données pour le navigateur (Edge/Chrome)
    databaseFactory = databaseFactoryFfiWeb;
  }
  // -------------
  // 1. Initialiser Supabase en premier
  await Supabase.initialize(
    url: 'https://hujnwvmaerycpbhbeotk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1am53dm1hZXJ5Y3BiaGJlb3RrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NTA2MDAsImV4cCI6MjA5MTQyNjYwMH0.80VxMKN-_WKfU--hAe85D7s-v_TdKTN-bsQXi9ZxmpU',
  );

  final prefs = await SharedPreferences.getInstance();

  // 2. Récupérer l'état et les infos stockées
  final bool isRegistered = prefs.getBool('is_registered') ?? false;
  final bool isLoggedIn   = prefs.getBool('is_logged_in')  ?? false;
  
  // Données dynamiques
  final int id       = prefs.getInt('commercant_id')     ?? 0;
  final String nom   = prefs.getString('nom_commercant') ?? '';
  final String boutique = prefs.getString('nom_boutique')   ?? '';
  final String ville = prefs.getString('ville')          ?? '';

  Widget startPage;

  if (!isRegistered) {
    // Cas 1 : Jamais inscrit
    startPage = const RegisterPage();
  } else if (!isLoggedIn) {
    // Cas 2 : Inscrit mais session expirée (demande du PIN)
    // On envoie les données pour que la LoginPage sache QUI se connecte
    startPage = LoginPage(
      commercantId: id,
      nomCommercant: nom,
      nomBoutique: boutique,
      ville: ville,
    );
  } else {
    // Cas 3 : Déjà connecté
    startPage = DashboardPage(
      commercantId: id,
      nomCommercant: nom,
      nomBoutique: boutique,
      ville: ville,
    );
  }

  runApp(MyApp(startPage: startPage));
}

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
          primary: const Color(0xFF0F6E56),
        ),
        useMaterial3: true,
      ),
      home: startPage,
    );
  }
}