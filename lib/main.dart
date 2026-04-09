import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart';
import 'login.dart';
import 'dashbord.dart';

// ══════════════════════════════════════════════════════════════
//  POINT D'ENTRÉE
//  Logique :
//    1. Jamais installé      → RegisterPage
//    2. Compte créé, app fermée → LoginPage (PIN)
//    3. Déjà connecté (session active) → DashboardPage
// ══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Clés stockées localement
  final bool isRegistered = prefs.getBool('is_registered') ?? false;
  final bool isLoggedIn   = prefs.getBool('is_logged_in')  ?? false;

  Widget startPage;
  if (!isRegistered) {
    startPage = const RegisterPage();          // 1re installation
  } else if (!isLoggedIn) {
    startPage = const LoginPage();            // Compte existant → PIN
  } else {
    // Session encore active (rare, mais possible en dev)
    final nom      = prefs.getString('nom_commercant') ?? '';
    final boutique = prefs.getString('nom_boutique')   ?? '';
    final ville    = prefs.getString('ville')          ?? '';
    startPage = DashboardPage(
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