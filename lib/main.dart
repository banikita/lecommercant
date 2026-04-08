import 'package:flutter/material.dart';
import 'register.dart';
import 'login.dart';
 
void main() {
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecommercant ',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}