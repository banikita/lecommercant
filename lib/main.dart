import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:le_commercant/database/app_database.dart';
import 'register.dart';
import 'login.dart';
import 'dashbord.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // 1. Supabase
  await Supabase.initialize(
    url: 'https://hujnwvmaerycpbhbeotk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1am53dm1hZXJ5Y3BiaGJlb3RrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NTA2MDAsImV4cCI6MjA5MTQyNjYwMH0.80VxMKN-_WKfU--hAe85D7s-v_TdKTN-bsQXi9ZxmpU',
  );

  // 2. Initialiser AppDatabase (SharedPreferences) AVANT tout le reste
  await AppDatabase.init();

  // 3. Lire l'état de session
  final prefs = await SharedPreferences.getInstance();
  final bool isRegistered = prefs.getBool('is_registered') ?? false;
  final bool isLoggedIn   = prefs.getBool('is_logged_in')  ?? false;

  final int    id       = prefs.getInt('commercant_id')     ?? 0;
  final String nom      = prefs.getString('nom_commercant') ?? '';
  final String boutique = prefs.getString('nom_boutique')   ?? '';
  final String ville    = prefs.getString('ville')          ?? '';

  Widget startPage;

  if (!isRegistered) {
    startPage = const RegisterPage();
  } else if (!isLoggedIn) {
    startPage = LoginPage(
      commercantId: id,
      nomCommercant: nom,
      nomBoutique: boutique,
      ville: ville,
    );
  } else {
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
