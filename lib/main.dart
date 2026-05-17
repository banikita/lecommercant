import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'dashbord.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hujnwvmaerycpbhbeotk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1'
        'am53dm1hZXJ5Y3BiaGJlb3RrIiwicm9sZSI6Im'
        'Fub24iLCJpYXQiOjE3NzU4NTA2MDAsImV4cCI6'
        'MjA5MTQyNjYwMH0.80VxMKN-_WKfU--hAe85D7'
        's-v_TdKTN-bsQXi9ZxmpU',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Commerçant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F6E56),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: FutureBuilder<bool>(
        future: _checkLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUserData(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  final data = userSnapshot.data!;
                  return DashboardPage(
                    commercantId: data['id'],
                    nomCommercant: data['nom_commercant'],
                    nomBoutique: data['nom_boutique'],
                    ville: data['ville'],
                  );
                }
                return const LoginPage();
              },
            );
          }
          return const LoginPage();
        },
      ),
    );
  }

  Future<bool> _checkLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('commercant_id');
    final nom = prefs.getString('nom_commercant');
    final boutique = prefs.getString('nom_boutique');
    final ville = prefs.getString('ville');
    if (id == null || nom == null || boutique == null || ville == null)
      return null;
    return {
      'id': id,
      'nom_commercant': nom,
      'nom_boutique': boutique,
      'ville': ville,
    };
  }
}
