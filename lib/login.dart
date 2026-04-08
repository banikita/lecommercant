import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}


class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("Login Page")),
    );
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("PIN SCREEN ACTIF"),
        ),
      ),
    );
  }
}

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  final int _pinLength = 4;

  void _onKeyPressed(String key) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += key;
      });

      if (_pin.length == _pinLength) {
        _validatePin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _validatePin() {
    if (_pin == '1234') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code correct !'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code incorrect, réessayez.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _pin = '';
      });
    }
  }

  void _onForgotPin() {
   
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code oublié'),
        content: const Text('Veuillez contacter le support.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // ==============================
            // REMPLACEZ ICI VOTRE LOGO
            // ==============================
            Image.asset(
              'lib/assets/logo.png', // ← Mettez le chemin de votre logo
              width: 100,
              height: 100,
            ),
            // Si vous n'avez pas encore ajouté le logo dans assets,
            // utilisez temporairement ce bloc à la place :
            Container(
               width: 100,
              height: 100,
               decoration: BoxDecoration(
                 color: Color(0xFFE8F5E9),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Icon(Icons.lock, size: 50, color: Color(0xFF2E7D32)),
             ),

            const SizedBox(height: 60),

            // Indicateurs de points (PIN)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? const Color(0xFF2E7D32)      // Rempli = vert
                        : const Color(0xFFA5D6A7),     // Vide = vert clair
                  ),
                );
              }),
            ),

            const SizedBox(height: 50),

          Expanded(
  child: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 8),
          _buildBottomRow(),
        ],
      ),
    ),
  ),
),
            // Lien "Oublié votre code secret ?"
            GestureDetector(
              onTap: _onForgotPin,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: Text(
                  'Oublié votre code secret ?',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(width: 80, height: 80), // Espace vide à gauche
        _buildKey('0'),
        _buildDeleteKey(),
      ],
    );
  }

  Widget _buildKey(String value) {
    return GestureDetector(
      onTap: () => _onKeyPressed(value),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_outlined,
          size: 28,
          color: Colors.black54,
        ),
      ),
    );
  }
}